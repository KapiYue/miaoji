-- Audio is processed through the trusted API with a service-role client. Keep
-- objects private, size-limited, and unavailable through public Storage URLs.
insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'user-audio',
    'user-audio',
    false,
    26214400,
    array['audio/mp4', 'audio/m4a', 'audio/x-m4a']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- App Store Review Guideline 5.1.1(v): a signed-in user can permanently
-- delete their own Auth record. account_snapshots is removed by its FK
-- ON DELETE CASCADE. The empty search_path and auth.uid() check keep the
-- SECURITY DEFINER function narrowly scoped to the caller's own account.
create or replace function public.delete_current_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    caller_id uuid := (select auth.uid());
begin
    if caller_id is null then
        raise exception 'authentication required' using errcode = '42501';
    end if;

    delete from auth.users where id = caller_id;
end;
$$;

revoke all on function public.delete_current_account() from public;
revoke all on function public.delete_current_account() from anon;
grant execute on function public.delete_current_account() to authenticated;
