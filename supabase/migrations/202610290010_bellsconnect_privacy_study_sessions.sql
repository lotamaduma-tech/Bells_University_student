-- BellsConnect privacy controls and study-session capacity.
begin;
create table if not exists public.campus_user_blocks (
 id uuid primary key default gen_random_uuid(),
 blocker_id uuid not null references public.profiles(id) on delete cascade,
 blocked_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 constraint campus_user_blocks_not_self check(blocker_id<>blocked_id),
 constraint campus_user_blocks_unique unique(blocker_id,blocked_id)
);
create index if not exists campus_user_blocks_blocked_idx on public.campus_user_blocks(blocked_id,blocker_id);
alter table public.campus_user_blocks enable row level security;
create policy "members read own blocks" on public.campus_user_blocks for select to authenticated using(blocker_id=(select auth.uid()));
create policy "members create own blocks" on public.campus_user_blocks for insert to authenticated with check(blocker_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=blocked_id and p.university='Bells University of Technology'));
create policy "members remove own blocks" on public.campus_user_blocks for delete to authenticated using(blocker_id=(select auth.uid()));
grant select,insert,delete on public.campus_user_blocks to authenticated;

create table if not exists public.campus_user_reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references public.profiles(id) on delete cascade,
 reported_id uuid not null references public.profiles(id) on delete cascade,
 reason text not null check(char_length(trim(reason)) between 2 and 80),
 details text not null default '' check(char_length(details)<=1000),
 status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')),
 created_at timestamptz not null default now(),
 constraint campus_user_reports_not_self check(reporter_id<>reported_id)
);
create index if not exists campus_user_reports_status_created_idx on public.campus_user_reports(status,created_at desc);
alter table public.campus_user_reports enable row level security;
create policy "members submit reports" on public.campus_user_reports for insert to authenticated with check(reporter_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=reported_id and p.university='Bells University of Technology'));
create policy "members read own submitted reports" on public.campus_user_reports for select to authenticated using(reporter_id=(select auth.uid()));
grant insert,select on public.campus_user_reports to authenticated;
revoke update,delete on public.campus_user_reports from anon,authenticated;

drop policy if exists "connected participants read campus messages" on public.campus_messages;
create policy "connected participants read campus messages" on public.campus_messages for select to authenticated using(
 exists(select 1 from public.campus_conversations c where c.id=conversation_id and (c.user_low=(select auth.uid()) or c.user_high=(select auth.uid())) and not public.is_blocked_between(c.user_low,c.user_high))
);
drop policy if exists "connected participants send campus messages" on public.campus_messages;
create policy "connected participants send campus messages" on public.campus_messages for insert to authenticated with check(
 sender_id=(select auth.uid()) and exists(select 1 from public.campus_conversations c where c.id=conversation_id
 and (c.user_low=(select auth.uid()) or c.user_high=(select auth.uid()))
 and exists(select 1 from public.campus_connections cn where cn.status='accepted' and ((cn.requester_id=c.user_low and cn.recipient_id=c.user_high) or (cn.requester_id=c.user_high and cn.recipient_id=c.user_low)))
 and not public.is_blocked_between(c.user_low,c.user_high))
);
drop policy if exists "connected participants can read campus conversations" on public.campus_conversations;
create policy "connected participants can read campus conversations" on public.campus_conversations for select to authenticated using(
 (user_low=(select auth.uid()) or user_high=(select auth.uid()))
 and exists(select 1 from public.campus_connections c where c.status='accepted' and ((c.requester_id=user_low and c.recipient_id=user_high) or (c.requester_id=user_high and c.recipient_id=user_low)))
 and not public.is_blocked_between(user_low,user_high)
);
drop policy if exists "connected participants can create campus conversations" on public.campus_conversations;
create policy "connected participants can create campus conversations" on public.campus_conversations for insert to authenticated with check(
 (user_low=(select auth.uid()) or user_high=(select auth.uid()))
 and exists(select 1 from public.campus_connections c where c.status='accepted' and ((c.requester_id=user_low and c.recipient_id=user_high) or (c.requester_id=user_high and c.recipient_id=user_low)))
 and exists(select 1 from public.profiles p where p.id=user_low and p.university='Bells University of Technology' and p.status='active')
 and exists(select 1 from public.profiles p where p.id=user_high and p.university='Bells University of Technology' and p.status='active')
 and not public.is_blocked_between(user_low,user_high)
);

alter table public.campus_meetups add column if not exists subject text not null default 'General study';
alter table public.campus_meetups add column if not exists max_participants integer not null default 6;
alter table public.campus_meetups drop constraint if exists campus_meetups_max_participants_check;
alter table public.campus_meetups add constraint campus_meetups_max_participants_check check(max_participants between 2 and 30);
alter table public.campus_meetups drop constraint if exists campus_meetups_subject_check;
alter table public.campus_meetups add constraint campus_meetups_subject_check check(char_length(trim(subject)) between 2 and 80);

create or replace function public.bellsconnect_enforce_study_capacity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare capacity integer; current_count integer;
begin
 select m.max_participants into capacity from public.campus_meetups m where m.id=new.meetup_id for update;
 if capacity is null then raise exception 'Study session not found'; end if;
 select count(*) into current_count from public.campus_meetup_members mm where mm.meetup_id=new.meetup_id;
 if current_count>=capacity then raise exception 'This study session is full'; end if;
 return new;
end; $$;
revoke all on function public.bellsconnect_enforce_study_capacity() from public,anon,authenticated;
drop trigger if exists bellsconnect_study_capacity on public.campus_meetup_members;
create trigger bellsconnect_study_capacity before insert on public.campus_meetup_members for each row execute function public.bellsconnect_enforce_study_capacity();
commit;