-- ============================================================
-- LoungeLink · sql/278_push_kanali_enum.sql
-- 31 Ağustos 2026
--
-- 🔴 276 CANLIDA HER BİLDİRİMİ PATLATIYORDU. UÇTAN UCA TEST YAKALADI.
--
-- 276'da `push_kanali(p_category text)` tanımladım ve `notify_push`
-- tetikleyicisinin gövdesine `push_kanali(NEW.category)` yazdım.
-- Ama `notifications.category` bir TEXT değil, `notif_category` ENUM'u.
--
-- PostgreSQL fonksiyon çözümlemesinde enum → text ÖRTÜK dönüşüm
-- YAPMAZ. Sonuç:
--
--     ERROR: function push_kanali(notif_category) does not exist
--
-- ve bu hata `notifications` tablosuna yapılan HER INSERT'te fırlıyor.
-- Yani bildirim üreten her akış — istek gönderme, kabul, oturum
-- başlatma, mesaj — sunucuda düşüyordu.
--
-- ⚠️ NEDEN 276'NIN KENDİ NÖBETÇİSİ YAKALAMADI: iki nöbetçi de
-- fonksiyonu DOĞRUDAN `push_kanali('sohbet')` gibi TEXT literal ile
-- çağırıyordu — ki o çağrı çalışıyor. Tetikleyicinin İÇİNDEKİ çağrı
-- ise ancak GERÇEK bir insert olduğunda değerlendiriliyor; PL/pgSQL
-- gövdeyi kurulum anında çözmez.
--
-- 🆕 SINIF: "BİR FONKSİYONU KENDİ TESTİNDE ÇAĞIRDIĞIN TİPLE DEĞİL,
-- ÜRÜNÜN ONU ÇAĞIRDIĞI TİPLE SINA — ARADAKİ FARK, KURULUMDA DEĞİL
-- İLK GERÇEK KAYITTA ORTAYA ÇIKAR."
--
-- Bunu bulan şey `npm run e2e` oldu: gerçek bir Postgres kaldırıp
-- gerçek bir kullanıcıyla gerçek bir ilan açıyor. Statik hiçbir
-- denetim bunu göremezdi.
-- ============================================================

-- ── ÇÖZÜM: ENUM İÇİN AŞIRI YÜKLEME ──────────────────────────────
-- `notify_push`in gövdesini değiştirmek yerine bir aşırı yükleme
-- ekliyorum. Sebebi: gövdeyi düzenlemek 276'nın DO-bloğunu tekrar
-- koşturmayı gerektirir ve o blok metin ikamesi yapıyor — iki kez
-- çalışırsa ne yapacağı belirsiz. Aşırı yükleme ise tek yönlü ve
-- geri alınabilir.
create or replace function public.push_kanali(p_category notif_category)
returns text
language sql
immutable
set search_path = public
as $$ select public.push_kanali(p_category::text) $$;

comment on function public.push_kanali(notif_category) is
  'ENUM aşırı yüklemesi. `notify_push` tetikleyicisi kategoriyi enum '
  'olarak geçiyor; PostgreSQL enum→text örtük dönüşüm yapmadığı için '
  '276 tek başına çalışma anında patlıyordu (bkz. 278 başlığı).';

revoke all on function public.push_kanali(notif_category) from public;
grant execute on function public.push_kanali(notif_category)
  to authenticated, service_role;

-- ── NÖBETÇİ 1: ÜRÜNÜN ÇAĞIRDIĞI TİPLE ÇAĞIR ─────────────────────
-- 276'nın nöbetçisinin yapmadığı şey tam olarak bu.
do $$
declare v text;
begin
  -- ⚠️ ENUM DEĞERLERİ İNGİLİZCE: requests, sessions, invites,
  -- connections, system, safety, credits, ratings. İlk yazımda
  -- 'sohbet' geçtim ve nöbetçi "invalid input value for enum" dedi —
  -- yani nöbetçi, KENDİ yazarının kategori adlarını bilmediğini
  -- yakaladı. 276'yı yazarken de aynı varsayımı yapabilirdim.
  select public.push_kanali('safety'::notif_category) into v;
  if v <> 'guvenlik' then
    raise exception '278: safety → % (beklenen guvenlik)', v;
  end if;
  select public.push_kanali('requests'::notif_category) into v;
  if v <> 'akis' then
    raise exception '278: requests → % (beklenen akis)', v;
  end if;
  raise notice '278: enum asiri yuklemesi calisiyor (safety→guvenlik, requests→akis)';
end $$;

-- ── NÖBETÇİ 2: GERÇEK BİR INSERT ─────────────────────────────────
-- 🔴 ASIL KAPI BU. Fonksiyonun var olması yetmez; tetikleyicinin
-- İÇİNDEN çağrılabildiğini ancak gerçek bir kayıt kanıtlar.
-- Kayıt geri alınıyor — nöbetçi veri bırakmaz.
do $$
declare v_uid uuid;
begin
  select id into v_uid from users limit 1;
  if v_uid is null then
    raise notice '278: kullanici yok — insert nobetcisi atlandi';
    return;
  end if;
  begin
    insert into notifications (user_id, category, title, body)
    values (v_uid, 'system', '278 nobetci', 'gecici kayit');
    raise notice '278 NOBETCI OK: bildirim insert edilebiliyor';
    raise exception 'ROLLBACK_278';   -- kaydı geri al
  exception
    when others then
      if sqlerrm <> 'ROLLBACK_278' then
        raise exception '278: bildirim insert HALA PATLIYOR → %', sqlerrm;
      end if;
  end;
end $$;
