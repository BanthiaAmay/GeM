-- Run after all migrations in an isolated test database.
begin;
do $$
declare cases text[][] := array[
 array['Vinegar (सिरका)', 'Supply of Vinegar 5 L bottles', 'true'],
 array['Vinegar (सिरका)', 'Supply of rice', 'false'],
 array['Desktop Computers (V2)', 'Desktop Computers (V2)', 'true'],
 array['Plants (Flowering, Foliage, Ornamental & Medicinal)', 'Repair of Plant/ Systems', 'false'],
 array['C++', 'C++ compiler licence', 'true'],
 array['सिरका', 'Supply of Vinegar', 'false']
];
 c text[];
begin
 foreach c slice 1 in array cases loop
  if public.keyword_matches(c[2], c[1]) <> c[3]::boolean then
   raise exception 'keyword % vs "%": expected %', c[1], c[2], c[3];
  end if;
 end loop;
 if public.keyword_pattern('Vinegar (सिरका)') <> '^(?=.*\mvinegar(s|es|ing)?\M)' then
  raise exception 'Hindi fragments in pattern: %', public.keyword_pattern('Vinegar (सिरका)');
 end if;
end $$;

-- Right after the migration: nobody is opted in to WhatsApp, nothing waits.
do $$begin
 if exists(select 1 from public.bid_alert_preferences where whatsapp_opt_in)
 then raise exception 'WhatsApp still opted in'; end if;
 if exists(select 1 from public.bid_delivery_jobs where channel='whatsapp' and status='pending')
 then raise exception 'WhatsApp job still pending'; end if;
end $$;

-- A Hindi-named category fills the inbox from English bids.
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000e01');
insert into public.gem_bids(id,source_id,title,closes_at,source_url,published) values
 ('00000000-0000-0000-0000-00000000e0b1','AF-1','Supply of Vinegar 5 L',now()+interval '5 days','https://bidplus.gem.gov.in/v',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000e01',true);
select public.save_bid_interests(array['Vinegar (सिरका)']);
reset role;
do $$begin
 if not exists(select 1 from public.bid_notifications where user_id='00000000-0000-0000-0000-000000000e01')
 then raise exception 'Vinegar inbox not filled'; end if;
end $$;
rollback;
