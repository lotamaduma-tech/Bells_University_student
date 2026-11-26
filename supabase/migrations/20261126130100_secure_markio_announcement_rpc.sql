alter function public.markio_publish_announcement(text,text,text,uuid) security invoker;
revoke all on function public.markio_publish_announcement(text,text,text,uuid) from public,anon;
grant execute on function public.markio_publish_announcement(text,text,text,uuid) to authenticated;