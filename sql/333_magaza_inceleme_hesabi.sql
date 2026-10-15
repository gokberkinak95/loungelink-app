-- ============================================================================
-- 333 · MAĞAZA İNCELEME HESABI (15 Ekim 2026 · App Store + Google Play yayını)
--
-- NEDEN: Apple (Guideline 2.1) ve Google Play ("Uygulama erişimi"), giriş isteyen
-- uygulamalarda İNCELEMECİYE TAM ERİŞİMLİ bir demo hesap ister. Bizde iki engel var:
--   1. İstek göndermek için doğrulanmış iletişim gerekiyor ve doğrulama kodu
--      e-postaya gidiyor — incelemeci bizim adresimize gelen kodu okuyamaz.
--   2. Yeni bir hesap boş bir dünyaya düşer: Keşfet/Tanış boş görünür → "uygulama
--      işlevsiz" reddi.
-- Bu fonksiyon, uygulamada NORMAL YOLDAN açılmış bir hesabı inceleme için hazırlar:
--   · e-posta ve telefon "doğrulandı" (yöntem: manual — kayıtta izi kalır)
--   · bakiye 10 krediye tamamlanır (yönetici düzeltmesi olarak deftere yazılır)
--   · test/vitrin hesaplarını görür (302 · test_gorunurlugu) — incelemeci boş ekran görmez
-- Hesabı OLUŞTURMAZ (şifre özeti üretmek uygulamanın işi); yalnız var olanı hazırlar.
--
-- KULLANIM (SQL Editor):
--   1. Uygulamada e-postayla kayıt ol: inceleme@loungelink.co + güçlü bir şifre
--   2. select public.inceleme_hesabi_hazirla('inceleme@loungelink.co');
--   3. Aynı e-posta + şifreyi App Store Connect › App Review Information ve
--      Google Play Console › App content › App access alanına yaz.
-- Yayından sonra hesabı kapatmak istersen: BO → Kullanıcılar → hesap → yasakla.
-- Tekrar koşulabilir.
-- ============================================================================

create or replace function public.inceleme_hesabi_hazirla(p_email text)
returns jsonb
language plpgsql security definer set search_path = public as $ih333$
declare
  v_uid uuid;
  v_bal int;
  v_ek  int;
begin
  -- Yalnız SQL Editor (postgres / service_role) ya da yönetici.
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;

  select id into v_uid from users where lower(email) = lower(btrim(p_email));
  if v_uid is null then
    return jsonb_build_object('ok', false, 'neden',
      'Bu e-postayla hesap yok. Önce uygulamada bu e-postayla kayıt ol, sonra tekrar çalıştır.');
  end if;

  insert into verifications (user_id, email_verified, email_verified_at, phone_verified, phone_verified_at, phone_verified_method)
  values (v_uid, true, now(), true, now(), 'manual')
  on conflict (user_id) do update
    set email_verified = true, email_verified_at = coalesce(verifications.email_verified_at, now()),
        phone_verified = true, phone_verified_at = coalesce(verifications.phone_verified_at, now()),
        phone_verified_method = coalesce(verifications.phone_verified_method, 'manual');

  insert into test_gorunurlugu (user_id, ekleyen)
  values (v_uid, '333 · magaza inceleme')
  on conflict (user_id) do nothing;

  select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = v_uid;
  v_ek := greatest(0, 10 - v_bal);
  if v_ek > 0 then
    insert into credit_ledger (user_id, delta, reason, balance_after, note)
    values (v_uid, v_ek, 'admin_adjust', v_bal + v_ek, 'Mağaza inceleme hesabı (333)');
  end if;

  return jsonb_build_object('ok', true, 'kullanici', v_uid, 'bakiye', v_bal + v_ek,
                            'not', 'Doğrulandı, 10 kredi, vitrin görünür.');
end $ih333$;

revoke all on function public.inceleme_hesabi_hazirla(text) from public, anon, authenticated;
grant execute on function public.inceleme_hesabi_hazirla(text) to service_role;

-- ── 2 · "BETA" KULLANICIYA GÖRÜNMEZ (Apple 2.2) ─────────────────────────────
-- App Store "beta / demo / test" diye kendini tanıtan uygulamayı reddeder (beta = TestFlight).
-- `request_credit_topup` kullanıcıya iki "Beta döneminde…" cümlesi döndürüyordu.
do $bt333$
declare r record; v text;
begin
  for r in
    select p.oid, pg_get_functiondef(p.oid) as tanim
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'request_credit_topup'
       and pg_get_functiondef(p.oid) like '%Beta döneminde%'
  loop
    v := replace(r.tanim, 'Beta döneminde talepler elle değerlendiriliyor.', 'Talepler ekibimiz tarafından elle değerlendiriliyor.');
    v := replace(v, 'Talebin alındı. Beta döneminde elle değerlendiriliyor.', 'Talebin alındı; ekibimiz en kısa sürede değerlendirecek.');
    execute v;
    raise notice '333 §2: request_credit_topup metinleri guncellendi.';
  end loop;
end $bt333$;

-- ── DOĞRULAMA ──────────────────────────────────────────────────────────────
select 'inceleme hesabi fonksiyonu' as kontrol,
       exists (select 1 from pg_proc where proname = 'inceleme_hesabi_hazirla')
   and not has_function_privilege('authenticated', 'public.inceleme_hesabi_hazirla(text)', 'execute') as tamam
union all
select 'kullaniciya beta yazmiyor',
       position('Beta döneminde' in pg_get_functiondef('public.request_credit_topup'::regproc)) = 0;
-- Beklenen: iki satır tamam = true.
