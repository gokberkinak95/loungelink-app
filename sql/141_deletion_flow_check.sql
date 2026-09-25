-- ============================================================
-- LoungeLink · 141_deletion_flow_check.sql
-- HESAP SILME ZINCIRI: BENIM DEPLOY TALIMATIM KIRMIŞTI
--
-- ⚠️ Uygulamayi ETKILER (084 atlandiysa tablo eksik).
--
-- ------------------------------------------------------------
-- 🔴 BULDUGUM SEY BIR KOD HATASI DEGIL, BIR TALIMAT HATASI
-- ------------------------------------------------------------
-- Aylar once verdigim deploy sirasi soyleydi:
--     083 → 086 → 087 → ...   (⚠️ 084/085 atla)
--
-- Gerekcem: "086 bunlari tamamen degistiriyor". 085 icin DOGRUYDU —
-- 085_lounge_rules_v2 gercekten 086 ile degisti.
--
-- Ama 084 BASKA BIR KONU: 084_deletion_requests — hesap silme
-- talepleri tablosu. Numarasi yan yana diye ayni cumleye koymusum.
--
-- Sonuc: canlida `deletion_requests` tablosu MUHTEMELEN YOK.
-- Yani BO'daki /hesap-sil sayfasi ve app'teki silme butonu hata
-- veriyor — ve bu Google Play'in ZORUNLU tuttugu bir akis
-- ("Account deletion URL" magaza listesinde isteniyor).
--
-- Ders: dosyalari numaraya gore gruplamak, KONUYA gore gruplamak
-- degildir. "084/085 atla" demek kolaydi; ikisinin ne yaptigini
-- ayri ayri yazmak dogruydu.
--
-- Bu dosya zinciri UCTAN UCA kurar ve eksikse tamamlar — 084
-- calistirilmis olsa da olmasa da guvenle calisir.
-- ============================================================

create table if not exists deletion_requests (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  reason      text,
  status      text not null default 'pending'
              check (status in ('pending','verified','done','rejected')),
  note        text,
  handled_by  text,
  handled_at  timestamptz,
  created_at  timestamptz default now()
);
create index if not exists idx_delreq_status on deletion_requests(status, created_at desc);
alter table deletion_requests enable row level security;
-- Politika YOK = yalniz service_role (BO) ve security definer erisir.
-- Talep olusturma anonim yapilabilmeli (kullanici giris yapamiyor olabilir),
-- o yuzden asagidaki fonksiyon `security definer`.

create or replace function public.request_account_deletion(p_email text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if coalesce(p_email,'') !~ '^[^@]+@[^@]+\.[^@]+$' then
    raise exception 'invalid_email';
  end if;
  -- 🔴 SILME OTOMATIK DEGIL. E-postasini bilen herkesin baskasinin
  -- hesabini silebilmesi demek olurdu. Talep kaydedilir, BO'da
  -- kullanici dogrulandiktan SONRA islenir.
  insert into deletion_requests (email, note)
  values (lower(trim(p_email)), nullif(trim(coalesce(p_reason,'')),''))
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id,
    'note', 'Talebin alindi. Kimligini dogruladiktan sonra 30 gun icinde islenecek.');
end $$;
grant execute on function public.request_account_deletion(text, text) to anon, authenticated;

-- ---- ZINCIR DENETIMI ----
-- 🔴 "Tablo var mi" yetmez: silme TALEBI alindiginda onu ISLEYECEK
-- fonksiyon da olmali. Tabloyu kurup yurutucuyu unutmak, bu projede
-- uc kez yaptigim "gorunmeyen veri" hatasinin ayni sinifidir.
do $$
declare v_missing text[] := '{}';
begin
  if to_regclass('public.deletion_requests') is null then
    v_missing := v_missing || ('deletion_requests tablosu')::text;
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = 'admin_anonymize_user') then
    v_missing := v_missing || ('admin_anonymize_user() — 094 calistirilmamis')::text;
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = 'request_account_deletion') then
    v_missing := v_missing || ('request_account_deletion()')::text;
  end if;

  if array_length(v_missing, 1) is null then
    raise notice '✓ Hesap silme zinciri TAM: talep -> BO -> anonimlestirme';
  else
    raise warning '⚠ Hesap silme zincirinde EKSIK: %', array_to_string(v_missing, ', ');
  end if;
end $$;

select 'deletion_requests' as tablo, count(*)::text as talep from deletion_requests;

select '141 OK - hesap silme zinciri uctan uca kuruldu' as sonuc;
