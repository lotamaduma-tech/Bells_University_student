-- BellsConnect in-app notifications for requests, accepted connections, messages, and meetup joins.
begin;
create table if not exists public.campus_notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 kind text not null check (kind in ('connection_request','connection_accepted','new_message','meetup_joined')),
 title text not null check (char_length(title) between 1 and 140),
 body text not null default '' check (char_length(body)<=300),
 connection_id uuid references public.campus_connections(id) on delete cascade,
 conversation_id uuid references public.campus_conversations(id) on delete cascade,
 meetup_id uuid references public.campus_meetups(id) on delete cascade,
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists campus_notifications_recipient_created_idx on public.campus_notifications(recipient_id,created_at desc);
alter table public.campus_notifications enable row level security;
drop policy if exists "members read own campus notifications" on public.campus_notifications;
create policy "members read own campus notifications" on public.campus_notifications for select to authenticated using(recipient_id=(select auth.uid()));
drop policy if exists "members mark own campus notifications read" on public.campus_notifications;
create policy "members mark own campus notifications read" on public.campus_notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
grant select, update(read_at) on public.campus_notifications to authenticated;
revoke insert, delete on public.campus_notifications from anon, authenticated;
create or replace function public.notify_campus_connection_request()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text;
begin
 if new.status='pending' then
  select p.display_name into sender_name from public.profiles p where p.id=new.requester_id;
  insert into public.campus_notifications(recipient_id,actor_id,kind,title,body,connection_id)
  values(new.recipient_id,new.requester_id,'connection_request','New connection request',coalesce(sender_name,'A Bells student')||' wants to connect with you.',new.id);
 end if;
 return new;
end; $$;
revoke all on function public.notify_campus_connection_request() from public, anon, authenticated;
drop trigger if exists campus_connection_request_notification on public.campus_connections;
create trigger campus_connection_request_notification after insert on public.campus_connections for each row execute function public.notify_campus_connection_request();
create or replace function public.notify_campus_connection_accepted()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient_name text;
begin
 if old.status='pending' and new.status='accepted' then
  select p.display_name into recipient_name from public.profiles p where p.id=new.recipient_id;
  insert into public.campus_notifications(recipient_id,actor_id,kind,title,body,connection_id)
  values(new.requester_id,new.recipient_id,'connection_accepted','Connection request accepted',coalesce(recipient_name,'A Bells student')||' accepted your request.',new.id);
 end if;
 return new;
end; $$;
revoke all on function public.notify_campus_connection_accepted() from public, anon, authenticated;
drop trigger if exists campus_connection_accepted_notification on public.campus_connections;
create trigger campus_connection_accepted_notification after update of status on public.campus_connections for each row execute function public.notify_campus_connection_accepted();
create or replace function public.notify_campus_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid; sender_name text; conv public.campus_conversations;
begin
 select * into conv from public.campus_conversations c where c.id=new.conversation_id;
 if not found then return new; end if;
 recipient:=case when conv.user_low=new.sender_id then conv.user_high else conv.user_low end;
 select p.display_name into sender_name from public.profiles p where p.id=new.sender_id;
 insert into public.campus_notifications(recipient_id,actor_id,kind,title,body,conversation_id)
 values(recipient,new.sender_id,'new_message','New message from '||coalesce(sender_name,'a connection'),left(new.body,160),new.conversation_id);
 return new;
end; $$;
revoke all on function public.notify_campus_message() from public, anon, authenticated;
drop trigger if exists campus_message_notification on public.campus_messages;
create trigger campus_message_notification after insert on public.campus_messages for each row execute function public.notify_campus_message();
create or replace function public.notify_campus_meetup_joined()
returns trigger language plpgsql security definer set search_path = '' as $$
declare host uuid; meetup_title text; joiner_name text;
begin
 select m.host_id,m.title into host,meetup_title from public.campus_meetups m where m.id=new.meetup_id;
 if host is null or host=new.user_id then return new; end if;
 select p.display_name into joiner_name from public.profiles p where p.id=new.user_id;
 insert into public.campus_notifications(recipient_id,actor_id,kind,title,body,meetup_id)
 values(host,new.user_id,'meetup_joined','Someone joined your meet-up',coalesce(joiner_name,'A Bells student')||' joined "'||left(meetup_title,90)||'".',new.meetup_id);
 return new;
end; $$;
revoke all on function public.notify_campus_meetup_joined() from public, anon, authenticated;
drop trigger if exists campus_meetup_joined_notification on public.campus_meetup_members;
create trigger campus_meetup_joined_notification after insert on public.campus_meetup_members for each row execute function public.notify_campus_meetup_joined();
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='campus_notifications') then
  alter publication supabase_realtime add table public.campus_notifications;
 end if;
end $$;
commit;