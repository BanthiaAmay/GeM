-- WhatsApp digests of matching GeM bids (Meta WhatsApp Cloud API, approved
-- template). Jobs are already queued by queue_bid_matches for opted-in users.
begin;

-- Server-only. Cancels jobs for closed bids or withdrawn consent, then claims
-- due jobs for users not messaged within p_min_gap, so each message is a
-- digest. Consent and number are re-read here, immediately before sending.
create function public.claim_whatsapp_jobs(p_limit integer default 1000, p_min_gap interval default '24 hours')
returns table(job_id uuid, user_id uuid, attempts integer, phone text, language text,
 source_id text, title text, buyer text, state text, closes_at timestamptz)
language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
begin
 update public.bid_delivery_jobs j set status='cancelled', last_error='Bid closed or WhatsApp consent withdrawn'
 where j.channel='whatsapp' and j.status='pending'
  and (not exists(select 1 from public.gem_bids b where b.id=j.bid_id and b.published and b.closes_at>now())
   or not exists(select 1 from public.bid_alert_preferences p where p.user_id=j.user_id
    and p.whatsapp_opt_in and p.whatsapp_number is not null and p.consented_at is not null));
 update public.bid_delivery_jobs j set status='failed', last_error=coalesce(j.last_error,'Worker lease expired')
 where j.channel='whatsapp' and j.status='processing' and j.locked_at<now()-interval '15 minutes'
  and j.attempts>=5;
 return query
 with due as (
  select j.id from public.bid_delivery_jobs j
  where j.channel='whatsapp' and j.available_at<=now() and j.attempts<5
   and (j.status='pending' or (j.status='processing' and j.locked_at<now()-interval '15 minutes'))
   and not exists(select 1 from public.bid_delivery_jobs s where s.user_id=j.user_id
    and s.channel='whatsapp' and s.status='sent' and s.sent_at>now()-p_min_gap)
  order by j.created_at limit greatest(coalesce(p_limit,1000),1)
  for update skip locked
 ), claimed as (
  update public.bid_delivery_jobs j set status='processing', locked_at=now(), attempts=j.attempts+1
  from due where j.id=due.id returning j.id, j.user_id, j.attempts, j.bid_id
 )
 select c.id, c.user_id, c.attempts, p.whatsapp_number,
  coalesce(nullif(pr.state->>'language',''),'en'),
  b.source_id, b.title, b.buyer, b.state, b.closes_at
 from claimed c
 join public.gem_bids b on b.id=c.bid_id
 join public.bid_alert_preferences p on p.user_id=c.user_id
 left join public.profiles pr on pr.id=c.user_id;
end $$;
revoke all on function public.claim_whatsapp_jobs(integer,interval) from public,anon,authenticated;
grant execute on function public.claim_whatsapp_jobs(integer,interval) to service_role;

-- Server-only: a STOP reply (from the provider webhook) turns WhatsApp off
-- for every account using that number and cancels what is still queued.
create function public.whatsapp_opt_out(p_phone text) returns integer
language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
 update public.bid_alert_preferences set whatsapp_opt_in=false, consented_at=null,
  consent_version=null, updated_at=now()
 where whatsapp_number=p_phone and whatsapp_opt_in;
 get diagnostics affected = row_count;
 update public.bid_delivery_jobs j set status='cancelled', last_error='Opted out on WhatsApp'
 where j.channel='whatsapp' and j.status='pending' and j.user_id in
  (select user_id from public.bid_alert_preferences where whatsapp_number=p_phone);
 return affected;
end $$;
revoke all on function public.whatsapp_opt_out(text) from public,anon,authenticated;
grant execute on function public.whatsapp_opt_out(text) to service_role;
commit;
