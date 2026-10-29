-- BellsConnect campus social network and 16+ age policy.
begin;
alter table public.profiles drop constraint if exists profiles_age_check;
alter table public.profiles add constraint profiles_age_check check (age >= 16 and age <= 120);
alter table public.private_profile_data drop constraint if exists private_profile_data_date_of_birth_check;
alter table public.private_profile_data add constraint private_profile_data_date_of_birth_check check (date_of_birth <= (current_date - interval '16 years')::date);
alter table public.user_preferences drop constraint if exists user_preferences_min_age_check;
alter table public.user_preferences add constraint user_preferences_min_age_check check (min_age >= 16 and min_age <= 100);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare dob date; name_value text;
begin
 name_value:=nullif(trim(coalesce(new.raw_user_meta_data->>'display_name','')),'');
 if name_value is null then name_value:='New member'; end if;
 begin dob:=(new.raw_user_meta_data->>'date_of_birth')::date; exception when others then dob:=null; end;
 if dob is null or dob>(current_date-interval '16 years')::date then raise exception 'BellsConnect is available to students aged 16 or older.'; end if;
 insert into public.profiles(id,display_name,status,university) values(new.id,left(name_value,50),'incomplete','Bells University of Technology');
 insert into public.private_profile_data(user_id,date_of_birth) values(new.id,dob);
 return new;
end; $$;

create or replace function public.complete_profile(
 display_name_value text,bio_value text,photo_path_value text,interests_value text[],sports_value text[],likes_value text[],dislikes_value text[],intention_value public.relationship_intention
) returns public.profiles language plpgsql security definer set search_path = '' as $$
declare actor uuid:=auth.uid(); result public.profiles;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 if char_length(trim(coalesce(display_name_value,''))) not between 2 and 50 then raise exception 'Name must be 2 to 50 characters'; end if;
 if char_length(coalesce(bio_value,''))>500 then raise exception 'Bio is too long'; end if;
 if coalesce(cardinality(interests_value),0)>20 or coalesce(cardinality(sports_value),0)>15 or coalesce(cardinality(likes_value),0)>30 or coalesce(cardinality(dislikes_value),0)>30 then raise exception 'Too many profile selections'; end if;
 if photo_path_value is null or split_part(photo_path_value,'/',1)<>actor::text then raise exception 'Upload a profile photo to your own folder'; end if;
 if not exists(select 1 from public.private_profile_data pp where pp.user_id=actor and pp.date_of_birth<=(current_date-interval '16 years')::date) then raise exception 'BellsConnect is available to students aged 16 or older'; end if;
 update public.profiles set age=(select extract(year from age(current_date,pp.date_of_birth))::smallint from public.private_profile_data pp where pp.user_id=actor),
 display_name=trim(display_name_value),bio=coalesce(bio_value,''),photo_path=photo_path_value,interests=coalesce(interests_value,'{}'),sports=coalesce(sports_value,'{}'),likes=coalesce(likes_value,'{}'),dislikes=coalesce(dislikes_value,'{}'),relationship_intention=intention_value,university='Bells University of Technology',status='active',updated_at=now()
 where id=actor returning * into result;
 return result;
end; $$;
revoke all on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) from public;
grant execute on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) to authenticated;

create table public.campus_connections (
 id uuid primary key default gen_random_uuid(), requester_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(requester_id<>recipient_id), unique(requester_id,recipient_id)
);
create index campus_connections_recipient_status_idx on public.campus_connections(recipient_id,status,created_at desc);
alter table public.campus_connections enable row level security;
create policy "connected users can view their requests" on public.campus_connections for select to authenticated using(requester_id=(select auth.uid()) or recipient_id=(select auth.uid()));
create policy "active Bells students can request connection" on public.campus_connections for insert to authenticated with check(
 requester_id=(select auth.uid()) and status='pending'
 and exists(select 1 from public.profiles a,public.profiles b where a.id=requester_id and b.id=recipient_id and a.status='active' and b.status='active' and a.university='Bells University of Technology' and b.university='Bells University of Technology')
 and not public.is_blocked_between(requester_id,recipient_id));
create policy "recipient responds to connection request" on public.campus_connections for update to authenticated using(recipient_id=(select auth.uid()) and status='pending') with check(recipient_id=(select auth.uid()) and status in ('accepted','declined'));
grant select,insert on public.campus_connections to authenticated; grant update(status) on public.campus_connections to authenticated;

create table public.campus_conversations (
 id uuid primary key default gen_random_uuid(), user_low uuid not null references public.profiles(id) on delete cascade,
 user_high uuid not null references public.profiles(id) on delete cascade, created_at timestamptz not null default now(),
 check(user_low<user_high), unique(user_low,user_high)
);
alter table public.campus_conversations enable row level security;
create policy "connected participants can read campus conversations" on public.campus_conversations for select to authenticated using(
 (user_low=(select auth.uid()) or user_high=(select auth.uid()))
 and exists(select 1 from public.campus_connections c where c.status='accepted' and ((c.requester_id=user_low and c.recipient_id=user_high) or (c.requester_id=user_high and c.recipient_id=user_low))));
create policy "connected participants can create campus conversations" on public.campus_conversations for insert to authenticated with check(
 (user_low=(select auth.uid()) or user_high=(select auth.uid()))
 and exists(select 1 from public.campus_connections c where c.status='accepted' and ((c.requester_id=user_low and c.recipient_id=user_high) or (c.requester_id=user_high and c.recipient_id=user_low)))
 and exists(select 1 from public.profiles p where p.id=user_low and p.university='Bells University of Technology' and p.status='active')
 and exists(select 1 from public.profiles p where p.id=user_high and p.university='Bells University of Technology' and p.status='active'));
grant select,insert on public.campus_conversations to authenticated;

create table public.campus_messages (
 id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.campus_conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(trim(body)) between 1 and 3000), created_at timestamptz not null default now()
);
create index campus_messages_conversation_created_idx on public.campus_messages(conversation_id,created_at);
alter table public.campus_messages enable row level security;
create policy "connected participants read campus messages" on public.campus_messages for select to authenticated using(
 exists(select 1 from public.campus_conversations c where c.id=conversation_id and (c.user_low=(select auth.uid()) or c.user_high=(select auth.uid()))));
create policy "connected participants send campus messages" on public.campus_messages for insert to authenticated with check(
 sender_id=(select auth.uid()) and exists(select 1 from public.campus_conversations c where c.id=conversation_id and (c.user_low=(select auth.uid()) or c.user_high=(select auth.uid()))
 and exists(select 1 from public.campus_connections cn where cn.status='accepted' and ((cn.requester_id=c.user_low and cn.recipient_id=c.user_high) or (cn.requester_id=c.user_high and cn.recipient_id=c.user_low)))
 and not public.is_blocked_between(c.user_low,c.user_high)));
grant select,insert on public.campus_messages to authenticated;

create table public.campus_meetups (
 id uuid primary key default gen_random_uuid(), host_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(char_length(trim(title)) between 3 and 80),
 location text not null check(char_length(trim(location)) between 3 and 120),
 details text not null default '' check(char_length(details)<=500),
 starts_at timestamptz not null, created_at timestamptz not null default now(), check(starts_at>created_at)
);
create index campus_meetups_starts_idx on public.campus_meetups(starts_at);
alter table public.campus_meetups enable row level security;
create policy "active Bells students can see campus meetups" on public.campus_meetups for select to authenticated using(
 exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.status='active' and p.university='Bells University of Technology')
 and exists(select 1 from public.profiles h where h.id=host_id and h.status='active' and h.university='Bells University of Technology'));
create policy "active Bells students can host meetups" on public.campus_meetups for insert to authenticated with check(
 host_id=(select auth.uid()) and starts_at>now() and exists(select 1 from public.profiles p where p.id=host_id and p.status='active' and p.university='Bells University of Technology'));
create policy "hosts can edit their own meetups" on public.campus_meetups for update to authenticated using(host_id=(select auth.uid())) with check(host_id=(select auth.uid()));
create policy "hosts can remove their own meetups" on public.campus_meetups for delete to authenticated using(host_id=(select auth.uid()));
grant select,insert,update,delete on public.campus_meetups to authenticated;

create table public.campus_meetup_members (
 meetup_id uuid not null references public.campus_meetups(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(meetup_id,user_id)
);
alter table public.campus_meetup_members enable row level security;
create policy "meetup participants visible to campus members" on public.campus_meetup_members for select to authenticated using(
 exists(select 1 from public.campus_meetups m where m.id=meetup_id)
 and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.status='active' and p.university='Bells University of Technology'));
create policy "active Bells students can join meetups" on public.campus_meetup_members for insert to authenticated with check(
 user_id=(select auth.uid()) and exists(select 1 from public.campus_meetups m where m.id=meetup_id and m.host_id<>(select auth.uid()) and m.starts_at>now())
 and exists(select 1 from public.profiles p where p.id=user_id and p.status='active' and p.university='Bells University of Technology'));
grant select,insert on public.campus_meetup_members to authenticated;

do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='campus_messages') then alter publication supabase_realtime add table public.campus_messages; end if;
end $$;
commit;