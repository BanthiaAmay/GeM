-- Keeps the database small (the Supabase free plan allows 500 MB). Called
-- by the worker after each collection. Open bids stay, because the feed,
-- Saathi and newly joined sellers still need them.
begin;

create index if not exists gem_bids_closes on public.gem_bids(closes_at);
create index if not exists bid_jobs_created on public.bid_delivery_jobs(created_at);

-- Server-only. Returns how many rows each rule touched.
create function public.cleanup_bids(
 p_closed_grace interval default '2 days',
 p_slim_after interval default '1 day',
 p_jobs_after interval default '3 days')
returns jsonb language plpgsql security definer set search_path='' as $$
declare closed integer; slimmed integer; jobs integer;
begin
 -- 1. Bids closed for a while. Their inbox entries and jobs go with them.
 delete from public.gem_bids where closes_at < now() - p_closed_grace;
 get diagnostics closed = row_count;

 -- 2. Bids that matched nobody keep only the small facts after a day; the
 --    full buyer terms, specifications and links are the bulk of each row.
 update public.gem_bids b
 set details = b.details - 'atc' - 'specifications' - 'links'
 where b.fetched_at < now() - p_slim_after
  and (b.details ? 'atc' or b.details ? 'specifications' or b.details ? 'links')
  and not exists(select 1 from public.bid_notifications n where n.bid_id=b.id)
  and not exists(select 1 from public.bid_delivery_jobs j where j.bid_id=b.id);
 get diagnostics slimmed = row_count;

 -- 3. Finished delivery records. Recent "sent" rows stay: the minimum gap
 --    between a user's messages (up to 24 hours) is measured from them.
 delete from public.bid_delivery_jobs
 where status in ('sent','cancelled','failed') and created_at < now() - p_jobs_after;
 get diagnostics jobs = row_count;

 return jsonb_build_object('closed_bids_deleted', closed, 'bids_slimmed', slimmed,
  'old_jobs_deleted', jobs);
end $$;
revoke all on function public.cleanup_bids(interval,interval,interval) from public,anon,authenticated;
grant execute on function public.cleanup_bids(interval,interval,interval) to service_role;
commit;
