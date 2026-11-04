begin;

-- GeM Weekly Bulletin videos from the official GeM YouTube channel's public
-- upload feed. Written only by scripts/bulletin_worker.py (service role).
create table public.gem_bulletins (
 id uuid primary key default gen_random_uuid(),
 video_id text not null unique check (video_id ~ '^[A-Za-z0-9_-]{11}$'),
 title text not null check (length(title) between 1 and 300),
 published_at timestamptz not null,
 published boolean not null default true,
 fetched_at timestamptz not null default now()
);
create index gem_bulletins_latest on public.gem_bulletins(published_at desc) where published;

alter table public.gem_bulletins enable row level security;
revoke all on public.gem_bulletins from public,anon,authenticated;
grant select on public.gem_bulletins to anon,authenticated;
grant all on public.gem_bulletins to service_role;
create policy published_bulletins on public.gem_bulletins for select to anon,authenticated using(published);

commit;
