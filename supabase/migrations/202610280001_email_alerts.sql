-- Email digests of matching GeM bids, sent by the server worker to the
-- account's verified sign-in address. Builds on 202610220002_push_alerts.sql.
begin;

alter table public.bid_alert_preferences
 add column email_enabled boolean not null default true;

alter table public.bid_delivery_jobs drop constraint bid_delivery_jobs_channel_check;
alter table public.bid_delivery_jobs
 add constraint bid_delivery_jobs_channel_check check (channel in ('whatsapp','push','email'));

create function public.set_email_alerts(p_enabled boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid(); result public.bid_alert_preferences;
begin
 if caller is null then raise exception 'Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(caller::text,0));
 insert into public.bid_alert_preferences as prefs(user_id,email_enabled) values(caller,p_enabled)
 on conflict(user_id) do update set email_enabled=excluded.email_enabled, updated_at=now()
 returning * into result;
 if not p_enabled then
  update public.bid_delivery_jobs set status='cancelled'
  where user_id=caller and channel='email' and status='pending';
 end if;
 return to_jsonb(result);
end $$;
revoke all on function public.set_email_alerts(boolean) from public,anon;
grant execute on function public.set_email_alerts(boolean) to authenticated;

-- Same matching as before, plus an email job for users who keep email on.
create or replace function public.queue_bid_matches(p_bid_id uuid) returns integer
language plpgsql security definer set search_path='' as $$
declare bid public.gem_bids; pref public.bid_alert_preferences; matched integer := 0; haystack text;
begin
 select * into bid from public.gem_bids where id=p_bid_id and published and closes_at>now();
 if not found then return 0; end if;
 haystack := bid.title || ' ' || bid.category;
 for pref in select p.* from public.bid_alert_preferences p
  where public.bid_matches(haystack, bid.state, p.keywords, p.states) order by p.user_id loop
  perform pg_advisory_xact_lock(hashtextextended(pref.user_id::text,0));
  -- Re-read after lock so opt-out cannot race this job.
  select * into pref from public.bid_alert_preferences where user_id=pref.user_id;
  if not found or not public.bid_matches(haystack, bid.state, pref.keywords, pref.states) then
   continue;
  end if;
  matched := matched+1;
  if pref.in_app_enabled then
   insert into public.bid_notifications(user_id,bid_id,title,body,source_url)
   values(pref.user_id,bid.id,bid.title,
    concat_ws(' · ', nullif(bid.buyer,''), nullif(bid.state,''), bid.source_id),bid.source_url)
   on conflict(user_id,bid_id) do nothing;
   if exists(select 1 from public.push_devices d where d.user_id=pref.user_id) then
    insert into public.bid_delivery_jobs(user_id,bid_id,channel)
    values(pref.user_id,bid.id,'push') on conflict(user_id,bid_id,channel) do nothing;
   end if;
  end if;
  if pref.email_enabled then
   insert into public.bid_delivery_jobs(user_id,bid_id,channel)
   values(pref.user_id,bid.id,'email') on conflict(user_id,bid_id,channel) do nothing;
  end if;
  if pref.whatsapp_opt_in then
   insert into public.bid_delivery_jobs(user_id,bid_id,channel)
   values(pref.user_id,bid.id,'whatsapp') on conflict(user_id,bid_id,channel) do nothing;
  end if;
 end loop;
 return matched;
end $$;

-- Server-only. Like claim_push_jobs, for email: cancels jobs for closed bids,
-- turned-off email or accounts without a confirmed address, then claims due
-- jobs for users not emailed within p_min_gap, so each email is a digest.
create function public.claim_email_jobs(p_limit integer default 1000, p_min_gap interval default '12 hours')
returns table(job_id uuid, user_id uuid, attempts integer, email text, language text,
 source_id text, title text, buyer text, state text, closes_at timestamptz, source_url text,
 details jsonb)
language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
begin
 update public.bid_delivery_jobs j set status='cancelled', last_error='Bid closed, email off or no confirmed email'
 where j.channel='email' and j.status='pending'
  and (not exists(select 1 from public.gem_bids b where b.id=j.bid_id and b.published and b.closes_at>now())
   or not exists(select 1 from public.bid_alert_preferences p where p.user_id=j.user_id and p.email_enabled)
   or not exists(select 1 from auth.users u where u.id=j.user_id and u.email is not null
    and u.email_confirmed_at is not null));
 update public.bid_delivery_jobs j set status='failed', last_error=coalesce(j.last_error,'Worker lease expired')
 where j.channel='email' and j.status='processing' and j.locked_at<now()-interval '15 minutes'
  and j.attempts>=5;
 return query
 with due as (
  select j.id from public.bid_delivery_jobs j
  where j.channel='email' and j.available_at<=now() and j.attempts<5
   and (j.status='pending' or (j.status='processing' and j.locked_at<now()-interval '15 minutes'))
   and not exists(select 1 from public.bid_delivery_jobs s where s.user_id=j.user_id
    and s.channel='email' and s.status='sent' and s.sent_at>now()-p_min_gap)
  order by j.created_at limit greatest(coalesce(p_limit,1000),1)
  for update skip locked
 ), claimed as (
  update public.bid_delivery_jobs j set status='processing', locked_at=now(), attempts=j.attempts+1
  from due where j.id=due.id returning j.id, j.user_id, j.attempts, j.bid_id
 )
 select c.id, c.user_id, c.attempts, u.email::text,
  coalesce(nullif(pr.state->>'language',''),'en'),
  b.source_id, b.title, b.buyer, b.state, b.closes_at, b.source_url, b.details
 from claimed c
 join public.gem_bids b on b.id=c.bid_id
 join auth.users u on u.id=c.user_id
 left join public.profiles pr on pr.id=c.user_id;
end $$;
revoke all on function public.claim_email_jobs(integer,interval) from public,anon,authenticated;
grant execute on function public.claim_email_jobs(integer,interval) to service_role;
commit;
