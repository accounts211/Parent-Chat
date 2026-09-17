-- Production hardening for the first public release.

create table if not exists public.stripe_events (
  event_id text primary key,
  event_type text not null,
  received_at timestamptz not null default now()
);

alter table public.stripe_events enable row level security;
revoke all on public.stripe_events from anon, authenticated;

do $$
begin
  alter table public.market_listings add column if not exists sold boolean not null default false;
  alter table public.market_listings add column if not exists sold_at timestamptz;
exception when duplicate_column then null;
end $$;

create index if not exists events_created_at_idx on public.events (created_at desc);
create index if not exists forum_threads_created_at_idx on public.forum_threads (created_at desc);
create index if not exists forum_replies_thread_id_created_at_idx on public.forum_replies (thread_id, created_at asc);
create index if not exists market_listings_created_at_idx on public.market_listings (created_at desc);
create index if not exists saved_filters_member_id_idx on public.saved_filters (member_id);
create index if not exists notifications_member_id_ts_idx on public.notifications (member_id, ts desc);
create index if not exists reports_created_at_idx on public.reports (created_at desc);
create index if not exists reports_target_idx on public.reports (target_type, target_id);

create policy "update own listings" on public.market_listings
  for update using (auth.uid() = posted_by) with check (auth.uid() = posted_by);
grant update (title, price, cond, category, description, town, photo, discount_note, sold, sold_at)
  on public.market_listings to authenticated;

revoke execute on function public.admin_dashboard_report() from anon;
revoke execute on function public.notify_matching_saved_filters() from anon, authenticated;
grant execute on function public.admin_dashboard_report() to authenticated;

insert into storage.buckets (id, name, public)
values ('market-photos', 'market-photos', true)
on conflict (id) do update set public = true;

create policy "members upload market photos" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'market-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "members delete own market photos" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'market-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Stripe event ids are inserted by the service-role webhook before processing.
-- A duplicate event_id is safely ignored by the webhook.
