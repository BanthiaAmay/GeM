-- Follow-ups after the GeM category picker went live:
--   * 95 GeM categories carry a Hindi name in brackets ("Vinegar (सिरका)").
--     The Hindi word was split into fragments that English bid titles never
--     contain, so such a category matched nothing. Only Latin letters and
--     digits now count as words (GeM bid titles are English).
--   * WhatsApp is no longer offered in the app: earlier opt-ins are switched
--     off and their waiting messages cancelled, so nothing piles up.
begin;

create or replace function public.keyword_tokens(p_text text, p_strict boolean default true) returns text[]
language sql immutable set search_path='' as $$
 select coalesce(array_agg(distinct w), '{}') from (
  select regexp_replace(m[1], '^(\w{3,})s$', '\1') as w
  from regexp_matches(lower(coalesce(p_text, '')), '([a-z0-9_]+)', 'g') as m
 ) t
 where (not p_strict or w !~ '^(v[0-9]+|[0-9]+|[a-z])$')
   and w not in ('and','or','of','for','the','with','to','in','on','at','by','is',
    'service','supply','supplie','item','good','equipment','material','procurement',
    'purchase','custom','bid','boq','work','product','various','misc','general',
    'hiring_of','other','new','annual','contract','rate');
$$;

-- Re-tidy and re-fill every inbox with the corrected matching.
delete from public.bid_notifications n
using public.gem_bids b, public.bid_alert_preferences p
where b.id = n.bid_id and p.user_id = n.user_id
  and not public.bid_matches(b.title || ' ' || b.category, b.state, p.keywords, p.states);
select public.backfill_bid_alerts(user_id) from public.bid_alert_preferences;

-- WhatsApp is off for everyone until it is offered again.
update public.bid_alert_preferences
set whatsapp_opt_in = false, consented_at = null, consent_version = null, updated_at = now()
where whatsapp_opt_in;
update public.bid_delivery_jobs set status = 'cancelled', last_error = 'WhatsApp not offered'
where channel = 'whatsapp' and status = 'pending';

commit;
