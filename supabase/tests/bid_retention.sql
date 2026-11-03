-- Run after all migrations in an isolated test database.
begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000a01');
insert into public.gem_bids(id,source_id,title,closes_at,source_url,published,fetched_at,details) values
 ('00000000-0000-0000-0000-000000000b01','R-CLOSED','Old chairs',now()-interval '3 days','https://bidplus.gem.gov.in/1',true,now()-interval '20 days','{"atc":"x"}'),
 ('00000000-0000-0000-0000-000000000b02','R-JUST-CLOSED','Recent chairs',now()-interval '1 day','https://bidplus.gem.gov.in/2',true,now()-interval '10 days','{}'),
 ('00000000-0000-0000-0000-000000000b03','R-UNMATCHED','Open tables',now()+interval '9 days','https://bidplus.gem.gov.in/3',true,now()-interval '2 days','{"atc":"long","specifications":"s","links":[],"documents_required":["OEM"]}'),
 ('00000000-0000-0000-0000-000000000b04','R-MATCHED','Open sofas',now()+interval '9 days','https://bidplus.gem.gov.in/4',true,now()-interval '2 days','{"atc":"keep"}'),
 ('00000000-0000-0000-0000-000000000b05','R-NEW','New desks',now()+interval '9 days','https://bidplus.gem.gov.in/5',true,now(),'{"atc":"fresh"}');
insert into public.bid_notifications(user_id,bid_id,title,body,source_url) values
 ('00000000-0000-0000-0000-000000000a01','00000000-0000-0000-0000-000000000b01','t','b','https://bidplus.gem.gov.in/1'),
 ('00000000-0000-0000-0000-000000000a01','00000000-0000-0000-0000-000000000b04','t','b','https://bidplus.gem.gov.in/4');
insert into public.bid_delivery_jobs(user_id,bid_id,channel,status,created_at) values
 ('00000000-0000-0000-0000-000000000a01','00000000-0000-0000-0000-000000000b04','email','sent',now()-interval '5 days'),
 ('00000000-0000-0000-0000-000000000a01','00000000-0000-0000-0000-000000000b04','push','sent',now()-interval '1 day');
set local role service_role;
do $$
declare r jsonb := public.cleanup_bids();
begin
 if (r->>'closed_bids_deleted')::int<>1 then raise exception 'closed: %', r; end if;
 if (r->>'bids_slimmed')::int<>1 then raise exception 'slimmed: %', r; end if;
 if (r->>'old_jobs_deleted')::int<>1 then raise exception 'jobs: %', r; end if;
 if exists(select 1 from public.gem_bids where source_id='R-CLOSED') then raise exception 'Closed bid kept'; end if;
 if not exists(select 1 from public.gem_bids where source_id='R-JUST-CLOSED') then raise exception 'Grace period ignored'; end if;
 if (select details from public.gem_bids where source_id='R-UNMATCHED')<>'{"documents_required":["OEM"]}'::jsonb then raise exception 'Slimming wrong'; end if;
 if not ((select details from public.gem_bids where source_id='R-MATCHED') ? 'atc') then raise exception 'Matched bid slimmed'; end if;
 if not ((select details from public.gem_bids where source_id='R-NEW') ? 'atc') then raise exception 'New bid slimmed'; end if;
 if exists(select 1 from public.bid_notifications where bid_id='00000000-0000-0000-0000-000000000b01') then raise exception 'Inbox for closed bid kept'; end if;
 if (select count(*) from public.bid_delivery_jobs)<>1 then raise exception 'Recent sent job removed'; end if;
end $$;
do $$begin
 if has_function_privilege('authenticated','public.cleanup_bids(interval,interval,interval)','EXECUTE') then raise exception 'Cleanup must be server-only'; end if;
end $$;
reset role;
rollback;
