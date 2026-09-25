-- ============================================================================
-- 270c — KARAR: sızıntı var mı, yok mu?   (SALT OKUNUR · TABLO DÖNDÜRÜR)
--
-- 🔴 ÜÇÜNCÜ KEZ AYNI HATA
-- Belirleyici cevabı yine `raise notice` içine koymuşum. Supabase onu
-- ayrı bir "Messages" panelinde gösteriyor; sen sonuç sekmesine bakıyorsun
-- ve orada YOK. Bunu 000'da fark edip düzeltmiştim, sonra 270a'da,
-- şimdi 270b'de tekrar yaptım.
--
-- Bir kere yapmak dikkatsizlik, üç kere yapmak alışkanlıktır. Kural
-- basit ve istisnasız: BU PROJEDE HER SQL DOSYASI CEVABINI TABLOYLA
-- VERİR. `raise notice` yalnızca ek bilgi içindir, asla karar için değil.
--
-- 🆕 SINIF: "BİR ÇIKTI KANALI KULLANICIYA GÖRÜNMÜYORSA, O KANALA YAZILAN
-- HER ŞEY YAZILMAMIŞ SAYILIR — VE AYNI HATAYI ÜÇÜNCÜ KEZ YAPIYORSAN
-- SORUN UNUTKANLIK DEĞİL, KURALIN YAZILI OLMAMASIDIR."
--
-- ----------------------------------------------------------------------------
-- ELDEKİ KANIT (270b §2)
--     tarih ✓ : false    ← geçmiş tarihli
--     aktif ✓ : false    ← İLAN AKTİF DEĞİL
--     staff değil ✓ : false
--     is_visible ✓ : false
--
-- Dört kapının dördü de "hayır" diyor. Aktif olmayan, tarihi geçmiş bir
-- ilan `discover_availabilities`ten çıkamaz. Bu dosya onu KANITLIYOR.
-- ============================================================================

do $k270c$
declare
  v_normal uuid; v_eski text; v_id uuid;
  v_gorunuyor boolean;
  v_toplam_test int; v_toplam_gercek int;
begin
  drop table if exists _270c;
  create temp table _270c(
    sira int, soru text, cevap text, karar text);

  v_eski := current_setting('request.jwt.claims', true);

  select id into v_normal from users u
   where u.deleted_at is null and not coalesce(u.is_staff,false)
     and not exists (select 1 from availabilities a where a.host_id=u.id and a.active)
   limit 1;

  if v_normal is null then
    insert into _270c values (0, 'Örnek normal kullanıcı', 'YOK',
      '⚠️ staff olmayan hesap yok — normal bakış denenemedi');
    return;
  end if;

  insert into _270c values (0, 'Bakan kişi (staff DEĞİL)',
    (select email from users where id = v_normal), '—');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_normal::text)::text, true);

  -- Şüpheli dört ilan, tek tek
  for v_id in select unnest(array[
      '8ea6c495-a7cb-4ce0-abe5-a4aecaaa853b',
      'd770cc1a-e652-4fed-a967-a413bbbd6629',
      '8bf70984-0368-4236-b230-a4d3e2b72d05',
      '197a86aa-6c31-4b46-883b-cd9c6f6a3536']::uuid[])
  loop
    select exists (select 1 from public.discover_availabilities() d where d.id = v_id)
      into v_gorunuyor;
    insert into _270c values (1,
      'Şüpheli ilan ' || left(v_id::text, 8),
      case when v_gorunuyor then 'GÖRÜNÜYOR' else 'görünmüyor' end,
      case when v_gorunuyor then '🔴 gerçek sızıntı' else '✅ sızmıyor' end);
  end loop;

  -- Genel sayım
  select count(*) into v_toplam_test from public.discover_availabilities() d
    join users hu on hu.id=d.host_id where coalesce(hu.is_staff,false);
  select count(*) into v_toplam_gercek from public.discover_availabilities() d
    join users hu on hu.id=d.host_id where not coalesce(hu.is_staff,false);

  insert into _270c values (2, 'Normal kullanıcıya görünen TEST ilanı',
    v_toplam_test::text,
    case when v_toplam_test = 0 then '✅ sızıntı yok'
         else '🔴 ' || v_toplam_test || ' test ilanı sızıyor' end);

  insert into _270c values (3, 'Normal kullanıcıya görünen GERÇEK ilan',
    v_toplam_gercek::text,
    case when v_toplam_gercek = 0 then '⚠️ Keşfet boş'
         else '✅ ürün ayakta' end);

  perform set_config('request.jwt.claims', coalesce(v_eski,''), true);
end $k270c$;

select sira as "#", soru as "soru", cevap as "cevap", karar as "karar"
  from _270c order by sira, soru;
