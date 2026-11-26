create policy "Approved listings may be opened from public share links" on public.marketplace_listings for select to anon using (status = 'approved' and exists (select 1 from public.seller_profiles sp where sp.user_id = marketplace_listings.seller_id and sp.status = 'approved'));
grant select (id, seller_id, title, description, category, price_ngn, image_paths, availability, fulfillment, created_at, is_pinned) on public.marketplace_listings to anon;
create policy "Approved seller stores are publicly readable" on public.seller_profiles for select to anon using (status = 'approved');
grant select (user_id, store_name, description, logo_path, cover_path, status) on public.seller_profiles to anon;
