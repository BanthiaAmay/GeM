-- Records the objects first created by hand in the Supabase SQL editor for
-- Saved Bids, Tender Analytics and the Home counters, so the database can be
-- rebuilt from migrations and CI tests them. Written to be safe on the live
-- project: tables are created only if missing, and existing rows are kept.
--
-- It also settles three things the hand-made version left open:
--   * deleting an account removes the user's saved bids and analytics
--     (on delete cascade), and "Delete my data" clears them too;
--   * each user reads and writes only their own rows (RLS, owner-only);
--   * one row per user and bid, which the app's upserts rely on.
-- Also adds set_in_app_alerts: the Alerts page's "App Notifications" switch,
-- saved on its own like set_email_alerts (no WhatsApp number needed).
begin;

create table if not exists public.saved_bids (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  source_id text not null,
  bid_data jsonb not null,
  saved_at timestamptz not null default now()
);

create table if not exists public.tender_analytics_data (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  source_id text not null,
  status text default 'saved',
  procurement_cost numeric,
  manufacturing_cost numeric,
  labour_cost numeric,
  packaging_cost numeric,
  logistics_cost numeric,
  installation_cost numeric,
  taxes_cost numeric,
  compliance_cost numeric,
  warranty_cost numeric,
  financing_cost numeric,
  other_cost numeric,
  extra_costs_json text,
  selling_price numeric,
  gst_rate numeric default 18,
  bid_submission_date text,
  result_date text,
  award_date text,
  delivery_date text,
  invoice_date text,
  payment_received_date text,
  po_value numeric,
  amount_received numeric,
  notes text,
  updated_at timestamptz default now()
);

-- Rows belong to an account and go with it.
alter table public.saved_bids
  drop constraint if exists saved_bids_user_id_fkey,
  add constraint saved_bids_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete cascade;
alter table public.tender_analytics_data
  drop constraint if exists tender_analytics_data_user_id_fkey,
  add constraint tender_analytics_data_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete cascade;

-- One row per user and bid (the app upserts on user_id, source_id). Added only
-- when no unique index on exactly those columns exists yet.
do $$
declare t text;
begin
  foreach t in array array['saved_bids', 'tender_analytics_data'] loop
    if not exists (
      select 1 from pg_index i
      where i.indrelid = format('public.%I', t)::regclass and i.indisunique
        and (select array_agg(a.attname::text order by a.attname)
             from pg_attribute a
             where a.attrelid = i.indrelid and a.attnum = any(i.indkey))
            = array['source_id', 'user_id']
    ) then
      execute format('alter table public.%I add constraint %I unique (user_id, source_id)',
                     t, t || '_user_source_key');
    end if;
  end loop;
end $$;

-- Owner-only access, replacing whatever policies were set by hand.
alter table public.saved_bids enable row level security;
alter table public.tender_analytics_data enable row level security;
do $$
declare p record;
begin
  for p in select tablename, policyname from pg_policies
           where schemaname = 'public' and tablename in ('saved_bids', 'tender_analytics_data') loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;
create policy saved_bids_owner on public.saved_bids for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy tender_analytics_owner on public.tender_analytics_data for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on table public.saved_bids, public.tender_analytics_data from anon;
grant select, insert, update, delete on table public.saved_bids, public.tender_analytics_data
  to authenticated;

-- Home: open published bids on GeM (the "Active bids on GeM" tile). Public.
drop function if exists public.gem_active_bids_count();
create function public.gem_active_bids_count() returns integer
language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.gem_bids b where b.published and b.closes_at > now();
$$;
revoke all on function public.gem_active_bids_count() from public;
grant execute on function public.gem_active_bids_count() to anon, authenticated;

-- Home: the caller's matching open bids, and how many close within 7 days.
drop function if exists public.my_matching_bids_stats();
create function public.my_matching_bids_stats()
returns table(total integer, closing_7d integer)
language sql stable security definer set search_path = '' as $$
  select
    count(*)::integer,
    count(*) filter (where b.closes_at <= now() + interval '7 days')::integer
  from public.gem_bids b
  join public.bid_alert_preferences p on p.user_id = (select auth.uid())
  where b.published
    and b.closes_at > now()
    and public.bid_matches(b.title || ' ' || b.category, b.state, p.keywords, p.states);
$$;
revoke all on function public.my_matching_bids_stats() from public, anon;
grant execute on function public.my_matching_bids_stats() to authenticated;

-- Alerts page "App Notifications" switch. Off also cancels pending pushes.
create or replace function public.set_in_app_alerts(p_enabled boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid(); result public.bid_alert_preferences;
begin
 if caller is null then raise exception 'Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(caller::text,0));
 insert into public.bid_alert_preferences as prefs(user_id,in_app_enabled) values(caller,p_enabled)
 on conflict(user_id) do update set in_app_enabled=excluded.in_app_enabled, updated_at=now()
 returning * into result;
 if not p_enabled then
  update public.bid_delivery_jobs set status='cancelled'
  where user_id=caller and channel='push' and status='pending';
 end if;
 return to_jsonb(result);
end $$;
revoke all on function public.set_in_app_alerts(boolean) from public, anon;
grant execute on function public.set_in_app_alerts(boolean) to authenticated;

-- "Delete my data" also clears saved bids and Tender Analytics.
create or replace function public.delete_my_data() returns void language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Authentication required'; end if;
 delete from public.saved_bids where user_id=caller;
 delete from public.tender_analytics_data where user_id=caller;
 delete from public.saathi_usage where user_id=caller;
 delete from public.push_devices where user_id=caller;
 delete from public.bid_delivery_jobs where user_id=caller;
 delete from public.bid_notifications where user_id=caller;
 delete from public.bid_alert_preferences where user_id=caller;
 delete from public.funnel_events where user_id=caller;
 delete from public.support_requests where user_id=caller;
 delete from public.outcomes where user_id=caller;
 delete from public.research_assignments where user_id=caller;
 delete from public.profiles where id=caller;
end $$;

commit;
