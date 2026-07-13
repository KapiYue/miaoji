create table public.account_snapshots (
    user_id uuid primary key references auth.users(id) on delete cascade,
    data jsonb not null check (jsonb_typeof(data) = 'object'),
    updated_at timestamptz not null default now()
);

alter table public.account_snapshots enable row level security;

revoke all on table public.account_snapshots from anon;
grant select, insert, update, delete on table public.account_snapshots to authenticated;

create policy "Users can read their own account snapshot"
on public.account_snapshots
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own account snapshot"
on public.account_snapshots
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own account snapshot"
on public.account_snapshots
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their own account snapshot"
on public.account_snapshots
for delete
to authenticated
using ((select auth.uid()) = user_id);

create function public.set_account_snapshot_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger set_account_snapshot_updated_at
before update on public.account_snapshots
for each row execute function public.set_account_snapshot_updated_at();
