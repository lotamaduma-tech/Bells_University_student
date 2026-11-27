begin;

-- Allow administrator alerts to use the same push outbox as student notifications.
-- Account-security notices remain in-app only until their delivery policy is explicitly enabled.
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

-- Notify every administrator when a student profile is created.
create or replace function public.markio_notify_admin_registration()
returns trigger
language plpgsql
security definer
set search_path=''
as $fn$
declare admin_row record;
begin
  for admin_row in
    select user_id from public.bellsconnect_admins
  loop
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
create or replace function public.markio_notify_admin_submission()
returns trigger
language plpgsql
security definer
set search_path=''
as $fn$
declare admin_row record; title_text text; body_text text; path_text text; kind_text text;
begin
  if tg_table_name='seller_applications' then
    title_text:='New seller application';
    body_text:='A student submitted a seller application for review.';
    path_text:='/admin/sellers?application='||new.id::text;
    kind_text:='seller_application';
  elsif tg_table_name='marketplace_listings' then
    title_text:='New listing submitted';
    body_text:='A seller submitted a new product or service listing for review.';
    path_text:='/admin';
    kind_text:='new_listing';
  elsif tg_table_name='marketplace_account_requests' then
    title_text:='New account request';
    body_text:='A user submitted an account request.';
    path_text:='/admin/requests?request='||new.id::text;
    kind_text:='account_request';
  elsif tg_table_name='listing_reports' then
    title_text:='New listing report';
    body_text:='A marketplace listing was reported.';
    path_text:='/admin/reports?report='||new.id::text;
    kind_text:='listing_report';
  elsif tg_table_name='bellsconnect_feedback' then
    title_text:='New support request';
    body_text:='A user submitted a support request.';
    path_text:='/admin/support?request='||new.id::text;
    kind_text:='support_request';
  elsif tg_table_name='premium_interest' then
    title_text:='Premium early access request';
    body_text:='A user requested MARKIO Premium early access.';
    path_text:='/admin/premium?user='||new.user_id::text;
    kind_text:='premium_interest';
  else
    return new;
  end if;

  for admin_row in select user_id from public.bellsconnect_admins loop
    perform public.markio_emit_notification(
      admin_row.user_id,
      null,
      kind_text,
      'admin',
      title_text,
      body_text,
      path_text,
      tg_table_name||':'||new.id::text||':'||admin_row.user_id::text,
      jsonb_build_object('record_id',new.id,'source_table',tg_table_name)
    );
  end loop;
  return new;
end;
$fn$;
revoke all on function public.markio_notify_admin_submission() from public,anon,authenticated;

drop trigger if exists markio_admin_new_listing on public.marketplace_listings;
create trigger markio_admin_new_listing
after insert on public.marketplace_listings
for each row
when (new.status='pending')
execute function public.markio_notify_admin_submission();

commit;
