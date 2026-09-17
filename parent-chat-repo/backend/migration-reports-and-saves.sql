-- ============================================================
-- Parent Chat — migration: reports & saved items (run AFTER schema.sql)
-- Adds: reporting (forum/marketplace), and free "save for later" bookmarks.
-- Safe to run on top of the v2 schema. Dashboard → SQL Editor → Run.
-- ============================================================

create table reports (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('thread','listing')),
  target_id uuid not null,
  reason text not null,
  details text default '',
  reported_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
alter table reports enable row level security;
-- No select policy for anon/authenticated on purpose — reports are only
-- ever visible to you, via Supabase Table Editor (service_role bypasses RLS).
create policy "insert own reports" on reports for insert with check (auth.uid() = reported_by);
grant usage on schema public to authenticated;
grant insert on reports to authenticated;

create table saved_items (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references members(id) on delete cascade,
  item_type text not null check (item_type in ('event','place')),
  item_ref text not null,
  created_at timestamptz not null default now(),
  unique (member_id, item_type, item_ref)
);
alter table saved_items enable row level security;
create policy "read own saved" on saved_items for select using (auth.uid() = member_id);
create policy "insert own saved" on saved_items for insert with check (auth.uid() = member_id);
create policy "delete own saved" on saved_items for delete using (auth.uid() = member_id);
grant select, insert, delete on saved_items to authenticated;
