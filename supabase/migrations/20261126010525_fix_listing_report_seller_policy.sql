-- Correct seller/listing correlation in the private listing-report insert policy.
drop policy if exists "Users report approved listings once" on public.listing_reports;
create policy "Users report approved listings once"
on public.listing_reports for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and seller_id is not null
  and seller_id <> (select auth.uid())
  and exists (
    select 1 from public.marketplace_listings l
    where l.id = listing_reports.listing_id
      and l.seller_id = listing_reports.seller_id
      and l.status = 'approved'
  )
);
