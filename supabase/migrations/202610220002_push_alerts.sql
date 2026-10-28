-- App (push) notifications for matching GeM bids, the business interests that
-- drive matching, and richer collected bid records. Builds on
-- 202610220001_bid_alerts.sql.
begin;

-- A contact number is needed only for WhatsApp; app notifications work without one.
alter table public.bid_alert_preferences alter column whatsapp_number drop not null;
alter table public.bid_alert_preferences
 add constraint whatsapp_needs_number check (not whatsapp_opt_in or whatsapp_number is not null);

-- Listing and bid-document fields written by the server collector.
alter table public.gem_bids
 add column ministry text not null default '' check (length(ministry) <= 300),
 add column organisation text not null default '' check (length(organisation) <= 300),
 add column quantity integer check (quantity is null or quantity >= 0),
 add column starts_at timestamptz,
 add column details jsonb not null default '{}'::jsonb
  check (jsonb_typeof(details) = 'object' and octet_length(details::text) <= 100000);
create index gem_bids_recent on public.gem_bids(starts_at desc) where published;

alter table public.bid_delivery_jobs add column sent_at timestamptz;

-- One row per app install. A token follows whichever user last signed in on it.
create table public.push_devices (
 token text primary key check (length(token) between 20 and 4096),
 user_id uuid not null references auth.users(id) on delete cascade,
 platform text not null check (platform in ('android','ios')),
 language text not null default 'en' check (language ~ '^[a-z]{2}$'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index push_devices_user on public.push_devices(user_id);
alter table public.push_devices enable row level security;
revoke all on public.push_devices from public,anon,authenticated;
grant all on public.push_devices to service_role;

-- Every word of a keyword must begin a word of the text: case-insensitive,
-- literal (no wildcards) and ignoring a trailing plural "s". "LED lights"
-- matches "LED Luminaire For Street Lights"; "pen" does not match "open".
create function public.keyword_matches(p_text text, p_keyword text) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(bool_and(lower(p_text) ~ ('\m' || regexp_replace(
  regexp_replace(w, '^(\w{3,})s$', '\1'), '([!$()*+.:<=>?[\\\]^{|}-])', '\\\1', 'g'))), false)
 from regexp_split_to_table(lower(trim(p_keyword)), '\s+') as w where w <> '';
$$;

-- At least one keyword is required: "all bids" would mean thousands of alerts a day.
-- Empty states still means all India.
create function public.bid_matches(p_text text, p_state text, p_keywords text[], p_states text[])
returns boolean language sql immutable set search_path='' as $$
 select exists(select 1 from unnest(p_keywords) k where public.keyword_matches(p_text, k))
  and (cardinality(p_states) = 0 or exists(select 1 from unnest(p_states) s
   where lower(trim(s)) = lower(p_state)));
$$;

-- Saves the "what do you sell" answers from onboarding. Leaves contact and
-- channel choices untouched; a new row gets app alerts on by default.
create function public.save_bid_interests(p_keywords text[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid(); result public.bid_alert_preferences;
begin
 if caller is null then raise exception 'Authentication required'; end if;
 p_keywords := coalesce(p_keywords, '{}');
 if cardinality(p_keywords) > 10 or exists(select 1 from unnest(p_keywords) v
  where length(trim(v)) = 0 or length(v) > 80)
 then raise exception 'Use up to 10 keywords of 1 to 80 characters'; end if;
 perform pg_advisory_xact_lock(hashtextextended(caller::text,0));
 insert into public.bid_alert_preferences as prefs(user_id,keywords) values(caller,p_keywords)
 on conflict(user_id) do update set keywords=excluded.keywords, updated_at=now()
 returning * into result;
 return to_jsonb(result);
end $$;
revoke all on function public.save_bid_interests(text[]) from public,anon;
grant execute on function public.save_bid_interests(text[]) to authenticated;

create function public.register_push_device(p_token text, p_platform text, p_language text default 'en')
returns void language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Authentication required'; end if;
 insert into public.push_devices(token,user_id,platform,language)
 values(p_token,caller,p_platform,coalesce(nullif(p_language,''),'en'))
 on conflict(token) do update set user_id=caller, platform=excluded.platform,
  language=excluded.language, updated_at=now();
 -- Keep the ten most recently used installs per account.
 delete from public.push_devices d where d.user_id=caller and d.token not in
  (select token from public.push_devices where user_id=caller order by updated_at desc limit 10);
end $$;
revoke all on function public.register_push_device(text,text,text) from public,anon;
grant execute on function public.register_push_device(text,text,text) to authenticated;

create function public.unregister_push_device(p_token text) returns void
language sql security definer set search_path='' as $$
 delete from public.push_devices where token=p_token and user_id=(select auth.uid());
$$;
revoke all on function public.unregister_push_device(text) from public,anon;
grant execute on function public.unregister_push_device(text) to authenticated;

-- Open bids matching the caller's saved interests, newest first. Runs with the
-- caller's own privileges, so row-level security still applies.
create function public.my_matching_bids(p_limit integer default 50)
returns setof public.gem_bids language sql stable set search_path='' as $$
 select b.* from public.gem_bids b
 join public.bid_alert_preferences p on p.user_id=(select auth.uid())
 where b.published and b.closes_at>now()
  and public.bid_matches(b.title || ' ' || b.category, b.state, p.keywords, p.states)
 order by coalesce(b.starts_at,b.fetched_at) desc
 limit least(greatest(coalesce(p_limit,50),1),100);
$$;
revoke all on function public.my_matching_bids(integer) from public,anon;
grant execute on function public.my_matching_bids(integer) to authenticated;

-- Idempotent matching, now with word matching, a richer inbox line and push
-- jobs for users with a registered device.
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
  if pref.whatsapp_opt_in then
   insert into public.bid_delivery_jobs(user_id,bid_id,channel)
   values(pref.user_id,bid.id,'whatsapp') on conflict(user_id,bid_id,channel) do nothing;
  end if;
 end loop;
 return matched;
end $$;

-- Server-only. Cancels push jobs for closed bids or users who turned app alerts
-- off, then claims due jobs. A user who received a push within p_min_gap waits,
-- so the next run groups their new bids into one message.
create function public.claim_push_jobs(p_limit integer default 500, p_min_gap interval default '1 hour')
returns table(job_id uuid, user_id uuid, attempts integer, source_id text, title text,
 buyer text, state text, closes_at timestamptz)
language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
begin
 update public.bid_delivery_jobs j set status='cancelled', last_error='Bid closed or app alerts off'
 where j.channel='push' and j.status='pending'
  and (not exists(select 1 from public.gem_bids b where b.id=j.bid_id and b.published and b.closes_at>now())
   or not exists(select 1 from public.bid_alert_preferences p where p.user_id=j.user_id and p.in_app_enabled));
 update public.bid_delivery_jobs j set status='failed', last_error=coalesce(j.last_error,'Worker lease expired')
 where j.channel='push' and j.status='processing' and j.locked_at<now()-interval '15 minutes'
  and j.attempts>=5;
 return query
 with due as (
  select j.id from public.bid_delivery_jobs j
  where j.channel='push' and j.available_at<=now() and j.attempts<5
   and (j.status='pending' or (j.status='processing' and j.locked_at<now()-interval '15 minutes'))
   and not exists(select 1 from public.bid_delivery_jobs s where s.user_id=j.user_id
    and s.channel='push' and s.status='sent' and s.sent_at>now()-p_min_gap)
  order by j.created_at limit greatest(coalesce(p_limit,500),1)
  for update skip locked
 ), claimed as (
  update public.bid_delivery_jobs j set status='processing', locked_at=now(), attempts=j.attempts+1
  from due where j.id=due.id returning j.id, j.user_id, j.attempts, j.bid_id
 )
 select c.id, c.user_id, c.attempts, b.source_id, b.title, b.buyer, b.state, b.closes_at
 from claimed c join public.gem_bids b on b.id=c.bid_id;
end $$;
revoke all on function public.claim_push_jobs(integer,interval) from public,anon,authenticated;
grant execute on function public.claim_push_jobs(integer,interval) to service_role;

create or replace function public.delete_my_data() returns void language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Authentication required'; end if;
 delete from public.push_devices where user_id=caller;
 delete from public.bid_delivery_jobs where user_id=caller;
 delete from public.bid_notifications where user_id=caller;
 delete from public.bid_alert_preferences where user_id=caller;
 delete from public.funnel_events where user_id=caller;
 delete from public.support_requests where user_id=caller;
 delete from public.outcomes where user_id=caller;
 delete from public.research_assignments where user_id=caller;
 delete from public.profiles where id=caller;
end $$;
commit;
