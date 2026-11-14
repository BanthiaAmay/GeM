-- Run after all migrations in an isolated test database.
begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-00000000c001'), ('00000000-0000-0000-0000-00000000c002');

-- The window ends at midnight IST after the tenth day.
do $$begin
 if public.valuation_window_end('2026-11-14 10:00+05:30') <> '2026-11-25 00:00+05:30'::timestamptz
  then raise exception 'window end: %', public.valuation_window_end('2026-11-14 10:00+05:30'); end if;
 -- 23:30 IST is already the next UTC day's evening in UTC terms; still IST-based.
 if public.valuation_window_end('2026-11-14 23:30+05:30') <> '2026-11-25 00:00+05:30'::timestamptz
  then raise exception 'late-evening window end'; end if;
 if public.valuation_window_end('2026-11-15 00:10+05:30') <> '2026-11-26 00:00+05:30'::timestamptz
  then raise exception 'after-midnight window end'; end if;
end $$;

insert into public.gem_bids(id,source_id,title,closes_at,source_url,published,status) values
 ('00000000-0000-0000-0000-00000000d001','V-COMPLETE','Chairs',now()+interval '2 days','https://bidplus.gem.gov.in/1',true,'open'),
 ('00000000-0000-0000-0000-00000000d002','V-PARTIAL','Desks',now()+interval '3 days','https://bidplus.gem.gov.in/2',true,'open'),
 ('00000000-0000-0000-0000-00000000d003','V-UNVALUED','Lamps',now()+interval '4 days','https://bidplus.gem.gov.in/3',true,'open'),
 ('00000000-0000-0000-0000-00000000d004','V-LAST-SECOND','Fans',public.valuation_window_end()-interval '1 second','https://bidplus.gem.gov.in/4',true,'open'),
 ('00000000-0000-0000-0000-00000000d005','V-DAY-11','Tables',public.valuation_window_end(),'https://bidplus.gem.gov.in/5',true,'open'),
 ('00000000-0000-0000-0000-00000000d006','V-CANCELLED','Pens',now()+interval '2 days','https://bidplus.gem.gov.in/6',true,'cancelled'),
 ('00000000-0000-0000-0000-00000000d007','V-CLOSED','Ink',now()-interval '1 hour','https://bidplus.gem.gov.in/7',true,'open'),
 ('00000000-0000-0000-0000-00000000d008','V-OTHER-USER','Sofas',now()+interval '2 days','https://bidplus.gem.gov.in/8',true,'open'),
 ('00000000-0000-0000-0000-00000000d009','V-PENDING','Racks',now()+interval '5 days','https://bidplus.gem.gov.in/9',true,'open'),
 ('00000000-0000-0000-0000-00000000d010','V-FAILED','Mats',now()+interval '5 days','https://bidplus.gem.gov.in/10',true,'open');
insert into public.bid_notifications(user_id,bid_id,title,body,source_url)
select '00000000-0000-0000-0000-00000000c001', id, 't', 'b', source_url
from public.gem_bids where source_id like 'V-%' and source_id <> 'V-OTHER-USER';
insert into public.bid_notifications(user_id,bid_id,title,body,source_url) values
 ('00000000-0000-0000-0000-00000000c002','00000000-0000-0000-0000-00000000d008','t','b','https://bidplus.gem.gov.in/8');

set local role service_role;
insert into public.item_prices(id,query_key,source_name,source_url,listed_price,gst_included,unit_price,tax_basis) values
 ('00000000-0000-0000-0000-00000000e001','chair','gem','https://mkp.gem.gov.in/a',1000,true,1000,'gst_inclusive'),
 ('00000000-0000-0000-0000-00000000e002','chair','indiamart','https://www.indiamart.com/b',1100,true,1100,'gst_inclusive'),
 ('00000000-0000-0000-0000-00000000e003','desk','indiamart','https://www.indiamart.com/c',5000,null,5000,'unknown');
insert into public.item_prices(id,query_key,source_name,source_url,listed_price,gst_included,unit_price,tax_basis,last_verified_at) values
 ('00000000-0000-0000-0000-00000000e004','fan','gem','https://mkp.gem.gov.in/d',2000,true,2000,'gst_inclusive',now()-interval '4 days');

do $$
declare r jsonb;
begin
 -- Complete: two items, both priced.
 r := public.replace_bid_valuation('00000000-0000-0000-0000-00000000d001',
  '[{"name":"Chair A","qty":10,"unit":"Nos","priced":true,"unit_price":1050,"line_value":10500,"match_score":0.9,"price_reliability":"reduced","offer_ids":["00000000-0000-0000-0000-00000000e001","00000000-0000-0000-0000-00000000e002"]},
    {"name":"Chair B","qty":2,"unit":"Nos","priced":true,"unit_price":1000,"line_value":2000,"match_score":0.8,"price_reliability":"provisional","offer_ids":["00000000-0000-0000-0000-00000000e001"]}]',
  '{"extraction_status":"complete","match_confidence":0.88,"price_reliability":0.62,"confidence":"medium"}');
 if (r->>'priced_value_inr')::numeric <> 12500 then raise exception 'complete total: %', r; end if;

 -- Partial: one priced, one unpriced.
 perform public.replace_bid_valuation('00000000-0000-0000-0000-00000000d002',
  '[{"name":"Desk","qty":3,"priced":true,"unit_price":1000,"line_value":3000,"match_score":0.8,"price_reliability":"provisional","offer_ids":["00000000-0000-0000-0000-00000000e001"]},
    {"name":"Custom cabinet","qty":1}]',
  '{"extraction_status":"complete","match_confidence":0.8,"price_reliability":0.4,"confidence":"low"}');
 if (select complete from public.bid_valuations where bid_id='00000000-0000-0000-0000-00000000d002')
  then raise exception 'Partial bid marked complete'; end if;

 -- Fully priced but the extraction was incomplete: not complete.
 perform public.replace_bid_valuation('00000000-0000-0000-0000-00000000d004',
  '[{"name":"Fan","qty":1,"priced":true,"unit_price":1000,"line_value":1000,"match_score":0.9,"price_reliability":"provisional","offer_ids":["00000000-0000-0000-0000-00000000e001"]}]',
  '{"extraction_status":"incomplete","match_confidence":0.9,"price_reliability":0.4,"confidence":"low"}');

 -- Zero priced: ₹0, null ratios, low confidence whatever was sent.
 perform public.replace_bid_valuation('00000000-0000-0000-0000-00000000d003',
  '[{"name":"Lamp","qty":5}]',
  '{"extraction_status":"complete","match_confidence":0.9,"price_reliability":1,"confidence":"high"}');
 if exists (select 1 from public.bid_valuations where bid_id='00000000-0000-0000-0000-00000000d003'
   and (priced_value_inr<>0 or match_confidence is not null or price_reliability is not null or confidence<>'low'))
  then raise exception 'Zero-priced guard failed'; end if;
end $$;

-- Attempts: failures count up and a success resets the count.
do $$begin
 perform public.record_bid_attempt('00000000-0000-0000-0000-00000000d010','failed','fetch','GeM unreachable');
 perform public.record_bid_attempt('00000000-0000-0000-0000-00000000d009','failed','price','x');
 perform public.record_bid_attempt('00000000-0000-0000-0000-00000000d009','failed','price','x');
 if (select attempts from public.bid_valuation_attempts where bid_id='00000000-0000-0000-0000-00000000d009') <> 2 then raise exception 'attempts not counted'; end if;
 perform public.record_bid_attempt('00000000-0000-0000-0000-00000000d009','ok');
 if (select attempts from public.bid_valuation_attempts where bid_id='00000000-0000-0000-0000-00000000d009') <> 0 then raise exception 'success did not reset'; end if;
 delete from public.bid_valuation_attempts where bid_id='00000000-0000-0000-0000-00000000d009';
end $$;

-- Run lease: one run at a time; a retry with the same id is fine; a dead
-- run (stale heartbeat) is taken over and can no longer heartbeat.
do $$
declare r1 uuid := '00000000-0000-0000-0000-0000000000a1'; r2 uuid := '00000000-0000-0000-0000-0000000000a2';
 r3 uuid := '00000000-0000-0000-0000-0000000000a3';
begin
 if public.start_valuation_run(r1, 'office-pc') is distinct from r1 then raise exception 'first run refused'; end if;
 if public.start_valuation_run(r2, 'laptop') is not null then raise exception 'overlapping run allowed'; end if;
 if public.start_valuation_run(r1, 'office-pc') is distinct from r1 then raise exception 'retry refused'; end if;
 if public.heartbeat_valuation_run(r1) is not true then raise exception 'heartbeat failed'; end if;
 update public.valuation_runs set heartbeat_at = now() - interval '20 minutes' where id = r1;
 if public.start_valuation_run(r2, 'laptop') is distinct from r2 then raise exception 'stale lease not taken over'; end if;
 if (select status from public.valuation_runs where id = r1) <> 'abandoned' then raise exception 'dead run not abandoned'; end if;
 if public.heartbeat_valuation_run(r1) is true then raise exception 'abandoned run still heartbeats'; end if;
 perform public.finish_valuation_run(r2, 'finished', 3, 1, '{"indiamart":{"unavailable":2}}', '');
 if (select (status, bids_ok, bids_failed) from public.valuation_runs where id = r2) <> ('finished'::text, 3, 1)
  then raise exception 'finish not recorded'; end if;
 if public.start_valuation_run(r3, 'office-pc') is distinct from r3 then raise exception 'new run after finish refused'; end if;
 perform public.finish_valuation_run(r3, 'finished', 0, 0);
end $$;

-- An unknown-GST offer cannot price an item; the old rows stay untouched.
do $$
declare before_count integer := (select count(*) from public.bid_items where bid_id='00000000-0000-0000-0000-00000000d002');
begin
 begin
  perform public.replace_bid_valuation('00000000-0000-0000-0000-00000000d002',
   '[{"name":"Desk","qty":3,"priced":true,"unit_price":5000,"line_value":15000,"match_score":0.9,"price_reliability":"provisional","offer_ids":["00000000-0000-0000-0000-00000000e003"]}]',
   '{"extraction_status":"complete","match_confidence":0.9,"price_reliability":0.4,"confidence":"low"}');
  raise exception 'Unknown-GST offer accepted';
 exception when raise_exception then
  if sqlerrm = 'Unknown-GST offer accepted' then raise; end if;
 end;
 -- A stale offer (verified 4 days ago) cannot price an item either.
 begin
  perform public.replace_bid_valuation('00000000-0000-0000-0000-00000000d002',
   '[{"name":"Desk","qty":1,"priced":true,"unit_price":2000,"line_value":2000,"match_score":0.9,"price_reliability":"provisional","offer_ids":["00000000-0000-0000-0000-00000000e004"]}]',
   '{"extraction_status":"complete","confidence":"low"}');
  raise exception 'Stale offer accepted';
 exception when raise_exception then
  if sqlerrm = 'Stale offer accepted' then raise; end if;
 end;
 -- A bad row mid-way rolls the whole replacement back.
 begin
  perform public.replace_bid_valuation('00000000-0000-0000-0000-00000000d002',
   '[{"name":"Desk","qty":3},{"name":"","qty":1}]', '{"extraction_status":"complete"}');
  raise exception 'Invalid item accepted';
 exception when check_violation then null;
 end;
 if (select count(*) from public.bid_items where bid_id='00000000-0000-0000-0000-00000000d002') <> before_count
  then raise exception 'Failed replacement changed items'; end if;
 if not exists (select 1 from public.bid_items where bid_id='00000000-0000-0000-0000-00000000d002' and name='Custom cabinet')
  then raise exception 'Old items lost'; end if;
end $$;

-- Foreign currency without a dated rate is refused.
do $$begin
 begin
  insert into public.item_prices(query_key,source_name,source_url,listed_price,currency,fx_rate,tax_basis)
  values('x','other','https://example.com/x',10,'USD',83,'unknown');
  raise exception 'Undated FX accepted';
 exception when check_violation then null;
 end;
 begin
  insert into public.item_prices(query_key,source_name,source_url,listed_price,tax_basis)
  values('x','other','https://example.com/y',10,'net');
  raise exception 'Bad tax basis accepted';
 exception when check_violation then null;
 end;
 -- Fresh valuations are skipped; only the never-valued V-OTHER-USER remains.
 -- V-FAILED is held back by its retry backoff.
 if (select array_agg(source_id) from public.valuer_candidate_bids(100, '3 days')) <> array['V-OTHER-USER','V-PENDING'] then
  raise exception 'Candidates: %', (select array_agg(source_id) from public.valuer_candidate_bids(100, '3 days'));
 end if;
 if (select count(*) from public.valuer_candidate_bids(100, '-1 hour')) <> 6 then
  raise exception 'Candidates: %', (select array_agg(source_id) from public.valuer_candidate_bids(100, '-1 hour'));
 end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000c001',true);
do $$
declare r jsonb := public.my_open_bids_value();
begin
 -- Open in window: COMPLETE, PARTIAL, UNVALUED, LAST-SECOND, PENDING, FAILED.
 -- Not: day 11, cancelled, closed, another user's bid.
 if (r->>'open_count')::int <> 6 then raise exception 'open: %', r; end if;
 if (r->>'complete_count')::int <> 1 then raise exception 'complete: %', r; end if;
 if (r->>'incomplete_count')::int <> 5 then raise exception 'incomplete: %', r; end if;
 -- ₹0 is never ambiguous: valued-with-no-price, failed and pending are apart.
 if (r->>'no_price_count')::int <> 1 then raise exception 'no price: %', r; end if;
 if (r->>'failed_count')::int <> 1 then raise exception 'failed: %', r; end if;
 if (r->>'pending_count')::int <> 1 then raise exception 'pending: %', r; end if;
 if (r->>'complete_value_inr')::numeric <> 12500 then raise exception 'complete value: %', r; end if;
 if (r->>'partial_value_inr')::numeric <> 4000 then raise exception 'partial value: %', r; end if;
 if public.bid_valuation_detail('00000000-0000-0000-0000-00000000d001') is null then raise exception 'Own detail hidden'; end if;
 if jsonb_array_length(public.bid_valuation_detail('00000000-0000-0000-0000-00000000d001')->'items') <> 2 then raise exception 'Detail items'; end if;
 if public.bid_valuation_detail('00000000-0000-0000-0000-00000000d008') is not null then raise exception 'Other user detail visible'; end if;
 if public.bid_valuation_detail('00000000-0000-0000-0000-00000000d001')->>'status' <> 'valued' then raise exception 'valued status'; end if;
 if public.bid_valuation_detail('00000000-0000-0000-0000-00000000d009')->>'status' <> 'pending' then raise exception 'pending status'; end if;
 r := public.bid_valuation_detail('00000000-0000-0000-0000-00000000d010');
 if r->>'status' <> 'failed' or r->'attempt'->>'stage' <> 'fetch' then raise exception 'failed status: %', r; end if;
 if r->'attempt' ? 'error' then raise exception 'error text exposed to the app'; end if;
 if jsonb_typeof(r->'valuation') <> 'null' then raise exception 'failed bid has a valuation: %', r; end if;
end $$;
do $$begin
 begin perform 1 from public.bid_valuations; raise exception 'Table readable';
 exception when insufficient_privilege then null; end;
 begin perform public.replace_bid_valuation('00000000-0000-0000-0000-00000000d001','[]','{}'); raise exception 'Writer callable';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000c002',true);
do $$begin
 if (public.my_open_bids_value()->>'open_count')::int <> 1 then raise exception 'Other user sees: %', public.my_open_bids_value(); end if;
 if (public.my_open_bids_value()->>'complete_value_inr')::numeric <> 0 then raise exception 'Other user value leaked'; end if;
end $$;
reset role;

do $$begin
 if has_function_privilege('anon','public.my_open_bids_value()','EXECUTE') then raise exception 'anon can read totals'; end if;
 if has_function_privilege('anon','public.bid_valuation_detail(uuid)','EXECUTE') then raise exception 'anon can read detail'; end if;
 if has_function_privilege('authenticated','public.valuer_candidate_bids(integer,interval)','EXECUTE') then raise exception 'candidates not server-only'; end if;
 if has_function_privilege('authenticated','public.start_valuation_run(uuid,text,interval)','EXECUTE') then raise exception 'lease not server-only'; end if;
 if has_function_privilege('authenticated','public.record_bid_attempt(uuid,text,text,text)','EXECUTE') then raise exception 'attempts not server-only'; end if;
end $$;
rollback;
