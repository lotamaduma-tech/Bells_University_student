-- Enforce the initial Bells-only community boundary and add useful FK indexes.
begin;
drop policy if exists "profile visible to owner or active members" on public.profiles;
create policy "Bells members can see Bells profiles" on public.profiles
for select to authenticated using (
 id=(select auth.uid()) or (
  status='active' and university='Bells University of Technology'
  and not public.is_blocked_between((select auth.uid()),profiles.id)
 )
);
drop policy if exists "members can view photos for active profiles" on storage.objects;
create policy "Bells members can view Bells profile photos" on storage.objects
for select to authenticated using (
 bucket_id='bloom-profile-photos' and (
  (storage.foldername(name))[1]=(select auth.uid())::text
  or exists(select 1 from public.profiles p where p.id::text=(storage.foldername(name))[1]
    and p.status='active' and p.university='Bells University of Technology')
 )
);
create index if not exists campus_conversations_user_high_idx on public.campus_conversations(user_high);
create index if not exists campus_meetup_members_user_id_idx on public.campus_meetup_members(user_id);
create index if not exists campus_meetups_host_id_idx on public.campus_meetups(host_id);
create index if not exists campus_messages_sender_id_idx on public.campus_messages(sender_id);
commit;