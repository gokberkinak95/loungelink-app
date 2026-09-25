-- ============================================================
-- LoungeLink · 060_security_hardening.sql
--
-- 🔴 GÜVENLİK DENETİMİ SONUCU — iki gerçek açık kapatılıyor.
--
-- AÇIK 1 — RLS'siz tablolar:
--   6 tabloda Row Level Security HİÇ açılmamış: otp_tokens, reports,
--   consents, invites, subscriptions, audit_log. Supabase'de public
--   şemadaki tablolar REST API ile dışarı açıktır; RLS kapalıysa
--   APK'dan çıkarılabilen publishable key ile bu tablolar doğrudan
--   okunabilir/yazılabilir.
--
-- AÇIK 2 — Korumasız ayrıcalıklı fonksiyonlar:
--   12 admin fonksiyonu SECURITY DEFINER, iç yetki kontrolü YOK ve
--   REVOKE de YOK. PostgreSQL fonksiyonlara varsayılan olarak PUBLIC
--   execute verir → giriş yapmış HERHANGİ bir kullanıcı bunları RPC
--   ile çağırabilirdi. Örnek: admin_adjust_credit ile kendine sınırsız
--   kredi, admin_set_trust ile kendine 100 güven puanı,
--   admin_set_verification ile doğrulamasız kimlik onayı,
--   resolve_report ile kendisi hakkındaki şikayeti kapatma.
--
-- NEDEN GÜVENLE ÇALIŞTIRILIR:
--   • App bu 6 tabloya HİÇ doğrudan erişmiyor (hepsi SECURITY DEFINER
--     RPC üzerinden) — DEFINER fonksiyonlar RLS'i bypass eder.
--   • BO service_role anahtarı kullanıyor — o da RLS'i bypass eder.
--   • REVOKE deseni 043/045/047/048'de zaten kanıtlanmış: BO'ya
--     service_role grant'ı veriliyor, kullanıcıdan yetki alınıyor.
-- ============================================================


-- ============================================================
-- BÖLÜM 1 — RLS AÇ + POLİTİKALAR
-- ============================================================

-- 1.1 otp_tokens — telefon doğrulama kodları (hash'li).
-- Hiçbir kullanıcı doğrudan görmemeli. Politika YOK = herkese kapalı.
-- send_otp/verify_otp SECURITY DEFINER olduğu için çalışmaya devam eder.
alter table otp_tokens enable row level security;

-- 1.2 audit_log — yönetim denetim kaydı.
-- Kullanıcı ne okumalı ne de yazmalı (izini silememeli). Politika YOK.
alter table audit_log enable row level security;

-- 1.3 reports — şikayet kayıtları. GÜVENLİK KRİTİK:
-- şikayet edilen kişi kendisi hakkındaki şikayeti GÖRMEMELİ.
alter table reports enable row level security;
drop policy if exists reports_select_own on reports;
create policy reports_select_own on reports
  for select using (reporter_id = auth.uid());

-- 1.4 consents — KVKK rıza kayıtları (PII: ip, user_agent).
alter table consents enable row level security;
drop policy if exists consents_select_own on consents;
create policy consents_select_own on consents
  for select using (user_id = auth.uid());

-- 1.5 invites — host davetleri. Taraflar kendi davetini görebilir.
alter table invites enable row level security;
drop policy if exists invites_select_party on invites;
create policy invites_select_party on invites
  for select using (host_id = auth.uid() or guest_id = auth.uid());

-- 1.6 subscriptions — abonelik/fatura durumu. Kullanıcı kendi planını
-- okuyabilir ama DEĞİŞTİREMEZ (kendini premium yapamaz).
alter table subscriptions enable row level security;
drop policy if exists subs_select_own on subscriptions;
create policy subs_select_own on subscriptions
  for select using (user_id = auth.uid());


-- ============================================================
-- BÖLÜM 2 — AYRICALIKLI FONKSİYONLARDAN KULLANICI YETKİSİNİ AL
-- Desen 043/045/047/048 ile birebir aynı:
--   revoke ... from public, authenticated   → kullanıcı çağıramaz
--   grant execute ... to service_role       → BO çağırmaya devam eder
-- ============================================================

-- Kredi/puan manipülasyonu (kendine sınırsız kredi verme riski)
revoke all on function public.admin_adjust_credit(uuid, int, text) from public, anon, authenticated;
grant execute on function public.admin_adjust_credit(uuid, int, text) to service_role;

revoke all on function public.admin_adjust_points(uuid, int, text) from public, anon, authenticated;
grant execute on function public.admin_adjust_points(uuid, int, text) to service_role;

revoke all on function public.admin_bulk_credit(int, text, text) from public, anon, authenticated;
grant execute on function public.admin_bulk_credit(int, text, text) to service_role;

revoke all on function public.admin_credit_adjust(uuid, int, text) from public, anon, authenticated;
grant execute on function public.admin_credit_adjust(uuid, int, text) to service_role;

-- Güven puanı / doğrulama manipülasyonu (trust-first mimarinin temeli)
revoke all on function public.admin_set_trust(uuid, int, text) from public, anon, authenticated;
grant execute on function public.admin_set_trust(uuid, int, text) to service_role;

revoke all on function public.admin_set_verification(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.admin_set_verification(uuid, text, boolean) to service_role;

-- Başkasının profilini düzenleme
revoke all on function public.admin_update_profile(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.admin_update_profile(uuid, jsonb) to service_role;

-- Moderasyon: puan silme / şikayet-itiraz kapatma (kendi hakkındakini kapatma riski)
revoke all on function public.remove_rating(uuid) from public, anon, authenticated;
grant execute on function public.remove_rating(uuid) to service_role;

revoke all on function public.resolve_report(uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function public.resolve_report(uuid, text, text, uuid) to service_role;

revoke all on function public.resolve_dispute(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.resolve_dispute(uuid, text, uuid) to service_role;

-- Kural motoru + kayıt kredisi (tekrar çağırıp kredi üretme riski)
revoke all on function public.apply_rule_engine(uuid) from public, anon, authenticated;
grant execute on function public.apply_rule_engine(uuid) to service_role;

revoke all on function public.grant_signup_credits(uuid) from public, anon, authenticated;
grant execute on function public.grant_signup_credits(uuid) to service_role;


-- ============================================================
-- BÖLÜM 3 — DOĞRULAMA
-- ============================================================

-- 3.1 Artık RLS'siz public tablo kaldı mı? (boş dönmeli)
select tablename as "RLS ACIK DEGIL (bos olmali)"
from pg_tables
where schemaname = 'public'
  and tablename not in (select relname from pg_class where relrowsecurity = true)
order by tablename;

-- 3.2 Kullanıcıya açık kalan ayrıcalıklı fonksiyon var mı? (boş dönmeli)
select p.proname as "HALA KULLANICIYA ACIK (bos olmali)"
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'admin_adjust_credit','admin_adjust_points','admin_bulk_credit','admin_credit_adjust',
    'admin_set_trust','admin_set_verification','admin_update_profile',
    'remove_rating','resolve_report','resolve_dispute','apply_rule_engine','grant_signup_credits')
  and has_function_privilege('authenticated', p.oid, 'execute');

select '060 OK — RLS 6 tabloda acildi, 12 ayricalikli fonksiyon kullaniciya kapatildi' as sonuc;
