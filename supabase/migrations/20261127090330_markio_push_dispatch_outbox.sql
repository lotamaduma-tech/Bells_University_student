begin;

create extension if not exists pg_net;
create extension if not exists pg_cron;
create schema if not exists private;

create table if not exists private.markio_push_dispatch_jobs (
  notification_id uuid primary key references public.markio_notifications(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  dispatch_token text not null,
  status text not null default 'pending'
    check (status in ('pending','processing','retry','delivered','skipped','failed')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  delivered_at timestamptz
);
create index if not exists markio_push_dispatch_due_idx
  on private.markio_push_dispatch_jobs(status,next_attempt_at)
  where status in ('pending','retry','processing');

create table if not exists private.markio_push_deliveries (
  notification_id uuid not null references public.markio_notifications(id) on delete cascade,
  subscription_id uuid not null references public.markio_push_subscriptions(id) on delete cascade,
  delivered_at timestamptz not null default now(),
  primary key(notification_id,subscription_id)
);

alter table private.markio_push_dispatch_jobs enable row level security;
alter table private.markio_push_deliveries enable row level security;
revoke all on schema private from public, anon, authenticated;
revoke all on private.markio_push_dispatch_jobs from public, anon, authenticated, service_role;
revoke all on private.markio_push_deliveries from public, anon, authenticated, service_role;

create or replace function public.markio_claim_push_job(
  p_notification_id uuid,
  p_dispatch_token text
)
returns table(recipient_id uuid,attempt_count integer)
language plpgsql
security definer
set search_path=''
as $fn$
begin
  return query
  update private.markio_push_dispatch_jobs j
  set status='processing',
      attempt_count=j.attempt_count+1,
      updated_at=now()
  where j.notification_id=p_notification_id
    and j.dispatch_token=p_dispatch_token
    and (
      (j.status in ('pending','retry') and j.next_attempt_at<=now())
      or (j.status='processing' and j.updated_at < now()-interval '2 minutes')
    )
  returning j.recipient_id,j.attempt_count;
end;
$fn$;
revoke all on function public.markio_claim_push_job(uuid,text) from public,anon,authenticated;
grant execute on function public.markio_claim_push_job(uuid,text) to service_role;

create or replace function public.markio_get_push_delivery_subscription_ids(p_notification_id uuid)
returns uuid[]
language sql
security definer
set search_path=''
as $fn$
  select coalesce(array_agg(d.subscription_id),array[]::uuid[])
  from private.markio_push_deliveries d
  where d.notification_id=p_notification_id;
$fn$;
revoke all on function public.markio_get_push_delivery_subscription_ids(uuid) from public,anon,authenticated;
grant execute on function public.markio_get_push_delivery_subscription_ids(uuid) to service_role;

create or replace function public.markio_record_push_delivery(
  p_notification_id uuid,
  p_subscription_id uuid
)
returns void
language plpgsql
security definer
set search_path=''
as $fn$
begin
  insert into private.markio_push_deliveries(notification_id,subscription_id)
  values(p_notification_id,p_subscription_id)
  on conflict(notification_id,subscription_id) do nothing;
end;
$fn$;
revoke all on function public.markio_record_push_delivery(uuid,uuid) from public,anon,authenticated;
grant execute on function public.markio_record_push_delivery(uuid,uuid) to service_role;

create or replace function public.markio_finish_push_job(
  p_notification_id uuid,
  p_dispatch_token text,
  p_status text,
  p_error text default null,
  p_retry_delay_seconds integer default 60
)
returns boolean
language plpgsql
security definer
set search_path=''
as $fn$
begin
  if p_status not in ('delivered','skipped','retry','failed') then
    raise exception 'Invalid push job status';
  end if;

  update private.markio_push_dispatch_jobs j
  set status=case
        when p_status='retry' and j.attempt_count>=6 then 'failed'
        else p_status
      end,
      next_attempt_at=case
        when p_status='retry' and j.attempt_count<6
          then now()+make_interval(secs=>greatest(30,least(3600,coalesce(p_retry_delay_seconds,60))))
        else j.next_attempt_at
      end,
      last_error=left(coalesce(p_error,''),500),
      delivered_at=case when p_status='delivered' then now() else j.delivered_at end,
      dispatch_token=case
        when p_status in ('delivered','skipped','failed') or (p_status='retry' and j.attempt_count>=6)
          then ''
        else j.dispatch_token
      end,
      updated_at=now()
  where j.notification_id=p_notification_id
    and j.dispatch_token=p_dispatch_token
    and j.status='processing';

  return found;
end;
$fn$;
revoke all on function public.markio_finish_push_job(uuid,text,text,text,integer) from public,anon,authenticated;
grant execute on function public.markio_finish_push_job(uuid,text,text,text,integer) to service_role;

create or replace function private.dispatch_markio_push_retries()
returns void
language plpgsql
security definer
set search_path=''
as $fn$
declare job record;
begin
  for job in
    select j.notification_id,j.dispatch_token
    from private.markio_push_dispatch_jobs j
    where
      (j.status in ('pending','retry') and j.next_attempt_at<=now())
      or (j.status='processing' and j.updated_at < now()-interval '2 minutes')
    order by j.next_attempt_at
    limit 100
  loop
    begin
      perform net.http_post(
        url:='https://gxiirebjidkgucucegzn.supabase.co/functions/v1/send-markio-push',
        headers:=jsonb_build_object(
          'Content-Type','application/json',
          'apikey','sb_publishable_syLl1qVSi6ZWgz3seVB2qQ_sPCiY2un'
        ),
        body:=jsonb_build_object(
          'notificationId',job.notification_id,
          'dispatchToken',job.dispatch_token
        ),
        timeout_milliseconds:=10000
      );
    exception when others then
      update private.markio_push_dispatch_jobs
      set status='retry',
          next_attempt_at=now()+interval '1 minute',
          last_error=left(SQLERRM,500),
          updated_at=now()
      where notification_id=job.notification_id;
    end;
  end loop;
end;
$fn$;
revoke all on function private.dispatch_markio_push_retries() from public,anon,authenticated,service_role;

create or replace function private.enqueue_markio_push()
returns trigger
language plpgsql
security definer
set search_path=''
as $fn$
declare token text;
begin
  if new.category in ('admin','account_security') then
    return new;
  end if;

  token:=encode(gen_random_bytes(32),'hex');
  insert into private.markio_push_dispatch_jobs(notification_id,recipient_id,dispatch_token)
  values(new.id,new.recipient_id,token)
  on conflict(notification_id) do nothing;

  if not found then
    return new;
  end if;

  begin
    perform net.http_post(
      url:='https://gxiirebjidkgucucegzn.supabase.co/functions/v1/send-markio-push',
      headers:=jsonb_build_object(
        'Content-Type','application/json',
        'apikey','sb_publishable_syLl1qVSi6ZWgz3seVB2qQ_sPCiY2un'
      ),
      body:=jsonb_build_object(
        'notificationId',new.id,
        'dispatchToken',token
      ),
      timeout_milliseconds:=10000
    );
  exception when others then
    update private.markio_push_dispatch_jobs
    set status='retry',
        next_attempt_at=now()+interval '1 minute',
        last_error=left(SQLERRM,500),
        updated_at=now()
    where notification_id=new.id;
  end;

  return new;
end;
$fn$;
revoke all on function private.enqueue_markio_push() from public,anon,authenticated,service_role;

drop trigger if exists markio_enqueue_push_after_notification on public.markio_notifications;
create trigger markio_enqueue_push_after_notification
after insert on public.markio_notifications
for each row execute function private.enqueue_markio_push();

do $fn$
declare job_id bigint;
begin
  for job_id in select jobid from cron.job where jobname='markio-push-retry' loop
    perform cron.unschedule(job_id);
  end loop;
  perform cron.schedule(
    'markio-push-retry',
    '* * * * *',
    'select private.dispatch_markio_push_retries();'
  );
end;
$fn$;

do $fn$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='markio_notifications'
  ) then
    alter publication supabase_realtime add table public.markio_notifications;
  end if;
end;
$fn$;

commit;
