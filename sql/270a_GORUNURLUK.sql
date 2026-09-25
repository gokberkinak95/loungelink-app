-- ============================================================================
-- 270a — GÖRÜNÜRLÜK TEŞHİSİ: KİM NEYİ GÖRÜYOR?   (SALT OKUNUR)
--
-- 🔴 NEDEN AYRI DOSYA
-- Bu kontrol 270'in içindeyken `raise exception` ile duruyordu ve tüm
-- dosyayı geri alıyordu — yani bir TEŞHİS, bir DÜZELTMEYİ iptal ediyordu.
-- Artık ayrı ve hiçbir şeyi değiştirmiyor.
--
-- 🔴 VE SAYI YERİNE KAYIT DÖNDÜRÜYOR
-- Önceki nöbetçi "4 adet staff ilani goruyor" diyordu. Bir sayı, sebebi
-- söylemez. Bu dosya SIZAN SATIRLARI ADIYLA veriyor: hangi ilan, hangi
-- host, hangi bayrak. Sebep ancak kayda bakınca görünür.
--
-- 🆕 SINIF: "BİR İHLALİ SAYIYLA RAPORLAMAK, ONU ARAŞTIRILAMAZ KILAR —
-- KAÇ TANE OLDUĞU DEĞİL, HANGİLERİ OLDUĞU DÜZELTİLEBİLİR BİLGİDİR."
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════
-- §1 — ÖZET: iki bakış açısı
-- ════════════════════════════════════════════════════════════════════════
do $g270a$
declare
  v_staff uuid; v_normal uuid; v_s int; v_n int; v_g int; v_eski text;
  r record;
begin
  v_eski := current_setting('request.jwt.claims', true);

  select id into v_staff  from users where is_staff and deleted_at is null limit 1;
  select id into v_normal from users u
   where u.deleted_at is null and not coalesce(u.is_staff,false)
     and not exists (select 1 from availabilities a where a.host_id=u.id and a.active)
   limit 1;

  if v_staff is null then
    raise notice '270a: STAFF HESABI YOK — fiksturu kimse goremez.';
    raise notice '  Cozum: update users set is_staff = true where email = ''<senin-hesabin>'';';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', v_staff::text)::text, true);
    select count(*) into v_s from public.discover_availabilities() d
      join users hu on hu.id=d.host_id where coalesce(hu.is_staff,false);
    raise notice '270a: STAFF bakinca gorunen TEST ilani: %', v_s;
  end if;

  if v_normal is null then
    raise notice '270a: staff olmayan ornek kullanici yok — normal bakis denenemedi.';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', v_normal::text)::text, true);
    select count(*) into v_n from public.discover_availabilities() d
      join users hu on hu.id=d.host_id where coalesce(hu.is_staff,false);
    select count(*) into v_g from public.discover_availabilities() d
      join users hu on hu.id=d.host_id where not coalesce(hu.is_staff,false);
    raise notice '270a: NORMAL bakinca — TEST ilani: %  ·  GERCEK ilan: %', v_n, v_g;

    if v_n > 0 then
      raise warning '270a: ⚠ % test ilani normal kullaniciya sizyor. Detay asagidaki tabloda.', v_n;
    else
      raise notice '270a: ✓ test ilani normal kullaniciya sizmiyor.';
    end if;
  end if;

  perform set_config('request.jwt.claims', coalesce(v_eski,''), true);
end $g270a$;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — SIZAN SATIRLAR: hangi ilan, hangi host, NEDEN geçiyor
--
-- Sızıntının sebebi genelde bayraklardan birinin beklenenden farklı
-- olmasıdır. Tabloda hepsi yan yana: `is_staff`, `shadow_limited`,
-- `is_visible()` sonucu, onaylı host başvurusu, görünürlük.
-- ════════════════════════════════════════════════════════════════════════
do $t270a$
declare v_normal uuid; v_eski text;
begin
  v_eski := current_setting('request.jwt.claims', true);
  select id into v_normal from users u
   where u.deleted_at is null and not coalesce(u.is_staff,false)
     and not exists (select 1 from availabilities a where a.host_id=u.id and a.active)
   limit 1;
  perform set_config('request.jwt.claims',
    json_build_object('sub', coalesce(v_normal::text,''))::text, true);

  -- ⚠️ `on commit drop` DEĞİL: Supabase SQL Editor her ifadeyi kendi
  -- işleminde çalıştırır, tablo bir sonraki SELECT'e kalmaz. Önce düşür,
  -- sonra kur.
  drop table if exists _sizan;
  create temp table _sizan as
  select d.id as avail_id, d.host_id, d.airport_code, d.avail_date
    from public.discover_availabilities() d
    join users hu on hu.id = d.host_id
   where coalesce(hu.is_staff,false);

  perform set_config('request.jwt.claims', coalesce(v_eski,''), true);
end $t270a$;

select
  u.email                                                as "host",
  u.role                                                 as "rol",
  u.is_staff                                             as "is_staff",
  coalesce(u.shadow_limited,false)                       as "gölge kısıt",
  public.is_visible(u.id)                                as "is_visible()",
  exists (select 1 from host_applications ha
           where ha.user_id = u.id and ha.status='approved')  as "onaylı başvuru",
  s.airport_code                                         as "havalimanı",
  s.avail_date                                           as "tarih",
  s.avail_id                                             as "ilan id"
from _sizan s
join users u on u.id = s.host_id
order by u.email, s.avail_date;
