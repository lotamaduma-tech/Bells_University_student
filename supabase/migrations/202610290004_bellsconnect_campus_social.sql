-- BellsConnect campus social network and 16+ age policy.
begin;
alter table public.profiles drop constraint if exists profiles_age_check;
alter table public.profiles add constraint profiles_age_check check (age >= 16 and age <= 120);
alter table public.private_profile_data drop constraint if exists private_profile_data_date_of_birth_check;
alter table public.private_profile_data add constraint private_profile_data_date_of_birth_check check (date_of_birth <= (current_date - interval '16 years')::date);
alter table public.user_preferences drop constraint if exists user_preferences_min_age_check;
alter table public.user_preferences add constraint user_preferences_min_age_check check (min_age >= 16 and min_age <= 100);
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare dob date; name_value text;
begin
 name_value:=nullif(trim(coalesce(new.raw_user_meta_data->>'display_name','')),'');
 if name_value is null then name_value:='New member'; end if;
 begin dob:=(new.raw_user_meta_data->>'date_of_birth')::date; exception when others then dob:=null; end;
 if dob is null or dob>(current_date-interval '16 years')::date then raise exception 'BellsConnect is available to students aged 16 or older.'; end if;
 insert into public.profiles(id,display_name,status,university) values(new.id,left(name_value,50),'incomplete','Bells University of Technology');
 insert into public.private_profile_data(user_id,date_of_birth) values(new.id,dob);
 return new;
end; $$;
create or replace function public.complete_profile(
 display_name_value text,bio_value text,photo_path_value text,interests_value text[],sports_value text[],likes_value text[],dislikes_value text[],intention_value public.relationship_intention
) returns public.profiles language plpgsql security definer set search_path = '' as $$
declare actor uuid:=auth.uid(); result public.profiles;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 if char_length(trim(coalesce(display_name_value,''))) not between 2 and 50 then raise exception 'Name must be 2 to 50 characters'; end if;
 if char_length(coalesce(bio_value,''))>500 then raise exception 'Bio is too long'; end if;
 if coalesce(cardinality(interests_value),0)>20 or coalesce(cardinality(sports_value),0)>15 or coalesce(cardinality(likes_value),0)>30 or coalesce(cardinality(dislikes_value),0)>30 then raise exception 'Too many profile selections'; end if;
 if photo_path_value is null or split_part(photo_path_value,'/',1)<>actor::text then raise exception 'Upload a profile photo to your own folder'; end if;
 if not exists(select 1 from public.private_profile_data pp where pp.user_id=actor and pp.date_of_birth<=(current_date-interval '16 years')::date) then raise exception 'BellsConnect is available to students aged 16 or older'; end if;
 update public.profiles set age=(select extract(year from age(current_date,pp.date_of_birth))::smallint from public.private_profile_data pp where pp.user_id=actor),
 display_name=trim(display_name_value),bio=coalesce(bio_value,''),photo_path=photo_path_value,interests=coalesce(interests_value,'{}'),sports=coalesce(sports_value,'{}'),likes=coalesce(likes_value,'{}'),dislikes=coalesce(dislikes_value,'{}'),relationship_intention=intention_value,university='Bells University of Technology',status='active',updated_at=now()
 where id=actor returning * into result;
 return result;
end; $$;
revoke all on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) from public;
grant execute on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) to authenticated;
-- Private birth date remains private; profile access is still protected by existing RLS.
commit;