-- Keep a versioned server-side record of the terms and separate cross-border
-- consent accepted immediately before an explicit cloud login. The record is
-- removed with the Auth user when the account is deleted.
create table public.privacy_consents (
    user_id uuid primary key references auth.users(id) on delete cascade,
    policy_version text not null,
    terms_version text not null,
    cross_border_consent boolean not null check (cross_border_consent),
    cross_border_recipient text not null,
    consented_at timestamptz not null default now()
);

alter table public.privacy_consents enable row level security;

revoke all on table public.privacy_consents from anon;
grant select, insert, update, delete on table public.privacy_consents to authenticated;

create policy "Users can read their own privacy consent"
on public.privacy_consents
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can record their own privacy consent"
on public.privacy_consents
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can renew their own privacy consent"
on public.privacy_consents
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their own privacy consent"
on public.privacy_consents
for delete
to authenticated
using ((select auth.uid()) = user_id);
