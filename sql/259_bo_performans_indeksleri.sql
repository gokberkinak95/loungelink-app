-- ============================================================================
-- 259 — BACKOFFICE PERFORMANS İNDEKSLERİ
--
-- 🔴 NEDEN
-- Gökberk: "host başvuruları, istekler, uyarılar, kredi defteri, analitik,
-- büyüme, hata kaydı, oturumlar sayfalarında aşırı geç açılma hatta
-- açılmama."
--
-- Ölçüm (/api/tani, production): Vercel `iad1` ↔ Supabase arası tek gidiş-
-- dönüş **345 ms**, yayılım yalnız 27 ms. Dar yayılım = mesafe, yük değil.
--
-- BO tarafında sabit maliyeti 8 turdan 1'e indirdim (v1.87–v1.88) ve
-- analitik/büyüme sayfalarının tablo indirmesini kestim (v1.89). Geriye
-- kalan: SORGUNUN KENDİSİ. Bu sayfaların hepsi aynı deseni kullanıyor —
--
--     select ... from T order by created_at desc limit N
--
-- İndeks yoksa Postgres bunun için TÜM TABLOYU okur ve sıralar. 100 satır
-- isteyip 50.000 satır taramak, tabloyu büyüdükçe yavaşlayan bir sayfa
-- demektir: bugün "geç açılıyor", yarın "açılmıyor".
--
-- 🆕 SINIF: "`order by ... limit N` BİR İNDEKS TALEBİDİR — İNDEKS YOKSA
-- VERİTABANI N SATIR İÇİN BÜTÜN TABLOYU OKUR VE SORUN VERİ BÜYÜDÜKÇE
-- KENDİLİĞİNDEN KÖTÜLEŞİR."
--
-- ⚠️ BU DOSYA GÜVENLİ: yalnız `create index if not exists`. Hiçbir veri
-- değişmiyor, hiçbir şey silinmiyor, iki kez çalıştırılabilir. Tablolar
-- şu an küçük olduğu için `concurrently` gerekmiyor (tek işlemde çalışır).
--
-- ⚠️ İNDEKSİN BEDELİ DE VAR: her yazma işlemi indeksleri de günceller.
-- O yüzden buraya YALNIZCA BO'nun gerçekten `order by`/`where` ile
-- kullandığı kolonlar konuldu — koddan sayılarak, tahminle değil.
-- ============================================================================

do $$
declare
  v_var int;
  v_yok text[] := '{}';
  v_t text;
begin
  -- Tablo yoksa indeks denemesi hata verir; hangi tabloların var olduğunu
  -- ölçüp sadece onlara indeks açıyoruz.
  foreach v_t in array array[
    'credit_ledger','requests','sessions','host_applications','app_errors',
    'audit_log','availabilities','visits','points_ledger','redemptions',
    'disputes','connection_requests','users','reports'
  ] loop
    if to_regclass('public.' || v_t) is null then
      v_yok := v_yok || v_t;
    end if;
  end loop;
  if array_length(v_yok, 1) is not null then
    raise notice '259: bu tablolar yok, atlanıyor: %', v_yok;
  end if;
end $$;

-- ── ZAMAN SIRALI LİSTELER (BO'da `order by created_at desc limit N`) ──────
create index if not exists ix_credit_ledger_created       on public.credit_ledger (created_at desc);
create index if not exists ix_requests_created            on public.requests (created_at desc);
create index if not exists ix_app_errors_created          on public.app_errors (created_at desc);
create index if not exists ix_audit_log_created           on public.audit_log (created_at desc);
create index if not exists ix_points_ledger_created       on public.points_ledger (created_at desc);
create index if not exists ix_redemptions_created         on public.redemptions (created_at desc);
create index if not exists ix_disputes_created            on public.disputes (created_at desc);
create index if not exists ix_conn_requests_created       on public.connection_requests (created_at desc);
create index if not exists ix_users_created               on public.users (created_at desc);

-- `sessions` started_at ile sıralanıyor (created_at değil) — koddan ölçüldü.
create index if not exists ix_sessions_started            on public.sessions (started_at desc);

-- ── DURUM + ZAMAN (kuyruk sayfaları önce duruma filtreliyor) ─────────────
-- Kısmi indeks: yalnız BEKLEYEN satırlar. Kuyruk sayfası her zaman
-- "pending" istiyor; tamamlananları indekste tutmanın anlamı yok ve
-- kısmi indeks hem küçük hem hızlı.
create index if not exists ix_host_apps_pending
  on public.host_applications (created_at desc) where status = 'pending';
create index if not exists ix_requests_status_created
  on public.requests (status, created_at desc);
create index if not exists ix_sessions_status_started
  on public.sessions (status, started_at desc);

-- ── ANALİTİK/BÜYÜME PENCERELERİ (v1.89 sorguları) ────────────────────────
-- `availabilities` artık `avail_date` penceresiyle ve `active` filtresiyle
-- geliyor; `visits` de `visit_date` penceresiyle.
create index if not exists ix_avail_active_date
  on public.availabilities (avail_date) where active;
create index if not exists ix_visits_date
  on public.visits (visit_date);
create index if not exists ix_avail_airport_date
  on public.availabilities (airport_code, avail_date);

-- ── NÖBETÇİ ─────────────────────────────────────────────────────────────
-- 🔴 "İndeksi yazdım" ile "indeks var" aynı şey değildir: bir yazım hatası,
-- olmayan bir kolon ya da farklı bir şema hepsini sessizce atlatabilir.
-- Bu blok SAYIYOR ve tutmuyorsa migration'ı DÜŞÜRÜYOR.
do $$
declare
  v_beklenen text[] := array[
    'ix_credit_ledger_created','ix_requests_created','ix_app_errors_created',
    'ix_audit_log_created','ix_points_ledger_created','ix_redemptions_created',
    'ix_disputes_created','ix_conn_requests_created','ix_users_created',
    'ix_sessions_started','ix_host_apps_pending','ix_requests_status_created',
    'ix_sessions_status_started','ix_avail_active_date','ix_visits_date',
    'ix_avail_airport_date'
  ];
  v_ad text;
  v_eksik text[] := '{}';
begin
  foreach v_ad in array v_beklenen loop
    if not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = v_ad) then
      v_eksik := v_eksik || v_ad;
    end if;
  end loop;
  if array_length(v_eksik, 1) is not null then
    raise exception '259 NOBETCI: su indeksler olusmadi: %', v_eksik;
  end if;
  raise notice '259: % indeks yerinde.', array_length(v_beklenen, 1);
end $$;

-- ── İSTATİSTİKLERİ TAZELE ───────────────────────────────────────────────
-- Yeni indeks, planlayıcı onu KULLANMAYI seçmezse işe yaramaz. `analyze`
-- planlayıcıya tabloların güncel dağılımını verir.
--
-- 🆕 SINIF: "BİR İNDEKS AÇMAK ONU KULLANDIRMAZ — PLANLAYICI ESKİ
-- İSTATİSTİKLE KARAR VERİYORSA YENİ İNDEKSİ GÖRMEZ."
analyze public.credit_ledger;
analyze public.requests;
analyze public.sessions;
analyze public.host_applications;
analyze public.app_errors;
analyze public.availabilities;
analyze public.visits;
