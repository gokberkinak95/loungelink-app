-- ============================================================
-- LoungeLink · 168_carrier_gap_and_paid_entry.sql
-- 480 VAKALIK MATRİSİN BULDUĞU ÜÇ GERÇEK HATA
--
-- ⚠️ Uygulamayı ETKİLER (karar motoru + kural verisi).
--
-- 167'nin beklenti matrisi ilk koşusunda 480 vakanın 211'inde
-- uyuşmazlık buldu. Sınıflandırınca üç kök çıktı — üçü de
-- "17 senaryo yeterli" dediğim sürece görünmeyecek şeylerdi.
-- ============================================================

-- ============================================================
-- 🔴 1) TAŞIYICI DELİĞİ: KURAL VAR AMA BU HAVAYOLU İÇİN YOK
-- ------------------------------------------------------------
-- Classic ve Classic Plus kurallarının HEPSİ taşıyıcıya bağlı
-- (TK / VF / AJ). Bir Classic üyesi başka bir havayoluyla uçan
-- bir ilana bakınca hiçbir kural eşleşmiyor ve karar PROGRAM
-- VARSAYILANINA düşüyor → "1 misafir hakkın var" (YANLIŞ:
-- Classic'in hiçbir koşulda misafir hakkı yoktur).
--
-- Bu, 163'te kapattığım deliğin kardeşi. Orada taşıyıcı BİLİNMİYORDU;
-- burada BİLİNİYOR ama o taşıyıcı için kural yazılmamış. İkisinde de
-- yanlış olan aynı şey: eşleşme bulunamayınca EN CÖMERT cevaba
-- düşmek. Motorun üçüncü geçişi de aynı ilkeyi uygular.
-- ============================================================

-- sqlcheck: allow-replace resolve_guest_rule  (dönüş tipi AYNI — jsonb)
do $$
declare v_src text;
begin
  select prosrc into v_src from pg_proc
   where proname='resolve_guest_rule' and pronamespace='public'::regnamespace limit 1;
  if v_src is null then raise exception '168: resolve_guest_rule yok'; end if;
  if position('ÜÇÜNCÜ GEÇİŞ' in v_src) > 0 then
    raise notice '168: üçüncü geçiş zaten var';
  end if;
end $$;

-- Üçüncü geçiş, İKİNCİ geçişin hemen ardına eklenir. İkinci geçiş
-- tier'ı gevşetiyordu; üçüncüsü TAŞIYICIYI gevşetir ve yine EN
-- KISITLAYICIYI seçer.
do $$
declare v_src text; v_new text;
begin
  select prosrc into v_src from pg_proc
   where proname='resolve_guest_rule' and pronamespace='public'::regnamespace limit 1;

  if position('ÜÇÜNCÜ GEÇİŞ' in v_src) > 0 then return; end if;

  v_new := replace(v_src,
'  if not found then
    return jsonb_build_object(
      ''found'', false, ''program'', p.name,',
'  -- 🔴 ÜÇÜNCÜ GEÇİŞ (168): taşıyıcı BİLİNİYOR ama o taşıyıcı için
  -- kural yazılmamış. Örnek: Classic üyesi, kuralları yalnız TK/VF
  -- için tanımlı, ilan başka bir havayolunda. Eşleşme yoksa program
  -- varsayılanına düşmek = en cömert cevabı vermek. Bunun yerine
  -- taşıyıcıyı yok sayıp aynı kart tipinin EN KISITLAYICI kuralını
  -- uygularız ve cevabı "kesin değil" diye işaretleriz.
  if not found and p_tier is not null then
    select * into r from lounge_guest_rules x
     where x.program_id = p_program_id
       and (x.venue_id is null or x.venue_id = p_venue_id)
       and (x.venue_scope is null or x.venue_scope = v_scope)
       and x.card_tier = p_tier
       and (x.cabin_class is null or x.cabin_class = p_cabin)
       and (x.effective_to is null or x.effective_to >= current_date)
     order by coalesce(x.venue_id = p_venue_id, false) desc,
              coalesce(x.guest_allowance, 0),
              (case when coalesce(x.family_allowed,false) then 1 else 0 end),
              x.created_at desc
     limit 1;
    if found then v_unknown := true; end if;
  end if;

  if not found then
    return jsonb_build_object(
      ''found'', false, ''program'', p.name,');

  if v_new = v_src then
    raise exception '168: üçüncü geçiş eklenemedi — gövde kalıbı değişmiş, ELLE bakılmalı';
  end if;

  execute 'create or replace function public.resolve_guest_rule('
       || pg_get_function_arguments((select oid from pg_proc
            where proname='resolve_guest_rule' and pronamespace='public'::regnamespace limit 1))
       || ') returns jsonb language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '168: resolve_guest_rule üçüncü geçişle güncellendi';
end $$;

-- ---- 1b) TABAN KURAL: Classic/CLPL hiçbir koşulda misafir almaz ----
-- Motor düzeltmesi deliği kapatır ama VERİ de açık konuşmalı:
-- taşıyıcıdan bağımsız bir taban satır, niyeti belgeler.
insert into lounge_guest_rules
  (program_id, venue_id, venue_scope, card_tier, carrier,
   guest_allowance, family_allowed, paid_entry_allowed, notes)
select p.id, null, null, t.tier, null, 0, false,
       (p.code = 'TK_MS' and t.tier = 'CLPL'),   -- CLPL iç hatta kendisi girer
       'Bu kart tipinin hiçbir taşıyıcıda ve hiçbir kapsamda misafir hakkı yoktur.'
  from lounge_programs p
  cross join (values ('CLASSIC'),('CLPL')) as t(tier)
 where p.code in ('TK_MS','AJET_MS')
   and not exists (
     select 1 from lounge_guest_rules r
      where r.program_id = p.id and r.card_tier = t.tier
        and r.carrier is null and r.venue_id is null and r.venue_scope is null);

-- ============================================================
-- 🔴 2) ÜCRETLİ GİRİŞ BAYRAĞI: 90 VAKA "YASAK" DİYORDU
-- ------------------------------------------------------------
-- Priority Pass ve DragonPass kurallarında misafir sayısı doğru
-- (0 — hiçbir planda ücretsiz misafir yok) ama paid_entry_allowed
-- işaretlenmemişti. Sonuç: motor "misafir alamazsın" diyordu, oysa
-- doğrusu "misafirin de girebilir, kapıda 30€/36€ öder".
-- 164'te operatör salonları için yaptığım ayrımın kart ağlarında
-- yapılmamış hali. Kullanıcı için fark büyük: biri kapıyı kapatır,
-- öteki fiyat söyler.
-- ============================================================
update lounge_guest_rules r
   set paid_entry_allowed = true,
       notes = coalesce(nullif(r.notes,''), '')
               || case when coalesce(r.notes,'') = '' then '' else ' ' end
               || 'Misafir ücretsiz DAHİL değildir; kapıda tarife üzerinden girer.'
  from lounge_programs p
 where p.id = r.program_id
   and p.code in ('PRIORITY_PASS','DRAGONPASS','LOUNGEKEY','DREAMFOLKS','PGS_PAID','IGA_PASS','HIGHPASS','LOUNGEME')
   and coalesce(r.paid_entry_allowed, false) = false
   and coalesce(r.guest_allowance, 0) = 0;

-- ============================================================
-- 🔴 3) SALON İSTİSNASI KART TİPİNİ AŞIYORDU
-- ------------------------------------------------------------
-- IST dış hat M&S bölümünün "aile var" istisnası (Tablo-4) tier
-- YAZILMADAN girilmiş satırlar üzerinden CLASSIC'e de uygulanıyordu:
-- matris "CLASSIC · domestic · SA → misafir=1 aile=true" yakaladı.
-- Bir salon istisnası ancak İSTİSNANIN TANINDIĞI kart tipleri için
-- geçerlidir; tier'ı boş bir venue satırı herkesi kapsar.
-- ============================================================
do $$
declare n int;
begin
  -- Tier'ı boş OLAN ve aile hakkı VEREN venue-spesifik satırları
  -- yalnız hak sahibi tier'lara kopyalayıp genel satırı daraltıyoruz.
  insert into lounge_guest_rules
    (program_id, venue_id, venue_scope, card_tier, carrier,
     guest_allowance, family_allowed, paid_entry_allowed, notes)
  select r.program_id, r.venue_id, r.venue_scope, t.tier, r.carrier,
         r.guest_allowance, r.family_allowed, r.paid_entry_allowed,
         coalesce(r.notes,'') || ' (168: istisna yalnız bu kart tipleri için)'
    from lounge_guest_rules r
    cross join (values ('ELPL'),('ELITE'),('MS_EC')) as t(tier)
   where r.venue_id is not null and r.card_tier is null
     and coalesce(r.family_allowed,false)
     and not exists (select 1 from lounge_guest_rules x
                      where x.program_id = r.program_id and x.venue_id = r.venue_id
                        and x.card_tier = t.tier
                        and x.carrier is not distinct from r.carrier);
  get diagnostics n = row_count;

  -- Genel (tier'sız) istisna satırından aile hakkı KALDIRILIR:
  -- artık hak sahibi tier'ların kendi satırı var.
  update lounge_guest_rules r
     set family_allowed = false,
         notes = coalesce(r.notes,'') || ' (168: aile hakkı tier bazlı satırlara taşındı)'
   where r.venue_id is not null and r.card_tier is null and coalesce(r.family_allowed,false);

  raise notice '168: % tier-bazlı istisna satırı üretildi', n;
end $$;

-- ---- DOĞRULAMA: matris ne kadar düzeldi? ----
do $$
declare s record;
begin
  select * into s from public.rule_matrix_summary();
  raise notice '168 SONRASI MATRİS: %/% geçti (kalan %)', s.gecen, s.toplam, s.kalan;
  if s.kalan > s.toplam / 2 then
    raise exception '168: matrisin yarısından fazlası hâlâ kırmızı (% / %)', s.kalan, s.toplam;
  end if;
end $$;

select '168 OK - tasiyici deligi + ucretli giris + salon istisnasi' as sonuc;
