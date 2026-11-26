alter table public.bellsconnect_admins add column if not exists role text not null default 'admin' check (role in ('admin','super_admin'));
update public.bellsconnect_admins set role=case when user_id='8142a2f9-5c73-4b94-86ed-b9e5192359fc'::uuid then 'super_admin' else 'admin' end;
insert into public.bellsconnect_admins(user_id,role) values ('8142a2f9-5c73-4b94-86ed-b9e5192359fc'::uuid,'super_admin') on conflict(user_id) do update set role='super_admin';
create table if not exists public.marketplace_admin_role_audit(id uuid primary key default gen_random_uuid(),actor_id uuid not null references auth.users(id),target_user_id uuid not null references auth.users(id),action text not null check(action in ('promote','demote')),created_at timestamptz not null default now());
alter table public.marketplace_admin_role_audit enable row level security;
drop policy if exists "Admins read role audit" on public.marketplace_admin_role_audit;
create policy "Admins read role audit" on public.marketplace_admin_role_audit for select to authenticated using(exists(select 1 from public.bellsconnect_admins a where a.user_id=(select auth.uid())));
revoke insert,update,delete on public.bellsconnect_admins from anon,authenticated;
revoke all on public.marketplace_admin_role_audit from anon,authenticated;
grant select on public.marketplace_admin_role_audit to authenticated;
create or replace function public.manage_marketplace_admin_role(target_user_id uuid, action text) returns text language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is distinct from '8142a2f9-5c73-4b94-86ed-b9e5192359fc'::uuid then raise exception 'Only the MARKIO founder can manage administrator roles' using errcode='42501'; end if;
 if target_user_id is null or target_user_id='8142a2f9-5c73-4b94-86ed-b9e5192359fc'::uuid then raise exception 'The founder role cannot be changed' using errcode='22023'; end if;
 if action='promote' then
  if not exists(select 1 from auth.users u where u.id=target_user_id) then raise exception 'User not found' using errcode='P0002'; end if;
  insert into public.bellsconnect_admins(user_id,role) values(target_user_id,'admin') on conflict(user_id) do update set role='admin';
 elsif action='demote' then
  delete from public.bellsconnect_admins where user_id=target_user_id and role='admin';
 else raise exception 'Unsupported role action' using errcode='22023';
 end if;
 insert into public.marketplace_admin_role_audit(actor_id,target_user_id,action) values((select auth.uid()),target_user_id,action);
 return action;
end; $$;
revoke all on function public.manage_marketplace_admin_role(uuid,text) from public,anon;
grant execute on function public.manage_marketplace_admin_role(uuid,text) to authenticated;
create or replace function public.admin_list_marketplace_users(search_text text default null)
returns table(user_id uuid,display_name text,username text,admin_role text,seller_status text)
language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.bellsconnect_admins a where a.user_id=(select auth.uid())) then raise exception 'Administrator access required' using errcode='42501'; end if;
 return query select p.id,p.display_name,p.username,a.role,sp.status from public.profiles p left join public.bellsconnect_admins a on a.user_id=p.id left join public.seller_profiles sp on sp.user_id=p.id
 where search_text is null or p.display_name ilike '%'||search_text||'%' or p.username ilike '%'||search_text||'%' order by p.display_name nulls last limit 100;
end; $$;
revoke all on function public.admin_list_marketplace_users(text) from public,anon;
grant execute on function public.admin_list_marketplace_users(text) to authenticated;
drop policy if exists "Approved sellers create pending listings" on public.marketplace_listings;
create policy "Approved sellers publish listings" on public.marketplace_listings for insert to authenticated with check(seller_id=(select auth.uid()) and status='approved' and exists(select 1 from public.seller_profiles s where s.user_id=(select auth.uid()) and s.status='approved'));
drop policy if exists "Owners update own listings" on public.marketplace_listings;
create policy "Owners update own listings" on public.marketplace_listings for update to authenticated using(seller_id=(select auth.uid())) with check(seller_id=(select auth.uid()) and status in ('approved','paused'));
drop policy if exists "Users insert own marketplace preferences" on public.marketplace_preferences;
create policy "Users insert own marketplace preferences" on public.marketplace_preferences for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists "Users update own marketplace preferences" on public.marketplace_preferences;
create policy "Users update own marketplace preferences" on public.marketplace_preferences for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
