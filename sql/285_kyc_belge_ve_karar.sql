-- ============================================================
-- LoungeLink · sql/285_kyc_belge_ve_karar.sql
-- 2 Eylül 2026
--
-- 🔴 KYC TEK TIKLA ONAYLANIYORDU — VE ORTADA BELGE YOKTU
--
--   BO'daki "Kimliği onayla" düğmesi `verifications.id_verified=true`
--   yazıyordu. Onaylayan kişi NEYE baktığını kaydetmiyordu, çünkü
--   bakacak bir şey yoktu: uygulamada kimlik belgesi yükleme akışı
--   HİÇ YAZILMAMIŞTI. "Kimlik doğrulandı" rozeti (+18 güven, +400
--   puan, keşifte +14) bir insanın bir düğmeye basmasından ibaretti.
--
--   Bu dosya:
--     · özel `kyc` kovası (herkese kapalı; sahibi yazar, yalnız servis rolü okur)
--     · verifications: id_status / belge yolları / karar notu / karar veren
--     · kimlik_belgesi_gonder()  — uygulama: belge + selfie yolu
--     · kimlik_durumum()         — uygulama: durum ve ret notu
--     · bo_kyc_kuyrugu()         — BO: yalnız BELGE GÖNDERMİŞ olanlar
--     · bo_kyc_karar()           — BO: onay/ret + zorunlu not (ret'te)
--                                  + belgeyi SİLME işareti (KVKK: karar
--                                  sonrası belge tutulmaz)
--
-- 🆕 SINIF: "KANITSIZ ONAY, ONAY DEĞİL TAHMİNDİR — VE ROZETİ ALAN
-- KİŞİ O TAHMİNİ HERKESE GÜVEN DİYE GÖSTERİR."
-- ============================================================

-- ── 1 · Kova: özel ──────────────────────────────────────────────
insert into storage.buckets (id, name, public) values ('kyc', 'kyc', false)
on conflict (id) do nothing;

drop policy if exists "kyc_own_write" on storage.objects;
create policy "kyc_own_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'kyc' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "kyc_own_update" on storage.objects;
create policy "kyc_own_update" on storage.objects for update to authenticated
  using (bucket_id = 'kyc' and (storage.foldername(name))[1] = auth.uid()::text);
-- OKUMA POLİTİKASI YOK: sahibi bile URL ile okuyamaz; BO servis rolüyle
-- imzalı URL üretir. Belge bir kez yüklenir, karardan sonra silinir.

-- ── 2 · Kolonlar (additive) ─────────────────────────────────────
alter table verifications add column if not exists id_status text not null default 'none';
alter table verifications add column if not exists id_doc_path text;
alter table verifications add column if not exists id_selfie_path text;
alter table verifications add column if not exists id_submitted_at timestamptz;
alter table verifications add column if not exists id_review_note text;
alter table verifications add column if not exists id_reviewed_by text;
alter table verifications add column if not exists id_reviewed_at timestamptz;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'verif_id_status_chk') then
    alter table verifications add constraint verif_id_status_chk
      check (id_status in ('none','submitted','approved','rejected'));
  end if;
end $$;
-- Geçmiş: zaten onaylı olanlar 'approved'
update verifications set id_status = 'approved' where id_verified and id_status = 'none';

-- ── 3 · Uygulama RPC'leri ───────────────────────────────────────
create or replace function public.kimlik_belgesi_gonder(p_doc_path text, p_selfie_path text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_st text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);
  -- Yol kendi klasöründe olmalı: başkasının belgesini "benim" diye gönderemez
  if p_doc_path is null or p_doc_path !~ ('^' || v_uid::text || '/') then raise exception 'kyc_path_invalid'; end if;
  if p_selfie_path is not null and p_selfie_path !~ ('^' || v_uid::text || '/') then raise exception 'kyc_path_invalid'; end if;
  select id_status into v_st from verifications where user_id = v_uid;
  if v_st = 'approved' then raise exception 'kyc_already_approved'; end if;
  if v_st = 'submitted' then raise exception 'kyc_already_submitted'; end if;
  insert into verifications (user_id) values (v_uid) on conflict (user_id) do nothing;
  update verifications
     set id_status = 'submitted', id_doc_path = p_doc_path, id_selfie_path = p_selfie_path,
         id_submitted_at = now(), id_review_note = null, updated_at = now()
   where user_id = v_uid;
  insert into audit_log (action, entity_type, entity_id, after_data)
  values ('kyc.submitted', 'verifications', v_uid, jsonb_build_object('selfie', p_selfie_path is not null));
  return jsonb_build_object('ok', true, 'status', 'submitted', 'sla_saat', 48);
end $$;
revoke all on function public.kimlik_belgesi_gonder(text,text) from public, anon;
grant execute on function public.kimlik_belgesi_gonder(text,text) to authenticated;

create or replace function public.kimlik_durumum()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('status', v.id_status, 'verified', v.id_verified,
                                             'submitted_at', v.id_submitted_at, 'note', v.id_review_note,
                                             'reviewed_at', v.id_reviewed_at)
                     from verifications v where v.user_id = auth.uid()),
                  jsonb_build_object('status','none','verified',false))
$$;
revoke all on function public.kimlik_durumum() from public, anon;
grant execute on function public.kimlik_durumum() to authenticated;

-- ── 4 · BO RPC'leri (yalnız servis rolü / admin) ────────────────
create or replace function public.bo_kyc_kuyrugu(p_limit int default 100)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is not null and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select jsonb_agg(x order by x->>'submitted_at') into v from (
    select jsonb_build_object(
      'user_id', v.user_id, 'email', u.email, 'name', p.name, 'phone_verified', v.phone_verified,
      'doc_path', v.id_doc_path, 'selfie_path', v.id_selfie_path, 'submitted_at', v.id_submitted_at,
      'bekleme_saat', round(extract(epoch from (now() - v.id_submitted_at))/3600)::int,
      'legal_name', null,
      'sikayet', (select count(*) from reports r where r.target_id = v.user_id),
      'onceki_ret', (select count(*) from audit_log a where a.entity_id = v.user_id and a.action = 'kyc.rejected')) as x
    from verifications v
    join users u on u.id = v.user_id
    left join profiles p on p.user_id = v.user_id
    where v.id_status = 'submitted' and coalesce(u.is_staff,false) = false
    limit greatest(coalesce(p_limit,100),1)) t;
  return coalesce(v, '[]'::jsonb);
end $$;

create or replace function public.bo_kyc_karar(p_user_id uuid, p_karar text, p_not text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_email text; v_doc text; v_selfie text; v_before jsonb;
begin
  if auth.uid() is not null and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  if p_karar not in ('approved','rejected') then raise exception 'gecersiz_karar'; end if;
  if p_karar = 'rejected' and coalesce(btrim(p_not),'') = '' then raise exception 'ret_notu_zorunlu'; end if;
  select email into v_email from users where id = auth.uid();
  select id_doc_path, id_selfie_path, to_jsonb(v) - 'id_doc_path' - 'id_selfie_path' into v_doc, v_selfie, v_before
    from verifications v where user_id = p_user_id;
  if not found then raise exception 'verification_not_found'; end if;
  update verifications
     set id_status = p_karar,
         id_verified = (p_karar = 'approved'),
         id_verified_at = case when p_karar = 'approved' then now() else id_verified_at end,
         id_provider = case when p_karar = 'approved' then 'manual-backoffice' else id_provider end,
         id_review_note = nullif(btrim(coalesce(p_not,'')),''),
         id_reviewed_by = coalesce(v_email, 'admin'), id_reviewed_at = now(),
         -- KVKK: karar verildi, belge yolu tabloda kalmaz (dosyayı BO siler)
         id_doc_path = null, id_selfie_path = null, updated_at = now()
   where user_id = p_user_id;
  insert into audit_log (action, entity_type, entity_id, before_data, after_data)
  values ('kyc.' || p_karar, 'verifications', p_user_id, v_before,
          jsonb_build_object('karar', p_karar, 'not', p_not, 'karar_veren', coalesce(v_email,'admin')));
  insert into notifications (user_id, category, title, body, ref_type, ref_id)
  values (p_user_id, 'system',
          case when p_karar = 'approved' then 'Kimliğin doğrulandı ✓' else 'Kimlik belgen kabul edilmedi' end,
          case when p_karar = 'approved' then 'Profilinde doğrulanmış rozeti var; keşifte daha öne çıkıyorsun.'
               else coalesce(nullif(btrim(p_not),''), 'Belge okunamadı.') || ' Yeniden yükleyebilirsin.' end,
          'user', p_user_id);
  return jsonb_build_object('ok', true, 'silinecek', jsonb_strip_nulls(jsonb_build_object('doc', v_doc, 'selfie', v_selfie)));
end $$;
revoke all on function public.bo_kyc_kuyrugu(int) from public, anon, authenticated;
revoke all on function public.bo_kyc_karar(uuid,text,text) from public, anon, authenticated;
grant execute on function public.bo_kyc_kuyrugu(int) to service_role;
grant execute on function public.bo_kyc_karar(uuid,text,text) to service_role;

-- ── NÖBETÇİLER ──────────────────────────────────────────────────
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'kyc' and public = false) then raise exception '285: kyc kovasi yok/acik'; end if;
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname like 'kyc%' and cmd = 'SELECT') then
    raise exception '285: kyc kovasinda okuma politikasi var — olmamali'; end if;
  if not exists (select 1 from information_schema.columns where table_name='verifications' and column_name='id_status') then raise exception '285: id_status yok'; end if;
  if has_function_privilege('authenticated', 'public.bo_kyc_karar(uuid,text,text)', 'execute') then raise exception '285: bo_kyc_karar authenticated''a acik'; end if;
  raise notice '285 NOBETCI OK: kyc kovasi ozel · belge gonder/durum · BO kuyruk+karar (ret notu zorunlu)';
end $$;
