\set ON_ERROR_STOP on
begin;
insert into auth.users values('10000000-0000-0000-0000-000000000001'),('20000000-0000-0000-0000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into public.profiles(id,state,research_consent) values(auth.uid(),'{}',false);
-- Every negative assertion must fail with an authorization error, not arbitrary SQL.
do $$begin
 begin
  insert into public.profiles(id) values('20000000-0000-0000-0000-000000000002');
  raise exception 'TEST FAILED: cross-user profile write allowed';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.funnel_events(id,user_id,session_id,event_name,occurred_at,rule_version) values(gen_random_uuid(),auth.uid(),gen_random_uuid(),'page_view',now(),'test');
  raise exception 'TEST FAILED: event accepted without consent';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.outcomes(user_id,stage,reference,status,verified_at) values(auth.uid(),'registration','test reference','verified',now());
  raise exception 'TEST FAILED: forged verified status accepted';
 exception when insufficient_privilege then null; end;
 begin
  perform public.review_outcome(gen_random_uuid(),'verified','fake review note');
  raise exception 'TEST FAILED: client could call review RPC';
 exception when insufficient_privilege then null; end;
end$$;
update public.profiles set research_consent=true where id=auth.uid();
insert into public.funnel_events(id,user_id,session_id,event_name,occurred_at,rule_version) values('30000000-0000-0000-0000-000000000003',auth.uid(),gen_random_uuid(),'page_view',now(),'test');
-- Retrying an event is idempotent using INSERT ON CONFLICT DO NOTHING.
insert into public.funnel_events(id,user_id,session_id,event_name,occurred_at,rule_version) values('30000000-0000-0000-0000-000000000003',auth.uid(),gen_random_uuid(),'page_view',now(),'test') on conflict(id) do nothing;
insert into public.outcomes(user_id,stage,reference) values(auth.uid(),'registration','seller-test');
insert into public.outcomes(user_id,stage,reference) values(auth.uid(),'registration','seller-test-2') on conflict(user_id,stage) do update set user_id=excluded.user_id,stage=excluded.stage,reference=excluded.reference;
insert into public.support_requests(user_id,kind,note,partner_consent) values(auth.uid(),'guidance','Please help with category',true);
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
do $$begin
 if (select count(*) from public.profiles)<>0 then raise exception 'TEST FAILED: cross-user profile read'; end if;
 if (select count(*) from public.funnel_events)<>0 then raise exception 'TEST FAILED: cross-user event read'; end if;
 if (select count(*) from public.outcomes)<>0 then raise exception 'TEST FAILED: cross-user outcome read'; end if;
 if (select count(*) from public.support_requests)<>0 then raise exception 'TEST FAILED: cross-user support read'; end if;
end$$;
reset role;
set local role service_role;
select public.review_outcome(id,'verified','Checked official seller record with participant consent') from public.outcomes;
reset role;
insert into public.benchmarks(category,city,metric,value_low,value_high,unit,source_title,source_url,as_of,sample_size,methodology,published) values
('office','Pune','active_buyers',1,2,'buyers','Test ONLY','https://example.com','2026-09-09',2,'Synthetic test fixture, not real procurement data',true),
('office','Pune','active_buyers',3,4,'buyers','Test ONLY','https://example.com','2026-09-09',2,'Synthetic unpublished fixture, not procurement data',false);
set local role anon;
do $$begin
 if (select count(*) from public.benchmarks)<>1 then raise exception 'TEST FAILED: unpublished benchmark leaked'; end if;
 begin perform * from public.research_export; raise exception 'TEST FAILED: public research export'; exception when insufficient_privilege then null; end;
end$$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
do $$begin
 if (select status from public.outcomes limit 1)<>'verified' then raise exception 'TEST FAILED: server review did not verify'; end if;
end$$;
select public.delete_my_data();
do $$begin
 if (select count(*) from public.profiles)<>0 or (select count(*) from public.outcomes)<>0 or (select count(*) from public.funnel_events)<>0 or (select count(*) from public.support_requests)<>0 then raise exception 'TEST FAILED: deletion incomplete'; end if;
end$$;
rollback;
select 'All RLS smoke checks passed' as result;
