-- Estimated market value of open bids, written by the valuer on the office PC
-- (scripts/bid_valuer). Server-only tables; the app reads totals and one
-- bid's breakdown through two RPCs scoped to the caller's own inbox.
-- Estimates are contract values from public market prices, never profit.
begin;

-- Cancelled bids leave GeM's ongoing listing before their end date; the
-- valuer marks them so they drop out of every total.
alter table public.gem_bids
 add column status text not null default 'open' check (status in ('open','cancelled'));

-- One SHA-256 per bid document or attachment: unchanged documents are not
-- extracted again.
create table public.bid_documents (
 bid_id uuid not null references public.gem_bids(id) on delete cascade,
 url text not null check (length(url) between 1 and 500),
 sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
 fetched_at timestamptz not null default now(),
 primary key (bid_id, url)
);

-- Every market listing seen, kept as evidence. Re-scraping the same listing
-- updates its row (unique query_key + source_url) instead of adding one.
create table public.item_prices (
 id uuid primary key default gen_random_uuid(),
 query_key text not null check (length(query_key) between 1 and 300),
 source_name text not null check (length(source_name) between 1 and 60),
 source_url text not null check (source_url ~ '^https://' and length(source_url) <= 1000),
 seller_name text not null default '' check (length(seller_name) <= 300),
 seller_key text not null default '' check (length(seller_key) <= 300),
 title text not null default '' check (length(title) <= 500),
 listed_price numeric not null check (listed_price >= 0),
 gst_included boolean,                         -- null: the listing does not say
 gst_rate numeric check (gst_rate is null or gst_rate between 0 and 28),
 unit_price numeric check (unit_price is null or unit_price >= 0),
 unit text not null default '' check (length(unit) <= 20),
 tax_basis text not null check (tax_basis in ('gst_inclusive','gst_exclusive','unknown')),
 pack_quantity numeric not null default 1 check (pack_quantity > 0),
 currency text not null default 'INR' check (currency ~ '^[A-Z]{3}$'),
 fx_rate numeric check (fx_rate is null or fx_rate > 0),
 fx_rate_date date,
 product_match_score numeric check (product_match_score is null or product_match_score between 0 and 1),
 first_seen_at timestamptz not null default now(),
 last_verified_at timestamptz not null default now(),
 unique (query_key, source_url),
 -- A conversion is only ever stored together with the dated rate it used.
 check (currency = 'INR' or (fx_rate is null) = (fx_rate_date is null)),
 check (currency <> 'INR' or (fx_rate is null and fx_rate_date is null)),
 -- GST-inclusive means the listing said so, or said "excl. GST" with a known rate.
 check (tax_basis <> 'gst_inclusive' or gst_included or gst_rate is not null)
);
create index item_prices_fresh on public.item_prices(query_key, last_verified_at);

create table public.bid_items (
 id uuid primary key default gen_random_uuid(),
 bid_id uuid not null references public.gem_bids(id) on delete cascade,
 position integer not null check (position >= 0),
 name text not null check (length(name) between 1 and 500),
 spec jsonb not null default '{}'::jsonb,
 brand text not null default '' check (length(brand) <= 200),
 model text not null default '' check (length(model) <= 200),
 unit text not null default '' check (length(unit) <= 20),
 qty numeric check (qty is null or qty > 0),
 delivery jsonb not null default '[]'::jsonb,
 issues jsonb not null default '[]'::jsonb,
 priced boolean not null default false,
 unit_price numeric check (unit_price is null or unit_price >= 0),
 line_value numeric check (line_value is null or line_value >= 0),
 match_score numeric check (match_score is null or match_score between 0 and 1),
 offer_count integer not null default 0 check (offer_count >= 0),
 offer_ids uuid[] not null default '{}',
 price_reliability text not null default 'unpriced'
  check (price_reliability in ('normal','reduced','provisional','unpriced')),
 unique (bid_id, position),
 check (offer_count = cardinality(offer_ids)),
 check (priced = (unit_price is not null)),
 check (priced or (price_reliability = 'unpriced' and line_value is null and match_score is null)),
 check (not priced or (qty is not null and line_value is not null and match_score is not null
        and offer_count >= 1 and price_reliability <> 'unpriced'
        and abs(line_value - qty * unit_price) < 0.01))
);
create index bid_items_bid on public.bid_items(bid_id);

create table public.bid_valuations (
 bid_id uuid primary key references public.gem_bids(id) on delete cascade,
 priced_value_inr numeric not null default 0 check (priced_value_inr >= 0),
 item_count integer not null default 0 check (item_count >= 0),
 priced_count integer not null default 0 check (priced_count between 0 and item_count),
 pricing_coverage numeric check (pricing_coverage is null or pricing_coverage between 0 and 1),
 match_confidence numeric check (match_confidence is null or match_confidence between 0 and 1),
 price_reliability numeric check (price_reliability is null or price_reliability between 0 and 1),
 confidence text not null check (confidence in ('high','medium','low')),
 confidence_factors jsonb not null default '{}'::jsonb,
 extraction_status text not null check (extraction_status in ('complete','incomplete','unpriceable')),
 complete boolean not null,
 incomplete_reason text not null default '' check (length(incomplete_reason) <= 500),
 documents_hash text not null default '' check (length(documents_hash) <= 64),
 valued_at timestamptz not null default now(),
 check (complete = (extraction_status = 'complete' and item_count > 0 and priced_count = item_count)),
 -- Nothing priced: ₹0, no ratios (never a division by zero), low confidence.
 check (priced_count > 0 or (priced_value_inr = 0 and match_confidence is null
        and price_reliability is null and confidence = 'low'))
);

-- The latest valuation attempt per bid, so "failed, will retry" is never
-- shown as "not valued yet" or as ₹0. attempts counts consecutive failures.
create table public.bid_valuation_attempts (
 bid_id uuid primary key references public.gem_bids(id) on delete cascade,
 status text not null check (status in ('ok','failed')),
 stage text not null default '' check (stage in ('','fetch','extract','price','save')),
 error text not null default '' check (length(error) <= 500),
 attempts integer not null default 0 check (attempts >= 0),
 last_attempt_at timestamptz not null default now()
);

-- One row per valuer run: a lease (heartbeat) so two runs never overlap, and
-- a record of what the run did, readable from the dashboard.
create table public.valuation_runs (
 id uuid primary key,
 host text not null default '' check (length(host) <= 200),
 status text not null check (status in ('running','finished','failed','abandoned')),
 started_at timestamptz not null default now(),
 heartbeat_at timestamptz not null default now(),
 finished_at timestamptz,
 bids_ok integer not null default 0 check (bids_ok >= 0),
 bids_failed integer not null default 0 check (bids_failed >= 0),
 source_errors jsonb not null default '{}'::jsonb,
 note text not null default '' check (length(note) <= 500)
);
create index valuation_runs_started on public.valuation_runs(started_at desc);
create unique index valuation_runs_one_running on public.valuation_runs((true)) where status = 'running';

alter table public.bid_documents enable row level security;
alter table public.item_prices enable row level security;
alter table public.bid_items enable row level security;
alter table public.bid_valuations enable row level security;
alter table public.bid_valuation_attempts enable row level security;
alter table public.valuation_runs enable row level security;
revoke all on public.bid_documents, public.item_prices, public.bid_items, public.bid_valuations,
 public.bid_valuation_attempts, public.valuation_runs from anon, authenticated;
grant all on public.bid_documents, public.item_prices, public.bid_items, public.bid_valuations,
 public.bid_valuation_attempts, public.valuation_runs to service_role;

-- Server-only run lease. Returns p_id when this run may start, NULL while
-- another run's heartbeat is fresh. A run whose heartbeat stopped (the
-- process died) is marked abandoned and replaced. Calling again with the
-- same p_id is safe, so the caller can retry after a network error.
create function public.start_valuation_run(p_id uuid, p_host text default '',
 p_stale interval default '15 minutes')
returns uuid language plpgsql security definer set search_path = '' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended('valuation_runs', 0));
 if exists (select 1 from public.valuation_runs where id = p_id and status = 'running') then
  return p_id;
 end if;
 update public.valuation_runs set status = 'abandoned', finished_at = now(),
  note = 'heartbeat stopped'
 where status = 'running' and heartbeat_at < now() - p_stale;
 if exists (select 1 from public.valuation_runs where status = 'running') then
  return null;
 end if;
 insert into public.valuation_runs(id, host, status) values (p_id, left(coalesce(p_host, ''), 200), 'running');
 return p_id;
end $$;

-- False when the lease was lost (taken over as abandoned): the run must stop.
create function public.heartbeat_valuation_run(p_id uuid)
returns boolean language sql security definer set search_path = '' as $$
 update public.valuation_runs set heartbeat_at = now()
 where id = p_id and status = 'running'
 returning true
$$;

create function public.finish_valuation_run(p_id uuid, p_status text, p_ok integer,
 p_failed integer, p_source_errors jsonb default '{}'::jsonb, p_note text default '')
returns void language sql security definer set search_path = '' as $$
 update public.valuation_runs set status = p_status, finished_at = now(), heartbeat_at = now(),
  bids_ok = greatest(p_ok, 0), bids_failed = greatest(p_failed, 0),
  source_errors = coalesce(p_source_errors, '{}'::jsonb), note = left(coalesce(p_note, ''), 500)
 where id = p_id and status = 'running'
$$;

-- One bid's latest attempt. A failure adds to the consecutive count; a
-- success resets it.
create function public.record_bid_attempt(p_bid_id uuid, p_status text,
 p_stage text default '', p_error text default '')
returns void language sql security definer set search_path = '' as $$
 insert into public.bid_valuation_attempts as a (bid_id, status, stage, error, attempts, last_attempt_at)
 values (p_bid_id, p_status, coalesce(p_stage, ''), left(coalesce(p_error, ''), 500),
         case when p_status = 'failed' then 1 else 0 end, now())
 on conflict (bid_id) do update set status = excluded.status, stage = excluded.stage,
  error = excluded.error, last_attempt_at = excluded.last_attempt_at,
  attempts = case when excluded.status = 'failed' then a.attempts + 1 else 0 end
$$;

revoke all on function public.start_valuation_run(uuid, text, interval),
 public.heartbeat_valuation_run(uuid),
 public.finish_valuation_run(uuid, text, integer, integer, jsonb, text),
 public.record_bid_attempt(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.start_valuation_run(uuid, text, interval),
 public.heartbeat_valuation_run(uuid),
 public.finish_valuation_run(uuid, text, integer, integer, jsonb, text),
 public.record_bid_attempt(uuid, text, text, text) to service_role;

-- End of the valuation window: the whole tenth day after today, in IST.
-- Shared by the valuer's candidate list and the app's totals.
create function public.valuation_window_end(p_now timestamptz default now())
returns timestamptz language sql stable set search_path = '' as $$
 select (((p_now at time zone 'Asia/Kolkata')::date + 11)::timestamp at time zone 'Asia/Kolkata')
$$;
grant execute on function public.valuation_window_end(timestamptz) to authenticated, service_role;

-- Server-only. Open matched bids in the window whose valuation is missing or
-- older than p_stale, soonest-closing first.
create function public.valuer_candidate_bids(p_limit integer default 300,
 p_stale interval default '3 days')
returns table (id uuid, source_id text, title text, category text, quantity integer,
 details jsonb, source_url text, closes_at timestamptz, valued_at timestamptz,
 documents_hash text)
language sql stable security definer set search_path = '' as $$
 select b.id, b.source_id, b.title, b.category, b.quantity, b.details, b.source_url,
        b.closes_at, v.valued_at, coalesce(v.documents_hash, '')
 from public.gem_bids b
 left join public.bid_valuations v on v.bid_id = b.id
 where b.published and b.status = 'open'
  and b.closes_at > now() and b.closes_at < public.valuation_window_end()
  and exists (select 1 from public.bid_notifications n where n.bid_id = b.id)
  and (v.valued_at is null or v.valued_at < now() - p_stale)
  -- A failed bid waits 2^failures hours (at most a day) before the next try.
  and not exists (select 1 from public.bid_valuation_attempts a
                  where a.bid_id = b.id and a.status = 'failed'
                   and a.last_attempt_at > now() - least(interval '24 hours',
                                                         interval '1 hour' * power(2, a.attempts)))
 order by b.closes_at
 limit greatest(p_limit, 0)
$$;
revoke all on function public.valuer_candidate_bids(integer, interval) from public, anon, authenticated;
grant execute on function public.valuer_candidate_bids(integer, interval) to service_role;

-- Server-only. Replaces one bid's items and valuation in a single
-- transaction: a failure leaves the previous rows exactly as they were.
-- Item counts and the priced total are derived here, not trusted from input.
create function public.replace_bid_valuation(p_bid_id uuid, p_items jsonb, p_valuation jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 n_items integer; n_priced integer; total numeric;
 status text := p_valuation->>'extraction_status';
begin
 if not exists (select 1 from public.gem_bids where id = p_bid_id) then
  raise exception 'Unknown bid %', p_bid_id;
 end if;
 if jsonb_typeof(p_items) <> 'array' then raise exception 'p_items must be an array'; end if;
 -- Priced items may only use fresh, INR, GST-comparable offers.
 if exists (
  select 1
  from jsonb_array_elements(p_items) i
  cross join lateral jsonb_array_elements_text(coalesce(i->'offer_ids', '[]'::jsonb)) o(offer_id)
  left join public.item_prices p on p.id = o.offer_id::uuid
  where coalesce((i->>'priced')::boolean, false)
   and (p.id is null or p.currency <> 'INR' or p.tax_basis <> 'gst_inclusive'
        or p.unit_price is null or p.last_verified_at < now() - interval '3 days'))
 then
  raise exception 'A priced item uses a missing, stale, non-INR or non-GST-comparable offer';
 end if;

 delete from public.bid_items where bid_id = p_bid_id;
 insert into public.bid_items (bid_id, position, name, spec, brand, model, unit, qty, delivery,
  issues, priced, unit_price, line_value, match_score, offer_count, offer_ids, price_reliability)
 select p_bid_id, (e.ord - 1)::integer, e.i->>'name',
  coalesce(e.i->'spec', '{}'::jsonb), coalesce(e.i->>'brand', ''), coalesce(e.i->>'model', ''),
  coalesce(e.i->>'unit', ''), (e.i->>'qty')::numeric, coalesce(e.i->'delivery', '[]'::jsonb),
  coalesce(e.i->'issues', '[]'::jsonb), coalesce((e.i->>'priced')::boolean, false),
  (e.i->>'unit_price')::numeric, (e.i->>'line_value')::numeric, (e.i->>'match_score')::numeric,
  jsonb_array_length(coalesce(e.i->'offer_ids', '[]'::jsonb)),
  array(select x::uuid from jsonb_array_elements_text(coalesce(e.i->'offer_ids', '[]'::jsonb)) x),
  coalesce(e.i->>'price_reliability', 'unpriced')
 from jsonb_array_elements(p_items) with ordinality e(i, ord);

 select count(*), count(*) filter (where priced), coalesce(sum(line_value) filter (where priced), 0)
 into n_items, n_priced, total
 from public.bid_items where bid_id = p_bid_id;

 insert into public.bid_valuations as v (bid_id, priced_value_inr, item_count, priced_count,
  pricing_coverage, match_confidence, price_reliability, confidence, confidence_factors,
  extraction_status, complete, incomplete_reason, documents_hash, valued_at)
 values (p_bid_id, total, n_items, n_priced,
  case when n_items > 0 then n_priced::numeric / n_items end,
  case when n_priced > 0 then (p_valuation->>'match_confidence')::numeric end,
  case when n_priced > 0 then (p_valuation->>'price_reliability')::numeric end,
  case when n_priced > 0 then coalesce(p_valuation->>'confidence', 'low') else 'low' end,
  coalesce(p_valuation->'confidence_factors', '{}'::jsonb),
  status,
  status = 'complete' and n_items > 0 and n_priced = n_items,
  coalesce(p_valuation->>'incomplete_reason', ''),
  coalesce(p_valuation->>'documents_hash', ''), now())
 on conflict (bid_id) do update set
  priced_value_inr = excluded.priced_value_inr, item_count = excluded.item_count,
  priced_count = excluded.priced_count, pricing_coverage = excluded.pricing_coverage,
  match_confidence = excluded.match_confidence, price_reliability = excluded.price_reliability,
  confidence = excluded.confidence, confidence_factors = excluded.confidence_factors,
  extraction_status = excluded.extraction_status, complete = excluded.complete,
  incomplete_reason = excluded.incomplete_reason, documents_hash = excluded.documents_hash,
  valued_at = excluded.valued_at;

 return jsonb_build_object('items', n_items, 'priced', n_priced, 'priced_value_inr', total);
end $$;
revoke all on function public.replace_bid_valuation(uuid, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.replace_bid_valuation(uuid, jsonb, jsonb) to service_role;

-- The caller's open matched bids in the window. complete_value_inr sums only
-- bids with every item priced; partial_value_inr is the priced part of the
-- rest, kept separate. Not-complete bids are split by why, so ₹0 is never
-- shown for a bid that was simply not valued:
--   no_price_count: valued, but no item could be priced
--   failed_count:   not valued; the latest attempt failed (it will retry)
--   pending_count:  not valued yet
create function public.my_open_bids_value()
returns jsonb language sql stable security definer set search_path = '' as $$
 with open_bids as (
  select v.bid_id is not null as valued, v.complete, v.priced_value_inr, v.priced_count,
         a.status as attempt
  from public.bid_notifications n
  join public.gem_bids b on b.id = n.bid_id
  left join public.bid_valuations v on v.bid_id = b.id
  left join public.bid_valuation_attempts a on a.bid_id = b.id
  where n.user_id = auth.uid()
   and b.published and b.status = 'open'
   and b.closes_at > now() and b.closes_at < public.valuation_window_end()
 )
 select jsonb_build_object(
  'open_count', count(*),
  'complete_count', count(*) filter (where complete),
  'incomplete_count', count(*) filter (where complete is not true),
  'no_price_count', count(*) filter (where valued and priced_count = 0),
  'failed_count', count(*) filter (where not valued and attempt = 'failed'),
  'pending_count', count(*) filter (where not valued and attempt is distinct from 'failed'),
  'complete_value_inr', coalesce(sum(priced_value_inr) filter (where complete), 0),
  'partial_value_inr', coalesce(sum(priced_value_inr) filter (where complete is not true), 0))
 from open_bids
$$;
revoke all on function public.my_open_bids_value() from public, anon;
grant execute on function public.my_open_bids_value() to authenticated;

-- One bid's status and breakdown, only if the bid is in the caller's own
-- inbox (NULL otherwise). status: 'valued', 'failed' (will retry) or
-- 'pending'. Error text stays server-side; the app sees stage and time.
create function public.bid_valuation_detail(p_bid_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
 select jsonb_build_object(
  'status', case when v.bid_id is not null then 'valued'
                 when a.status = 'failed' then 'failed' else 'pending' end,
  'attempt', case when a.bid_id is not null then jsonb_build_object(
    'status', a.status, 'stage', a.stage, 'attempts', a.attempts,
    'last_attempt_at', a.last_attempt_at) end,
  'valuation', to_jsonb(v) - 'documents_hash',
  'items', coalesce((
   select jsonb_agg(jsonb_build_object(
    'name', i.name, 'brand', i.brand, 'model', i.model, 'unit', i.unit, 'qty', i.qty,
    'priced', i.priced, 'unit_price', i.unit_price, 'line_value', i.line_value,
    'match_score', i.match_score, 'offer_count', i.offer_count,
    'price_reliability', i.price_reliability, 'issues', i.issues,
    'offers', coalesce((
     select jsonb_agg(jsonb_build_object(
      'source_name', p.source_name, 'source_url', p.source_url, 'seller_name', p.seller_name,
      'unit_price', p.unit_price, 'listed_price', p.listed_price,
      'gst_included', p.gst_included, 'gst_rate', p.gst_rate,
      'last_verified_at', p.last_verified_at) order by p.unit_price)
     from public.item_prices p where p.id = any(i.offer_ids)), '[]'::jsonb))
    order by i.position)
   from public.bid_items i where i.bid_id = p_bid_id), '[]'::jsonb))
 from (select p_bid_id as id) target
 left join public.bid_valuations v on v.bid_id = target.id
 left join public.bid_valuation_attempts a on a.bid_id = target.id
 where exists (select 1 from public.bid_notifications n
               where n.bid_id = p_bid_id and n.user_id = auth.uid())
$$;
revoke all on function public.bid_valuation_detail(uuid) from public, anon;
grant execute on function public.bid_valuation_detail(uuid) to authenticated;

commit;
