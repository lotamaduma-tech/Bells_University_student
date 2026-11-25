-- MARKIO Premium foundations: vendor interest, subscriptions, and listing analytics.
-- Additive only: existing marketplace, authentication, and moderation tables are preserved.

create table if not exists public.listing_views (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.marketplace_listings(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint listing_views_not_self check (seller_id <> viewer_id)
);
create index if not exists listing_views_seller_created_idx on public.listing_views (seller_id, created_at desc);
create index if not exists listing_views_listing_created_idx on public.listing_views (listing_id, created_at desc);
alter table public.listing_views enable row level security;
revoke all on public.listing_views from anon, authenticated;
grant select, insert on public.listing_views to authenticated;
drop policy if exists "Viewers record approved listing views" on public.listing_views;
create policy "Viewers record approved listing views" on public.listing_views for insert to authenticated
with check (viewer_id = (select auth.uid()) and seller_id <> (select auth.uid()) and exists (
  select 1 from public.marketplace_listings l where l.id = listing_id and l.seller_id = listing_views.seller_id and l.status = 'approved'
));
drop policy if exists "Vendors read views for their own listings" on public.listing_views;
create policy "Vendors read views for their own listings" on public.listing_views for select to authenticated using (seller_id = (select auth.uid()));

create table if not exists public.premium_interest (
  user_id uuid primary key references auth.users(id) on delete cascade,
  source text not null default 'vendor-dashboard' check (source in ('vendor-dashboard','storefront')),
  status text not null default 'interested' check (status in ('interested','contacted','converted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.premium_interest enable row level security;
revoke all on public.premium_interest from anon, authenticated;
grant select, insert, update on public.premium_interest to authenticated;
drop policy if exists "Users read their own Premium interest" on public.premium_interest;
create policy "Users read their own Premium interest" on public.premium_interest for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Users register their own Premium interest" on public.premium_interest;
create policy "Users register their own Premium interest" on public.premium_interest for insert to authenticated with check (user_id = (select auth.uid()) and status = 'interested');
drop policy if exists "Admins read Premium interest" on public.premium_interest;
create policy "Admins read Premium interest" on public.premium_interest for select to authenticated using (exists (select 1 from public.bellsconnect_admins a where a.user_id = (select auth.uid())));
drop policy if exists "Admins update Premium interest" on public.premium_interest;
create policy "Admins update Premium interest" on public.premium_interest for update to authenticated
using (exists (select 1 from public.bellsconnect_admins a where a.user_id = (select auth.uid())))
with check (exists (select 1 from public.bellsconnect_admins a where a.user_id = (select auth.uid())));

create table if not exists public.vendor_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_code text not null default 'premium' check (plan_code = 'premium'),
  billing_period text not null check (billing_period in ('monthly','annual')),
  status text not null default 'pending' check (status in ('pending','active','past_due','canceled','expired')),
  provider text,
  provider_reference text unique,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists vendor_subscriptions_user_status_idx on public.vendor_subscriptions (user_id, status, created_at desc);
alter table public.vendor_subscriptions enable row level security;
revoke all on public.vendor_subscriptions from anon, authenticated;
grant select on public.vendor_subscriptions to authenticated;
drop policy if exists "Vendors read their own subscriptions" on public.vendor_subscriptions;
create policy "Vendors read their own subscriptions" on public.vendor_subscriptions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Admins read vendor subscriptions" on public.vendor_subscriptions;
create policy "Admins read vendor subscriptions" on public.vendor_subscriptions for select to authenticated using (exists (select 1 from public.bellsconnect_admins a where a.user_id = (select auth.uid())));
grant all on public.listing_views, public.premium_interest, public.vendor_subscriptions to service_role;