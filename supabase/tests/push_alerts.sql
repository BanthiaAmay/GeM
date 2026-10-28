-- Run after all migrations in an isolated test database. Never sends messages.
begin;
do $$begin
 if not public.keyword_matches('LED Luminaire For Road And Street Lights','LED lights') then raise exception 'Multi-word keyword failed'; end if;
 if not public.keyword_matches('Ball Point Pen (V2)','pens') then raise exception 'Plural keyword failed'; end if;
 if public.keyword_matches('Open tender for chairs','pen') then raise exception 'Keyword matched inside a word'; end if;
 if not public.keyword_matches('C++ compiler licence','c++') then raise exception 'Literal punctuation failed'; end if;
 if public.keyword_matches('Office stationery','%') or public.keyword_matches('Office stationery','.*') then raise exception 'Keyword treated as a pattern'; end if;
 if public.keyword_matches('Office stationery','   ') then raise exception 'Blank keyword matched'; end if;
 if public.bid_matches('Office stationery','Gujarat','{}','{}') then raise exception 'Empty keywords must not match'; end if;
end $$;

insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000301'),
 ('00000000-0000-0000-0000-000000000302'),
 ('00000000-0000-0000-0000-000000000303');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.save_bid_interests(array['LED lights','stationery']);
select public.register_push_device(repeat('a',40),'android','hi');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
select public.save_bid_interests(array[]::text[]);
select public.register_push_device(repeat('b',40),'ios','en');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select public.save_bid_interests(array['stationery']);
do $$begin
 if has_table_privilege('authenticated','public.push_devices','SELECT') then raise exception 'Device tokens readable by users'; end if;
 if has_function_privilege('authenticated','public.claim_push_jobs(integer,interval)','EXECUTE') then raise exception 'Claim must be server-only'; end if;
 begin
  perform public.save_bid_interests(array['']);
  raise exception 'Blank keyword accepted';
 exception when raise_exception then
  if SQLERRM <> 'Use up to 10 keywords of 1 to 80 characters' then raise; end if;
 end;
end $$;
reset role;
do $$begin
 if (select whatsapp_number from public.bid_alert_preferences where user_id='00000000-0000-0000-0000-000000000301') is not null
  or (select in_app_enabled from public.bid_alert_preferences where user_id='00000000-0000-0000-0000-000000000301') is not true
 then raise exception 'Interests should save without a phone, alerts on'; end if;
 if (select user_id from public.push_devices where token=repeat('a',40))<>'00000000-0000-0000-0000-000000000301'
 then raise exception 'Device registration failed'; end if;
end $$;

-- A token moves to whichever account signs in on the device.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
select public.register_push_device(repeat('b',40),'ios','ta');
select public.unregister_push_device(repeat('a',40));
reset role;
do $$begin
 if not exists(select 1 from public.push_devices where token=repeat('a',40)) then raise exception 'Another user removed a device'; end if;
 if (select language from public.push_devices where token=repeat('b',40))<>'ta' then raise exception 'Device refresh failed'; end if;
end $$;

insert into public.gem_bids(id,source_id,title,state,buyer,closes_at,starts_at,source_url,published) values
 ('00000000-0000-0000-0000-000000000401','GEM/2026/B/1','LED Luminaire For Road And Street Lights','Gujarat','Panchayat Department',now()+interval '5 days',now(),'https://bidplus.gem.gov.in/showbidDocument/1',true),
 ('00000000-0000-0000-0000-000000000402','GEM/2026/B/2','Office Stationery Kit','Maharashtra','',now()+interval '5 days',now()-interval '1 hour','https://bidplus.gem.gov.in/showbidDocument/2',true),
 ('00000000-0000-0000-0000-000000000403','GEM/2026/B/3','Open Shelving Unit','Kerala','',now()+interval '5 days',now(),'https://bidplus.gem.gov.in/showbidDocument/3',true);
set local role service_role;
select public.queue_bid_matches('00000000-0000-0000-0000-000000000401');
select public.queue_bid_matches('00000000-0000-0000-0000-000000000403');
reset role;
do $$begin
 if (select count(*) from public.bid_notifications)<>1 then raise exception 'Only user 301 should match the LED bid'; end if;
 if (select body from public.bid_notifications)<>'Panchayat Department · Gujarat · GEM/2026/B/1' then raise exception 'Inbox line wrong'; end if;
 if (select count(*) from public.bid_delivery_jobs where channel='push')<>1 then raise exception 'Push job not queued'; end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
do $$begin
 if (select count(*) from public.my_matching_bids())<>2 then raise exception 'Matching feed should list the LED and stationery bids'; end if;
 if (select source_id from public.my_matching_bids() limit 1)<>'GEM/2026/B/1' then raise exception 'Matching feed not newest first'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
do $$begin
 if exists(select 1 from public.my_matching_bids()) then raise exception 'No keywords should mean no matches'; end if;
end $$;
reset role;

set local role service_role;
do $$
declare claimed integer;
begin
 select count(*) into claimed from public.claim_push_jobs();
 if claimed<>1 then raise exception 'First claim should return one job, got %', claimed; end if;
 if exists(select 1 from public.claim_push_jobs()) then raise exception 'A leased job was claimed twice'; end if;
 update public.bid_delivery_jobs set status='sent', sent_at=now() where channel='push';
end $$;
select public.queue_bid_matches('00000000-0000-0000-0000-000000000402');
do $$begin
 if exists(select 1 from public.claim_push_jobs()) then raise exception 'Minimum gap between pushes ignored'; end if;
 if (select count(*) from public.claim_push_jobs(500, interval '0 seconds'))<>1 then raise exception 'Due job not claimed after gap'; end if;
end $$;
reset role;

-- Closed bids and turned-off alerts cancel pending pushes.
update public.bid_delivery_jobs set status='pending' where status='processing';
update public.bid_alert_preferences set in_app_enabled=false where user_id='00000000-0000-0000-0000-000000000301';
set local role service_role;
do $$begin
 if exists(select 1 from public.claim_push_jobs(500, interval '0 seconds')) then raise exception 'Opted-out user was claimed'; end if;
end $$;
reset role;
do $$begin
 if (select status from public.bid_delivery_jobs where bid_id='00000000-0000-0000-0000-000000000402' and channel='push')<>'cancelled' then raise exception 'Opt-out did not cancel push'; end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.delete_my_data();
reset role;
do $$begin
 if exists(select 1 from public.push_devices where user_id='00000000-0000-0000-0000-000000000301') then raise exception 'Device not deleted with data'; end if;
 if not exists(select 1 from public.push_devices where user_id='00000000-0000-0000-0000-000000000302') then raise exception 'Other user device deleted'; end if;
end $$;
rollback;
