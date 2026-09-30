\set ON_ERROR_STOP on
begin;
insert into auth.users values('10000000-0000-0000-0000-000000000001'),('20000000-0000-0000-0000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into public.gst_invoice_records(id,user_id,payload) values('30000000-0000-0000-0000-000000000003',auth.uid(),'{}');
insert into storage.objects(bucket_id,name) values('gst-invoices','10000000-0000-0000-0000-000000000001/a.pdf');
do $$begin
 begin insert into public.gst_invoice_records(id,user_id,payload) values('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','{}');raise exception 'TEST FAILED: cross-user invoice write';exception when insufficient_privilege then null;end;
 begin insert into storage.objects(bucket_id,name) values('gst-invoices','20000000-0000-0000-0000-000000000002/b.pdf');raise exception 'TEST FAILED: cross-user PDF write';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
do $$begin
 if (select count(*) from public.gst_invoice_records)<>0 then raise exception 'TEST FAILED: cross-user invoice read';end if;
 if (select count(*) from storage.objects)<>0 then raise exception 'TEST FAILED: cross-user PDF read';end if;
end$$;
rollback;
select 'GST private-storage RLS checks passed' as result;
