-- Run after all migrations in an isolated test database.
begin;
do $$
declare cases text[][] := array[
 -- keyword, bid text, should match
 array['Desktop Computers (V2)', 'Desktop Computers (V2) with Windows', 'true'],
 array['Paraffin Wax Bath for Physiotherapy/Rehabilitation (V2)', 'Paraffin Wax Bath for Physiotherapy/Rehabilitation (V2)', 'true'],
 array['Grain Storage Bin', 'Grain Storage Bins 50 MT galvanised', 'true'],
 array['Table', 'Supply of SIM based Intrinsically Safe Tablets', 'false'],
 array['Table', 'Office Tables and chairs', 'true'],
 array['pH Paper (V2)', 'Photo Paper, Bond Paper A4', 'false'],
 array['pH Paper (V2)', 'pH Paper (V2) strips', 'true'],
 array['Pulses', 'SYNERGIC PULSED GTAW MACHINE', 'false'],
 array['Pulses', 'Supply of pulses and rice', 'true'],
 array['LED lights', 'High mast lighting tower with LED flood light', 'true'],
 array['Uniform', 'Non-Uniformity Calibration Set-Up', 'false'],
 array['Uniform', 'PT UNIFORM (T-SHIRT & SHORTS)', 'true'],
 array['Plants (Flowering, Foliage, Ornamental & Medicinal)', 'Repair of Plant/ Systems/Equipments', 'false'],
 array['Service', 'Custom Bid for Services - anything', 'false'],
 array['Security services', 'Hiring of security manpower', 'true'],
 array['C++', 'C++ compiler licence', 'true'],
 array['Desktop Computers (V2)', 'Supply of V2 rockets', 'false']
];
 c text[];
begin
 foreach c slice 1 in array cases loop
  if public.keyword_matches(c[2], c[1]) <> c[3]::boolean then
   raise exception 'keyword % vs "%": expected %', c[1], c[2], c[3];
  end if;
 end loop;
end $$;

insert into auth.users(id) values ('00000000-0000-0000-0000-000000000c01'),('00000000-0000-0000-0000-000000000c02');
insert into public.gem_bids(id,source_id,title,category,state,closes_at,source_url,published,starts_at) values
 ('00000000-0000-0000-0000-00000000c0b1','AM-1','Desktop Computers (V2)','Desktop Computers (V2)','Delhi',now()+interval '9 days','https://bidplus.gem.gov.in/a1',true,now()-interval '2 days'),
 ('00000000-0000-0000-0000-00000000c0b2','AM-2','Office Chair (V3)','Office Chair','Delhi',now()+interval '9 days','https://bidplus.gem.gov.in/a2',true,now()-interval '1 day'),
 ('00000000-0000-0000-0000-00000000c0b3','AM-3','Desktop Computers (V2)','Desktop Computers','Delhi',now()-interval '1 day','https://bidplus.gem.gov.in/a3',true,now()-interval '9 days');

-- A long GeM category name saves, and the inbox fills with open matches only.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000c01',true);
select public.save_bid_interests(array['Desktop Computers (V2) ' || repeat('with extra specification text ', 4)]);
select public.save_bid_interests(array['Desktop Computers (V2)']);
reset role;
do $$begin
 if (select count(*) from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000c01') <> 1
 then raise exception 'Backfill should add the one open matching bid'; end if;
 if exists(select 1 from public.bid_delivery_jobs where user_id='00000000-0000-0000-0000-000000000c01')
 then raise exception 'Backfill must not send push or email'; end if;
end $$;

-- Changing the business swaps the inbox.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000c01',true);
select public.save_bid_interests(array['Office Chair']);
reset role;
do $$begin
 if exists(select 1 from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000c01'
   and bid_id='00000000-0000-0000-0000-00000000c0b1') then raise exception 'Old business alert kept'; end if;
 if not exists(select 1 from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000c01'
   and bid_id='00000000-0000-0000-0000-00000000c0b2') then raise exception 'New business not backfilled'; end if;
end $$;

-- App alerts off: no inbox backfill.
insert into public.bid_alert_preferences(user_id,keywords,in_app_enabled)
 values ('00000000-0000-0000-0000-000000000c02',array['Office Chair'],false);
do $$begin
 if exists(select 1 from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000c02')
 then raise exception 'Backfilled although app alerts are off'; end if;
end $$;

-- GeM cancels a bid: it leaves inboxes and unsent alerts.
insert into public.bid_delivery_jobs(user_id,bid_id,channel)
 values ('00000000-0000-0000-0000-000000000c01','00000000-0000-0000-0000-00000000c0b2','email');
update public.gem_bids set status='cancelled' where id='00000000-0000-0000-0000-00000000c0b2';
do $$begin
 if exists(select 1 from public.bid_notifications where bid_id='00000000-0000-0000-0000-00000000c0b2')
 then raise exception 'Cancelled bid still in an inbox'; end if;
 if (select status from public.bid_delivery_jobs where bid_id='00000000-0000-0000-0000-00000000c0b2') <> 'cancelled'
 then raise exception 'Cancelled bid email still pending'; end if;
end $$;
rollback;
