-- Applied to Supabase project gxiirebjidkgucucegzn on 2026-11-26.
-- Public profile previews are opt-in. Only minimal fields are exposed to anonymous visitors.
-- Seller save analytics expose listing IDs only, never the identities of people who saved them.

alter table public.profiles
  add column if not exists public_profile_enabled boolean not null default false;

drop policy if exists "Public marketplace profiles can be viewed anonymously" on public.profiles;
create policy "Public marketplace profiles can be viewed anonymously"
on public.profiles for select to anon
using (status = 'active' and public_profile_enabled = true);

grant select (id, display_name, username, photo_path, public_profile_enabled)
on public.profiles to anon;

drop policy if exists "Public seller stores for discoverable profiles" on public.seller_profiles;
create policy "Public seller stores for discoverable profiles"
on public.seller_profiles for select to anon
using (
  status = 'approved'
  and exists (
    select 1 from public.profiles p
    where p.id = seller_profiles.user_id
      and p.status = 'active'
      and p.public_profile_enabled = true
  )
);

grant select (user_id, store_name, description, logo_path, cover_path, status)
on public.seller_profiles to anon;

drop policy if exists "Sellers read saves for own listings" on public.saved_listings;
create policy "Sellers read saves for own listings"
on public.saved_listings for select to authenticated
using (
  exists (
    select 1 from public.marketplace_listings l
    where l.id = saved_listings.listing_id
      and l.seller_id = (select auth.uid())
  )
);

revoke select on public.saved_listings from authenticated;
grant select (listing_id) on public.saved_listings to authenticated;
