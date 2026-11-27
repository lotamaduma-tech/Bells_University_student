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
