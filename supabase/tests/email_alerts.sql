-- Run after all migrations in an isolated test database. Never sends email.
begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-0000-0000-000000000501','a@example.com',now()),
 ('00000000-0000-0000-0000-000000000502','b@example.com',now()),
 ('00000000-0000-0000-0000-000000000503','c@example.com',null);
insert into public.profiles(id,state) values ('00000000-0000-0000-0000-000000000501','{"language":"ta"}');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000501',true);
select public.save_bid_interests(array['furniture']);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000502',true);
select public.save_bid_interests(array['furniture']);
select public.set_email_alerts(false);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000503',true);
select public.save_bid_interests(array['furniture']);
do $$begin
 if has_function_privilege('authenticated','public.claim_email_jobs(integer,interval)','EXECUTE') then raise exception 'Email claim must be server-only'; end if;
end $$;
reset role;

insert into public.gem_bids(id,source_id,title,closes_at,source_url,published) values
 ('00000000-0000-0000-0000-000000000601','GEM/2026/B/601','Office Furniture',now()+interval '5 days','https://bidplus.gem.gov.in/showbidDocument/601',true),
 ('00000000-0000-0000-0000-000000000602','GEM/2026/B/602','Steel Furniture',now()+interval '5 days','https://bidplus.gem.gov.in/showbidDocument/602',true);
set local role service_role;
select public.queue_bid_matches('00000000-0000-0000-0000-000000000601');
select public.queue_bid_matches('00000000-0000-0000-0000-000000000602');
do $$
declare n integer; lang text; addr text;
begin
 if (select count(*) from public.bid_delivery_jobs where channel='email')<>4 then raise exception 'Email jobs: only users with email on'; end if;
 select count(*), min(language), min(email) into n, lang, addr from public.claim_email_jobs();
 if n<>2 or lang<>'ta' or addr<>'a@example.com' then raise exception 'Claim wrong: % % %', n, lang, addr; end if;
 if (select count(*) from public.bid_delivery_jobs where channel='email' and status='cancelled')<>2 then raise exception 'Unconfirmed address not cancelled'; end if;
 update public.bid_delivery_jobs set status='sent', sent_at=now() where channel='email' and status='processing';
end $$;
reset role;
rollback;
