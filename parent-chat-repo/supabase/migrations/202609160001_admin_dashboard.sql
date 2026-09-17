-- Private admin reporting. Add approved admin emails explicitly; do not make this table public.
create table if not exists public.admin_users (
  email text primary key,
  added_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;

create or replace function public.admin_dashboard_report()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if caller_email = '' or not exists (
    select 1 from public.admin_users where lower(email) = caller_email
  ) then
    raise exception 'admin access required' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'members', coalesce((
      select jsonb_agg(to_jsonb(m) order by m.joined desc)
      from (
        select id, name, email, town, premium, joined
        from public.members
        order by joined desc
      ) m
    ), '[]'::jsonb),
    'threads', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.created_at desc)
      from (
        select id, title, body, town, author, posted_by, created_at
        from public.forum_threads
        order by created_at desc
      ) t
    ), '[]'::jsonb),
    'listings', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.created_at desc)
      from (
        select id, title, price, cond, category, description, town, author, posted_by, created_at
        from public.market_listings
        order by created_at desc
      ) l
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.admin_dashboard_report() from public;
grant execute on function public.admin_dashboard_report() to authenticated;

-- Add an administrator with:
-- insert into public.admin_users (email) values ('admin@example.com');
