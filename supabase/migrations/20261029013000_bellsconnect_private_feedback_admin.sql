-- BellsConnect private developer feedback and administrator access.
create table if not exists public.bellsconnect_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  added_by uuid references auth.users(id) on delete set null
);

create table if not exists public.bellsconnect_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  category text not null check (category in ('suggestion','bug','experience','other')),
  message text not null check (char_length(trim(message)) between 8 and 3000),
  status text not null default 'new' check (status in ('new','reviewing','resolved')),
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bellsconnect_feedback_created_at_idx
  on public.bellsconnect_feedback (created_at desc);
create index if not exists bellsconnect_feedback_status_created_at_idx
  on public.bellsconnect_feedback (status, created_at desc);

alter table public.bellsconnect_admins enable row level security;
alter table public.bellsconnect_feedback enable row level security;

revoke all on public.bellsconnect_admins from anon, authenticated;
revoke all on public.bellsconnect_feedback from anon, authenticated;
grant select on public.bellsconnect_admins to authenticated;
grant select, insert on public.bellsconnect_feedback to authenticated;
grant update on public.bellsconnect_feedback to authenticated;

drop policy if exists "Admins can read their own admin membership" on public.bellsconnect_admins;
create policy "Admins can read their own admin membership"
  on public.bellsconnect_admins for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Signed-in students can submit feedback" on public.bellsconnect_feedback;
create policy "Signed-in students can submit feedback"
  on public.bellsconnect_feedback for insert to authenticated
  with check (
    (user_id is null or user_id = (select auth.uid()))
    and status = 'new'
    and admin_notes is null
  );

drop policy if exists "Only admins can read feedback" on public.bellsconnect_feedback;
create policy "Only admins can read feedback"
  on public.bellsconnect_feedback for select to authenticated
  using (exists (
    select 1 from public.bellsconnect_admins a
    where a.user_id = (select auth.uid())
  ));

drop policy if exists "Only admins can update feedback" on public.bellsconnect_feedback;
create policy "Only admins can update feedback"
  on public.bellsconnect_feedback for update to authenticated
  using (exists (
    select 1 from public.bellsconnect_admins a
    where a.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.bellsconnect_admins a
    where a.user_id = (select auth.uid())
  ));

create or replace function public.bellsconnect_feedback_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists bellsconnect_feedback_touch_updated_at on public.bellsconnect_feedback;
create trigger bellsconnect_feedback_touch_updated_at
before update on public.bellsconnect_feedback
for each row execute function public.bellsconnect_feedback_touch_updated_at();
