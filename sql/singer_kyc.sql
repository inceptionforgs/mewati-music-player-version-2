-- Additive. Does not drop singer catalog tables.
-- App uses anonymous sign-in → JWT role is `authenticated`, not `anon`.
-- Policies allow both so the form works after splash auth.

insert into storage.buckets (id, name, public)
values ('singer-kyc-docs', 'singer-kyc-docs', false)
on conflict (id) do update set public = false;

create table if not exists public.singer_applications (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mobile_number text not null,
  id_document_path text not null,
  liveness_image_path text not null,
  liveness_check_method text not null default 'head_turn_left_right',
  terms_version text not null,
  terms_text_snapshot text not null,
  terms_accepted boolean not null default false,
  terms_accepted_at timestamptz not null,
  consent_ip_address text,
  consent_device_info text,
  consent_hash text not null,
  status text not null default 'pending',
  rejection_reason text,
  reviewed_at timestamptz,
  reviewed_by uuid,
  created_at timestamptz not null default now(),
  submitted_by uuid,
  id_document_sha256 text,
  liveness_image_sha256 text,
  terms_text_sha256 text,
  consent_manifest text,
  evidence_pack_sha256 text,
  section_65b_issued_at timestamptz,
  section_65b_note text
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'singer_applications_status_check'
  ) then
    alter table public.singer_applications
      add constraint singer_applications_status_check
      check (status in ('pending','approved','rejected'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'singer_applications_reviewed_by_fkey'
  ) then
    alter table public.singer_applications
      add constraint singer_applications_reviewed_by_fkey
      foreign key (reviewed_by) references auth.users(id);
  end if;
exception when others then
  raise notice 'reviewed_by fkey skipped: %', sqlerrm;
end $$;

alter table public.singer_applications
  add column if not exists submitted_by uuid;
alter table public.singer_applications
  add column if not exists id_document_sha256 text;
alter table public.singer_applications
  add column if not exists liveness_image_sha256 text;
alter table public.singer_applications
  add column if not exists terms_text_sha256 text;
alter table public.singer_applications
  add column if not exists consent_manifest text;
alter table public.singer_applications
  add column if not exists evidence_pack_sha256 text;
alter table public.singer_applications
  add column if not exists section_65b_issued_at timestamptz;
alter table public.singer_applications
  add column if not exists section_65b_note text;

alter table public.singer_applications enable row level security;

drop policy if exists "singer_applications_insert" on public.singer_applications;
create policy "singer_applications_insert"
  on public.singer_applications for insert
  to anon, authenticated
  with check (true);

drop policy if exists "singer_applications_no_select" on public.singer_applications;
create policy "singer_applications_no_select"
  on public.singer_applications for select
  to anon, authenticated
  using (false);

drop policy if exists "singer_applications_no_update" on public.singer_applications;
create policy "singer_applications_no_update"
  on public.singer_applications for update
  to anon, authenticated
  using (false);

drop policy if exists "singer_applications_no_delete" on public.singer_applications;
create policy "singer_applications_no_delete"
  on public.singer_applications for delete
  to anon, authenticated
  using (false);

create or replace function public.singer_applications_immutable_core()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    if new.name is distinct from old.name
       or new.mobile_number is distinct from old.mobile_number
       or new.id_document_path is distinct from old.id_document_path
       or new.liveness_image_path is distinct from old.liveness_image_path
       or new.liveness_check_method is distinct from old.liveness_check_method
       or new.terms_version is distinct from old.terms_version
       or new.terms_text_snapshot is distinct from old.terms_text_snapshot
       or new.terms_accepted is distinct from old.terms_accepted
       or new.terms_accepted_at is distinct from old.terms_accepted_at
       or new.consent_ip_address is distinct from old.consent_ip_address
       or new.consent_device_info is distinct from old.consent_device_info
       or new.consent_hash is distinct from old.consent_hash
       or new.created_at is distinct from old.created_at
       or new.submitted_by is distinct from old.submitted_by
       or new.id_document_sha256 is distinct from old.id_document_sha256
       or new.liveness_image_sha256 is distinct from old.liveness_image_sha256
       or new.terms_text_sha256 is distinct from old.terms_text_sha256
       or new.consent_manifest is distinct from old.consent_manifest
       or new.evidence_pack_sha256 is distinct from old.evidence_pack_sha256 then
      raise exception 'core singer application fields are immutable';
    end if;
    return new;
  end if;
  raise exception 'singer applications cannot be updated by this role';
end;
$$;

drop trigger if exists trg_singer_applications_immutable on public.singer_applications;
create trigger trg_singer_applications_immutable
  before update on public.singer_applications
  for each row
  execute function public.singer_applications_immutable_core();

drop function if exists public.submit_singer_application(
  uuid, text, text, text, text, text, text, timestamptz, text, text, text
);

create or replace function public.submit_singer_application(
  p_id uuid,
  p_name text,
  p_mobile_number text,
  p_id_document_path text,
  p_liveness_image_path text,
  p_terms_version text,
  p_terms_text_snapshot text,
  p_terms_accepted_at timestamptz,
  p_consent_ip_address text,
  p_consent_device_info text,
  p_consent_hash text,
  p_id_document_sha256 text,
  p_liveness_image_sha256 text,
  p_terms_text_sha256 text,
  p_consent_manifest text,
  p_evidence_pack_sha256 text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'name required';
  end if;
  if p_mobile_number is null or p_mobile_number !~ '^[0-9]{10}$' then
    raise exception 'mobile required';
  end if;

  insert into public.singer_applications (
    id, name, mobile_number, id_document_path, liveness_image_path,
    liveness_check_method, terms_version, terms_text_snapshot,
    terms_accepted, terms_accepted_at, consent_ip_address,
    consent_device_info, consent_hash, status, submitted_by,
    id_document_sha256, liveness_image_sha256, terms_text_sha256,
    consent_manifest, evidence_pack_sha256
  ) values (
    p_id, trim(p_name), p_mobile_number, p_id_document_path, p_liveness_image_path,
    'head_turn_left_right', p_terms_version, p_terms_text_snapshot,
    true, p_terms_accepted_at, p_consent_ip_address,
    p_consent_device_info, p_consent_hash, 'pending', auth.uid(),
    p_id_document_sha256, p_liveness_image_sha256, p_terms_text_sha256,
    p_consent_manifest, p_evidence_pack_sha256
  );

  return p_id;
end;
$$;

revoke all on function public.submit_singer_application(
  uuid, text, text, text, text, text, text, timestamptz, text, text, text,
  text, text, text, text, text
) from public;
grant execute on function public.submit_singer_application(
  uuid, text, text, text, text, text, text, timestamptz, text, text, text,
  text, text, text, text, text
) to anon, authenticated;

grant insert on public.singer_applications to anon, authenticated;

drop policy if exists "kyc_docs_insert" on storage.objects;
create policy "kyc_docs_insert"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'singer-kyc-docs');

drop policy if exists "kyc_docs_no_select" on storage.objects;
create policy "kyc_docs_no_select"
  on storage.objects for select
  to anon, authenticated
  using (false);

drop policy if exists "kyc_docs_no_update" on storage.objects;
create policy "kyc_docs_no_update"
  on storage.objects for update
  to anon, authenticated
  using (false);

drop policy if exists "kyc_docs_no_delete" on storage.objects;
create policy "kyc_docs_no_delete"
  on storage.objects for delete
  to anon, authenticated
  using (false);

-- Admin-only: pull the sealed consent record. Does not change any row.
drop function if exists public.export_singer_consent_proof(uuid, text);

create or replace function public.export_singer_consent_proof(
  p_id uuid default null,
  p_mobile text default null
)
returns table (
  id uuid,
  name text,
  mobile_number text,
  id_document_path text,
  liveness_image_path text,
  terms_version text,
  terms_text_snapshot text,
  terms_accepted_at timestamptz,
  consent_ip_address text,
  consent_device_info text,
  consent_hash text,
  status text,
  created_at timestamptz,
  id_document_sha256 text,
  liveness_image_sha256 text,
  terms_text_sha256 text,
  consent_manifest text,
  evidence_pack_sha256 text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'admin only';
  end if;

  return query
  select
    a.id,
    a.name,
    a.mobile_number,
    a.id_document_path,
    a.liveness_image_path,
    a.terms_version,
    a.terms_text_snapshot,
    a.terms_accepted_at,
    a.consent_ip_address,
    a.consent_device_info,
    a.consent_hash,
    a.status,
    a.created_at,
    a.id_document_sha256,
    a.liveness_image_sha256,
    a.terms_text_sha256,
    a.consent_manifest,
    a.evidence_pack_sha256
  from public.singer_applications a
  where (p_id is not null and a.id = p_id)
     or (p_id is null and p_mobile is not null and a.mobile_number = p_mobile)
  order by a.created_at desc
  limit 1;
end;
$$;

revoke all on function public.export_singer_consent_proof(uuid, text) from public;

notify pgrst, 'reload schema';