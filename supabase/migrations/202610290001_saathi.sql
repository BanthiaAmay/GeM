-- Saathi, the in-app assistant. The Gemini key and the user's data stay on
-- the server (supabase/functions/saathi); this table only meters usage so
-- one account cannot run up the model bill. No questions or answers are
-- stored.
begin;

create table public.saathi_usage (
 user_id uuid not null references auth.users(id) on delete cascade,
 day date not null default (now() at time zone 'Asia/Kolkata')::date,
 questions integer not null default 0 check (questions >= 0),
 primary key (user_id, day)
);
alter table public.saathi_usage enable row level security;
revoke all on public.saathi_usage from public,anon,authenticated;
grant all on public.saathi_usage to service_role;

-- Server-only: counts one question for the user and says whether it is
-- within today's (IST) limit.
create function public.saathi_take_question(p_user uuid, p_daily_limit integer default 40)
returns boolean language plpgsql security definer set search_path='' as $$
declare used integer;
begin
 insert into public.saathi_usage as u(user_id,questions) values(p_user,1)
 on conflict(user_id, day) do update set questions=u.questions+1
 returning questions into used;
 return used <= greatest(p_daily_limit,1);
end $$;
revoke all on function public.saathi_take_question(uuid,integer) from public,anon,authenticated;
grant execute on function public.saathi_take_question(uuid,integer) to service_role;

create or replace function public.delete_my_data() returns void language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Authentication required'; end if;
 delete from public.saathi_usage where user_id=caller;
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
