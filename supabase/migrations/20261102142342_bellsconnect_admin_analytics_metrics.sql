-- Admin-only aggregate analytics. This function returns counts only; it never exposes account rows.
create or replace function public.get_bellsconnect_admin_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  metrics jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.bellsconnect_admins a where a.user_id = auth.uid()
  ) then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'registered_students', (select count(*) from auth.users),
    'active_sellers', (select count(*) from public.seller_profiles where status = 'approved'),
    'active_users_30d', (select count(*) from auth.users where last_sign_in_at >= now() - interval '30 days'),
    'active_users_7d', (select count(*) from auth.users where last_sign_in_at >= now() - interval '7 days'),
    'total_listings', (select count(*) from public.marketplace_listings where status <> 'removed'),
    'approved_listings', (select count(*) from public.marketplace_listings where status = 'approved')
  ) into metrics;

  return metrics;
end;
$$;

revoke all on function public.get_bellsconnect_admin_metrics() from public, anon;
grant execute on function public.get_bellsconnect_admin_metrics() to authenticated;
