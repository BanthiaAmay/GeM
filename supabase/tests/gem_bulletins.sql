-- Run after all migrations in an isolated test database.
begin;
insert into public.gem_bulletins(video_id,title,published_at,published) values
 ('AAAAAAAAAA1','GeM Bulletin October Week #4',now()-interval '1 day',true),
 ('AAAAAAAAAA2','GeM Bulletin October Week #3',now()-interval '8 days',true),
 ('AAAAAAAAAA3','Hidden bulletin',now(),false);

do $$begin
 begin
  insert into public.gem_bulletins(video_id,title,published_at) values ('not a video id','x',now());
  raise exception 'Invalid video id accepted';
 exception when check_violation then null;
 end;
end $$;

set local role anon;
do $$begin
 if (select count(*) from public.gem_bulletins)<>2 then raise exception 'Unpublished bulletin visible'; end if;
 if (select video_id from public.gem_bulletins order by published_at desc limit 1)<>'AAAAAAAAAA1' then
  raise exception 'Latest bulletin order failed';
 end if;
 if has_table_privilege('anon','public.gem_bulletins','INSERT') then raise exception 'Anon bulletin write'; end if;
 if has_table_privilege('authenticated','public.gem_bulletins','UPDATE') then raise exception 'Bulletin update permission'; end if;
end $$;
reset role;
rollback;
