-- ============================================================================
-- 273 — SEED VERİSİ TEST İÇİN YETERLİ Mİ?   (SALT OKUNUR · TABLO DÖNDÜRÜR)
--
-- 🔴 GÖKBERK: "Kapsamlı bir app testi yapabilmek için kapsamlı userlar ve
--    datalar lazım (başvurulabilir / başvurulamaz / host'a sor gibi ilanlar
--    vs, tüm kural tabloları)."
--
-- Bu dosya soruyu ÖLÇÜYOR: bir STAFF hesabıyla Keşfet'i açtığında kural
-- motorunun kaç farklı çıktısını GERÇEKTEN görüyorsun?
--
-- ⚠️ Bakış açısı STAFF. 269c2 test hesaplarını gerçek kullanıcılardan
-- gizledi; 270 §1 onları staff'e geri açtı. Yani fikstür yalnız senin
-- gözünde var — doğrusu da bu.
--
-- 🆕 SINIF: "TEST VERİSİNİN VARLIĞI YETMEZ — TEST EDEN KİŞİNİN GÖZÜNDEN
-- KAÇ FARKLI DURUM GÖRÜNDÜĞÜ ÖLÇÜLMELİDİR; KAPSAM, SATIR SAYISI DEĞİL
-- DURUM ÇEŞİTLİLİĞİDİR."
-- ============================================================================

do $k273$
declare
  v_staff uuid; v_eski text;
begin
  drop table if exists _273;
  create temp table _273(sira numeric, bolum text, olcut text, deger text, karar text);

  v_eski := current_setting('request.jwt.claims', true);
  select id into v_staff from users where is_staff and deleted_at is null limit 1;

  if v_staff is null then
    insert into _273 values (0,'KURULUM','Staff hesabı','YOK',
      '🔴 update users set is_staff=true where email=''<senin hesabın>'';');
    return;
  end if;
  insert into _273 values (0,'KURULUM','Bakan (staff)',
    (select email from users where id=v_staff), '—');

  perform set_config('request.jwt.claims', json_build_object('sub', v_staff::text)::text, true);

  -- 1) KEŞFET'TE KAÇ İLAN GÖRÜNÜYOR
  insert into _273
  select 1,'KEŞFET','Görünen ilan', count(*)::text,
         case when count(*) = 0 then '🔴 hiç ilan yok — test_verisi_tazele() çalıştır'
              when count(*) < 10 then '⚠️ az — tazeleme gerekebilir'
              else '✅ yeterli' end
    from public.discover_availabilities();

  -- 2) KURAL MOTORU ÇIKTILARI — asıl kapsam ölçüsü
  insert into _273
  select 2, 'KURAL ÇIKTISI',
         case guest_policy
           when 'included'    then 'Ücretsiz misafir (başvurulabilir)'
           when 'paid'        then 'Ücretli misafir (başvurulabilir)'
           when 'not_allowed' then 'Misafir kabul edilmiyor'
           when 'unknown'     then 'Kural bilinmiyor (host''a sor)'
           else guest_policy end,
         count(*)::text,
         case when count(*) = 0 then '🔴 bu senaryo test edilemez' else '✅' end
    from public.discover_availabilities()
   group by guest_policy;

  -- 3) BAŞVURU ENGELİ OLAN İLANLAR
  insert into _273
  select 3,'ENGEL', coalesce(block_reason,'engel yok'), count(*)::text, '✅'
    from public.discover_availabilities() group by coalesce(block_reason,'engel yok');

  -- 4) EKSİK SENARYOLAR — hangi çıktı HİÇ YOK
  insert into _273
  select 4,'EKSİK SENARYO', x.ad, '0', '🔴 fikstürde yok'
    from (values ('included'),('paid'),('not_allowed'),('unknown')) x(ad)
   where not exists (select 1 from public.discover_availabilities() d
                      where d.guest_policy = x.ad);

  perform set_config('request.jwt.claims', coalesce(v_eski,''), true);

  -- 5) KURAL TABLOLARI (bakış açısından bağımsız)
  insert into _273 values
    (5,'KURAL TABLOSU','lounge_programs',   (select count(*)::text from lounge_programs),   ''),
    (5,'KURAL TABLOSU','lounge_venues',     (select count(*)::text from lounge_venues),     ''),
    (5,'KURAL TABLOSU','lounge_card_products',(select count(*)::text from lounge_card_products),''),
    (5,'KURAL TABLOSU','carriers',          (select count(*)::text from carriers),          ''),
    (5,'KURAL TABLOSU','rule_test_cases',   (select count(*)::text from rule_test_cases),   ''),
    (5,'KURAL TABLOSU','rule_venue_cases',  (select count(*)::text from rule_venue_cases),  '');
  update _273 set karar = case when deger::int = 0 then '🔴 BOŞ' else '✅ dolu' end
   where bolum = 'KURAL TABLOSU';

  -- 6) TEST HESAPLARI VE VERİSİ
  insert into _273 values
    (6,'TEST VERİSİ','Test hesabı',
       (select count(*)::text from users u where u.deleted_at is null
         and (u.email like '%@seed.loungelink.test' or u.email like '%@vitrin.loungelink.test'
           or u.email like '%@e2e.test')), ''),
    (6,'TEST VERİSİ','Bunlardan host',
       (select count(*)::text from users u where u.deleted_at is null and u.role='host'
         and (u.email like '%@seed.loungelink.test' or u.email like '%@vitrin.loungelink.test'
           or u.email like '%@e2e.test')), ''),
    (6,'TEST VERİSİ','Yayına uygun fikstür ilanı',
       (select count(*)::text from availabilities a join users u on u.id=a.host_id
         where a.active and a.avail_date >= current_date
           and (u.email like '%@seed.loungelink.test' or u.email like '%@vitrin.loungelink.test'
             or u.email like '%@e2e.test')), ''),
    (6,'TEST VERİSİ','TARİHİ GEÇMİŞ fikstür ilanı',
       (select count(*)::text from availabilities a join users u on u.id=a.host_id
         where a.active and a.avail_date < current_date
           and (u.email like '%@seed.loungelink.test' or u.email like '%@vitrin.loungelink.test'
             or u.email like '%@e2e.test')), ''),
    (6,'TEST VERİSİ','Fikstür seyahati (misafir uçuşu)',
       (select count(*)::text from visits v join users u on u.id=v.user_id
         where v.visit_date >= current_date
           and (u.email like '%@seed.loungelink.test' or u.email like '%@e2e.test')), '');
  update _273 set karar = case
      when olcut = 'TARİHİ GEÇMİŞ fikstür ilanı' and deger::int > 0
        then '⚠️ test_verisi_tazele() çalıştır'
      when deger::int = 0 then '🔴 yok'
      else '✅' end
   where bolum = 'TEST VERİSİ';
end $k273$;

select sira as "#", bolum as "bölüm", olcut as "ölçüt",
       deger as "değer", karar as "durum"
  from _273 order by sira, olcut;
