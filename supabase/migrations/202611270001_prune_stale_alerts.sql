-- Bid alerts follow the business. When a seller changes what they supply
-- (keywords) or where (states), alerts for bids that no longer match are
-- removed and their unsent pushes/emails cancelled, so Home never shows
-- alerts for a business they no longer run. Also tidies existing accounts
-- once. Matching is the same bid_matches the alert queue uses.
begin;

create or replace function public.prune_stale_bid_alerts() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.keywords is distinct from old.keywords or new.states is distinct from old.states then
  delete from public.bid_notifications n using public.gem_bids b
  where n.user_id = new.user_id and b.id = n.bid_id
    and not public.bid_matches(b.title || ' ' || b.category, b.state, new.keywords, new.states);
  update public.bid_delivery_jobs j set status = 'cancelled'
  from public.gem_bids b
  where j.user_id = new.user_id and j.status = 'pending' and b.id = j.bid_id
    and not public.bid_matches(b.title || ' ' || b.category, b.state, new.keywords, new.states);
 end if;
 return new;
end $$;
revoke all on function public.prune_stale_bid_alerts() from public, anon, authenticated;

drop trigger if exists bid_alert_preferences_prune on public.bid_alert_preferences;
create trigger bid_alert_preferences_prune
 after update of keywords, states on public.bid_alert_preferences
 for each row execute function public.prune_stale_bid_alerts();

-- One-off: accounts whose keywords already changed keep only matching alerts.
delete from public.bid_notifications n
using public.gem_bids b, public.bid_alert_preferences p
where b.id = n.bid_id and p.user_id = n.user_id
  and not public.bid_matches(b.title || ' ' || b.category, b.state, p.keywords, p.states);
update public.bid_delivery_jobs j set status = 'cancelled'
from public.gem_bids b, public.bid_alert_preferences p
where j.status = 'pending' and b.id = j.bid_id and p.user_id = j.user_id
  and not public.bid_matches(b.title || ' ' || b.category, b.state, p.keywords, p.states);

commit;
