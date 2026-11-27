begin;

-- Allow admin-category notifications through the existing push outbox.
-- Account-security notifications remain in-app only.
create or replace function private.enqueue_markio_push()
returns trigger
language plpgsql
security definer
set search_path=''
as $fn$
declare token text;
begin
  if new.category = 'account_security' then
    return new;
  end if;

  token:=encode(extensions.gen_random_bytes(32),'hex');
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

-- Notify every MARKIO administrator when a student profile is created.
create or replace function public.markio_notify_admin_registration()
returns trigger
language plpgsql
security definer
set search_path=''
as $fn$
declare admin_row record;
begin
  for admin_row in select user_id from public.bellsconnect_admins loop
    perform public.markio_emit_notification(
      admin_row.user_id,
      null,
      'new_user_registration',
      'admin',
      'New student registered',
      'A new student account has joined MARKIO.',
      '/admin',
      'new_user_registration:'||new.id::text||':'||admin_row.user_id::text,
      jsonb_build_object('new_user_id',new.id)
    );
  end loop;
  return new;
end;
$fn$;
revoke all on function public.markio_notify_admin_registration() from public,anon,authenticated;

drop trigger if exists markio_admin_new_registration on public.profiles;
create trigger markio_admin_new_registration
after insert on public.profiles
for each row execute function public.markio_notify_admin_registration();

-- Notify administrators when a new listing enters the review queue.
drop trigger if exists markio_admin_new_listing on public.marketplace_listings;
create trigger markio_admin_new_listing
after insert on public.marketplace_listings
for each row
when (new.status='pending')
execute function public.markio_notify_admin_submission();

commit;