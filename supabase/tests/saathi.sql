-- Run after all migrations in an isolated test database.
begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000901');
set local role service_role;
do $$begin
 if not public.saathi_take_question('00000000-0000-0000-0000-000000000901',2) then raise exception 'First question refused'; end if;
 if not public.saathi_take_question('00000000-0000-0000-0000-000000000901',2) then raise exception 'Second question refused'; end if;
 if public.saathi_take_question('00000000-0000-0000-0000-000000000901',2) then raise exception 'Daily limit ignored'; end if;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000901',true);
do $$begin
 if has_function_privilege('authenticated','public.saathi_take_question(uuid,integer)','EXECUTE')
  or has_table_privilege('authenticated','public.saathi_usage','SELECT')
 then raise exception 'Usage metering must be server-only'; end if;
end $$;
select public.delete_my_data();
reset role;
do $$begin
 if exists(select 1 from public.saathi_usage) then raise exception 'Usage not deleted with data'; end if;
end $$;
rollback;
