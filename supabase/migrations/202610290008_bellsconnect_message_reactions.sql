-- Limited, persistent reactions for private BellsConnect messages.
begin;

create table if not exists public.campus_message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.campus_messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (reaction in ('❤️','😂','👍','🔥','✨')),
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);

create index if not exists campus_message_reactions_message_idx
  on public.campus_message_reactions(message_id);

alter table public.campus_message_reactions enable row level security;

create policy "Connected chat participants can read reactions"
on public.campus_message_reactions for select to authenticated
using (
  exists (
    select 1
    from public.campus_messages m
    join public.campus_conversations c on c.id = m.conversation_id
    where m.id = message_id
      and (c.user_low = (select auth.uid()) or c.user_high = (select auth.uid()))
  )
);

create policy "Users can add their own chat reactions"
on public.campus_message_reactions for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.campus_messages m
    join public.campus_conversations c on c.id = m.conversation_id
    where m.id = message_id
      and (c.user_low = (select auth.uid()) or c.user_high = (select auth.uid()))
      and exists (
        select 1 from public.campus_connections cn
        where cn.status = 'accepted'
          and ((cn.requester_id = c.user_low and cn.recipient_id = c.user_high)
            or (cn.requester_id = c.user_high and cn.recipient_id = c.user_low))
      )
  )
);

create policy "Users can change or remove their own chat reactions"
on public.campus_message_reactions for update to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and reaction in ('❤️','😂','👍','🔥','✨')
);

create policy "Users can remove their own chat reactions"
on public.campus_message_reactions for delete to authenticated
using (user_id = (select auth.uid()));

grant select, insert, update, delete on public.campus_message_reactions to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'campus_message_reactions'
  ) then
    alter publication supabase_realtime add table public.campus_message_reactions;
  end if;
end $$;

commit;
