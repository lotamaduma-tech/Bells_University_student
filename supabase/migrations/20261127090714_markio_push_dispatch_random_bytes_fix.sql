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
      body:=jsonb_build_object('notificationId',new.id,'dispatchToken',token),
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
