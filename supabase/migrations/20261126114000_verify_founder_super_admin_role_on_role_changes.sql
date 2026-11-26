create or replace function private.manage_marketplace_admin_role(target_user_id uuid, action text)
returns text language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is distinct from '8142a2f9-5c73-4b94-86ed-b9e5192359fc'::uuid
    or not exists(select 1 from public.bellsconnect_admins a where a.user_id=(select auth.uid()) and a.role='super_admin') then
   raise exception 'Only the MARKIO founder super admin can manage administrator roles' using errcode='42501';
 end if;
 if target_user_id is null or target_user_id='8142a2f9-5c73-4b94-86ed-b9e5192359fc'::uuid then raise exception 'The founder role cannot be changed' using errcode='22023'; end if;
 if action='promote' then
  if not exists(select 1 from auth.users u where u.id=target_user_id) then raise exception 'User not found' using errcode='P0002'; end if;
  insert into public.bellsconnect_admins(user_id,role) values(target_user_id,'admin') on conflict(user_id) do update set role='admin';
 elsif action='demote' then delete from public.bellsconnect_admins where user_id=target_user_id and role='admin';
 else raise exception 'Unsupported role action' using errcode='22023'; end if;
 insert into public.marketplace_admin_role_audit(actor_id,target_user_id,action) values((select auth.uid()),target_user_id,action);
 return action;
end; $$;
