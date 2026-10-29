-- Message replies: each message may reference an earlier message in the same conversation.
alter table public.campus_messages
  add column if not exists reply_to uuid null
  references public.campus_messages(id) on delete set null;

create index if not exists campus_messages_reply_to_idx
  on public.campus_messages(reply_to);

-- Enforce that replies only point to messages in the same conversation.
create or replace function public.bellsconnect_validate_message_reply()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.reply_to is not null and not exists (
    select 1 from public.campus_messages parent
    where parent.id = new.reply_to
      and parent.conversation_id = new.conversation_id
  ) then
    raise exception 'Reply target must belong to the same conversation';
  end if;
  return new;
end;
$$;

drop trigger if exists bellsconnect_validate_message_reply on public.campus_messages;
create trigger bellsconnect_validate_message_reply
before insert or update of reply_to, conversation_id
on public.campus_messages
for each row execute function public.bellsconnect_validate_message_reply();
