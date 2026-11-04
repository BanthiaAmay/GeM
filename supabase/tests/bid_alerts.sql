-- Run after all migrations in an isolated test database. Never sends messages.
begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000101'),
 ('00000000-0000-0000-0000-000000000102'),
 ('00000000-0000-0000-0000-000000000103'),
 ('00000000-0000-0000-0000-000000000104');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
select public.save_bid_alert_preferences('+919876543210',true,true,array['stationery'],array['Maharashtra']);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000102',true);
select public.save_bid_alert_preferences('+919876543211',true,false,array['laptop'],array['Gujarat']);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000103',true);
select public.save_bid_alert_preferences('+919876543212',false,true,array['stationery'],array[]::text[]);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000104',true);
select public.save_bid_alert_preferences('+919876543213',true,true,array['%'],array[]::text[]);
do $$begin
 if (select count(*) from public.bid_alert_preferences)<>1 then raise exception 'Preference isolation failed'; end if;
 if has_table_privilege('authenticated','public.bid_delivery_jobs','SELECT') then raise exception 'Job privacy failed'; end if;
 if has_table_privilege('authenticated','public.gem_bids','INSERT') then raise exception 'Bid write permission failed'; end if;
 if has_table_privilege('authenticated','public.bid_notifications','UPDATE') then raise exception 'Inbox update permission failed'; end if;
 if has_function_privilege('authenticated','public.queue_bid_matches(uuid)','EXECUTE') then raise exception 'Matcher must be server-only'; end if;
 begin
  perform public.save_bid_alert_preferences('+911234567890',true,true);
  raise exception 'Invalid phone accepted';
 exception when check_violation then null; when raise_exception then
  if SQLERRM <> 'Invalid Indian mobile number' then raise; end if;
 end;
end $$;
reset role;

insert into public.gem_bids(id,source_id,title,state,closes_at,source_url,published) values
 ('00000000-0000-0000-0000-000000000201','TEST-OPEN','Office STATIONERY','Maharashtra',now()+interval '1 day','https://bidplus.gem.gov.in/test',true),
 ('00000000-0000-0000-0000-000000000202','TEST-CLOSED','Office stationery','Maharashtra',now()-interval '1 day','https://bidplus.gem.gov.in/test',true),
 ('00000000-0000-0000-0000-000000000203','TEST-DRAFT','Office stationery','Maharashtra',now()+interval '1 day','https://bidplus.gem.gov.in/test',false);
set local role service_role;
select public.queue_bid_matches('00000000-0000-0000-0000-000000000201');
select public.queue_bid_matches('00000000-0000-0000-0000-000000000201');
select public.queue_bid_matches('00000000-0000-0000-0000-000000000202');
select public.queue_bid_matches('00000000-0000-0000-0000-000000000203');
do $$begin
 if (select count(*) from public.bid_notifications)<>2 then raise exception 'Matching or inbox dedupe failed'; end if;
 if (select count(*) from public.bid_delivery_jobs where channel='whatsapp')<>1 then raise exception 'Opt-in or delivery dedupe failed'; end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
do $$begin
 if (select count(*) from public.bid_notifications)<>1 then raise exception 'Inbox isolation failed'; end if;
end $$;
select public.mark_bid_notification_read(id) from public.bid_notifications;
select public.save_bid_alert_preferences('+919876543210',false,true,array['stationery'],array['Maharashtra']);
reset role;
do $$begin
 if (select count(*) from public.bid_notifications where read_at is not null)<>1 then raise exception 'Read status ownership failed'; end if;
 if (select count(*) from public.bid_delivery_jobs where status='cancelled')<>1 then raise exception 'Opt-out cancellation failed'; end if;
end $$;

set local role anon;
do $$begin
 if (select count(*) from public.gem_bids)<>2 then raise exception 'Draft bid exposed'; end if;
 if has_table_privilege('anon','public.bid_alert_preferences','SELECT') then raise exception 'Anonymous contact access'; end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
select public.delete_my_data();
reset role;
do $$begin
 if exists(select 1 from public.bid_alert_preferences where user_id='00000000-0000-0000-0000-000000000101')
 or exists(select 1 from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000101')
 or exists(select 1 from public.bid_delivery_jobs where user_id='00000000-0000-0000-0000-000000000101')
 then raise exception 'Data deletion failed'; end if;
 if (select count(*) from public.bid_alert_preferences)<>3 then raise exception 'Other-user data deleted'; end if;
end $$;
rollback;
