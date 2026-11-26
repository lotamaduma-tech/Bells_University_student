-- Applied to Supabase project gxiirebjidkgucucegzn on 2026-11-26.
-- Marketplace seller actions, report integrity, persistent cart and account preferences.

alter table public.marketplace_listings
  add column if not exists is_pinned boolean not null default false;

alter table public.listing_reports
  add column if not exists seller_id uuid references auth.users(id) on delete set null;

update public.listing_reports r
set seller_id = l.seller_id
from public.marketplace_listings l
where r.listing_id = l.id and r.seller_id is null;

create unique index if not exists listing_reports_one_per_user_listing
  on public.listing_reports(listing_id, reporter_id);

create or replace function public.attach_listing_report_seller()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  select l.seller_id into new.seller_id
  from public.marketplace_listings l
  where l.id = new.listing_id and l.status = 'approved';
  if new.seller_id is null then
    raise exception 'This listing is unavailable for reporting.';
  end if;
  if new.seller_id = new.reporter_id then
    raise exception 'You cannot report your own listing.';
  end if;
  return new;
end;
$$;

drop trigger if exists listing_reports_attach_seller on public.listing_reports;
create trigger listing_reports_attach_seller
before insert on public.listing_reports
for each row execute function public.attach_listing_report_seller();

drop policy if exists "Users report listings" on public.listing_reports;
create policy "Users report approved listings once"
on public.listing_reports for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and seller_id is not null
  and seller_id <> (select auth.uid())
  and exists (
    select 1 from public.marketplace_listings l
    where l.id = listing_id and l.seller_id = seller_id and l.status = 'approved'
  )
);

create table if not exists public.marketplace_cart_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.marketplace_listings(id) on delete cascade,
  quantity integer not null default 1 check (quantity between 1 and 99),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);
alter table public.marketplace_cart_items enable row level security;
drop policy if exists "Users manage own marketplace cart" on public.marketplace_cart_items;
create policy "Users read own marketplace cart"
on public.marketplace_cart_items for select to authenticated
using (user_id = (select auth.uid()));
create policy "Users add approved listings to own cart"
on public.marketplace_cart_items for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.marketplace_listings l
    where l.id = listing_id and l.status = 'approved' and l.seller_id <> (select auth.uid())
  )
);
create policy "Users update own marketplace cart"
on public.marketplace_cart_items for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
create policy "Users remove own marketplace cart items"
on public.marketplace_cart_items for delete to authenticated
using (user_id = (select auth.uid()));

create table if not exists public.marketplace_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  seller_updates boolean not null default true,
  product_updates boolean not null default true,
  profile_discoverability boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.marketplace_preferences enable row level security;
drop policy if exists "Users manage own marketplace preferences" on public.marketplace_preferences;
create policy "Users read own marketplace preferences"
on public.marketplace_preferences for select to authenticated
using (user_id = (select auth.uid()));
create policy "Users insert own marketplace preferences"
on public.marketplace_preferences for insert to authenticated
with check (user_id = (select auth.uid()));
create policy "Users update own marketplace preferences"
on public.marketplace_preferences for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

grant select, insert, update, delete on public.marketplace_cart_items to authenticated;
grant select, insert, update on public.marketplace_preferences to authenticated;
