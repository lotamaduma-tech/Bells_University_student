drop policy if exists "Approved sellers publish listings" on public.marketplace_listings;
create policy "Approved sellers publish listings" on public.marketplace_listings
for insert to authenticated
with check (
 seller_id=(select auth.uid())
 and status in ('approved','pending')
 and exists(select 1 from public.seller_profiles s where s.user_id=(select auth.uid()) and s.status='approved')
);
