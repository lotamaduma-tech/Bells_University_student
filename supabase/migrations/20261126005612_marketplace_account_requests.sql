create table if not exists public.marketplace_account_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_type text not null check (request_type in ('deactivation','deletion','support')),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open','reviewing','completed','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.marketplace_account_requests enable row level security;
create policy "Users create own account requests" on public.marketplace_account_requests for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Users read own account requests" on public.marketplace_account_requests for select to authenticated using (user_id = (select auth.uid()));
create policy "Admins read account requests" on public.marketplace_account_requests for select to authenticated using (exists (select 1 from public.bellsconnect_admins a where a.user_id = (select auth.uid())));
create policy "Admins update account requests" on public.marketplace_account_requests for update to authenticated using (exists (select 1 from public.bellsconnect_admins a where a.user_id = (select auth.uid()))) with check (exists (select 1 from public.bellsconnect_admins a where a.user_id = (select auth.uid())));
grant select, insert, update on public.marketplace_account_requests to authenticated;
