-- Bid alert matching, checked against all 31,816 open bids and the 10,438
-- GeM categories the app offers (Nov 2026):
--   * Keywords are now GeM category names ("Desktop Computers (V2)"). A word
--     like "(v2)" could never match, so 82% of categories matched no open bid.
--     Words are now letters/digits only; version tags, numbers and bracketed
--     detail are ignored (brackets are kept when fewer than two words remain).
--   * Whole words, with plurals and "-ing": "Table" no longer matches
--     "Tablets", "pH" no longer "Photo", "Pulses" no longer "Pulsed";
--     "LED lights" still finds "LED lighting".
--   * Category names up to 200 characters save (502 were longer than 80 and
--     failed silently, leaving the seller with no alerts at all).
--   * Picking or changing keywords fills the alert inbox at once with up to
--     20 open matching bids (inbox only: no push or email burst), so a seller
--     sees alerts before the next new matching bid arrives.
--   * Bids GeM cancels or unpublishes drop out of inboxes and unsent alerts.
begin;

-- The words of a keyword that must all appear in a bid. Strict mode also
-- drops version tags, numbers and single letters ("V2", "50", "A").
create or replace function public.keyword_tokens(p_text text, p_strict boolean default true) returns text[]
language sql immutable set search_path='' as $$
 select coalesce(array_agg(distinct w), '{}') from (
  select regexp_replace(m[1], '^(\w{3,})s$', '\1') as w
  from regexp_matches(lower(coalesce(p_text, '')), '(\w+)', 'g') as m
 ) t
 where (not p_strict or w !~ '^(v[0-9]+|[0-9]+|[a-z])$')
   and w not in ('and','or','of','for','the','with','to','in','on','at','by','is',
    'service','supply','supplie','item','good','equipment','material','procurement',
    'purchase','custom','bid','boq','work','product','various','misc','general',
    'hiring_of','other','new','annual','contract','rate');
$$;

-- One regex per keyword, built once: every chosen word must appear as a
-- whole word (plural or "-ing" allowed). NULL when the keyword has no words.
create or replace function public.keyword_pattern(p_keyword text) returns text
language sql immutable set search_path='' as $$
 with bare as (
  select public.keyword_tokens(regexp_replace(lower(coalesce(p_keyword, '')), '\([^)]*\)', ' ', 'g')) as ws
 ), full_ as (
  select case when cardinality(b.ws) >= 2 then b.ws else public.keyword_tokens(p_keyword) end as ws
  from bare b
 ), picked as (
  -- Only tags or letters ("C++", "A4"): match those rather than nothing.
  select case when cardinality(f.ws) > 0 then f.ws else public.keyword_tokens(p_keyword, false) end as ws
  from full_ f
 )
 select '^' || string_agg('(?=.*\m' || w || '(s|es|ing)?\M)', '' order by w)
 from picked, unnest(picked.ws) as w;
$$;

create or replace function public.keyword_matches(p_text text, p_keyword text) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(lower(p_text) ~ public.keyword_pattern(p_keyword), false);
$$;

-- Matching with patterns built beforehand (fast path for scans of all bids).
create or replace function public.patterns_match(p_text text, p_state text, p_patterns text[], p_states text[])
returns boolean language sql immutable set search_path='' as $$
 select exists(select 1 from unnest(p_patterns) r where r is not null and lower(p_text) ~ r)
  and (cardinality(p_states) = 0 or exists(select 1 from unnest(p_states) st
   where lower(trim(st)) = lower(p_state)));
$$;

create or replace function public.keyword_patterns(p_keywords text[]) returns text[]
language sql immutable set search_path='' as $$
 select coalesce(array_agg(public.keyword_pattern(k)), '{}') from unnest(p_keywords) k;
$$;

-- "Bids for you" and the Home counter: patterns built once per call.
create or replace function public.my_matching_bids(p_limit integer default 50)
returns setof public.gem_bids language sql stable set search_path='' as $$
 with pr as (
  select public.keyword_patterns(p.keywords) as pats, p.states
  from public.bid_alert_preferences p where p.user_id = (select auth.uid())
 )
 select b.* from public.gem_bids b, pr
 where b.published and b.closes_at > now() and b.status <> 'cancelled'
  and public.patterns_match(b.title || ' ' || b.category, b.state, pr.pats, pr.states)
 order by coalesce(b.starts_at, b.fetched_at) desc
 limit least(greatest(coalesce(p_limit,50),1),100);
$$;

create or replace function public.my_matching_bids_stats()
returns table(total integer, closing_7d integer)
language sql stable security definer set search_path = '' as $$
 with pr as (
  select public.keyword_patterns(p.keywords) as pats, p.states
  from public.bid_alert_preferences p where p.user_id = (select auth.uid())
 )
 select count(*)::integer,
  count(*) filter (where b.closes_at <= now() + interval '7 days')::integer
 from public.gem_bids b, pr
 where b.published and b.closes_at > now() and b.status <> 'cancelled'
  and public.patterns_match(b.title || ' ' || b.category, b.state, pr.pats, pr.states);
$$;

-- Category names can be long; keep the 10-keyword limit.
create or replace function public.save_bid_interests(p_keywords text[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid(); result public.bid_alert_preferences;
begin
 if caller is null then raise exception 'Authentication required'; end if;
 p_keywords := coalesce(p_keywords, '{}');
 if cardinality(p_keywords) > 10 or exists(select 1 from unnest(p_keywords) v
  where length(trim(v)) = 0 or length(v) > 200)
 then raise exception 'Use up to 10 keywords of 1 to 200 characters'; end if;
 perform pg_advisory_xact_lock(hashtextextended(caller::text,0));
 insert into public.bid_alert_preferences as prefs(user_id,keywords) values(caller,p_keywords)
 on conflict(user_id) do update set keywords=excluded.keywords, updated_at=now()
 returning * into result;
 return to_jsonb(result);
end $$;

-- Up to 20 open matching bids into one seller's inbox (no push or email).
create or replace function public.backfill_bid_alerts(p_user uuid) returns integer
language plpgsql security definer set search_path='' as $$
declare pref public.bid_alert_preferences; pats text[]; added integer;
begin
 select * into pref from public.bid_alert_preferences where user_id = p_user;
 if not found or not pref.in_app_enabled or cardinality(pref.keywords) = 0 then return 0; end if;
 pats := public.keyword_patterns(pref.keywords);
 insert into public.bid_notifications(user_id,bid_id,title,body,source_url,created_at)
 select pref.user_id, b.id, b.title,
  concat_ws(' · ', nullif(b.buyer,''), nullif(b.state,''), b.source_id), b.source_url,
  least(coalesce(b.starts_at, b.fetched_at), now())
 from public.gem_bids b
 where b.published and b.closes_at > now() and b.status <> 'cancelled'
   and public.patterns_match(b.title || ' ' || b.category, b.state, pats, pref.states)
 order by coalesce(b.starts_at, b.fetched_at) desc
 limit 20
 on conflict (user_id,bid_id) do nothing;
 get diagnostics added = row_count;
 return added;
end $$;
revoke all on function public.backfill_bid_alerts(uuid) from public, anon, authenticated;

-- Keywords or states saved: drop alerts that no longer match, then fill.
create or replace function public.prune_stale_bid_alerts() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op = 'UPDATE' and new.keywords is not distinct from old.keywords
    and new.states is not distinct from old.states then
  return new;
 end if;
 if tg_op = 'UPDATE' then
  delete from public.bid_notifications n using public.gem_bids b
  where n.user_id = new.user_id and b.id = n.bid_id
    and not public.bid_matches(b.title || ' ' || b.category, b.state, new.keywords, new.states);
  update public.bid_delivery_jobs j set status = 'cancelled'
  from public.gem_bids b
  where j.user_id = new.user_id and j.status = 'pending' and b.id = j.bid_id
    and not public.bid_matches(b.title || ' ' || b.category, b.state, new.keywords, new.states);
 end if;
 perform public.backfill_bid_alerts(new.user_id);
 return new;
end $$;
revoke all on function public.prune_stale_bid_alerts() from public, anon, authenticated;
drop trigger if exists bid_alert_preferences_prune on public.bid_alert_preferences;
create trigger bid_alert_preferences_prune
 after insert or update of keywords, states on public.bid_alert_preferences
 for each row execute function public.prune_stale_bid_alerts();

-- A bid GeM cancels or unpublishes leaves inboxes and unsent alerts.
create or replace function public.withdraw_cancelled_bid_alerts() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status = 'cancelled' or not new.published then
  delete from public.bid_notifications where bid_id = new.id;
  update public.bid_delivery_jobs set status = 'cancelled', last_error = 'Bid cancelled on GeM'
  where bid_id = new.id and status = 'pending';
 end if;
 return new;
end $$;
revoke all on function public.withdraw_cancelled_bid_alerts() from public, anon, authenticated;
drop trigger if exists gem_bids_withdraw_alerts on public.gem_bids;
create trigger gem_bids_withdraw_alerts
 after update of status, published on public.gem_bids
 for each row when (new.status = 'cancelled' or not new.published)
 execute function public.withdraw_cancelled_bid_alerts();

-- One-off with the new matching: tidy every inbox, then fill it.
delete from public.bid_notifications n
using public.gem_bids b, public.bid_alert_preferences p
where b.id = n.bid_id and p.user_id = n.user_id
  and not public.bid_matches(b.title || ' ' || b.category, b.state, p.keywords, p.states);
update public.bid_delivery_jobs j set status = 'cancelled'
from public.gem_bids b, public.bid_alert_preferences p
where j.status = 'pending' and b.id = j.bid_id and p.user_id = j.user_id
  and not public.bid_matches(b.title || ' ' || b.category, b.state, p.keywords, p.states);
select public.backfill_bid_alerts(user_id) from public.bid_alert_preferences;

commit;
