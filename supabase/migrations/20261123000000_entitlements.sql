create table if not exists public.entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  is_premium boolean not null default false,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.entitlements enable row level security;

drop policy if exists "entitlements_select_own" on public.entitlements;
create policy "entitlements_select_own"
  on public.entitlements for select
  using (auth.uid() = user_id);

revoke all on public.entitlements from anon, authenticated;
grant select on public.entitlements to authenticated;

-- Answers only for the caller: another user's status always reads false.
create or replace function public.is_premium(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.entitlements
    where user_id = uid
      and uid = auth.uid()
      and is_premium
      and expires_at > now()
  );
$$;

revoke execute on function public.is_premium(uuid) from public, anon;
grant execute on function public.is_premium(uuid) to authenticated;

-- `ts` is the RevenueCat event time; an event older than the stored row is
-- dropped. Users deleted from auth are skipped instead of failing the FK.
create or replace function public.apply_entitlement(
  uid uuid,
  premium boolean,
  expires timestamptz,
  ts timestamptz
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.entitlements (user_id, is_premium, expires_at, updated_at)
  select uid, premium, expires, ts
  where exists (select 1 from auth.users where id = uid)
  on conflict (user_id) do update
    set is_premium = excluded.is_premium,
        expires_at = excluded.expires_at,
        updated_at = excluded.updated_at
    where excluded.updated_at >= entitlements.updated_at;
$$;

revoke execute on function public.apply_entitlement(uuid, boolean, timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function public.apply_entitlement(uuid, boolean, timestamptz, timestamptz)
  to service_role;

-- TRANSFER events carry no expiry, so the destination inherits the latest
-- expiry held by the source accounts.
create or replace function public.transfer_entitlement(
  from_ids uuid[],
  to_id uuid,
  expires timestamptz,
  ts timestamptz
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  moved timestamptz;
begin
  select greatest(expires, max(expires_at)) into moved
  from public.entitlements
  where user_id = any (from_ids) and is_premium;

  update public.entitlements
  set is_premium = false, updated_at = ts
  where user_id = any (from_ids) and updated_at <= ts;

  if to_id is not null and moved is not null then
    perform public.apply_entitlement(to_id, true, moved, ts);
  end if;
end;
$$;

revoke execute on function public.transfer_entitlement(uuid[], uuid, timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function public.transfer_entitlement(uuid[], uuid, timestamptz, timestamptz)
  to service_role;

drop policy if exists "backups_insert_own" on public.backups;
create policy "backups_insert_own"
  on public.backups for insert
  with check (auth.uid() = user_id and public.is_premium(auth.uid()));

drop policy if exists "backups_update_own" on public.backups;
create policy "backups_update_own"
  on public.backups for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and public.is_premium(auth.uid()));
