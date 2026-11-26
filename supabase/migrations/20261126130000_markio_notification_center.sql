-- MARKIO notification centre, push subscriptions, preferences and founder announcements.
begin;
create table if not exists public.markio_notifications (
 id uuid primary key default gen_random_uuid(), recipient_id uuid not null references auth.users(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null, kind text not null,
 category text not null check (category in ('orders','seller_activity','product_updates','announcements','account_security','admin')),
 title text not null check (char_length(title) between 1 and 140), body text not null default '' check (char_length(body)<=1000),
 target_path text not null default '/', dedupe_key text, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), read_at timestamptz,
 constraint markio_notifications_dedupe unique(recipient_id,dedupe_key)
);
create index if not exists markio_notifications_recipient_created_idx on public.markio_notifications(recipient_id,created_at desc);
create index if not exists markio_notifications_unread_idx on public.markio_notifications(recipient_id,created_at desc) where read_at is null;
create table if not exists public.markio_notification_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade, push_enabled boolean not null default false,
 order_notifications boolean not null default true, seller_activity boolean not null default true,
 product_updates boolean not null default true, announcements boolean not null default true,
 account_security boolean not null default true, onboarding_dismissed_at timestamptz,
 updated_at timestamptz not null default now()
);
create table if not exists public.markio_push_subscriptions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 endpoint text not null unique, p256dh text not null, auth text not null, device_label text,
 created_at timestamptz not null default now(), last_seen_at timestamptz not null default now(),
 last_error text, disabled_at timestamptz
);
create index if not exists markio_push_subscriptions_user_idx on public.markio_push_subscriptions(user_id) where disabled_at is null;
create table if not exists public.markio_announcements (
 id uuid primary key default gen_random_uuid(), author_id uuid not null references auth.users(id),
 title text not null check(char_length(title) between 1 and 140),
 message text not null check(char_length(message) between 1 and 2000),
 audience text not null check(audience in ('all','students','sellers')),
 created_at timestamptz not null default now(), idempotency_key uuid not null unique
);
alter table public.markio_notifications enable row level security;
alter table public.markio_notification_preferences enable row level security;
alter table public.markio_push_subscriptions enable row level security;
alter table public.markio_announcements enable row level security;
drop policy if exists "read own markio notifications" on public.markio_notifications;
create policy "read own markio notifications" on public.markio_notifications for select to authenticated using(recipient_id=(select auth.uid()));
drop policy if exists "update own markio notifications" on public.markio_notifications;
create policy "update own markio notifications" on public.markio_notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
drop policy if exists "delete own markio notifications" on public.markio_notifications;
create policy "delete own markio notifications" on public.markio_notifications for delete to authenticated using(recipient_id=(select auth.uid()));
revoke insert on public.markio_notifications from anon,authenticated;
grant select,update(read_at),delete on public.markio_notifications to authenticated;
drop policy if exists "manage own markio notification preferences" on public.markio_notification_preferences;
create policy "manage own markio notification preferences" on public.markio_notification_preferences for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
grant select,insert,update on public.markio_notification_preferences to authenticated;
drop policy if exists "manage own markio push subscriptions" on public.markio_push_subscriptions;
create policy "manage own markio push subscriptions" on public.markio_push_subscriptions for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
grant select,insert,update,delete on public.markio_push_subscriptions to authenticated;
drop policy if exists "admins read markio announcements" on public.markio_announcements;
create policy "admins read markio announcements" on public.markio_announcements for select to authenticated using(exists(select 1 from public.bellsconnect_admins a where a.user_id=(select auth.uid())));
revoke insert,update,delete on public.markio_announcements from anon,authenticated;
grant select on public.markio_announcements to authenticated;
create or replace function public.markio_emit_notification(p_recipient uuid,p_actor uuid,p_kind text,p_category text,p_title text,p_body text,p_path text,p_dedupe text,p_metadata jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_recipient is null then return; end if;
 if p_category not in ('account_security','admin') and exists(
  select 1 from public.markio_notification_preferences pref where pref.user_id=p_recipient and
  ((p_category='orders' and not pref.order_notifications) or (p_category='seller_activity' and not pref.seller_activity) or
   (p_category='product_updates' and not pref.product_updates) or (p_category='announcements' and not pref.announcements))
 ) then return; end if;
 insert into public.markio_notifications(recipient_id,actor_id,kind,category,title,body,target_path,dedupe_key,metadata)
 values(p_recipient,p_actor,p_kind,p_category,p_title,left(coalesce(p_body,''),1000),coalesce(p_path,'/'),p_dedupe,coalesce(p_metadata,'{}'::jsonb))
 on conflict(recipient_id,dedupe_key) do nothing;
end; $$;
revoke all on function public.markio_emit_notification(uuid,uuid,text,text,text,text,text,text,jsonb) from public,anon,authenticated;
create or replace function public.markio_notify_admin_submission() returns trigger language plpgsql security definer set search_path='' as $$
declare a record; t text; b text; p text; k text;
begin
 if tg_table_name='seller_applications' then t:='New seller application';b:='A student submitted a seller application for review.';p:='/admin/sellers?application='||new.id::text;k:='seller_application';
 elsif tg_table_name='marketplace_account_requests' then t:='New account request';b:='A user submitted an account request.';p:='/admin/requests?request='||new.id::text;k:='account_request';
 elsif tg_table_name='listing_reports' then t:='New listing report';b:='A marketplace listing was reported.';p:='/admin/reports?report='||new.id::text;k:='listing_report';
 elsif tg_table_name='bellsconnect_feedback' then t:='New support request';b:='A user submitted a support request.';p:='/admin/support?request='||new.id::text;k:='support_request';
 elsif tg_table_name='premium_interest' then t:='Premium early access request';b:='A user requested MARKIO Premium early access.';p:='/admin/premium?user='||new.user_id::text;k:='premium_interest';
 else return new; end if;
 for a in select user_id from public.bellsconnect_admins loop
  perform public.markio_emit_notification(a.user_id,null,k,'admin',t,b,p,tg_table_name||':'||new.id::text,jsonb_build_object('record_id',new.id,'source_table',tg_table_name));
 end loop;
 return new;
end; $$;
revoke all on function public.markio_notify_admin_submission() from public,anon,authenticated;
drop trigger if exists markio_admin_seller_application on public.seller_applications;
create trigger markio_admin_seller_application after insert on public.seller_applications for each row execute function public.markio_notify_admin_submission();
drop trigger if exists markio_admin_account_request on public.marketplace_account_requests;
create trigger markio_admin_account_request after insert on public.marketplace_account_requests for each row execute function public.markio_notify_admin_submission();
drop trigger if exists markio_admin_listing_report on public.listing_reports;
create trigger markio_admin_listing_report after insert on public.listing_reports for each row execute function public.markio_notify_admin_submission();
drop trigger if exists markio_admin_support_request on public.bellsconnect_feedback;
create trigger markio_admin_support_request after insert on public.bellsconnect_feedback for each row execute function public.markio_notify_admin_submission();
drop trigger if exists markio_admin_premium_interest on public.premium_interest;
create trigger markio_admin_premium_interest after insert on public.premium_interest for each row execute function public.markio_notify_admin_submission();
create or replace function public.markio_notify_seller_application_status() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status is distinct from new.status and new.status in ('approved','rejected') then
  perform public.markio_emit_notification(new.user_id,null,'seller_application_'||new.status,'account_security',
   case when new.status='approved' then 'Seller application approved' else 'Seller application update' end,
   case when new.status='approved' then 'Your MARKIO seller application has been approved.' else 'Your MARKIO seller application was not approved. Open your application for details.' end,
   '/apply','seller_application_status:'||new.id::text||':'||new.status,jsonb_build_object('application_id',new.id,'status',new.status));
 end if; return new;
end; $$;
revoke all on function public.markio_notify_seller_application_status() from public,anon,authenticated;
drop trigger if exists markio_seller_application_status_notification on public.seller_applications;
create trigger markio_seller_application_status_notification after update of status on public.seller_applications for each row execute function public.markio_notify_seller_application_status();
create or replace function public.markio_publish_announcement(p_title text,p_message text,p_audience text,p_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare announcement_id uuid; r record;
begin
 if auth.uid() is null or not exists(select 1 from public.bellsconnect_admins a where a.user_id=auth.uid() and a.role='super_admin') then raise exception 'Founder access required'; end if;
 if p_audience not in ('all','students','sellers') then raise exception 'Invalid audience'; end if;
 insert into public.markio_announcements(author_id,title,message,audience,idempotency_key)
 values(auth.uid(),trim(p_title),trim(p_message),p_audience,p_idempotency_key)
 on conflict(idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into announcement_id;
 if p_audience='all' then
  for r in select id from public.profiles loop perform public.markio_emit_notification(r.id,auth.uid(),'announcement','announcements',trim(p_title),trim(p_message),'/','announcement:'||announcement_id||':'||r.id,jsonb_build_object('announcement_id',announcement_id)); end loop;
 elsif p_audience='students' then
  for r in select p.id from public.profiles p where not exists(select 1 from public.seller_profiles s where s.user_id=p.id and s.status='approved') loop perform public.markio_emit_notification(r.id,auth.uid(),'announcement','announcements',trim(p_title),trim(p_message),'/','announcement:'||announcement_id||':'||r.id,jsonb_build_object('announcement_id',announcement_id)); end loop;
 else
  for r in select user_id as id from public.seller_profiles where status='approved' loop perform public.markio_emit_notification(r.id,auth.uid(),'announcement','announcements',trim(p_title),trim(p_message),'/','announcement:'||announcement_id||':'||r.id,jsonb_build_object('announcement_id',announcement_id)); end loop;
 end if;
 return announcement_id;
end; $$;
revoke all on function public.markio_publish_announcement(text,text,text,uuid) from public,anon;
grant execute on function public.markio_publish_announcement(text,text,text,uuid) to authenticated;
commit;
