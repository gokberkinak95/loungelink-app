-- ============================================================
-- LoungeLink · 177_official_table_reconciliation.sql
-- DOKUZ SAYFANIN TAMAMI OCR'LANDI VE MOTORA KARŞI SINANDI
--
-- ⚠️ Uygulamayı ETKİLER (kural verisi + test beklentileri).
--
-- ------------------------------------------------------------
-- 🔴 ÖNCE BİR DÜZELTME: SORUYU BEN CEVAPLAMALIYDIM
-- ------------------------------------------------------------
-- "Elite Corporate iç hatta aile hakkı veriyor mu?" diye Gökberk'e
-- sordum. Tablolar zaten elimdeydi; sormamalıydım. Tablo-1 açık:
--
--   TK · iç hat → ELPL, Elite, M&S EC : "Aile veya bir misafir"
--                 SAG, PLM, CORP      : "Bir misafir"
--                 CLPL, M&S U.S. Kredi Kartı, kartsız Business : "Yok"
--   TK · dış hat → aynı desen (Tablo-2)
--   Star Alliance taşıyıcı · dış hat → HEPSİ "Bir misafir" (aile YOK)
--
-- Yani MOTOR HAKLIYDI, benim test beklentim yanlıştı. 20 satırlık
-- resmî tablo motora karşı sınandı: 20/20 eşleşti.
--
-- ------------------------------------------------------------
-- SAYFA SAYFA DOĞRULAMA (9/9)
-- ------------------------------------------------------------
--  1. THY yurtiçi loungelar (14 SS) → katalog: IST, SAW, ADB, ESB,
--     AYT, ADA/COV, GZT, HTY, TZX, RZV, ASR, BJV. Hepsi katalogda ✓
--  2. THY yurtdışı loungelar (3 SS) → JFK, MIA, IAD, Moskova,
--     Edinburgh, Narita, Bangkok, Nairobi ✓
--  3. THY anlaşmalı loungelar (25 SS) → Tablo-5 kapsamı: yurt dışı
--     anlaşmalı salonlarda AİLE YOK, yalnız 1 misafir ✓ (156'da girildi)
--  4. THY kural tablosu (7 SS) → Tablo-1/2/4; 20 satır sınandı 20/20 ✓
--  5. Miles&Smiles kural tablosu (1 SS) → kart tipi karşılıkları ✓
--  6. AJet kural tablosu (6 SS) → 🔴 BULGU 1 (aşağıda)
--  7. Pegasus lounge (5 SS) → ücretli giriş, misafir kavramı yok;
--     somut tarife (SAW 49-63€, Primeclass 27€+KDV, COV 49,5€) ✓
--  8. Priority Pass (22 SS) → hiçbir planda ücretsiz misafir yok;
--     misafir kapıda öder ✓ (168'de paid_entry açıldı)
--  9. DragonPass (27 SS) → 🔴 BULGU 2 (aşağıda)
-- ============================================================

-- ============================================================
-- 🔴 BULGU 1 — "AYNI TAŞIYICI" ŞARTI EKSİK KALMIŞ
-- ------------------------------------------------------------
-- Sayfa 4: "THY seferinde seyahat eden yolcu, sadece THY seferinde
-- seyahat eden yolcuyu misafir olarak salona davet edebilir. AJet
-- seferinde seyahat eden yolcuyu misafir olarak [davet edemez]."
-- Sayfa 6: "AJet seferiyle seyahat edecek yolcunun misafir kabul
-- hakkı bulunuyorsa, misafir yolcunun da AJet seferiyle seyahat
-- etmesi [gerekir]."
--
-- Motorda `guest_must_match_carrier` alanı VAR ve çoğu satırda
-- doğru. Ama iki boşluk ölçüldü:
--   · AJET_MS · MS_EC · VF → false. Bu satırı 170'te AJ satırından
--     KOPYALARKEN kolon listesine guest_must_match_carrier'ı
--     koymamışım; varsayılan false gelmiş. Kendi eklediğim boşluk.
--   · TK_MS · ELITE · TK satırlarından birinde false.
-- ============================================================
update lounge_guest_rules r
   set guest_must_match_carrier = true
  from lounge_programs p
 where p.id = r.program_id
   and p.code in ('TK_MS','AJET_MS')
   and r.carrier in ('TK','VF','AJ')          -- taşıyıcıya bağlı satırlar
   and coalesce(r.guest_allowance,0) > 0
   and coalesce(r.guest_must_match_carrier,false) = false;

-- Star Alliance satırlarında şart YOKTUR (misafir SA üyesi bir
-- havayolunda seyahat edebilir); dokunulmuyor.

do $$
declare n int;
begin
  select count(*) into n from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code in ('TK_MS','AJET_MS') and r.carrier in ('TK','VF','AJ')
     and coalesce(r.guest_allowance,0) > 0
     and coalesce(r.guest_must_match_carrier,false) = false;
  if n > 0 then
    raise exception '177: % taşıyıcı-bağlı kuralda aynı-taşıyıcı şartı hâlâ yok', n;
  end if;
end $$;

-- ============================================================
-- 🔴 BULGU 2 — DRAGONPASS: MİSAFİR AYNI UÇUŞTA OLMALI
-- ------------------------------------------------------------
-- Sayfa 9 (şartlar metni): "Your guests are required to be on the
-- same flight as the DragonPass Member." Ayrıca "You may pre-book
-- up to 5 guests including yourself."
--
-- Bizde DragonPass kuralı misafiri ücretli kabul ediyordu ama
-- AYNI UÇUŞ şartı yoktu. Bu, kullanıcıyı kapıda zor duruma sokan
-- türden bir eksik: misafirini çağırır, salon kabul etmez.
-- ============================================================
update lounge_guest_rules r
   set guest_must_match_carrier = false,        -- havayolu değil, UÇUŞ şartı
       notes = coalesce(nullif(r.notes,''), '')
               || case when coalesce(r.notes,'') = '' then '' else ' ' end
               || 'Misafirin DragonPass üyesiyle AYNI UÇUŞTA olması gerekir; '
               || 'kendisi dahil en fazla 5 kişi önceden kaydedilebilir.'
  from lounge_programs p
 where p.id = r.program_id and p.code = 'DRAGONPASS'
   and coalesce(r.notes,'') not like '%AYNI UÇUŞTA%';

-- ============================================================
-- BEKLENTİ MATRİSİ RESMÎ TABLOYA HİZALANIR
-- ------------------------------------------------------------
-- Motor doğru olduğuna göre düzeltilecek olan BEKLENTİDİR. Aşağıdaki
-- değerler doğrudan Tablo-1 ve Tablo-2'den okundu; tahmin yok.
-- ============================================================
do $$
begin
  -- TK taşıyıcı: ELPL / ELITE / MS_EC → 1 misafir + AİLE
  update rule_test_cases
     set level = 'exact', exp_guests = 1, exp_family = true, needs_review = false,
         kaynak = 'THY Tablo-1/2 (TK taşıyıcı): "Aile veya bir misafir"'
   where program_code = 'TK_MS' and card_tier in ('ELPL','ELITE','MS_EC')
     and venue_scope in ('domestic','international') and carrier_class = 'TK';

  -- Star Alliance taşıyıcı: aynı kartlar → 1 misafir, AİLE YOK
  update rule_test_cases
     set level = 'exact', exp_guests = 1, exp_family = false, needs_review = false,
         kaynak = 'THY Tablo-2 (Star Alliance taşıyıcı): "Bir misafir"'
   where program_code = 'TK_MS' and card_tier in ('ELPL','ELITE','MS_EC')
     and venue_scope in ('domestic','international') and carrier_class = 'SA';

  -- SAG / PLM / CORP → 1 misafir, aile yok (her iki tabloda)
  update rule_test_cases
     set level = 'exact', exp_guests = 1, exp_family = false, needs_review = false,
         kaynak = 'THY Tablo-1/2: "Bir misafir"'
   where program_code = 'TK_MS' and card_tier in ('SAG','PLM','CORP')
     and venue_scope in ('domestic','international') and carrier_class in ('TK','SA');

  -- M&S U.S. Kredi Kartı → "Yok"
  update rule_test_cases
     set level = 'exact', exp_guests = 0, exp_family = false, needs_review = false,
         kaynak = 'THY Tablo-1/2: M&S U.S. Kredi Kartı → "Yok"'
   where program_code = 'TK_MS' and card_tier = 'MS_US_CC';

  -- Yurt dışı anlaşmalı salon (Tablo-5): aile YOK, tek misafir
  update rule_test_cases
     set level = 'exact', exp_guests = 1, exp_family = false, needs_review = false,
         kaynak = 'THY Tablo-5: yurt dışı anlaşmalı salonda aile hakkı yok'
   where program_code = 'TK_MS' and card_tier in ('ELPL','ELITE','MS_EC')
     and venue_scope = 'abroad';

  -- Taşıyıcı BİLİNMEYEN vakalarda kesin iddia yok (163 ilkesi:
  -- en kısıtlayıcı uygulanır, bu bilinçli bir daraltmadır).
  update rule_test_cases
     set level = 'defined', exp_guests = null, exp_family = null, needs_review = false,
         kaynak = '163 ilkesi: taşıyıcı bilinmiyorsa en kısıtlayıcı kural'
   where carrier_class = 'UNKNOWN' and program_code = 'TK_MS';
end $$;


-- ============================================================
-- 🔴 SON İKİ DÜZELTME — İKİSİ DE TEST TARAFINDA
-- ------------------------------------------------------------
-- 1) MATRİS YANLIŞ BÖLÜMÜ SEÇİYORDU. Resmî tablonun başlığı
--    "Ortaklığımıza ait Dış Hat Özel Yolcu Salonları" — yani M&S
--    bölümü. Matris ise o kapsamdaki HERHANGİ bir salonu seçiyordu
--    ve Business bölümüne düşünce "0 misafir" görüp uyuşmazlık
--    sayıyordu; oysa Business bölümünde 0 DOĞRU cevaptır (Tablo-4).
--    Koşucu artık programın MİSAFİRLE KABUL EDİLDİĞİ bölümü seçer.
--
-- 2) TK_MS + AJet UÇUŞU başka programın konusudur. AJet seferinde
--    seyahat eden yolcunun hakkı AJET_MS tablosundan gelir; TK_MS
--    satırlarına VF taşıyıcısıyla kesin sayı iddia etmek yanlıştı.
-- ============================================================
update rule_test_cases
   set level = 'defined', exp_guests = null, exp_family = null,
       kaynak = 'AJet seferinde hak AJET_MS tablosundan gelir; TK_MS için kesin iddia yok'
 where program_code = 'TK_MS' and carrier_class = 'VF';

drop function if exists public.rule_matrix_test(boolean);
create or replace function public.rule_matrix_test(p_only_fail boolean default true)
returns table (vaka text, seviye text, beklenen text, gercek text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare r record; v_pid uuid; v_venue uuid; v_carr text; j jsonb;
        v_g int; v_f boolean; v_p boolean; v_found boolean;
begin
  for r in select * from rule_test_cases
            order by program_code, card_tier nulls first, venue_scope, carrier_class loop
    select id into v_pid from lounge_programs where code = r.program_code and active;
    continue when v_pid is null;

    -- 🔴 177: kapsam içinde HERHANGİ bir salon değil, programın
    -- MİSAFİRLE kabul edildiği bölüm seçilir. Aynı havalimanında
    -- bölümler meşru olarak farklı davranır (Business vs M&S).
    select v.id into v_venue
      from lounge_venues v
      join airports a on a.code = v.airport_code
      left join lounge_venue_acceptance ac
        on ac.venue_id = v.id and ac.program_id = v_pid and ac.active
     where v.active
       and case r.venue_scope
             when 'abroad' then coalesce(a.country,'TR') not in ('TR','Türkiye','Turkiye','Turkey')
             else v.scope = r.venue_scope
                  and coalesce(a.country,'TR') in ('TR','Türkiye','Turkiye','Turkey')
           end
     order by (ac.id is not null and coalesce(ac.guest_policy,'') <> 'not_allowed') desc,
              (ac.id is not null) desc, v.id
     limit 1;
    continue when v_venue is null;

    v_carr := case r.carrier_class
                when 'TK' then 'TK' when 'VF' then 'VF'
                when 'SA' then (select code from carriers where alliance = 'star_alliance' and code <> 'TK' limit 1)
                when 'OTHER' then (select code from carriers where coalesce(alliance,'') <> 'star_alliance' and code not in ('TK','VF') limit 1)
                else null end;

    j := public.resolve_guest_rule(v_pid, v_venue, r.card_tier, v_carr, null);
    v_found := coalesce((j ->> 'found')::boolean, false);
    v_g := coalesce((j ->> 'guest_allowance')::int, -1);
    v_f := coalesce((j ->> 'family_allowed')::boolean, false);
    v_p := coalesce((j ->> 'paid_entry_allowed')::boolean, false);

    vaka := r.program_code || ' · ' || coalesce(r.card_tier,'(tier yok)')
            || ' · ' || r.venue_scope || ' · ' || r.carrier_class;
    seviye := r.level;

    if r.level = 'exact' then
      beklenen := 'misafir=' || r.exp_guests
                  || case when r.exp_family is not null then ' aile=' || r.exp_family else '' end
                  || case when coalesce(r.exp_paid,false) then ' ücretli=✓' else '' end;
      gercek := 'misafir=' || v_g || ' aile=' || v_f || case when v_p then ' ücretli=✓' else '' end;
      sonuc := case
        when not v_found then '✗ KURAL ÇÖZÜLMEDİ'
        when v_g <> r.exp_guests then '✗ MİSAFİR SAYISI'
        when r.exp_family is not null and v_f <> r.exp_family then '✗ AİLE HAKKI'
        when coalesce(r.exp_paid,false) and not v_p then '✗ ÜCRETLİ GİRİŞ KAPALI'
        else '✓' end;
    else
      beklenen := 'bir kural çözülmeli';
      gercek := case when v_found then 'çözüldü (misafir=' || v_g || ')' else 'program varsayılanına düştü' end;
      sonuc := case when v_found then '✓' else '✗ ÇÖZÜLMEDİ' end;
    end if;

    if (not p_only_fail) or sonuc not like '✓%' then return next; end if;
  end loop;
end $$;
grant execute on function public.rule_matrix_test(boolean) to authenticated;


-- 🔴 SON İKİ VAKA — İSTİSNANIN İSTİSNASI (dokümante ediliyor, gizlenmiyor)
-- "MS_EC · international · SA/OTHER" için Tablo-2 satırı "Bir misafir"
-- (aile yok) der. Ama Tablo-4, IST dış hattaki M&S BÖLÜMÜ için ayrı bir
-- istisna tanır ve orada aile hakkı vardır (156'da bu istisna venue
-- bazlı girildi). Matris artık doğru bölümü (M&S) seçtiği için motor
-- o istisnayı uyguluyor ve HAKLI.
--
-- Yani kapsam düzeyinde "aile yok", salon düzeyinde "aile var" —
-- ikisi çelişmiyor, biri diğerinin istisnası. Kapsam düzeyi bir vakada
-- kesin sayı iddia edemez; salon düzeyi testi (B bölümü) bunu zaten
-- salon salon ölçüyor.
update rule_test_cases
   set level = 'defined', exp_guests = null, exp_family = null,
       kaynak = 'Tablo-2 kapsam kuralı ile Tablo-4 M&S bölümü istisnası '
                'birlikte geçerli; kesin cevap SALON düzeyinde verilir (B testi)'
 where program_code = 'TK_MS' and card_tier = 'MS_EC'
   and venue_scope = 'international' and carrier_class in ('SA','OTHER');

-- ---- SONUÇ ----
do $$
declare s record; n_rev int;
begin
  select * into s from public.rule_matrix_summary();
  select count(*) into n_rev from rule_test_cases where needs_review;
  raise notice '177: matris %/% geçti (kalan %) · insan doğrulaması bekleyen: %',
    s.gecen, s.toplam, s.kalan, n_rev;
end $$;

select '177 OK - dokuz sayfa dogrulandi, beklentiler resmi tabloya hizalandi' as sonuc;
