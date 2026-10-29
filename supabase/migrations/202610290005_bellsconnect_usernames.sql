begin;
alter table public.profiles add column if not exists username text;
update public.profiles set username=left(coalesce(nullif(trim(both '-' from lower(regexp_replace(display_name,'[^a-zA-Z0-9]+','-','g'))),''),'student'),18)||'-'||left(id::text,5) where username is null;
alter table public.profiles alter column username set not null;
create unique index if not exists profiles_username_unique_idx on public.profiles(lower(username));
alter table public.profiles drop constraint if exists profiles_username_format_check;
alter table public.profiles add constraint profiles_username_format_check check(username ~ '^[a-z0-9][a-z0-9._-]{2,29}[a-z0-9]$');
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare dob date; name_value text; handle_value text;
begin
 name_value:=nullif(trim(coalesce(new.raw_user_meta_data->>'display_name','')),'');
 if name_value is null then name_value:='New member'; end if;
 begin dob:=(new.raw_user_meta_data->>'date_of_birth')::date; exception when others then dob:=null; end;
 if dob is null or dob>(current_date-interval '16 years')::date then raise exception 'BellsConnect is available to students aged 16 or older.'; end if;
 handle_value:=left(coalesce(nullif(trim(both '-' from lower(regexp_replace(name_value,'[^a-zA-Z0-9]+','-','g'))),''),'student'),18)||'-'||left(new.id::text,5);
 insert into public.profiles(id,display_name,username,status,university) values(new.id,left(name_value,50),handle_value,'incomplete','Bells University of Technology');
 insert into public.private_profile_data(user_id,date_of_birth) values(new.id,dob);
 return new;
end; $$;
commit;