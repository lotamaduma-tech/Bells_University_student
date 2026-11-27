begin;

create or replace function public.markio_notify_seller_application_status()
returns trigger
language plpgsql
security definer
set search_path=''
as $fn$
begin
  if old.status is distinct from new.status and new.status in ('approved','rejected') then
    perform public.markio_emit_notification(
      new.user_id,
      null,
      'seller_application_'||new.status,
      'seller_activity',
      case when new.status='approved' then 'Seller application approved' else 'Seller application update' end,
      case when new.status='approved'
        then 'Your MARKIO seller application has been approved.'
        else 'Your MARKIO seller application was not approved. Open your application for details.'
      end,
      '/apply',
      'seller_application_status:'||new.id::text||':'||new.status,
      jsonb_build_object('application_id',new.id,'status',new.status)
    );
  end if;
  return new;
end;
$fn$;
revoke all on function public.markio_notify_seller_application_status() from public,anon,authenticated;

create or replace function public.markio_notify_listing_status()
returns trigger
language plpgsql
security definer
set search_path=''
as $fn$
begin
  if old.status is distinct from new.status and new.status in ('approved','rejected') then
    perform public.markio_emit_notification(
      new.seller_id,
      null,
      'listing_'||new.status,
      'seller_activity',
      case when new.status='approved' then 'Your listing is now live' else 'Listing review update' end,
      case when new.status='approved'
        then 'Your MARKIO listing "'||left(new.title,120)||'" has been approved.'
        else 'Your MARKIO listing "'||left(new.title,120)||'" was not approved.'
      end,
      '/store',
      'listing_status:'||new.id::text||':'||new.status,
      jsonb_build_object('listing_id',new.id,'status',new.status)
    );
  end if;
  return new;
end;
$fn$;
revoke all on function public.markio_notify_listing_status() from public,anon,authenticated;

drop trigger if exists markio_listing_status_notification on public.marketplace_listings;
create trigger markio_listing_status_notification
after update of status on public.marketplace_listings
for each row execute function public.markio_notify_listing_status();

commit;
