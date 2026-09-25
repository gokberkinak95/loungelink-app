-- ============================================================
-- LoungeLink · 161_venue_merge_and_catalog_truth.sql
-- DUPLICATE'İN ÜÇÜNCÜ VE SON KATMANI: KAYNAK TABLO
--
-- ⚠️ Uygulamayı ETKİLER (katalog + karar motoru).
--
-- ------------------------------------------------------------
-- 🔴 158 ve 160 YANLIŞ KATMANI TEMİZLİYORDU
-- ------------------------------------------------------------
-- 158: venue başına tek `lounges` kaydı bıraktı.
-- 160: `lounges` içinde isim mükerrerlerini pasife çekti.
-- İkisi de TÜREV tabloyu düzeltiyordu. Oysa mükerrerlik
-- KAYNAKTA: lounge_venues'ta IST'te "Turkish Airlines Lounge —
-- İç Hat" ÜÇ kez, "Dış Hat (Miles&Smiles)" İKİ kez kayıtlı
-- (imla varyantları: "Ic Hat" / "İç Hat", "Dis" / "Dış").
--
-- Bunun iki sonucu var ve ikincisi daha sinsi:
--   1. 158'in uzlaştırması her aktif venue için bir katalog
--      kaydı açtığından mükerrer venue → mükerrer liste satırı.
--      160 bunları pasife çeker ama BİR SONRAKİ uzlaştırmada
--      geri gelirler — kaynak hâlâ mükerrer.
--   2. KURALLAR VE KABULLER MÜKERRERLER ARASINDA DAĞILMIŞ:
--      bir venue'da 8, ötekinde 6 kabul satırı var. Host hangi
--      kopyayı seçtiyse KARAR O KOPYANIN verisinden çıkıyor —
--      aynı salon için iki farklı cevap üretilebiliyordu.
--      Kullanıcının gördüğü "çoklama" kozmetikti; bu değil.
--
-- ÇÖZÜM: kaynakta BİRLEŞTİRME. Her (havalimanı, normalize ad)
-- için bir HAYATTA KALAN seçilir; tüm bağlı kayıtlar ona
-- taşınır (kural, kabul, partner, saha raporu, katalog, İLAN);
-- kopyalar pasife çekilir. Kayıt silinmez — geçmiş referanslar
-- kırılmaz.
-- ============================================================

-- ---- 1) BİRLEŞTİRME ----
do $$
declare g record; keep uuid; dups uuid[]; n_merged int := 0; n_moved int := 0;
begin
  for g in
    select airport_code,
           lower(regexp_replace(translate(name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g')) as nm
      from lounge_venues where active
     group by 1,2 having count(*) > 1
  loop
    -- HAYATTA KALAN: en çok kabul satırı olan (en zengin veri),
    -- eşitlikte en çok kuralı olan, sonra en yeni kayıt.
    select v.id into keep
      from lounge_venues v
     where v.active and v.airport_code = g.airport_code
       and lower(regexp_replace(translate(v.name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g')) = g.nm
     order by (select count(*) from lounge_venue_acceptance a where a.venue_id = v.id and a.active) desc,
              (select count(*) from lounge_guest_rules r where r.venue_id = v.id) desc,
              v.id desc
     limit 1;

    select array_agg(v.id) into dups
      from lounge_venues v
     where v.active and v.airport_code = g.airport_code
       and lower(regexp_replace(translate(v.name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g')) = g.nm
       and v.id <> keep;

    -- Kabul satırları: hayatta kalanda O PROGRAM için satır yoksa taşı,
    -- varsa kopyayı bırak (çakışma yaratmadan zenginleştirme).
    update lounge_venue_acceptance a set venue_id = keep
     where a.venue_id = any(dups)
       and not exists (select 1 from lounge_venue_acceptance b
                        where b.venue_id = keep and b.program_id = a.program_id);
    get diagnostics n_moved = row_count;

    -- Kurallar: aynı mantık (program + kart tipi + taşıyıcı üçlüsü benzersiz kalsın)
    update lounge_guest_rules r set venue_id = keep
     where r.venue_id = any(dups)
       and not exists (select 1 from lounge_guest_rules s
                        where s.venue_id = keep and s.program_id = r.program_id
                          and s.card_tier is not distinct from r.card_tier
                          and s.carrier is not distinct from r.carrier);

    -- Partnerler, saha raporları, katalog kayıtları ve İLANLAR koşulsuz taşınır
    update lounge_venue_partners set venue_id = keep where venue_id = any(dups);
    update lounge_field_reports  set venue_id = keep where venue_id = any(dups);
    update lounges               set venue_id = keep where venue_id = any(dups);
    update availabilities        set venue_id = keep where venue_id = any(dups);

    -- 🔴 İLK KOŞUDA BEKÇİ YAKALADI: ilanların bir kısmı venue'ya
    -- venue_id/lounge_id ile DEĞİL, lounge_name METNİYLE bağlanıyor
    -- (resolve_venue_for_availability'nin son çaresi). Kopya pasife
    -- çekilince o metin hiçbir aktif venue'ya uymuyor ve karar
    -- "venue bilinmiyor"a düşüp program varsayılanına kaçıyordu —
    -- CLPL senaryosu bu yüzden included döndü. Metinle bağlı ilanlar
    -- da hayatta kalana taşınır.
    update availabilities a set venue_id = keep
     where a.venue_id is null
       and a.airport_code = g.airport_code
       and lower(regexp_replace(translate(coalesce(a.lounge_name,''),'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g')) = g.nm;

    -- İlanların katalog bağı da hayatta kalanın AKTİF kaydına taşınır
    update availabilities a set lounge_id = (
             select l.id from lounges l where l.venue_id = keep and l.active limit 1)
     where a.lounge_id in (select l2.id from lounges l2 where l2.venue_id = any(dups));

    -- Artık bağsız kalan kopyalar pasife. Adları ARŞİV işaretiyle
    -- benzersizleşir: (airport_code, name) üzerinde tekillik kısıtı var
    -- ve aşağıdaki imla düzeltmesi aktif adı kopyanınkine eşitleyip
    -- çakışma yaratıyordu (ilk koşuda uq_lounge_venue patladı).
    update lounge_venues
       set active = false,
           name = name || ' (birleştirildi ' || left(id::text, 8) || ')'
     where id = any(dups);
    n_merged := n_merged + coalesce(array_length(dups,1),0);
  end loop;
  raise notice '161: % mükerrer venue birleştirildi, % kabul satırı taşındı', n_merged, n_moved;
end $$;

-- ---- 2) KATALOĞU KAYNAKLA YENİDEN HİZALA ----
-- Birleştirme sonrası türev tablo tekrar uzlaştırılır (158'in mantığı,
-- bu kez tekilleşmiş kaynak üzerinde).
update lounges l set active = false
 where l.active and (l.venue_id is null
    or not exists (select 1 from lounge_venues v where v.id = l.venue_id and v.active));

with ranked as (
  select l.id, row_number() over (partition by l.venue_id order by l.id desc) rn
    from lounges l where l.active and l.venue_id is not null)
update lounges set active = false where id in (select id from ranked where rn > 1);

insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code, v.name,
       coalesce(v.terminal, case v.scope when 'domestic' then 'İç Hat'
                                         when 'international' then 'Dış Hat' end),
       true, v.id
  from lounge_venues v
 where v.active
   and not exists (select 1 from lounges l where l.venue_id = v.id and l.active);

-- Katalog adı kaynaktan tazelenir (imla varyantları tek yazıma iner)
update lounges l set name = v.name,
       terminal = coalesce(v.terminal, case v.scope when 'domestic' then 'İç Hat'
                                                    when 'international' then 'Dış Hat' end)
  from lounge_venues v
 where l.venue_id = v.id and l.active and v.active
   and (l.name is distinct from v.name);

-- ---- 3) BEKÇİLER: mükerrerlik KAYNAKTA da bitmiş olmalı ----
do $$
declare n int;
begin
  select count(*) into n from (
    select 1 from lounge_venues where active
     group by airport_code,
              lower(regexp_replace(translate(name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g'))
     having count(*) > 1) x;
  if n > 0 then raise exception '161: % venue mükerreri KAYNAKTA duruyor', n; end if;

  select count(*) into n from (
    select 1 from lounges where active
     group by airport_code,
              lower(regexp_replace(translate(name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g'))
     having count(*) > 1) x;
  if n > 0 then raise exception '161: % katalog mükerreri duruyor', n; end if;

  -- Aktif venue'su olan her salon katalogda görünmeli (host seçebilsin)
  select count(*) into n from lounge_venues v
   where v.active and not exists (select 1 from lounges l where l.venue_id = v.id and l.active);
  if n > 0 then raise exception '161: % aktif venue katalogda yok', n; end if;

  -- Pasife çekilen venue'ya bağlı AKTİF ilan kalmamalı (taşınmış olmalı)
  select count(*) into n from availabilities a
    join lounge_venues v on v.id = a.venue_id
   where a.active and not v.active;
  if n > 0 then raise exception '161: % aktif ilan pasif venue''ya bağlı', n; end if;
end $$;

-- ---- 4) İÇ/DIŞ HAT KAPSAMI: her Türkiye salonunda TANIMLI olmalı ----
-- App'in sekmeleri venue.scope'a dayanır; 'both' veya NULL kapsam
-- kullanıcıya "hangi sekmede?" sorusunu cevapsız bırakır. Terminal
-- adından türetilebilenler doldurulur; kalanlar RAPORLANIR (uydurulmaz).
update lounge_venues v set scope = 'domestic'
 where v.active and coalesce(v.scope,'') in ('','both')
   and v.name ~* '(İç Hat|Ic Hat|iç hatlar)';
update lounge_venues v set scope = 'international'
 where v.active and coalesce(v.scope,'') in ('','both')
   and v.name ~* '(Dış Hat|Dis Hat|dış hatlar)';

do $$
declare n int;
begin
  select count(*) into n from lounge_venues v
    join airports a on a.code = v.airport_code
   where v.active and coalesce(a.country,'TR') in ('TR','Türkiye','Turkiye','Turkey')
     and coalesce(v.scope,'') not in ('domestic','international');
  if n > 0 then
    raise notice '161 NOT: % Türkiye salonunda kapsam hâlâ belirsiz (both/NULL) — iç/dış sekmesinde "Tümü" altında görünür', n;
  end if;
end $$;

-- ---- 4b) 🔴 SÜRESİ DOLAN KURALIN AÇTIĞI DELİK (bugün patladı) ----
-- Bekçi 161'i durdurdu ve sebebi 161 DEĞİLDİ: 156, CLPL için
-- kapsamlı (domestic/international) satırları eklerken eski GENEL
-- satıra effective_to = 2026-08-12 koymuştu. O tarih DÜN geçti.
-- Bugünden itibaren: venue'su BİLİNMEYEN bir ilanda CLPL host için
-- hiçbir kural eşleşmiyor → çözümleyici "kural yok" diyor → karar
-- program varsayılanına düşüyor → "misafir hakkın var" (YANLIŞ).
-- Yani veri doğruydu, ömrü bitmişti. Kapsamlı satırlar venue
-- bilindiğinde çalışır; venue bilinmediğinde YEDEK ŞART.
--
-- CLPL her iki kapsamda da 0 misafir demek olduğundan, kapsamsız
-- yedek satır güvenlidir ve iki durumu da doğru anlatır.
insert into lounge_guest_rules
  (program_id, venue_id, venue_scope, card_tier, carrier, guest_allowance,
   family_allowed, paid_entry_allowed, notes)
select p.id, null, null, 'CLPL', 'TK', 0, false, true,
       'Classic Plus: iç hatta kendisi girer, misafir hakkı yoktur; dış hat salonlarında tanımlı giriş hakkı yoktur.'
  from lounge_programs p
 where p.code = 'TK_MS'
   and not exists (
     select 1 from lounge_guest_rules r
      where r.program_id = p.id and r.card_tier = 'CLPL'
        and r.venue_id is null and r.venue_scope is null
        and (r.effective_to is null or r.effective_to >= current_date));

-- 🔴 KALICI BEKÇİ: bir kart tipinin TÜM kuralları süre bitiminden
-- ötürü kapanmışsa sessizce program varsayılanına düşeriz. Bu sınıf
-- bir daha fark edilmeden geçmesin — kapsamsız geçerli yedeği olmayan
-- her (program, kart tipi) çifti migration'ı DURDURUR.
do $$
declare n int; d text;
begin
  select count(*), coalesce(string_agg(distinct card_tier, ', '), '')
    into n, d
    from (
      select r.program_id, r.card_tier
        from lounge_guest_rules r
       where r.card_tier is not null
       group by 1,2
      having bool_and(r.effective_to is not null and r.effective_to < current_date)
          or not bool_or(r.venue_id is null and r.venue_scope is null
                         and (r.effective_to is null or r.effective_to >= current_date))
    ) x;
  if n > 0 then
    raise notice '161 UYARI: kapsamsız geçerli yedeği olmayan kart tipleri: % (%)', d, n;
  end if;
end $$;

-- ---- 5) ÇÖZÜMLEYİCİNİN İSİM YEDEĞİ NORMALİZE OLUR ----
-- 🔴 Yukarıdaki hatanın ikinci yarısı: son çare isim eşleşmesi TAM
-- eşitlik arıyordu, yani "İç Hat" ile "Ic Hat" farklı sayılıyordu.
-- Türkçe imla varyantı bir ilanı sessizce venue'suz bırakıyordu.
-- Aynı normalizasyon burada da uygulanır.
-- sqlcheck: allow-replace resolve_venue_for_availability  (dönüş tipi AYNI)
create or replace function public.resolve_venue_for_availability(p_avail_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select coalesce(
           a.venue_id,
           (select l.venue_id from lounges l where l.id = a.lounge_id),
           (select v.id from lounge_venues v
             where v.airport_code = a.airport_code and v.active
               and lower(regexp_replace(translate(v.name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g'))
                 = lower(regexp_replace(translate(coalesce(a.lounge_name,''),'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g'))
             limit 1)
         )
    from availabilities a where a.id = p_avail_id;
$$;

-- ---- 6) KATALOG YALNIZ SALONLARDAN OLUŞUR ----
-- 🔴 venue_kind ZATEN ayırt ediyordu (spa/shower/sleep/lounge) ama
-- 158'in uzlaştırması bu ayrımı OKUMUYORDU: XpresSpa, iGA Shower ve
-- iGA Sleepod host'a "salon" diye listeleniyordu. Misafir ağırlanacak
-- yer duş kabini olamaz — katalog yalnız venue_kind='lounge' taşır.
update lounges l set active = false
  from lounge_venues v
 where l.venue_id = v.id and l.active and coalesce(v.venue_kind,'lounge') <> 'lounge';

-- İmla tek yazıma iner (kaynakta da): "Dis Hat" → "Dış Hat", "Ic Hat" → "İç Hat".
-- Kullanıcı aynı salonu iki farklı yazımla görmemeli.
--
-- 🔴 İKİNCİ ÇAKIŞMA (yine ilk koşuda yakalandı): tekillik kısıtı
-- aktif/pasif ayırmıyor. Birleştirmeye GİRMEYEN eski PASİF kayıtlar
-- (zaten kapatılmış imla varyantları) hedef adı işgal ediyordu.
-- Yeniden adlandırmadan ÖNCE, aktif bir adla çakışacak tüm pasif
-- kayıtlar arşiv işaretiyle benzersizleştirilir.
update lounge_venues d
   set name = d.name || ' (arşiv ' || left(d.id::text, 8) || ')'
 where not d.active
   and exists (
     select 1 from lounge_venues a
      where a.active and a.airport_code = d.airport_code
        and lower(regexp_replace(translate(a.name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g'))
          = lower(regexp_replace(translate(d.name,'İıŞşĞğÜüÖöÇç','IiSsGgUuOoCc'),'\s+',' ','g')));

update lounge_venues set name = regexp_replace(name, 'Dis Hat', 'Dış Hat', 'g') where active and name like '%Dis Hat%';
update lounge_venues set name = regexp_replace(name, 'Ic Hat',  'İç Hat',  'g') where active and name like '%Ic Hat%';
update lounge_venues set terminal = 'Dış Hat' where active and terminal in ('Dis Hat','Dis hat');
update lounge_venues set terminal = 'İç Hat'  where active and terminal in ('Ic Hat','Ic hat');
update lounges l set name = v.name, terminal = coalesce(v.terminal, l.terminal)
  from lounge_venues v
 where l.venue_id = v.id and l.active
   and (l.name is distinct from v.name or l.terminal is distinct from v.terminal);

do $$
declare n int;
begin
  select count(*) into n from lounges l join lounge_venues v on v.id = l.venue_id
   where l.active and coalesce(v.venue_kind,'lounge') <> 'lounge';
  if n > 0 then raise exception '161: katalogda % salon-olmayan tesis aktif', n; end if;
end $$;

select '161 OK - venue birlestirme + katalog hizalama + kapsam' as sonuc;
