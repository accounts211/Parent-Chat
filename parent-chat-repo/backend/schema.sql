-- ============================================================
-- Parent Chat — Supabase schema (v2: real auth)
-- Run this on a FRESH Supabase project: Dashboard → SQL Editor → New query
-- → paste → Run. If you already ran the v1 schema on a live project with
-- real signups, talk to me before running this — it changes the shape of
-- the members table (see comments below) and a plain re-run will error on
-- tables that already exist.
-- ============================================================

create extension if not exists pgcrypto;

-- members.id is now the SAME id as the Supabase Auth user (auth.users.id),
-- not an independently generated one. This is what makes "only you can
-- edit your own profile" actually enforceable.
create table members (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  name text not null,
  town text not null,
  premium boolean not null default false,
  premium_since timestamptz,
  joined timestamptz not null default now()
);

create table saved_filters (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references members(id) on delete cascade,
  keyword text default '',
  category text default ''
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references members(id) on delete cascade,
  msg text not null,
  ts timestamptz not null default now(),
  read boolean not null default false
);

create table events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_date date,
  description text default '',
  town text not null,
  author text default 'A parent',
  posted_by uuid references auth.users(id),
  featured boolean not null default false,
  discount_note text default '',
  created_at timestamptz not null default now()
);

create table forum_threads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text default '',
  town text not null,
  author text default 'A parent',
  posted_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table forum_replies (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid references forum_threads(id) on delete cascade,
  who text default 'A parent',
  body text not null,
  posted_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table market_listings (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  price numeric default 0,
  cond text default 'Good',
  category text default 'Other',
  description text default '',
  town text not null,
  author text default 'A parent',
  posted_by uuid references auth.users(id),
  photo text,
  discount_note text default '',
  created_at timestamptz not null default now()
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table members enable row level security;
alter table saved_filters enable row level security;
alter table notifications enable row level security;
alter table events enable row level security;
alter table forum_threads enable row level security;
alter table forum_replies enable row level security;
alter table market_listings enable row level security;

-- Members: name/town/premium/joined are publicly readable (needed for the
-- in-app Admin stats card and to keep things simple for a small community
-- app) but email is NOT — see the column grants below. You can only ever
-- create or edit your own row, and only the Stripe webhook (using the
-- service_role key, which bypasses all of this) can set "premium".
create policy "read members" on members for select using (true);
create policy "insert own member" on members for insert with check (auth.uid() = id);
create policy "update own member" on members for update using (auth.uid() = id) with check (auth.uid() = id);

revoke select on members from anon, authenticated;
grant select (id, name, town, premium, premium_since, joined) on members to anon, authenticated;
revoke update on members from anon, authenticated;
grant update (name, town) on members to anon, authenticated;
grant insert (id, email, name, town) on members to authenticated;

-- Saved filters & notifications are private to the member they belong to.
create policy "read own filters" on saved_filters for select using (auth.uid() = member_id);
create policy "insert own filters" on saved_filters for insert with check (auth.uid() = member_id);
create policy "delete own filters" on saved_filters for delete using (auth.uid() = member_id);

create policy "read own notifications" on notifications for select using (auth.uid() = member_id);
create policy "update own notifications" on notifications for update using (auth.uid() = member_id) with check (auth.uid() = member_id);
-- No client-side insert policy for notifications — they're only ever
-- created by the trigger function below, which runs with elevated
-- privileges. This is what lets the app notify OTHER members about a
-- matching listing without ever letting your browser read their saved
-- searches.

-- Community content: anyone can read (even signed-out visitors browsing),
-- but you must be signed in to post, and only as yourself.
create policy "read events" on events for select using (true);
create policy "insert own events" on events for insert with check (auth.uid() = posted_by);
create policy "read threads" on forum_threads for select using (true);
create policy "insert own threads" on forum_threads for insert with check (auth.uid() = posted_by);
create policy "read replies" on forum_replies for select using (true);
create policy "insert own replies" on forum_replies for insert with check (auth.uid() = posted_by);
create policy "read listings" on market_listings for select using (true);
create policy "insert own listings" on market_listings for insert with check (auth.uid() = posted_by);

grant usage on schema public to anon, authenticated;
grant select, insert on saved_filters to authenticated;
grant delete on saved_filters to authenticated;
grant select, update on notifications to anon, authenticated;
grant select on events to anon, authenticated;
grant insert on events to authenticated;
grant select on forum_threads to anon, authenticated;
grant insert on forum_threads to authenticated;
grant select on forum_replies to anon, authenticated;
grant insert on forum_replies to authenticated;
grant select on market_listings to anon, authenticated;
grant insert on market_listings to authenticated;

-- ============================================================
-- Server-side matching: when a new listing is posted, notify any member
-- whose saved search matches it. Runs as the function owner (bypassing
-- RLS), which is exactly why this needed to move server-side — the old
-- client-side version required your browser to read everyone else's
-- saved searches, which the tighter RLS above no longer allows.
-- ============================================================
create or replace function notify_matching_saved_filters()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into notifications (member_id, msg)
  select sf.member_id,
         'New listing matching "' || coalesce(nullif(sf.keyword,''), sf.category) || '": ' || new.title || ' — £' || new.price
  from saved_filters sf
  where (new.posted_by is null or sf.member_id <> new.posted_by)
    and (
      (sf.keyword <> '' and (new.title ilike '%'||sf.keyword||'%' or new.description ilike '%'||sf.keyword||'%'))
      or (sf.category <> '' and sf.category = new.category)
    );
  return new;
end;
$$;

drop trigger if exists trg_notify_saved_filters on market_listings;
create trigger trg_notify_saved_filters
after insert on market_listings
for each row execute function notify_matching_saved_filters();
-- ============================================================
-- Part 3: reports & saved items


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
