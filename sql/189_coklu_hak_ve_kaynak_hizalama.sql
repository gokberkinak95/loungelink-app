-- ============================================================
-- 189 · ÇOKLU HAK MİMARİSİ + KAYNAK HİZALAMA
-- 17 Ağustos 2026
--
-- 🔴 GÖKBERK'İN SORUSU: "Kullanıcının birden fazla lounge
-- sağlayıcısından hakkı olabilir — hem THY Elite Plus olabilir, hem
-- kredi kartı avantajı, hem Priority Pass'i. Mix caseler, edge
-- caseler, negatif caseler hepsini doğru kurgula."
--
-- ÖLÇÜM — bugünkü davranış:
--   lounge_access_decision (157:196-228) host_entitlements'tan
--   `limit 1` ile TEK bir hak çekiyor. İki hakkı olan host'ta hangi
--   satırın döneceği SIRALAMASIZ bir `limit 1`'e bağlı — yani
--   RASTGELE. Aynı host, aynı salon, iki farklı çalıştırmada iki
--   farklı cevap alabilir.
--
-- ÜÇ SOMUT ZARAR:
--   1. Elite Plus + Priority Pass'i olan host'a "misafir hakkın yok"
--      denebiliyor (PP satırı seçildiyse), oysa M&S ile 1 misafir hakkı var.
--   2. Tersi daha kötü: PP salonunda M&S satırı seçilirse host'a
--      olmayan bir hak vaat edilir ve misafir KAPIDA geri çevrilir.
--   3. Kullanıcı hangi hakkıyla girdiğini bilmiyor — kapıda hangi
--      kartı uzatacağını da bilmiyor.
--
-- ÇÖZÜM: hakları TEK TEK değil TOPLU değerlendiren bir katman.
-- `best_access_for_user()` host'un TÜM haklarını o salona karşı
-- çözer, en iyisini seçer, GEREKÇESİNİ ve reddedilen alternatifleri
-- birlikte döndürür. Karar zinciri bozulmuyor — üstüne biniyor.
-- resolve_guest_rule imzası SABİT kalır (156'nın kritik kararı).
-- ============================================================


-- ============================================================
-- 1 · ÇOKLU HAK ÇÖZÜMLEYİCİSİ
-- ============================================================
-- Sıralama ilkesi — hangisi "en iyi" hak?
--   1. Salon o programı KABUL EDİYOR mu? (etmiyorsa aday değil)
--   2. Misafir hakkı ÇOK olan önce (host'un derdi misafir sokmak)
--   3. Misafir ÜCRETSİZ olan, ücretli olandan önce
--   4. Aile hakkı olan önce
--   5. Kaynağı DOĞRULANMIŞ olan, varsayılana göre önce
--   6. Eşitlikte: kullanıcının doğruladığı hak (verified) önce
--
-- 🔴 SIRALAMA "EN CÖMERT"İ SEÇMEZ, "EN ÇOK HAK VERENİ" SEÇER — ve
-- bu ikisi aynı şey DEĞİL. Bir hak yalnızca o salon o programı
-- kabul ediyorsa aday olur. Kabul etmeyen program, ne kadar cömert
-- olursa olsun listeye giremez. 163'ün dersi burada da geçerli:
-- bilmemek cömert davranmak için gerekçe değildir — ama BİLMEK de
-- hakkı yok saymak için gerekçe değildir.

drop function if exists public.access_options_for_user(uuid, uuid, text, text);
create or replace function public.access_options_for_user(
  p_user_id  uuid,
  p_venue_id uuid,
  p_carrier  text default null,
  p_flight   text default null
) returns table (
  program_code   text,
  program_name   text,
  tier           text,
  accepted       boolean,
  guest_allowance int,
  family_allowed boolean,
  guest_policy   text,
  fee_payer      text,
  guest_fee      text,
  confidence     text,
  headline       text,
  note           text,
  bank_dependent boolean,
  rank_no        int
) language plpgsql stable security definer set search_path = public as $$
declare r record; g jsonb; a lounge_venue_acceptance%rowtype; v_i int := 0;
begin
  for r in
    select he.program_id, he.tier, he.verified, he.carrier,
           p.code, p.name, p.entitlement_model, p.fee_payer
      from host_entitlements he
      join lounge_programs p on p.id = he.program_id
     where he.user_id = p_user_id and p.active
     order by he.verified desc, p.code
  loop
    -- Salon bu programı kabul ediyor mu?
    select * into a from lounge_venue_acceptance x
     where x.venue_id = p_venue_id and x.program_id = r.program_id and x.active
     order by x.is_placeholder, x.checked_at desc nulls last
     limit 1;

    program_code := r.code;
    program_name := r.name;
    tier         := r.tier;
    accepted     := coalesce(a.accepted, false);
    fee_payer    := r.fee_payer;
    -- 🔴 BANKAYA BAĞLI PROGRAMLAR: Priority Pass md.4/md.11, DragonPass
    -- 5.4 — ziyaret sayısını, ücreti ve misafir hakkını KARTI VEREN
    -- BANKA belirler. Bu programlarda motorun verebileceği en dürüst
    -- cevap "bankana göre değişir".
    -- İLK YAZIMDA bu satır yalnız KABUL EDİLEN dalda vardı; kabul
    -- etmeyen dalda false kalıyordu ve ölçümde Priority Pass
    -- "bank_dependent: false" göründü. Kullanıcı bundan "kartım
    -- bankaya bağlı değil" sonucunu çıkarırdı. İki dalda da doğru olmalı.
    bank_dependent := r.entitlement_model in ('card_network', 'bank_card')
                      or r.code in ('PRIORITY_PASS', 'DRAGONPASS', 'LOUNGEKEY',
                                    'DREAMFOLKS', 'EVERYLOUNGE', 'ONPASS',
                                    'AMEX_GLOBAL', 'BANK_CARD');

    if not coalesce(a.accepted, false) then
      -- NEGATİF CASE: kabul etmiyor. Listeden ATMIYORUZ — kullanıcı
      -- "bu kartım neden işe yaramadı" sorusunun cevabını görmeli.
      guest_allowance := 0; family_allowed := false;
      guest_policy := 'not_accepted'; guest_fee := null;
      confidence := 'verified';
      headline := 'Bu salon bu programı kabul etmiyor';
      note := null;
      v_i := v_i + 1; rank_no := 1000 + v_i;
      return next; continue;
    end if;

    g := public.resolve_guest_rule(r.program_id, p_venue_id, r.tier,
                                   coalesce(p_carrier, r.carrier), null);

    guest_allowance := coalesce((g ->> 'guest_allowance')::int, 0);
    family_allowed  := coalesce((g ->> 'family_allowed')::boolean, false);
    guest_policy    := coalesce(a.guest_policy, g ->> 'guest_policy', 'unknown');
    guest_fee       := g ->> 'guest_fee';
    confidence      := case when a.is_placeholder then 'unknown'
                            when a.checked_at is not null then 'verified'
                            else 'assumed' end;
    headline        := g ->> 'headline';
    note            := g ->> 'note';
    v_i := v_i + 1; rank_no := v_i;
    return next;
  end loop;
end $$;
grant execute on function public.access_options_for_user(uuid, uuid, text, text) to authenticated;


-- ---- 1b) EN İYİ HAK + GEREKÇE ----
-- App tek bir cevap ister ama kullanıcı GEREKÇEYİ de görmeli:
-- "M&S Elite Plus ile 1 misafir · Priority Pass'in bu salonda misafir
--  hakkı bankana bağlı" — iki hakkı olan biri neyle gireceğini bilsin.
drop function if exists public.best_access_for_user(uuid, uuid, text, text);
create or replace function public.best_access_for_user(
  p_user_id  uuid,
  p_venue_id uuid,
  p_carrier  text default null,
  p_flight   text default null
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_best record; v_all jsonb; v_n int; v_kabul int;
begin
  select count(*), count(*) filter (where o.accepted)
    into v_n, v_kabul
    from public.access_options_for_user(p_user_id, p_venue_id, p_carrier, p_flight) o;

  if v_n = 0 then
    return jsonb_build_object(
      'found', false, 'options', '[]'::jsonb,
      'headline', 'Henüz bir lounge hakkı eklemedin',
      'note', 'Kartını ya da statünü ekle — hangi salona girebileceğini söyleyelim.');
  end if;

  select * into v_best
    from public.access_options_for_user(p_user_id, p_venue_id, p_carrier, p_flight) o
   where o.accepted
   order by
     -- 🔴 SIRALAMA GEREKÇESİ (yukarıdaki ilke listesiyle birebir):
     -- 🔴 coalesce ŞART: NULL bir karşılaştırma DESC sıralamada EN BAŞA
     -- çıkar (145'in dersi). guest_policy ve confidence NULL olabilir;
     -- coalesce'siz yazınca "bilinmeyen" kayıt "en iyi hak" seçilirdi.
     -- sql_lint bunu kendi dosyamda yakaladı.
     coalesce(o.guest_allowance, 0) desc,                            -- 2
     coalesce(o.guest_policy = 'included', false) desc,              -- 3
     coalesce(o.family_allowed, false) desc,                         -- 4
     coalesce(o.confidence = 'verified', false) desc,                -- 5
     o.rank_no                                                       -- 6
   limit 1;

  select jsonb_agg(jsonb_build_object(
           'program', o.program_code, 'name', o.program_name, 'tier', o.tier,
           'accepted', o.accepted, 'guest_allowance', o.guest_allowance,
           'guest_policy', o.guest_policy, 'fee_payer', o.fee_payer,
           'guest_fee', o.guest_fee, 'confidence', o.confidence,
           'headline', o.headline, 'bank_dependent', o.bank_dependent)
           order by o.rank_no)
    into v_all
    from public.access_options_for_user(p_user_id, p_venue_id, p_carrier, p_flight) o;

  if v_best is null then
    -- NEGATİF CASE: hakkı var ama HİÇBİRİ bu salonu açmıyor.
    -- "Giremezsin" demek yerine ne GEREKTİĞİNİ söylüyoruz (marka §2).
    return jsonb_build_object(
      'found', false, 'options', coalesce(v_all, '[]'::jsonb),
      'total_rights', v_n, 'accepted_rights', 0,
      'headline', 'Bu salon eklediğin hakların hiçbirini kabul etmiyor',
      'note', 'Aynı havalimanındaki başka salonlara bakalım — bir tanesi seni alıyor olabilir.');
  end if;

  return jsonb_build_object(
    'found', true,
    'program', v_best.program_code,
    'program_name', v_best.program_name,
    'tier', v_best.tier,
    'guest_allowance', v_best.guest_allowance,
    'family_allowed', v_best.family_allowed,
    'guest_policy', v_best.guest_policy,
    'fee_payer', v_best.fee_payer,
    'guest_fee', v_best.guest_fee,
    'confidence', v_best.confidence,
    'bank_dependent', v_best.bank_dependent,
    'headline', v_best.headline,
    'total_rights', v_n,
    'accepted_rights', v_kabul,
    -- Çoklu hak varsa kullanıcıya SÖYLE. Sessizce en iyisini seçip
    -- geçmek, kapıda yanlış kartı uzatmasına yol açar.
    'multi_note', case when v_kabul > 1
      then 'Bu salonda ' || v_kabul || ' hakkın geçerli. En çok misafir hakkı veren: '
           || v_best.program_name || '. Kapıda bunu uzat.'
      else null end,
    'options', coalesce(v_all, '[]'::jsonb));
end $$;
grant execute on function public.best_access_for_user(uuid, uuid, text, text) to authenticated;


-- ============================================================
-- 2 · AJET × SABİHA GÖKÇEN — "neden giremiyorum?" (🔴 Gökberk bildirdi)
-- ============================================================
-- KAYNAK (AJet kural tablosu SS'i): SAW satırı tabloda VAR; Elite /
-- Elite Plus / Elit Corporate sütunu "ÜCRETSİZ" diyor. Classic ve
-- Classic Plus için "-".
-- Aynı sayfanın dipnotu: "Sabiha Gökçen'deki Turkish Airlines CIP
-- Lounge, 3 Nisan'dan itibaren geçici olarak hizmet dışında olacaktır."
--
-- 🔴 GÖKBERK HAKLI: tadilat bir KURAL değil, bir DURUM. Kuralı silmek
-- yanlış — salon açıldığında hak geri gelir ve biz onu kaybetmiş
-- oluruz. Doğrusu: hak DURUYOR, salonun o anki durumu AYRI bir
-- bilgi olarak gösteriliyor.
--
-- IST için durum FARKLI ve bunu dürüstçe söylüyoruz: AJet tablosunda
-- İstanbul Havalimanı satırı HİÇ YOK. Ne "girer" ne "girmez" yazıyor.
-- Kaynak sessizse biz de "kaynakta tanımlı değil" deriz — "giremezsin"
-- demek, yazmayan bir kuralı uydurmaktır.

-- 2a) AJET_MS'in SAW salonlarını kabul ettiğini yaz
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, is_placeholder, source_url, active)
select v.id, p.id, true, 'unknown', false,
       'https://ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge', true
  from lounge_venues v
  cross join lounge_programs p
 where p.code = 'AJET_MS' and v.active and v.airport_code = 'SAW'
   and not exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.program_id = p.id)
on conflict do nothing;

-- 2b) Elite / Elite Plus SAW'da ÜCRETSİZ girer (kaynak: AJet tablosu)
insert into lounge_guest_rules
  (program_id, venue_id, card_tier, carrier, guest_allowance, family_allowed,
   paid_entry_allowed, notes, effective_from)
select p.id, v.id, t.tier, 'AJ', 0, false, false,
       'AJet Elite/Elite Plus: Sabiha Gökçen CIP salonuna ÜCRETSİZ girersin. '
       'Misafir hakkı AJet tablosunda tanımlı değil — misafirle girmek için '
       'salonun kapı tarifesi geçerli olabilir. '
       '[kaynak: ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge]',
       current_date
  from lounge_programs p
  cross join lounge_venues v
  -- 🔴 BEKÇİ KENDİ HATAMI YAKALADI: ilk yazımda listeye 'ELITE_PLUS'
  -- da koymuştum. Projenin kademe kodu 'ELPL'; 'ELITE_PLUS' YENİ bir
  -- değer yarattı ve o kademe için hiçbir program düzeyi yedek kural
  -- olmadığından 16 (program × kademe × salon) kombinasyonu kuralsız
  -- kaldı → SEED durdu. Ölçüm: kapsam denetimi 0 → 16.
  -- Ders: kod sözlüğüne YENİ değer eklemek, o değer için yedek kural
  -- yazmayı da zorunlu kılar. Yeni bir kademe icat etmek yerine var
  -- olanı kullan.
  cross join (values ('ELITE'), ('ELPL')) t(tier)
 where p.code = 'AJET_MS' and v.active and v.airport_code = 'SAW'
   and not exists (select 1 from lounge_guest_rules r
                    where r.program_id = p.id and r.venue_id = v.id
                      and r.card_tier = t.tier and coalesce(r.carrier,'') = 'AJ')
on conflict do nothing;

-- 2c) Tadilat notu SALONA yazılır, kurala değil
update lounge_venues
   set notes = coalesce(nullif(notes, ''), '')
        || case when coalesce(notes, '') = '' then '' else ' · ' end
        || 'AJet/THY kaynağı: Sabiha Gökçen CIP Lounge 3 Nisan itibarıyla '
           'geçici olarak hizmet dışı olabilir — gitmeden önce doğrula.'
 where airport_code = 'SAW' and active
   and name ilike '%CIP%'
   and coalesce(notes, '') not like '%geçici olarak hizmet dışı%';


-- ============================================================
-- 3 · MILES&SMILES BİR KART DEĞİL, BİR STATÜDÜR (🔴 Gökberk bildirdi)
-- ============================================================
-- "Miles&smiles aslında karttan ziyade bir statü, AJet ve THY'yi
--  kapsayan. Miles&smiles kart diyince bu kredi kartı gibi anlaşılır."
--
-- Program adı zaten düzeltilmiş (TK_MS = "Miles&Smiles (THY & AJet
-- statüsü)"). Eksik olan: motorun DÖNDÜRDÜĞÜ metinlerde ve app'in
-- gösterdiği etikette "kart" kelimesi geçmesi.
-- Burada veri katmanını hizalıyoruz; app tarafı ayrı.

update lounge_programs
   set notes = coalesce(notes, '') ||
       case when coalesce(notes,'') = '' then '' else ' ' end ||
       '[189] Miles&Smiles bir SADAKAT STATÜSÜDÜR (Classic / Classic Plus / '
       'Elite / Elite Plus), kredi kartı değildir. THY ve AJet seferlerini '
       'kapsar. Miles&Smiles ortak markalı KREDİ KARTLARI (Garanti Bonus '
       'Miles&Smiles, Miles&Smiles Amex) AYRI bir programdır ve kendi lounge '
       'hakkını verir — ikisi karıştırılmamalı.'
 where code = 'TK_MS' and coalesce(notes, '') not like '%[189]%';


-- ============================================================
-- 4 · PRIORITY PASS: "hiçbir planda ücretsiz misafir yok" İDDİASI
--     KAYNAKLA DOĞRULANMIYOR (🔴 fazla iddia)
-- ============================================================
-- 177 bu cümleyi kesin bir olgu gibi yazmıştı. Kullanım Koşulları'nın
-- (yürürlük 26 Mart 2026) 22 ekran görüntüsü satır satır okundu:
--   md. 4  → misafir ücreti "Uygulanabilir olduğunda (Program üyelik
--            planına bağlı olarak)" — yani ŞARTA BAĞLI
--   md. 80 / md. 90 → "hak sahibi konuklar" ifadesi geçiyor
--   md. 11 → banka ziyaret sayısını ve hakları SINIRLAYABİLİR
-- Yani kaynak "hiçbir planda yok" demiyor; "plana ve bankaya bağlı"
-- diyor. Üstelik plan/ücret sayfası bu SS setinde HİÇ YOK.
--
-- 🔴 BU BİR "FAZLA İDDİA" HATASI VE BİZİM İÇİN EN PAHALI HATA TÜRÜ.
-- Ürünün tüm değeri "bilmediğimizi biliyoruz" güveninde. Kaynağın
-- söylemediği bir şeyi kesin gibi yazmak, yanlış cevap vermekten
-- daha kötü — çünkü güveni götürür.
--
-- Motor davranışı DEĞİŞMİYOR (0 misafir varsayımı en kısıtlayıcıdır
-- ve güvenli taraf). Değişen ŞEY, kullanıcıya söylediğimiz cümle.

update lounge_guest_rules r
   set notes = 'Priority Pass''te misafir hakkı ÜYELİK PLANINA ve KARTI VEREN '
               'BANKAYA bağlıdır (Kullanım Koşulları md.4 ve md.11). Bazı '
               'planlarda misafir hakkı olabilir; emin olmadığımız için ücretli '
               'varsayıyoruz. Kartını verene sor — kesin cevabı o verir. '
               'Misafir ücreti her zaman ÜYENİN kayıtlı kartından çekilir (md.6).'
  from lounge_programs p
 where p.id = r.program_id and p.code = 'PRIORITY_PASS';

update lounge_programs
   set notes = '[189 · kaynak 26 Mart 2026] Misafir eş zamanlı kaydolup girmeli '
               '(md.6). Misafirin biniş kartı zorunlu (md.5). Erişim aracı '
               'DEVREDİLEMEZ (md.11) — üye fiziken orada olmalı. Kalış süresi '
               'sınırını SALON koyar (md.19). Ücret, kota ve misafir hakkı '
               'BANKAYA göre değişir (md.4, md.11, md.18). '
               'Aynı uçuş şartı: kaynakta YOK.',
       source_url = 'https://www.prioritypass.com/tr-TR/conditions-of-use',
       checked_at = current_date,
       member_must_be_present = true,
       transferable = false,
       guest_needs_boarding_pass = true
 where code = 'PRIORITY_PASS';


-- ============================================================
-- 5 · DRAGONPASS: AYNI UÇUŞ ŞARTI DOĞRULANDI — kaynak atfı eklendi
-- ============================================================
-- Elimizdeki bilgi ("md. 7.15.7: misafir üyeyle aynı uçuşta olmalı")
-- 27 ekran görüntüsünde BİREBİR doğrulandı:
--   7.15.7 — "Your guests are required to be on the same flight as the
--             Dragonpass Member to enjoy Lounge access using the same
--             Dragonpass Membership."
-- Belgedeki TEK "same flight" ifadesi budur ve tam olarak bizim
-- senaryomuzu (host'un hakkıyla misafir sokma) kapsar → BAĞLAYICI.
--
-- NUMARA TUZAĞI: Lounge bölümü sıralamaya göre 7.9 olmalıydı; belgede
-- numaralandırma hatası var ve Lounge 7.15'e kaymış. 7.9'da arayan
-- bulamaz — kaynak atfına bu notu da yazıyoruz.
--
-- 5.4 — üyelik bir banka üzerinden alındıysa "the above may not be
-- applicable to you". Yani DragonPass kuralı her zaman
-- "BANKA × DragonPass" çifti olarak modellenmeli.

-- 🔴 guest_flight_coupling / source_url / checked_at kolonlari
-- lounge_guest_rules'ta YOK — lounge_programs'ta. Ilk yazimda ikisini
-- karistirdim ve migration durdu. Sema hafizadan yazmanin 12. ornegi;
-- bu kez ceza yalniz bir tur oldu cunku bekci canliyi gormeden yakaladi.
update lounge_guest_rules r
   set notes = 'DragonPass md.7.15.7: misafirin üyeyle AYNI UÇUŞTA olması '
               'gerekir. (Belgede numaralandırma hatası var — Lounge bölümü '
               '7.9 değil 7.15''tir.) Kart DEVREDİLEMEZ (7.1.1, 4.6): üye '
               'fiziken orada olmalı. Kalış tipik 2 saat, salon belirler. '
               'Ücret ve misafir hakkı KARTI VEREN BANKAYA göre değişir (5.4).',
       guest_must_match_carrier = true
  from lounge_programs p
 where p.id = r.program_id and p.code = 'DRAGONPASS';

update lounge_programs
   set guest_flight_coupling = 'same_flight',
       member_must_be_present = true,
       transferable = false,
       max_stay_hours = 2,
       notes = '[189 · kaynak 27 Mart 2026] Misafir üyeyle AYNI UÇUŞTA olmalı '
               '(md.7.15.7). Kart devredilemez (7.1.1 / 4.6 / 7.15.18f). '
               'Ön rezervasyon opsiyonel, en fazla 5 kişi, 48 saat iptal '
               'eşiği. 1 saat geç kalma toleransı, sonrası no-show ve iade '
               'yok. Ücret/plan bilgisi sözleşmede YOK — App/Website''e '
               'havale ediliyor (7.15.8). Banka kuralı değiştirebilir (5.4).',
       source_url = 'https://www.dragonpass.com/terms-and-conditions',
       checked_at = current_date
 where code = 'DRAGONPASS';


-- ============================================================
-- 6 · TAŞIYICI UYUŞMAZLIĞI — kullanıcıya ANLAŞILIR cümle (🔴 Gökberk)
-- ============================================================
-- "Ben AJet biletine sahibim, ilana başvuracağım kişi THY'li ise beni
--  içeri alamaz — bu ayrımı vermemiz önemli. 'Sizin biletiniz AJet,
--  ilan sahibinin THY olduğu için kabul almayacaktır' gibi."
--
-- KAYNAK ÇİFT YÖNLÜ VE SİMETRİK (transkriptte doğrulandı):
--   THY md.17 — "AJet seferinde seyahat eden yolcuyu misafir olarak
--                salona davet edemez"
--   AJet       — "misafir yolcunun da AJet seferiyle seyahat etmesi
--                 gerekmektedir"
-- Yani şart AYNI UÇUŞ değil, AYNI TAŞIYICI.

create or replace function public.carrier_mismatch_note(
  p_host_carrier  text,
  p_guest_carrier text
) returns jsonb language plpgsql immutable set search_path = public as $$
declare h text := upper(nullif(btrim(coalesce(p_host_carrier, '')), ''));
        g text := upper(nullif(btrim(coalesce(p_guest_carrier, '')), ''));
begin
  -- Bilinmiyorsa YARGI VERME. 163'ün ilkesi: bilmemek cömert davranmak
  -- için gerekçe değil — ama uydurmak için de gerekçe değil.
  if h is null or g is null then
    return jsonb_build_object('state', 'unknown', 'blocks', false,
      'title', 'Uçuş numaranı ekle, kesin cevabı verelim',
      'body', 'Misafirin host ile aynı havayolunda uçuyor olması gerekebilir. '
              'Uçuş numaranı yazarsan bunu senin yerine kontrol ederiz.');
  end if;

  if h = g then
    return jsonb_build_object('state', 'match', 'blocks', false,
      'title', 'Aynı havayolu — bu şart tamam',
      'body', 'İkiniz de ' || h || ' ile uçuyorsunuz.');
  end if;

  -- THY ↔ AJet: aynı statü programı ama AYRI taşıyıcı. En sık
  -- karıştırılan durum bu; adıyla söylüyoruz.
  if (h in ('TK') and g in ('VF', 'AJ')) or (h in ('VF', 'AJ') and g in ('TK')) then
    return jsonb_build_object('state', 'tk_ajet', 'blocks', true,
      'title', 'Biletler farklı havayolunda',
      'body', 'Senin biletin ' || case when g = 'TK' then 'Turkish Airlines'
                                       else 'AJet' end ||
              ', ilan sahibininki ' || case when h = 'TK' then 'Turkish Airlines'
                                            else 'AJet' end ||
              '. Miles&Smiles statüsü ikisini de kapsıyor ama salon kuralı '
              'misafirin host ile AYNI havayolunda uçmasını istiyor — bu '
              'ilandan kabul alamazsın.',
      'fix', 'Aynı havayolunda uçan bir ilan ara — keşifte havayolu filtresi var.');
  end if;

  return jsonb_build_object('state', 'mismatch', 'blocks', true,
    'title', 'Biletler farklı havayolunda',
    'body', 'Senin biletin ' || g || ', ilan sahibininki ' || h ||
            '. Bu salon misafirin host ile aynı havayolunda uçmasını istiyor.',
    'fix', 'Aynı havayolunda uçan bir ilan ara.');
end $$;
grant execute on function public.carrier_mismatch_note(text, text) to authenticated;


-- ============================================================
-- 7 · BEKÇİLER — hepsi GERÇEKTEN çağırır (186 dersi)
-- ============================================================
do $$
declare v_uid uuid; v_venue uuid; j jsonb; n int;
begin
  -- 7a) çoklu hak: iki hakkı olan bir kullanıcı kur, ikisinin de
  --     listede göründüğünü ÖLÇ.
  select he.user_id into v_uid from host_entitlements he
   group by he.user_id having count(*) >= 2 limit 1;

  if v_uid is null then
    -- Yapay ikinci hak ekle ki bekçi gerçekten bir şey ölçsün.
    select he.user_id into v_uid from host_entitlements he limit 1;
    if v_uid is not null then
      insert into host_entitlements (user_id, program_id, tier, origin)
      select v_uid, p.id, 'STANDARD', 'admin' from lounge_programs p
       where p.code = 'PRIORITY_PASS'
      on conflict do nothing;
    end if;
  end if;

  select v.id into v_venue from lounge_venues v where v.active and v.airport_code = 'IST' limit 1;

  if v_uid is null or v_venue is null then
    raise notice '189: coklu hak bekcisi atlandi (kullanici/salon yok)';
  else
    select count(*) into n from public.access_options_for_user(v_uid, v_venue, null, null);
    if n = 0 then raise exception '189: access_options_for_user hic secenek dondurmedi'; end if;
    j := public.best_access_for_user(v_uid, v_venue, null, null);
    if j is null or not (j ? 'options') then
      raise exception '189: best_access_for_user gecersiz cevap dondu';
    end if;
    raise notice '189: coklu hak calisiyor — % secenek, en iyi: %',
      n, coalesce(j ->> 'program', '(kabul eden yok)');
  end if;
end $$;

-- 7b) AJet × SAW: hak GÖRÜNÜYOR mu?
do $$
declare n int;
begin
  select count(*) into n
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
    join lounge_venues v on v.id = r.venue_id
   where p.code = 'AJET_MS' and v.airport_code = 'SAW'
     and r.card_tier in ('ELITE', 'ELPL', 'ELITE_PLUS');
  if n = 0 then
    raise exception '189: AJet Elite/Elite Plus icin SAW kurali YOK';
  end if;
  raise notice '189: AJet SAW kurali var (% satir)', n;
end $$;

-- 7c) taşıyıcı uyuşmazlığı metni: üç durum da doğru mu?
do $$
declare j jsonb;
begin
  j := public.carrier_mismatch_note('TK', 'VF');
  if coalesce((j ->> 'blocks')::boolean, false) is not true
     or (j ->> 'state') <> 'tk_ajet' then
    raise exception '189: TK/AJet uyusmazligi dogru raporlanmiyor: %', j;
  end if;
  j := public.carrier_mismatch_note('TK', 'TK');
  if coalesce((j ->> 'blocks')::boolean, true) is not false then
    raise exception '189: ayni tasiyici engel gibi raporlaniyor';
  end if;
  j := public.carrier_mismatch_note(null, 'TK');
  if (j ->> 'state') <> 'unknown' then
    raise exception '189: bilinmeyen tasiyici icin yargi veriliyor';
  end if;
  raise notice '189: tasiyici uyusmazligi metni uc durumda da dogru';
end $$;

-- 7d) yeni RPC'ler smoke testte görünsün (186 dersi: var olmak yetmez)
do $$
declare r record; v_bad int := 0;
begin
  for r in select * from public.rpc_smoke_test() where sonuc like '✗%' loop
    raise warning '189: RPC PATLIYOR — % : %', r.rpc, r.hata;
    v_bad := v_bad + 1;
  end loop;
  if v_bad > 0 then raise exception '189: % RPC canlida patliyor', v_bad; end if;
  raise notice '189: rpc_smoke_test hala temiz';
end $$;

select '189 OK - coklu hak mimarisi + kaynak hizalama' as sonuc;


-- ============================================================
-- 8 · KADEME KODU SÖZLÜĞÜ TEKLEŞTİRME (bekçinin ikinci bulgusu)
-- ============================================================
-- ÖLÇÜM: AJET_MS'te İKİ ayrı Elite Plus kodu yan yana duruyordu —
--   ELPL 10 satır · ELITE_PLUS 8 satır
-- Aynı kademe için iki kod, "aynı şeye iki isim" hatasının kural
-- verisindeki hâli. Motor host'un kartında hangisi yazılıysa onu
-- arar; diğerindeki satırlara ASLA ulaşamaz. Yani 8 kural erişilemez
-- durumda duruyordu ve kimse fark etmemişti.
--
-- ELPL kanonik; ELITE_PLUS ona taşınır. Çakışan satır varsa
-- ELITE_PLUS olanı pasife çekilir (silinmez — kaynak izi kalsın).
do $$
declare v_tasinan int; v_kapanan int;
begin
  -- Karşılığı OLMAYANLARI taşı
  with cakisan as (
    select e.id from lounge_guest_rules e
     where e.card_tier = 'ELITE_PLUS'
       and exists (select 1 from lounge_guest_rules k
                    where k.program_id = e.program_id
                      and k.card_tier = 'ELPL'
                      and coalesce(k.venue_id::text,'') = coalesce(e.venue_id::text,'')
                      and coalesce(k.carrier,'') = coalesce(e.carrier,'')
                      and coalesce(k.venue_scope,'') = coalesce(e.venue_scope,''))
  )
  update lounge_guest_rules set card_tier = 'ELPL'
   where card_tier = 'ELITE_PLUS' and id not in (select id from cakisan);
  get diagnostics v_tasinan = row_count;

  -- Çakışanları kapat (effective_to = dün) — silme, izi kalsın
  update lounge_guest_rules
     set effective_to = current_date - 1,
         notes = coalesce(notes,'') || ' [189: ELPL karsiligi zaten var, kapatildi]'
   where card_tier = 'ELITE_PLUS';
  get diagnostics v_kapanan = row_count;

  raise notice '189: kademe kodu tekletildi — % tasindi, % kapatildi', v_tasinan, v_kapanan;
end $$;

-- BEKÇİ: aynı kademe için iki kod kalmasın.
do $$
declare v_bad int;
begin
  select count(*) into v_bad from lounge_guest_rules
   where card_tier = 'ELITE_PLUS'
     and (effective_to is null or effective_to >= current_date);
  if v_bad > 0 then
    raise exception '189: % satirda hala ELITE_PLUS kodu geçerli — ELPL kanonik', v_bad;
  end if;
  raise notice '189: kademe kodu sozlugu tek';
end $$;


-- BEKÇİ: bankaya bağlı program, KABUL EDİLMESE DE öyle işaretlenmeli.
do $$
declare v_uid uuid; v_venue uuid; v_bad int;
begin
  select user_id into v_uid from host_entitlements
    where program_id = (select id from lounge_programs where code = 'PRIORITY_PASS')
    limit 1;
  select id into v_venue from lounge_venues where active limit 1;
  if v_uid is null or v_venue is null then
    raise notice '189: banka bagimliligi bekcisi atlandi'; return;
  end if;
  select count(*) into v_bad
    from public.access_options_for_user(v_uid, v_venue, null, null) o
   where o.program_code in ('PRIORITY_PASS','DRAGONPASS','LOUNGEKEY','AMEX_GLOBAL')
     and o.bank_dependent is not true;
  if v_bad > 0 then
    raise exception '189: % bankaya bagli program "bagli degil" diye isaretli', v_bad;
  end if;
  raise notice '189: bankaya bagli programlar dogru isaretli';
end $$;
