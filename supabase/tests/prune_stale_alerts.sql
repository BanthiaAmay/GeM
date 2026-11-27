-- Run after all migrations in an isolated test database.
begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000b01'),
 ('00000000-0000-0000-0000-000000000b02');
insert into public.gem_bids(id,source_id,title,category,state,closes_at,source_url,published) values
 ('00000000-0000-0000-0000-00000000b0b1','PSA-1','Office furniture','Furniture','Delhi',now()+interval '9 days','https://bidplus.gem.gov.in/p1',true),
 ('00000000-0000-0000-0000-00000000b0b2','PSA-2','Grain storage bin 50 MT','Storage','Delhi',now()+interval '9 days','https://bidplus.gem.gov.in/p2',true);
insert into public.bid_alert_preferences(user_id,keywords) values
 ('00000000-0000-0000-0000-000000000b01',array['furniture','grain storage bin']),
 ('00000000-0000-0000-0000-000000000b02',array['furniture']);
insert into public.bid_notifications(user_id,bid_id,title,body,source_url)
 select u, b, 'alert', '', 'https://bidplus.gem.gov.in/p'
 from unnest(array['00000000-0000-0000-0000-000000000b01','00000000-0000-0000-0000-000000000b02']::uuid[]) u,
      unnest(array['00000000-0000-0000-0000-00000000b0b1','00000000-0000-0000-0000-00000000b0b2']::uuid[]) b
 on conflict (user_id,bid_id) do nothing;
insert into public.bid_delivery_jobs(user_id,bid_id,channel) values
 ('00000000-0000-0000-0000-000000000b01','00000000-0000-0000-0000-00000000b0b1','push'),
 ('00000000-0000-0000-0000-000000000b01','00000000-0000-0000-0000-00000000b0b2','push');

-- The seller now supplies only grain storage bins.
update public.bid_alert_preferences set keywords=array['grain storage bin']
 where user_id='00000000-0000-0000-0000-000000000b01';
do $$begin
 if exists(select 1 from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000b01'
           and bid_id='00000000-0000-0000-0000-00000000b0b1')
 then raise exception 'Furniture alert kept after the business changed'; end if;
 if not exists(select 1 from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000b01'
               and bid_id='00000000-0000-0000-0000-00000000b0b2')
 then raise exception 'Matching grain storage alert was removed'; end if;
 if (select status from public.bid_delivery_jobs where user_id='00000000-0000-0000-0000-000000000b01'
     and bid_id='00000000-0000-0000-0000-00000000b0b1') <> 'cancelled'
 then raise exception 'Stale push was not cancelled'; end if;
 if (select status from public.bid_delivery_jobs where user_id='00000000-0000-0000-0000-000000000b01'
     and bid_id='00000000-0000-0000-0000-00000000b0b2') <> 'pending'
 then raise exception 'Matching push was cancelled'; end if;
 -- The other seller keeps their stored alerts (the trigger is per account).
 if (select count(*) from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000b02') <> 2
 then raise exception 'Another seller''s alerts changed'; end if;
end $$;

-- An update that leaves keywords and states alone removes nothing.
update public.bid_alert_preferences set email_enabled=false where user_id='00000000-0000-0000-0000-000000000b02';
do $$begin
 if (select count(*) from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000b02') <> 2
 then raise exception 'Unrelated preference change removed alerts'; end if;
end $$;
rollback;
