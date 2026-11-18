create table if not exists public.backups (
  user_id uuid primary key references auth.users (id) on delete cascade,
  content jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.backups enable row level security;

drop policy if exists "backups_select_own" on public.backups;
create policy "backups_select_own"
  on public.backups for select
  using (auth.uid() = user_id);

drop policy if exists "backups_insert_own" on public.backups;
create policy "backups_insert_own"
  on public.backups for insert
  with check (auth.uid() = user_id);

drop policy if exists "backups_update_own" on public.backups;
create policy "backups_update_own"
  on public.backups for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
