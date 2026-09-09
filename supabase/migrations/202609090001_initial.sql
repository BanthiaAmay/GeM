-- GeM Saathi. Apply through Supabase migrations or the SQL editor.
begin;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 state jsonb not null default '{}'::jsonb check (jsonb_typeof(state) = 'object' and octet_length(state::text) <= 65536),
 research_consent boolean not null default false,
 updated_at timestamptz not null default now()
);
create table public.funnel_events (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid not null,
 event_name text not null check (event_name in ('page_view','tool_started','tool_completed','cta_clicked','engagement','external_link_clicked','tracker_updated','module_completed','registration_intent','registration_self_reported','first_order_self_reported','support_requested','report_copied','report_exported','disqualified_by_choice','consent_granted')),
 page text check (length(page)<=80),
 referral_code text check (referral_code ~ '^[a-zA-Z0-9_-]{1,64}$'),
 occurred_at timestamptz not null,
 received_at timestamptz not null default now(),
 properties jsonb not null default '{}' check (jsonb_typeof(properties)='object' and octet_length(properties::text)<=2048),
 rule_version text not null check (length(rule_version)<=64)
);
create index funnel_user_time on public.funnel_events(user_id,occurred_at);
create index funnel_referral on public.funnel_events(referral_code,event_name);
create table public.support_requests (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('workshop','ca_referral','guidance')),
 note text not null check(length(note) between 1 and 1000),
 partner_consent boolean not null check(partner_consent),
 status text not null default 'pending' check(status in ('pending','contacted','closed')),
 created_at timestamptz not null default now()
);
create table public.outcomes (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 stage text not null check(stage in ('registration','first_order')),
 reference text not null check(length(reference) between 1 and 120),
 status text not null default 'self_reported' check(status in ('self_reported','verified','rejected')),
 claimed_at timestamptz not null default now(),
 verified_at timestamptz,
 verification_note text,
 unique(user_id,stage),
 check ((status='verified' and verified_at is not null) or (status<>'verified' and verified_at is null))
);
create table public.benchmarks (
 id uuid primary key default gen_random_uuid(),
 category text not null check(category in ('office','furniture','it','cleaning','other')),
 city text not null,
 metric text not null check(metric in ('order_value','active_buyers','procurements_per_month')),
 value_low numeric not null check(value_low>=0),
 value_high numeric not null check(value_high>=value_low),
 unit text not null,
 source_title text not null,
 source_url text not null check(source_url ~ '^https://'),
 as_of date not null,
 sample_size integer not null check(sample_size>0),
 methodology text not null check(length(methodology)>20),
 published boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.research_assignments (
 user_id uuid primary key references auth.users(id) on delete cascade,
 cohort text not null check(cohort in ('tool_assisted','comparison')),
 enrolled_at timestamptz not null,
 followup_due_at timestamptz not null,
 assignment_method text not null,
 check(followup_due_at>enrolled_at)
);
create table public.verification_audit (
 id bigint generated always as identity primary key,
 outcome_id uuid references public.outcomes(id) on delete cascade,
 old_status text, new_status text not null,
 note text not null, reviewed_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.funnel_events enable row level security;
alter table public.support_requests enable row level security;
alter table public.outcomes enable row level security;
alter table public.benchmarks enable row level security;
alter table public.research_assignments enable row level security;
alter table public.verification_audit enable row level security;

revoke all on public.profiles,public.funnel_events,public.support_requests,public.outcomes,public.benchmarks,public.research_assignments,public.verification_audit from anon,authenticated;
grant select,insert,update on public.profiles to authenticated;
grant select,insert on public.funnel_events to authenticated;
grant select on public.support_requests,public.outcomes to authenticated;
grant insert(user_id,kind,note,partner_consent) on public.support_requests to authenticated;
grant insert(user_id,stage,reference),update(user_id,stage,reference) on public.outcomes to authenticated;
grant select on public.benchmarks to anon,authenticated;
grant all on public.profiles,public.funnel_events,public.support_requests,public.outcomes,public.benchmarks,public.research_assignments,public.verification_audit to service_role;
grant usage,select on sequence public.verification_audit_id_seq to service_role;

create policy own_profile_read on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy own_profile_insert on public.profiles for insert to authenticated with check(id=(select auth.uid()));
create policy own_profile_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy own_events_read on public.funnel_events for select to authenticated using(user_id=(select auth.uid()));
create policy consented_events_insert on public.funnel_events for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.research_consent));
create policy own_requests_read on public.support_requests for select to authenticated using(user_id=(select auth.uid()));
create policy own_requests_insert on public.support_requests for insert to authenticated with check(user_id=(select auth.uid()) and partner_consent);
create policy own_outcomes_read on public.outcomes for select to authenticated using(user_id=(select auth.uid()));
create policy own_outcomes_insert on public.outcomes for insert to authenticated with check(user_id=(select auth.uid()) and status='self_reported' and verified_at is null);
create policy own_pending_outcomes_update on public.outcomes for update to authenticated using(user_id=(select auth.uid()) and status='self_reported') with check(user_id=(select auth.uid()) and status='self_reported' and verified_at is null);
create policy published_benchmarks on public.benchmarks for select to anon,authenticated using(published);

create function public.touch_profile() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now(); return new; end $$;
create trigger profile_timestamp before update on public.profiles for each row execute function public.touch_profile();

-- Callable only by trusted service-role operations, never by the shipped client.
create function public.review_outcome(target uuid, decision text, evidence_note text)
returns void language plpgsql security definer set search_path='' as $$
declare previous text;
begin
 if decision not in ('verified','rejected') or length(trim(evidence_note))<10 then raise exception 'A decision and substantive evidence note are required'; end if;
 select status into previous from public.outcomes where id=target for update;
 if not found then raise exception 'Outcome not found'; end if;
 update public.outcomes set status=decision,verified_at=case when decision='verified' then now() else null end,verification_note=evidence_note where id=target;
 insert into public.verification_audit(outcome_id,old_status,new_status,note) values(target,previous,decision,evidence_note);
end $$;
revoke all on function public.review_outcome(uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_outcome(uuid,text,text) to service_role;

create function public.delete_my_data() returns void language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Authentication required'; end if;
 delete from public.funnel_events where user_id=caller;
 delete from public.support_requests where user_id=caller;
 delete from public.outcomes where user_id=caller;
 delete from public.research_assignments where user_id=caller;
 delete from public.profiles where id=caller;
end $$;
revoke all on function public.delete_my_data() from public,anon;
grant execute on function public.delete_my_data() to authenticated;

-- Run/export only as an operator. Do not expose auth.users or contacts in exports.
create view public.research_export as
select a.user_id as participant_id,a.cohort,a.enrolled_at,a.followup_due_at,a.assignment_method,
 exists(select 1 from public.funnel_events e where e.user_id=a.user_id and e.event_name='tool_completed' and e.occurred_at between a.enrolled_at and a.followup_due_at) as engaged,
 exists(select 1 from public.funnel_events e where e.user_id=a.user_id and e.event_name='registration_intent' and e.occurred_at between a.enrolled_at and a.followup_due_at) as registration_intent,
 exists(select 1 from public.funnel_events e where e.user_id=a.user_id and e.event_name='disqualified_by_choice' and e.occurred_at between a.enrolled_at and a.followup_due_at) as disqualified_by_choice,
 exists(select 1 from public.outcomes o where o.user_id=a.user_id and o.stage='registration' and o.status='verified' and o.claimed_at between a.enrolled_at and a.followup_due_at) as verified_registration,
 exists(select 1 from public.outcomes o where o.user_id=a.user_id and o.stage='first_order' and o.status='verified' and o.claimed_at between a.enrolled_at and a.followup_due_at) as verified_first_order
from public.research_assignments a join public.profiles p on p.id=a.user_id where p.research_consent;
revoke all on public.research_export from public,anon,authenticated;
grant select on public.research_export to service_role;
commit;
