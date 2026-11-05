-- gem_bulletins now holds every recent video from the official GeM YouTube
-- channel, not only the Weekly Bulletin (the name is kept so existing app
-- builds keep working). Written only by scripts/gem_videos.py.
begin;

alter table public.gem_bulletins
 add column kind text not null default 'bulletin'
  check (kind in ('bulletin','tip','learning','story')),
 add column duration_seconds integer check (duration_seconds is null or duration_seconds >= 0);

create index gem_bulletins_kind_latest on public.gem_bulletins(kind, published_at desc) where published;

commit;
