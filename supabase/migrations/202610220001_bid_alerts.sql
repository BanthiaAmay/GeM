begin;

create table public.bid_alert_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 whatsapp_number text not null check (whatsapp_number ~ '^\+91[6-9][0-9]{9}$'),
 whatsapp_opt_in boolean not null default false,
 consented_at timestamptz,
 consent_version text,
 in_app_enabled boolean not null default true,
 keywords text[] not null default '{}',
 states text[] not null default '{}',
 updated_at timestamptz not null default now(),
 check (cardinality(keywords) <= 10 and cardinality(states) <= 10),
 check (octet_length(keywords::text) <= 1000 and octet_length(states::text) <= 1000),
 check (not whatsapp_opt_in or (consented_at is not null and consent_version is not null))
);

create table public.gem_bids (
 id uuid primary key default gen_random_uuid(),
 source_id text not null unique check (length(source_id) between 1 and 120),
 title text not null check (length(title) between 1 and 500),
 category text not null default '' check (length(category) <= 200),
 buyer text not null default '' check (length(buyer) <= 500),
 state text not null default '' check (length(state) <= 100),
 closes_at timestamptz not null,
 source_url text not null check (source_url ~ '^https://([a-z0-9-]+\.)*gem\.gov\.in/'),
 published boolean not null default false,
 fetched_at timestamptz not null default now()
);
create index gem_bids_open on public.gem_bids(closes_at) where published;

create table public.bid_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 bid_id uuid not null references public.gem_bids(id) on delete cascade,
 title text not null,
 body text not null,
 source_url text not null,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 unique(user_id,bid_id)
);
create index bid_inbox on public.bid_notifications(user_id,created_at desc);

-- Trusted workers only. The mobile app cannot insert, claim or send jobs.
create table public.bid_delivery_jobs (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 bid_id uuid not null references public.gem_bids(id) on delete cascade,
 channel text not null check (channel in ('whatsapp','push')),
 status text not null default 'pending' check (status in ('pending','processing','sent','failed','cancelled')),
 attempts integer not null default 0,
 available_at timestamptz not null default now(),
 locked_at timestamptz,
 provider_message_id text,
 last_error text,
 created_at timestamptz not null default now(),
 unique(user_id,bid_id,channel)
);
create index bid_delivery_pending on public.bid_delivery_jobs(available_at) where status='pending';

alter table public.bid_alert_preferences enable row level security;
alter table public.gem_bids enable row level security;
alter table public.bid_notifications enable row level security;
alter table public.bid_delivery_jobs enable row level security;
revoke all on public.bid_alert_preferences,public.gem_bids,public.bid_notifications,public.bid_delivery_jobs from public,anon,authenticated;
grant select on public.bid_alert_preferences,public.bid_notifications to authenticated;
grant select on public.gem_bids to anon,authenticated;
grant all on public.bid_alert_preferences,public.gem_bids,public.bid_notifications,public.bid_delivery_jobs to service_role;
create policy own_alert_preferences on public.bid_alert_preferences for select to authenticated using(user_id=(select auth.uid()));
create policy published_bids on public.gem_bids for select to anon,authenticated using(published);
create policy own_bid_notifications on public.bid_notifications for select to authenticated using(user_id=(select auth.uid()));

create function public.save_bid_alert_preferences(p_phone text, p_whatsapp boolean,
 p_in_app boolean, p_keywords text[] default '{}', p_states text[] default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid(); result public.bid_alert_preferences;
begin
 if caller is null then raise exception 'Authentication required'; end if;
 if p_phone !~ '^\+91[6-9][0-9]{9}$' then raise exception 'Invalid Indian mobile number'; end if;
 if exists(select 1 from unnest(p_keywords || p_states) v where length(trim(v))=0 or length(v)>80)
 then raise exception 'Filters must be 1 to 80 characters'; end if;
 -- Serializes preference changes with match/queue creation for this user.
 perform pg_advisory_xact_lock(hashtextextended(caller::text,0));
 insert into public.bid_alert_preferences as prefs
 (user_id,whatsapp_number,whatsapp_opt_in,consented_at,consent_version,in_app_enabled,keywords,states)
 values(caller,p_phone,p_whatsapp,case when p_whatsapp then now() end,
 case when p_whatsapp then 'bid-alerts-2026-10-22' end,p_in_app,p_keywords,p_states)
 on conflict(user_id) do update set
 whatsapp_number=excluded.whatsapp_number, whatsapp_opt_in=excluded.whatsapp_opt_in,
 consented_at=case when not p_whatsapp then null when prefs.whatsapp_opt_in and prefs.whatsapp_number=p_phone
 then prefs.consented_at else now() end,
 consent_version=excluded.consent_version, in_app_enabled=excluded.in_app_enabled,
 keywords=excluded.keywords,states=excluded.states,updated_at=now()
 returning * into result;
 update public.bid_delivery_jobs set status='cancelled'
 where user_id=caller and status='pending' and
 ((channel='whatsapp' and not p_whatsapp) or (channel='push' and not p_in_app));
 return to_jsonb(result);
end $$;
revoke all on function public.save_bid_alert_preferences(text,boolean,boolean,text[],text[]) from public,anon;
grant execute on function public.save_bid_alert_preferences(text,boolean,boolean,text[],text[]) to authenticated;

create function public.mark_bid_notification_read(p_id uuid) returns void
language sql security definer set search_path='' as $$
 update public.bid_notifications set read_at=coalesce(read_at,now())
 where id=p_id and user_id=(select auth.uid());
$$;
revoke all on function public.mark_bid_notification_read(uuid) from public,anon;
grant execute on function public.mark_bid_notification_read(uuid) to authenticated;

-- Idempotent matching. Empty keywords means all categories; empty states means all India.
-- Keyword matches are literal, case-insensitive substrings, not SQL wildcards.
create function public.queue_bid_matches(p_bid_id uuid) returns integer
language plpgsql security definer set search_path='' as $$
declare bid public.gem_bids; pref public.bid_alert_preferences; matched integer := 0;
begin
 select * into bid from public.gem_bids where id=p_bid_id and published and closes_at>now();
 if not found then return 0; end if;
 for pref in select * from public.bid_alert_preferences order by user_id loop
  perform pg_advisory_xact_lock(hashtextextended(pref.user_id::text,0));
  -- Re-read after lock so opt-out cannot race this job.
  select * into pref from public.bid_alert_preferences where user_id=pref.user_id;
  if not found then continue; end if;
  if (cardinality(pref.keywords)>0 and not exists(select 1 from unnest(pref.keywords) k
       where strpos(lower(bid.title || ' ' || bid.category),lower(k))>0))
     or (cardinality(pref.states)>0 and not exists(select 1 from unnest(pref.states) s
       where lower(s)=lower(bid.state))) then continue; end if;
  matched := matched+1;
  if pref.in_app_enabled then
   insert into public.bid_notifications(user_id,bid_id,title,body,source_url)
   values(pref.user_id,bid.id,bid.title,'Matching GeM bid · ' || bid.source_id,bid.source_url)
   on conflict(user_id,bid_id) do nothing;
  end if;
  if pref.whatsapp_opt_in then
   insert into public.bid_delivery_jobs(user_id,bid_id,channel)
   values(pref.user_id,bid.id,'whatsapp') on conflict(user_id,bid_id,channel) do nothing;
  end if;
 end loop;
 return matched;
end $$;
revoke all on function public.queue_bid_matches(uuid) from public,anon,authenticated;
grant execute on function public.queue_bid_matches(uuid) to service_role;

create or replace function public.delete_my_data() returns void language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Authentication required'; end if;
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
