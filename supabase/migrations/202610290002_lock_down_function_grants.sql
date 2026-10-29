begin;
-- Explicitly remove inherited default function privileges from browser roles.
revoke execute on function public.handle_new_user() from anon, authenticated;
revoke execute on function public.is_blocked_between(uuid,uuid) from anon;
revoke execute on function public.is_conversation_member(uuid) from anon;
revoke execute on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) from anon;
revoke execute on function public.record_like(uuid,text) from anon;
grant execute on function public.is_blocked_between(uuid,uuid) to authenticated;
grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.complete_profile(text,text,text,text[],text[],text[],text[],public.relationship_intention) to authenticated;
grant execute on function public.record_like(uuid,text) to authenticated;
commit;