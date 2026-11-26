alter table public.marketplace_listings disable trigger marketplace_listing_status_guard;
update public.marketplace_listings l set status='approved',updated_at=now() where l.status='pending' and exists(select 1 from public.seller_profiles s where s.user_id=l.seller_id and s.status='approved');
alter table public.marketplace_listings enable trigger marketplace_listing_status_guard;
