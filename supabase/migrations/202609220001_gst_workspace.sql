begin;
-- Invoice data is private to its owner. Extracted values are always drafts and editable.
create table public.gst_invoice_records (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=16384),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index gst_invoice_owner on public.gst_invoice_records(user_id);
alter table public.gst_invoice_records enable row level security;
revoke all on public.gst_invoice_records from anon,authenticated;
grant select,insert,update,delete on public.gst_invoice_records to authenticated;
grant all on public.gst_invoice_records to service_role;
create policy gst_invoice_select on public.gst_invoice_records for select to authenticated using(user_id=(select auth.uid()));
create policy gst_invoice_insert on public.gst_invoice_records for insert to authenticated with check(user_id=(select auth.uid()));
create policy gst_invoice_update on public.gst_invoice_records for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy gst_invoice_delete on public.gst_invoice_records for delete to authenticated using(user_id=(select auth.uid()));

-- Never use a public bucket or public URLs for invoice PDFs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('gst-invoices','gst-invoices',false,10485760,array['application/pdf'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=array['application/pdf'];
create policy gst_pdf_read on storage.objects for select to authenticated using(bucket_id='gst-invoices' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy gst_pdf_insert on storage.objects for insert to authenticated with check(bucket_id='gst-invoices' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy gst_pdf_update on storage.objects for update to authenticated using(bucket_id='gst-invoices' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='gst-invoices' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy gst_pdf_delete on storage.objects for delete to authenticated using(bucket_id='gst-invoices' and (storage.foldername(name))[1]=(select auth.uid())::text);

create or replace function public.delete_my_data() returns void language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Authentication required'; end if;
 delete from public.gst_invoice_records where user_id=caller;
 delete from public.funnel_events where user_id=caller;
 delete from public.support_requests where user_id=caller;
 delete from public.outcomes where user_id=caller;
 delete from public.research_assignments where user_id=caller;
 delete from public.profiles where id=caller;
end $$;
revoke all on function public.delete_my_data() from public,anon;
grant execute on function public.delete_my_data() to authenticated;
commit;
