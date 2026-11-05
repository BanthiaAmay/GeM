-- Run after all migrations in an isolated test database.
begin;
insert into public.gem_bulletins(video_id,title,published_at,kind,duration_seconds) values
 ('_xLQb-ZEfhE','GeM Bulletin November Week #1',now(),'bulletin',58),
 ('g9gsdEO7cTk','GeM Bid Showing "Not Eligible"? #GeMShorts',now(),'tip',45),
 ('6YAjRZUPIug','How Amit Vishwa Traders Grew with GeM',now(),'story',300);
insert into public.gem_bulletins(video_id,title,published_at) values ('DL_xpa4vB0o','Old row',now());
do $$begin
 if (select kind from public.gem_bulletins where video_id='DL_xpa4vB0o')<>'bulletin' then raise exception 'Default kind wrong'; end if;
 begin
  insert into public.gem_bulletins(video_id,title,published_at,kind) values ('abcdefghijk','x',now(),'music');
  raise exception 'Unknown kind accepted';
 exception when check_violation then null;
 end;
end $$;
set local role anon;
do $$begin
 if (select count(*) from public.gem_bulletins)<>4 then raise exception 'Anonymous read failed'; end if;
 if has_table_privilege('anon','public.gem_bulletins','INSERT') then raise exception 'Anonymous write allowed'; end if;
end $$;
reset role;
rollback;
