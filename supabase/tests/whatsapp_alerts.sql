-- Run after all migrations in an isolated test database. Never sends messages.
begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000701'),('00000000-0000-0000-0000-000000000702');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000701',true);
select public.save_bid_alert_preferences('+919876500001',true,true,array['tent'],array[]::text[]);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000702',true);
select public.save_bid_alert_preferences('+919876500002',false,true,array['tent'],array[]::text[]);
do $$begin
 if has_function_privilege('authenticated','public.claim_whatsapp_jobs(integer,interval)','EXECUTE')
  or has_function_privilege('authenticated','public.whatsapp_opt_out(text)','EXECUTE')
 then raise exception 'WhatsApp functions must be server-only'; end if;
end $$;
reset role;
insert into public.gem_bids(id,source_id,title,closes_at,source_url,published) values
 ('00000000-0000-0000-0000-000000000801','GEM/2026/B/801','Tent for event',now()+interval '5 days','https://bidplus.gem.gov.in/showbidDocument/801',true),
 ('00000000-0000-0000-0000-000000000802','GEM/2026/B/802','Tent and furniture',now()+interval '6 days','https://bidplus.gem.gov.in/showbidDocument/802',true);
set local role service_role;
select public.queue_bid_matches('00000000-0000-0000-0000-000000000801');
do $$
declare n integer; who text;
begin
 select count(*), min(phone) into n, who from public.claim_whatsapp_jobs();
 if n<>1 or who<>'+919876500001' then raise exception 'Only the opted-in user: % %', n, who; end if;
 update public.bid_delivery_jobs set status='sent', sent_at=now() where channel='whatsapp' and status='processing';
end $$;
select public.queue_bid_matches('00000000-0000-0000-0000-000000000802');
do $$begin
 if exists(select 1 from public.claim_whatsapp_jobs()) then raise exception '24-hour gap ignored'; end if;
 if public.whatsapp_opt_out('+919876500001')<>1 then raise exception 'Opt-out did not apply'; end if;
 if exists(select 1 from public.claim_whatsapp_jobs(1000, interval '0 seconds')) then raise exception 'Opted-out number claimed'; end if;
 if (select whatsapp_opt_in from public.bid_alert_preferences where user_id='00000000-0000-0000-0000-000000000701') then raise exception 'Consent not withdrawn'; end if;
end $$;
reset role;
rollback;
