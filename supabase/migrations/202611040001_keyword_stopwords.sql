-- Generic GeM words ("Service" alone matched about a quarter of all bids)
-- no longer count when matching. A keyword made only of such words matches
-- nothing; "Security services" still matches on "security".
begin;

create or replace function public.keyword_matches(p_text text, p_keyword text) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(bool_and(lower(p_text) ~ ('\m' || regexp_replace(w, '([!$()*+.:<=>?[\\\]^{|}-])', '\\\1', 'g'))), false)
 from (
  select regexp_replace(raw, '^(\w{3,})s$', '\1') as w
  from regexp_split_to_table(lower(trim(p_keyword)), '\s+') as raw where raw <> ''
 ) words
 where w not in ('and','or','of','for','the','with','to','in','on','at','by',
  'service','supply','supplie','item','good','equipment','material','procurement',
  'purchase','custom','bid','boq','work','product','various','misc','general',
  'hiring_of','other','new','annual','contract','rate');
$$;
commit;
