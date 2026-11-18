-- Run after all migrations in an isolated test database.
begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000a01'),
 ('00000000-0000-0000-0000-000000000a02');
insert into public.gem_bids(source_id,title,category,state,closes_at,source_url,published) values
 ('SBA-1','Office chairs','Furniture','Delhi',now()+interval '3 days','https://bidplus.gem.gov.in/a',true),
 ('SBA-2','Office desks','Furniture','Delhi',now()+interval '20 days','https://bidplus.gem.gov.in/b',true),
 ('SBA-3','Office chairs','Furniture','Delhi',now()+interval '3 days','https://bidplus.gem.gov.in/c',false),
 ('SBA-4','Office chairs','Furniture','Delhi',now()-interval '1 day','https://bidplus.gem.gov.in/d',true);
insert into public.bid_alert_preferences(user_id,keywords) values ('00000000-0000-0000-0000-000000000a01',array['office']);

-- Home counters.
set local role anon;
do $$begin
 if public.gem_active_bids_count() <> (select count(*) from public.gem_bids where published and closes_at>now())
 then raise exception 'Active bids count is wrong'; end if;
 if has_function_privilege('anon','public.my_matching_bids_stats()','EXECUTE')
 then raise exception 'Matching stats must need sign-in'; end if;
 if has_table_privilege('anon','public.saved_bids','SELECT') or has_table_privilege('anon','public.tender_analytics_data','SELECT')
 then raise exception 'Signed-out visitors must not read saved bids or analytics'; end if;
end $$;
reset role;

-- A user saves bids and analytics; upserts keep one row per bid.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000a01',true);
do $$
declare s record;
begin
 select * into s from public.my_matching_bids_stats();
 if s.total <> 2 or s.closing_7d <> 1 then raise exception 'Matching stats wrong: % %', s.total, s.closing_7d; end if;
 insert into public.saved_bids(user_id,source_id,bid_data) values (auth.uid(),'SBA-1','{"t":1}');
 insert into public.saved_bids(user_id,source_id,bid_data) values (auth.uid(),'SBA-1','{"t":2}')
  on conflict (user_id,source_id) do update set bid_data=excluded.bid_data;
 if (select count(*) from public.saved_bids) <> 1 then raise exception 'Upsert duplicated a saved bid'; end if;
 insert into public.tender_analytics_data(user_id,source_id,selling_price) values (auth.uid(),'SBA-1',100);
 insert into public.tender_analytics_data(user_id,source_id,selling_price) values (auth.uid(),'SBA-1',120)
  on conflict (user_id,source_id) do update set selling_price=excluded.selling_price;
 if (select selling_price from public.tender_analytics_data) <> 120 then raise exception 'Analytics upsert failed'; end if;
 begin
  insert into public.saved_bids(user_id,source_id,bid_data) values ('00000000-0000-0000-0000-000000000a02','SBA-2','{}');
  raise exception 'Saved a bid for another user';
 exception when insufficient_privilege then null;
 end;
end $$;

-- The other user sees none of it.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000a02',true);
do $$begin
 if exists(select 1 from public.saved_bids) or exists(select 1 from public.tender_analytics_data)
 then raise exception 'Another user''s rows are visible'; end if;
 insert into public.saved_bids(user_id,source_id,bid_data) values (auth.uid(),'SBA-2','{}');
 insert into public.tender_analytics_data(user_id,source_id) values (auth.uid(),'SBA-2');
end $$;

-- The App Notifications switch saves without a WhatsApp number.
do $$
declare r jsonb;
begin
 r := public.set_in_app_alerts(false);
 if (r->>'in_app_enabled')::boolean then raise exception 'In-app alerts not turned off'; end if;
 r := public.set_in_app_alerts(true);
 if not (r->>'in_app_enabled')::boolean then raise exception 'In-app alerts not turned on'; end if;
end $$;

-- "Delete my data" clears both tables for the caller only.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000a01',true);
select public.delete_my_data();
reset role;
do $$begin
 if exists(select 1 from public.saved_bids where user_id='00000000-0000-0000-0000-000000000a01')
  or exists(select 1 from public.tender_analytics_data where user_id='00000000-0000-0000-0000-000000000a01')
 then raise exception 'Delete my data left saved bids or analytics'; end if;
 if (select count(*) from public.saved_bids where user_id='00000000-0000-0000-0000-000000000a02') <> 1
 then raise exception 'Delete my data touched another user'; end if;
end $$;

-- Deleting an account removes its rows.
delete from auth.users where id='00000000-0000-0000-0000-000000000a02';
do $$begin
 if exists(select 1 from public.saved_bids) or exists(select 1 from public.tender_analytics_data)
 then raise exception 'Account deletion left saved bids or analytics'; end if;
end $$;
rollback;
