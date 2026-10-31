\set ON_ERROR_STOP on
begin;

insert into auth.users values
  ('10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002');

insert into public.profiles(id, state) values
  ('10000000-0000-0000-0000-000000000001', '{"owner":"one"}'),
  ('20000000-0000-0000-0000-000000000002', '{"owner":"two"}');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
select public.delete_my_account();

reset role;
do $$
begin
  if exists (
    select 1 from auth.users
    where id = '10000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'TEST FAILED: caller account was not deleted';
  end if;
  if not exists (
    select 1 from auth.users
    where id = '20000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'TEST FAILED: another account was deleted';
  end if;
  if exists (
    select 1 from public.profiles
    where id = '10000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'TEST FAILED: account rows did not cascade';
  end if;
end;
$$;

rollback;
select 'Account deletion checks passed' as result;
