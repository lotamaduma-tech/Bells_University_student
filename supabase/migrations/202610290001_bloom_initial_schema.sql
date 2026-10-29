-- Bloom: initial secure campus dating schema
-- Apply only to a dedicated Bloom Supabase project.
begin;

create extension if not exists pgcrypto;

create type public.profile_status as enum ('incomplete','active','paused','removed');
create type public.verification_status as enum ('unverified','pending','verified','rejected');
create type public.relationship_intention as enum ('meaningful_relationship','dating_with_intention','open_to_relationship','see_where_it_goes');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 50),
  age smallint not null default 18 check (age >= 18 and age <= 120),
  bio text not null default '' check (char_length(bio) <= 500),
  photo_path text,
  interests text[] not null default '{}' check (cardinality(interests) <= 20),
  sports text[] not null default '{}' check (cardinality(sports) <= 15),
  likes text[] not null default '{}' check (cardinality(likes) <= 30),
  dislikes text[] not null default '{}' check (cardinality(dislikes) <= 30),
  relationship_intention public.relationship_intention,
  university text not null default 'Bells University of Technology',
  affiliation_status public.verification_status not null default 'unverified',
  status public.profile_status not null default 'incomplete',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Date of birth is private and never exposed through the public discovery profile row.
create table public.private_profile_data (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  date_of_birth date not null check (date_of_birth <= (current_date - interval '18 years')::date),
  created_at timestamptz not null default now()
);

create table public.profile_prompts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  prompt text not null check (char_length(prompt) between 3 and 120),
  answer text not null check (char_length(answer) between 1 and 300),
  created_at timestamptz not null default now()
);

create table public.likes (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  decision text not null check (decision in ('like','pass')),
  created_at timestamptz not null default now(),
  unique(actor_id,target_id),
  check (actor_id <> target_id)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profiles(id) on delete cascade,
  user_high uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_low < user_high),
  unique(user_low,user_high)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(conversation_id,user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 3000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);
create index messages_conversation_created_idx on public.messages(conversation_id, created_at desc);
create index likes_target_decision_idx on public.likes(target_id, decision);
create index profiles_status_created_idx on public.profiles(status, created_at desc);

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id),
  check(blocker_id <> blocked_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  reason text not null check (char_length(trim(reason)) between 3 and 100),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);

create table public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  min_age smallint not null default 18 check (min_age >= 18 and min_age <= 100),
  max_age smallint not null default 35 check (max_age >= min_age and max_age <= 100),
  intentions public.relationship_intention[] not null default '{}',
  verified_only boolean not null default false,
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

-- The profile row is created after auth signup with minimal, untrusted metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  dob date;
  name_value text;
begin
  name_value := nullif(trim(coalesce(new.raw_user_meta_data ->> 'display_name','')), '');
  if name_value is null then name_value := 'New member'; end if;
  begin
    dob := (new.raw_user_meta_data ->> 'date_of_birth')::date;
  exception when others then
    dob := null;
  end;
  if dob is null or dob > (current_date - interval '18 years')::date then
    raise exception 'Bloom is available only to people aged 18 or older.';
  end if;
  insert into public.profiles(id, display_name, status)
  values (new.id, left(name_value,50), 'incomplete');
  insert into public.private_profile_data(user_id,date_of_birth) values(new.id,dob);
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Profile reads expose only active profiles to other signed-in members; owners can read their own incomplete profile.
alter table public.profiles enable row level security;
alter table public.private_profile_data enable row level security;
alter table public.profile_prompts enable row level security;
alter table public.likes enable row level security;
alter table public.matches enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.user_preferences enable row level security;

-- Security-definer helper avoids RLS hiding the other member's block record.
create or replace function public.is_blocked_between(user_a uuid,user_b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.blocks b
    where (b.blocker_id=user_a and b.blocked_id=user_b)
       or (b.blocker_id=user_b and b.blocked_id=user_a));
$$;
revoke all on function public.is_blocked_between(uuid,uuid) from public;
grant execute on function public.is_blocked_between(uuid,uuid) to authenticated;

create policy "owners can read private birth date" on public.private_profile_data
for select to authenticated using(user_id=(select auth.uid()));

create policy "profile visible to owner or active members" on public.profiles
for select to authenticated using (
  id = (select auth.uid()) or (
    status = 'active' and not public.is_blocked_between((select auth.uid()),profiles.id)
  )
);
create policy "owner inserts own profile" on public.profiles for insert to authenticated
with check (id = (select auth.uid()));
create policy "owner updates own profile" on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- Prevent clients from changing moderation/verification state or creating arbitrary profile rows.
revoke insert, update on public.profiles from authenticated;
grant update(display_name,bio,photo_path,interests,sports,likes,dislikes,relationship_intention,updated_at) on public.profiles to authenticated;

create policy "prompts visible for active profiles" on public.profile_prompts for select to authenticated
using (exists(select 1 from public.profiles p where p.id=user_id and (p.id=(select auth.uid()) or p.status='active')));
create policy "owner manages prompts" on public.profile_prompts for all to authenticated
using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));

create policy "participants see own likes" on public.likes for select to authenticated
using (actor_id=(select auth.uid()) or target_id=(select auth.uid()));
create policy "users create own decisions" on public.likes for insert to authenticated
with check (actor_id=(select auth.uid()) and target_id<>(select auth.uid())
  and exists(select 1 from public.profiles t where t.id=target_id and t.status='active')
  and not exists(select 1 from public.blocks b where
    (b.blocker_id=actor_id and b.blocked_id=target_id) or
    (b.blocker_id=target_id and b.blocked_id=actor_id)));
create policy "users update own decisions" on public.likes for update to authenticated
using(actor_id=(select auth.uid())) with check(actor_id=(select auth.uid()));
create policy "users delete own decisions" on public.likes for delete to authenticated
using(actor_id=(select auth.uid()));

create policy "match participants can view matches" on public.matches for select to authenticated
using(user_low=(select auth.uid()) or user_high=(select auth.uid()));
-- Match creation is intentionally performed by a trusted database function, not arbitrary client inserts.

create or replace function public.is_conversation_member(conversation_id_value uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.conversation_members cm
    where cm.conversation_id=conversation_id_value and cm.user_id=(select auth.uid()));
$$;
revoke all on function public.is_conversation_member(uuid) from public;
grant execute on function public.is_conversation_member(uuid) to authenticated;

create policy "conversation members can view conversations" on public.conversations for select to authenticated
using(public.is_conversation_member(id));
create policy "members see conversation membership" on public.conversation_members for select to authenticated
using(public.is_conversation_member(conversation_id));
-- Membership creation is reserved for the trusted matching function.
create policy "members read messages" on public.messages for select to authenticated
using(public.is_conversation_member(conversation_id));
create policy "members send messages to matched conversations" on public.messages for insert to authenticated
with check(sender_id=(select auth.uid())
  and public.is_conversation_member(conversation_id)
  and not exists(
    select 1 from public.conversation_members other
    where other.conversation_id=messages.conversation_id and other.user_id<>(select auth.uid())
      and public.is_blocked_between((select auth.uid()),other.user_id)
  ));
create policy "sender edits own messages" on public.messages for update to authenticated
using(sender_id=(select auth.uid())) with check(sender_id=(select auth.uid()));
create policy "sender deletes own messages" on public.messages for delete to authenticated
using(sender_id=(select auth.uid()));

create policy "users manage blocks they create" on public.blocks for all to authenticated
using(blocker_id=(select auth.uid())) with check(blocker_id=(select auth.uid()) and blocked_id<>(select auth.uid()));
create policy "users create reports" on public.reports for insert to authenticated
with check(reporter_id=(select auth.uid()) and (reported_user_id is null or reported_user_id<>(select auth.uid())));
create policy "reporters see own reports" on public.reports for select to authenticated
using(reporter_id=(select auth.uid()));
create policy "owners manage own preferences" on public.user_preferences for all to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));

-- Complete onboarding through a trusted function; clients cannot set status or verification fields directly.
create or replace function public.complete_profile(
  display_name_value text,
  bio_value text,
  photo_path_value text,
  interests_value text[],
  sports_value text[],
  likes_value text[],
  dislikes_value text[],
  intention_value public.relationship_intention
)
returns public.profiles language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  result public.profiles;
begin
  if actor is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from auth.users u where u.id=actor and u.email_confirmed_at is not null) then
    raise exception 'Verify your email before completing your Bloom profile';
  end if;
  if char_length(trim(coalesce(display_name_value,''))) not between 2 and 50 then raise exception 'Name must be 2 to 50 characters'; end if;
  if char_length(coalesce(bio_value,'')) > 500 then raise exception 'Bio is too long'; end if;
  if coalesce(cardinality(interests_value),0)>20 or coalesce(cardinality(sports_value),0)>15
    or coalesce(cardinality(likes_value),0)>30 or coalesce(cardinality(dislikes_value),0)>30 then
    raise exception 'Too many profile selections';
  end if;
  if photo_path_value is null or split_part(photo_path_value,'/',1) <> actor::text then raise exception 'Upload a profile photo to your own folder'; end if;
  if not exists(select 1 from public.private_profile_data pp where pp.user_id=actor and pp.date_of_birth <= (current_date - interval '18 years')::date) then
    raise exception 'Bloom is available only to people aged 18 or older';
  end if;
  update public.profiles set
    age=(select extract(year from age(current_date,pp.date_of_birth))::smallint from public.private_profile_data pp where pp.user_id=actor),
    display_name=trim(display_name_value),
    bio=coalesce(bio_value,''),
    photo_path=photo_path_value,
    interests=coalesce(interests_value,'{}'),
    sports=coalesce(sports_value,'{}'),
    likes=coalesce(likes_value,'{}'),
    dislikes=coalesce(dislikes_value,'{}'),
    relationship_intention=intention_value,
    status='active',
    updated_at=now()
  where id=actor returning * into result;
  return result;
end;
$$;
revoke all on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) from public;
grant execute on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) to authenticated;

-- Atomic like/match creation. A mutual match creates one conversation and both membership rows.
create or replace function public.record_like(target_user uuid, decision_value text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  low_id uuid;
  high_id uuid;
  match_row uuid;
  convo uuid;
begin
  if actor is null then raise exception 'Authentication required'; end if;
  if target_user is null or target_user=actor then raise exception 'Invalid target'; end if;
  if decision_value not in ('like','pass') then raise exception 'Invalid decision'; end if;
  if not exists(select 1 from public.profiles where id=target_user and status='active') then raise exception 'Profile unavailable'; end if;
  if exists(select 1 from public.blocks b where (b.blocker_id=actor and b.blocked_id=target_user) or (b.blocker_id=target_user and b.blocked_id=actor)) then raise exception 'Interaction unavailable'; end if;
  insert into public.likes(actor_id,target_id,decision) values(actor,target_user,decision_value)
  on conflict(actor_id,target_id) do update set decision=excluded.decision, created_at=now();
  if decision_value <> 'like' then return jsonb_build_object('matched',false); end if;
  if exists(select 1 from public.likes where actor_id=target_user and target_id=actor and decision='like') then
    low_id := least(actor,target_user);
    high_id := greatest(actor,target_user);
    insert into public.matches(user_low,user_high) values(low_id,high_id)
    on conflict(user_low,user_high) do nothing;
    select id into match_row from public.matches where user_low=low_id and user_high=high_id;
    insert into public.conversations(match_id) values(match_row) on conflict(match_id) do nothing;
    select id into convo from public.conversations where match_id=match_row;
    insert into public.conversation_members(conversation_id,user_id)
    values(convo,actor),(convo,target_user) on conflict do nothing;
    return jsonb_build_object('matched',true,'match_id',match_row,'conversation_id',convo);
  end if;
  return jsonb_build_object('matched',false);
end;
$$;
revoke all on function public.record_like(uuid,text) from public;
grant execute on function public.record_like(uuid,text) to authenticated;

-- Keep private user-uploaded photos in a private bucket. File path must start with the uploader's auth UUID.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('bloom-profile-photos','bloom-profile-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy "members can view photos for active profiles" on storage.objects
for select to authenticated using (
  bucket_id='bloom-profile-photos' and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or exists(select 1 from public.profiles p where p.id::text=(storage.foldername(name))[1] and p.status='active')
  )
);
create policy "users upload into their own photo folder" on storage.objects
for insert to authenticated with check(bucket_id='bloom-profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "users update own photo files" on storage.objects
for update to authenticated using(bucket_id='bloom-profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='bloom-profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "users delete own photo files" on storage.objects
for delete to authenticated using(bucket_id='bloom-profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);

-- Only message changes are enabled for Realtime initially; users must still pass RLS to read rows.
alter publication supabase_realtime add table public.messages;

commit;
