-- ============================================================
-- 216 · "HANGİ KARTIMI KULLANAYIM?" — ÜRÜNÜN ASIL SORUSU
-- 17 Ağustos 2026
--
-- 🔴 214 doğru veriyi yazdı ama YANLIŞ SORUYU cevaplıyordu.
-- Ölçüm — 214'ün karşılaştırma fonksiyonunu IST iGA Lounge için
-- çalıştırdım ve çıktı şuydu:
--
--   DRAGONPASS    | Misafir alinabilir ama UCRETLI | ... | AYNI UCUSTA olmali
--   LOUNGEKEY     | Misafir alinabilir ama UCRETLI | ...
--   PRIORITY_PASS | Misafir alinabilir ama UCRETLI | ...
--   TK_MS         | BILINMIYOR                     | ...   ← 🔴
--
-- TK_MS "bilinmiyor" çıkıyordu. Oysa bilinmiyor DEĞİL: THY'nin cevabı
-- KART TİPİNE bağlı ve o veri katalogda 194 satır hâlinde duruyor
-- (Tablo-1…Tablo-5). Elite ile "ailen veya bir misafir", Classic Plus
-- ile "misafir hakkın yok", Business biletiyle "yok".
--
-- Yani karşılaştırma salon×program ekseninde kalıyordu; ürünün sorusu
-- ise salon × program × SENİN KARTIN. Aynı hata sınıfı: doğru veriyi
-- yazıp yanlış eksende okumak, veriyi hiç yazmamakla aynı sonucu verir.
--
-- Bu dosya cevabı host'un elindeki KARTLARA göre veriyor:
-- `host_entitlements`te ne varsa onunla sorar, en iyi seçeneği önerir.
-- ============================================================

-- ⚠️ SÜTUN EKLİYORUM → ÖNCE DROP. `returns table(...)` satır tipidir;
-- `create or replace` tipi değiştiremez (bu turda bir kez yakalandım).
drop function if exists public.salon_misafir_karsilastirmasi(uuid);

create or replace function public.salon_misafir_karsilastirmasi(
  p_venue uuid, p_user uuid default null)
returns table (
  program        text,
  program_adi    text,
  kart_tipi      text,
  tasiyici       text,
  bende_var      boolean,
  misafir_hakki  text,
  ucretsiz_adet  int,
  aile_dahil     boolean,
  ucret          text,
  ucusa_bagli    text,
  azami_saat     numeric,
  uyari          text,
  kaynak         text,
  kontrol        date
) language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  r record; t record; v_dec jsonb; v_var boolean; v_tasiyici text;
begin
  for r in
    select p.id pid, p.code, p.name, p.kind,
           a.guest_policy, a.guest_included_count, a.guest_fee_amount, a.guest_fee_currency,
           a.guest_flight_coupling, a.max_stay_hours, a.conditions, a.children_note,
           a.source_url, a.checked_at,
           p.guest_default, p.guest_flight_coupling p_coup, p.max_stay_hours p_stay,
           p.source_url p_src, p.checked_at p_chk, p.notes p_notes
      from lounge_venue_acceptance a
      join lounge_programs p on p.id = a.program_id
     where a.venue_id = p_venue and a.accepted and a.active
     order by p.code
  loop
    v_var := exists (select 1 from host_entitlements e
                      where e.user_id = v_uid and e.program_id = r.pid);
    -- Salonun işletmecisinden taşıyıcı varsayımı (yalnız havayolu salonlarında anlamlı).
    select case
             when v.name ilike '%turkish airlines%' or coalesce(v.operator,'') ilike '%turkish%' then 'TK'
             when v.name ilike '%ajet%'    or coalesce(v.operator,'') ilike '%ajet%'    then 'VF'
             when v.name ilike '%pegasus%' or coalesce(v.operator,'') ilike '%pegasus%' then 'PC'
             else null end
      into v_tasiyici from lounge_venues v where v.id = p_venue;

    -- KART TİPİ OLAN PROGRAMLAR: her tier için ayrı satır.
    -- Bu, "bilinmiyor" cevabını ortadan kaldıran şey.
    if exists (select 1 from lounge_guest_rules g
                where g.program_id = r.pid and g.card_tier is not null) then
      for t in
        select distinct g.card_tier
          from lounge_guest_rules g
         where g.program_id = r.pid and g.card_tier is not null
           and (g.venue_id is null or g.venue_id = p_venue)
         order by g.card_tier
      loop
        -- 🔴 TAŞIYICI BOŞ BIRAKILAMAZ — ölçümle görüldü.
        -- `carrier=null` ile sorunca motor en TUTUCU satırı seçiyor:
        -- IST dış hatta Elite için "Aile veya bir misafir" yerine Star
        -- Alliance satırındaki "Bir misafir" dönüyordu (aile_dahil=false).
        -- Doğru varsayım salonun İŞLETMECİSİ: THY salonunda yolcu THY
        -- ile uçuyordur. Varsayımı gizlemiyorum, `tasiyici` sütununda
        -- yazıyorum — gizli varsayım, yanlış cevaptan beter olur.
        v_dec := public.resolve_guest_rule(r.pid, p_venue, t.card_tier, v_tasiyici, null);
        program       := r.code;
        program_adi   := r.name;
        kart_tipi     := t.card_tier;
        tasiyici      := coalesce(v_tasiyici, nullif(v_dec ->> 'carrier_scope',''), 'farketmez');
        -- "bende var mı" tier düzeyinde sorulur: host_entitlements.tier
        bende_var     := exists (select 1 from host_entitlements e
                                  where e.user_id = v_uid and e.program_id = r.pid
                                    and upper(coalesce(e.tier,'')) = upper(t.card_tier));
        misafir_hakki := case
          when (v_dec ->> 'blocked_reason') is not null then 'Misafir ALINAMAZ'
          when coalesce((v_dec ->> 'guest_allowance')::int, 0) > 0 then 'Ucretsiz misafir hakki var'
          when coalesce((v_dec ->> 'paid_entry_allowed')::boolean, false) then 'Misafir alinabilir ama UCRETLI'
          when (v_dec ->> 'found') = 'true' then 'Misafir ALINAMAZ'
          else 'Bilinmiyor' end;
        ucretsiz_adet := coalesce((v_dec ->> 'guest_allowance')::int, 0);
        aile_dahil    := coalesce((v_dec ->> 'family_allowed')::boolean, false);
        ucret         := coalesce(nullif(v_dec ->> 'guest_fee',''), '—');
        -- ⚠️ ETİKET DÜZELTMESİ: `same_flight_required` motorda AYNI UÇUŞ
        -- demek, aynı havayolu değil. İlk yazımda ikisini karıştırdım ve
        -- DragonPass satırı "aynı havayoluyla" diyordu — oysa sözleşme
        -- (7.15.7) açıkça "on the SAME FLIGHT" diyor. Bir kelime, ama
        -- kapıda misafirin içeri girip girmemesini belirleyen kelime.
        ucusa_bagli   := case
          when coalesce((v_dec ->> 'same_flight_required')::boolean, false) then 'Misafir AYNI UCUSTA olmali'
          when coalesce(r.guest_flight_coupling, r.p_coup) = 'same_carrier'  then 'Misafir AYNI HAVAYOLUYLA ucmali'
          when coalesce(r.guest_flight_coupling, r.p_coup) = 'same_alliance' then 'Misafir ayni ittifak havayoluyla ucmali'
          else 'Ucus sarti yok' end;
        azami_saat    := coalesce(r.max_stay_hours, r.p_stay);
        uyari         := nullif(btrim(coalesce(v_dec ->> 'headline','') || ' ' || coalesce(v_dec ->> 'note','')
                                   || ' ' || coalesce(r.conditions,'')), '');
        kaynak        := coalesce(r.source_url, r.p_src);
        kontrol       := coalesce(r.checked_at, r.p_chk);
        return next;
      end loop;

    else
      -- KART TİPİ OLMAYAN PROGRAM (kart ağları, ödemeli): tek satır.
      program       := r.code;
      program_adi   := r.name;
      kart_tipi     := null;
      tasiyici      := 'farketmez';
      bende_var     := v_var;
      misafir_hakki := case coalesce(r.guest_policy, r.guest_default)
        when 'included'    then 'Ucretsiz misafir hakki var'
        when 'paid'        then 'Misafir alinabilir ama UCRETLI'
        when 'not_allowed' then 'Misafir ALINAMAZ'
        else 'Bilinmiyor' end;
      ucretsiz_adet := coalesce(r.guest_included_count, 0);
      aile_dahil    := false;
      ucret := case
        when r.guest_fee_amount is not null
          then trim(to_char(r.guest_fee_amount, 'FM9999990.00')) || ' ' || coalesce(r.guest_fee_currency,'')
        when coalesce(r.guest_policy, r.guest_default) = 'paid'
          then 'Tutar degisken — karti veren kurumdan teyit et'
        else '—' end;
      ucusa_bagli := case coalesce(r.guest_flight_coupling, r.p_coup, 'any')
        when 'same_flight'   then 'Misafir AYNI UCUSTA olmali'
        when 'same_carrier'  then 'Misafir AYNI HAVAYOLUYLA ucmali'
        when 'same_alliance' then 'Misafir ayni ittifak havayoluyla ucmali'
        else 'Ucus sarti yok' end;
      azami_saat := coalesce(r.max_stay_hours, r.p_stay);
      uyari      := nullif(btrim(coalesce(r.conditions,'') || ' ' || coalesce(r.children_note,'')), '');
      kaynak     := coalesce(r.source_url, r.p_src);
      kontrol    := coalesce(r.checked_at, r.p_chk);
      return next;
    end if;
  end loop;
end $fn$;
grant execute on function public.salon_misafir_karsilastirmasi(uuid, uuid) to authenticated;


-- ============================================================
-- EN İYİ SEÇENEK — host'un ELİNDEKİ kartlar arasından
-- ============================================================
-- Host'un ekranında görmesi gereken tek cümle: "Bu salona X kartınla
-- gir; misafirin ücretsiz." Karşılaştırma tablosu ikinci ekran.
--
-- SIRALAMA ÜRÜN KARARIDIR ve gerekçesi şu: kullanıcının cebinden para
-- çıkmaması > misafirin kabul edilmesi > kolaylık.
--   1) ücretsiz misafir hakkı olan
--   2) aile hakkı da veren (daha geniş)
--   3) uçuş şartı olmayan (LoungeLink'te host ve misafir genelde
--      FARKLI uçuşta — `same_flight` şartı eşleşmeyi kapıda bozar)
--   4) ücretli ama kabul eden
create or replace function public.hangi_kartimi_kullanayim(
  p_venue uuid, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_en jsonb; v_n int; v_sahip int;
begin
  if v_uid is null then return jsonb_build_object('known', false, 'neden', 'oturum yok'); end if;

  select count(*) into v_sahip from host_entitlements where user_id = v_uid;

  select to_jsonb(x) into v_en from (
    select k.program, k.program_adi, k.kart_tipi, k.tasiyici, k.misafir_hakki, k.ucretsiz_adet,
           k.aile_dahil, k.ucret, k.ucusa_bagli, k.azami_saat, k.uyari, k.kaynak
      from public.salon_misafir_karsilastirmasi(p_venue, v_uid) k
     where k.bende_var
     order by
       case k.misafir_hakki
         when 'Ucretsiz misafir hakki var' then 1
         when 'Misafir alinabilir ama UCRETLI' then 2
         when 'Bilinmiyor' then 3
         else 4 end,
       (k.aile_dahil is not true),
       (k.ucusa_bagli <> 'Ucus sarti yok'),
       k.ucretsiz_adet desc
     limit 1) x;

  select count(*) into v_n from public.salon_misafir_karsilastirmasi(p_venue, v_uid);

  if v_en is null then
    return jsonb_build_object(
      'known', v_sahip > 0,
      'oneri', null,
      'kart_sayim', v_sahip,
      'salondaki_kaynak', v_n,
      'neden', case when v_sahip = 0
                    then 'Henuz bir erisim kaynagi (kart/statu) beyan etmemissin. Profil › Lounge Erisim Kurulumu''ndan ekleyince burasi dolar.'
                    else 'Beyan ettigin kartlarin hicbiri bu salonda gecmiyor. Karsilastirma tablosunda hangi kaynaklarin gectigini gorebilirsin.' end);
  end if;

  return jsonb_build_object(
    'known', true, 'oneri', v_en, 'kart_sayim', v_sahip, 'salondaki_kaynak', v_n);
end $fn$;
grant execute on function public.hangi_kartimi_kullanayim(uuid, uuid) to authenticated;

insert into rpc_client_surface (fn_name, client, note) values
  ('salon_misafir_karsilastirmasi', 'app', 'Salon x kaynak x kart tipi misafir hakki tablosu.'),
  ('hangi_kartimi_kullanayim',      'app', 'Host''un elindeki kartlar arasindan en iyi secenek.')
on conflict (fn_name) do update set client = excluded.client, note = excluded.note;


-- ============================================================
-- NÖBETÇİLER
-- ============================================================

-- 1) 🔴 "BİLİNMİYOR" CEVABI KALKTI MI (214'ün eksiği)
do $$
declare v_v uuid; v_bilinmiyor int; v_top int;
begin
-- 🔴 SALON SEÇİMİ ARTIK ADA DEĞİL ÖZELLİĞE BAĞLI — 18 Ağustos 2026.
-- Gökberk'te bu nöbetçi şunu verdi:
--     216: TK_MS/AJET_MS satiri hic uretilmedi
-- Sebebi nöbetçinin kendisiydi: sahneyi `name='iGA Lounge — Dış Hat'`
-- diye SABİT BİR ADLA seçiyordu. O salon onun katalogunda var ama
-- THY/AJet kabul satırı YOK; yani nöbetçi, sınamak istediği özelliğin
-- BULUNMADIĞI bir salonu seçip "özellik çalışmıyor" diye bağırıyordu.
--
-- Bu, bugün 215'te yaşadığımızın aynısı: bir denetimin metin sabitine
-- bağlanması. Salon adları bu projede sürekli normalleşiyor (190/211/214a)
-- ve her ad düzenlemesi bu nöbetçileri kırıyor.
--
-- Doğrusu: sınanacak ÖZELLİĞE sahip bir salon seç. Hiç yoksa bu GERÇEK
-- bir veri boşluğudur ve o zaman durmak doğrudur — ama o hâlde mesaj da
-- "salon bulunamadı" demeli, "özellik çalışmıyor" değil.
  select v.id into v_v
    from lounge_venues v
    join lounge_venue_acceptance a on a.venue_id = v.id and a.active and a.accepted
    join lounge_programs p on p.id = a.program_id
   where v.active and p.code in ('TK_MS','AJET_MS')
   order by v.airport_code, v.name
   limit 1;
  if v_v is null then
    raise exception '216: HICBIR salonda TK_MS/AJET_MS kabul satiri yok — '
      'havayolu programi katalogda hic baglanmamis (veri boslugu).';
  end if;

  select count(*) filter (where misafir_hakki = 'Bilinmiyor'), count(*)
    into v_bilinmiyor, v_top
    from public.salon_misafir_karsilastirmasi(v_v, null)
   where program in ('TK_MS','AJET_MS');
  if v_top = 0 then raise exception '216: TK_MS/AJET_MS satiri hic uretilmedi'; end if;
  if v_bilinmiyor = v_top then
    raise exception '216: havayolu programlarinin TAMAMI hala "Bilinmiyor" — kart tipi ekseni okunmuyor (%/%)', v_bilinmiyor, v_top;
  end if;
  raise notice '216: havayolu programi kart tipine gore cozuluyor — %/% satir hala bilinmiyor', v_bilinmiyor, v_top;
end $$;

-- 2) AYNI SALON, FARKLI KAYNAK → FARKLI CEVAP (dosyanın tezi)
do $$
declare v_v uuid; v_farkli int; v_top int; v_ad text;
begin
  -- Bu nöbetçi "aynı salon, farklı kaynak → farklı cevap" diyor; o hâlde
  -- EN ÇOK KAYNAĞI OLAN salonu seçmek gerekir, sabit bir adı değil.
  select v.id, v.name into v_v, v_ad
    from lounge_venues v
    join lounge_venue_acceptance a on a.venue_id = v.id and a.active and a.accepted
   where v.active
   group by v.id, v.name
   order by count(distinct a.program_id) desc, v.name
   limit 1;
  if v_v is null then raise notice '216: kabul satirli salon yok — atlandi'; return; end if;
  select count(distinct misafir_hakki), count(*) into v_farkli, v_top
    from public.salon_misafir_karsilastirmasi(v_v, null);
  if v_farkli < 2 then
    raise exception '216: "%" salonunda butun kaynaklar AYNI cevabi veriyor (% satir) — kaynaga gore degisim kayboldu', v_ad, v_top;
  end if;
  raise notice '216: "%" — % satir, misafir hakki % farkli deger aliyor', v_ad, v_top, v_farkli;
end $$;

-- 3) ÖNERİ FONKSİYONU GERÇEK BİR HOST İÇİN ÇALIŞIYOR MU (mutasyon)
-- Host'a bir hak veriyoruz, öneri çıkmalı; geri alıyoruz, öneri
-- kaybolmalı ve SEBEBİ yazmalı. İkisi de kanıtlanmalı: öneri üretmek
-- kolay, "öneri yok" durumunu doğru anlatmak zordur.
do $$
declare v_u uuid; v_v uuid; v_p uuid; v1 jsonb; v2 jsonb; v_vardi boolean := true;
        r record; v_denenen int := 0; v_ekledim boolean; v_tier text;
begin
  select id into v_u from users limit 1;
  select id into v_p from lounge_programs where code='PRIORITY_PASS';
  if v_u is null or v_p is null then raise notice '216: sahne yok — atlandi'; return; end if;

  -- 🔴 ÖNCE HAKKI VER, SONRA SAHNEYİ SEÇ — 18 Ağustos 2026.
  -- İlk düzeltmemde sahneyi "PRIORITY_PASS kabulü olan salon" diye
  -- seçtim ve Gökberk'te şu çıktı:
  --     216: hak verildigi halde oneri URETILMEDI
  --     → {"oneri": null, "kart_sayim": 1, "salondaki_kaynak": 8,
  --        "neden": "Beyan ettigin kartlarin hicbiri bu salonda gecmiyor"}
  --
  -- Yani salon PP'yi kabul ediyor ama o salonun kural satırları
  -- kullanıcının kartını "bende var" saymıyor (kart tipi ekseni
  -- tutmuyor). Kabul satırının varlığı, önerinin çıkacağını GARANTİ
  -- ETMİYOR — ben iki özelliği birbirine karıştırmışım.
  --
  -- Doğrusu: aranan özellik "kabul satırı var" değil, "karşılaştırma
  -- tablosunda bende_var satırı ÇIKIYOR". O yüzden hak önce veriliyor,
  -- sonra adaylar arasında bu koşulu SAĞLAYAN salon aranıyor.
  -- 🔴 VE ASIL KUSUR BURADAYDI: HAKKI TIER'SIZ EKLIYORDUM.
  -- `salon_misafir_karsilastirmasi` "bende var mi" sorusunu KART TIPI
  -- duzeyinde soruyor:
  --     bende_var := exists (select 1 from host_entitlements e
  --                           where e.user_id = v_uid and e.program_id = r.pid
  --                             and upper(coalesce(e.tier,'')) = upper(t.card_tier));
  -- Yani salonun o program icin kart tipi kurallari varsa, tier'i bos
  -- bir hak HICBIR satirla eslesmiyor. Bende ilk aday salonun kart tipi
  -- kurali YOKTU (o dalda `bende_var := v_var`, yani yalniz hakkin
  -- varligina bakiliyor) ve nobetci gecti; Gokberk'te ilk aday salonun
  -- kart tipi kurallari VARDI ve hicbiri tutmadi.
  --
  -- Duzeltme: her aday salon icin O SALONUN kendi kart tipini okuyup
  -- hakki o tier ile veriyoruz. Kart tipi kurali yoksa tier null kaliyor
  -- ve diger dal zaten calisiyor.
  for r in
    select v.id as vid,
           -- ⚠️ ONCE `g.venue_id = v.id` YAZMISTIM ve HICBIR tier bulamadi:
           -- kart tipi kurallarinin cogu PROGRAM DUZEYINDE duruyor
           -- (venue_id null), salonda ozel kural varsa onu EZIYOR.
           -- Fonksiyonun kendisi de aynen boyle okuyor:
           --     and (g.venue_id is null or g.venue_id = p_venue)
           -- Ayni kurali iki kez yazip birini yanlis yazmisim.
           (select g.card_tier
              from lounge_guest_rules g
             where g.program_id = v_p
               and (g.venue_id is null or g.venue_id = v.id)
               and coalesce(g.card_tier,'') <> ''
             order by (g.venue_id is not null) desc, g.card_tier
             limit 1) as tier
      from lounge_venues v
      join lounge_venue_acceptance a on a.venue_id = v.id and a.active and a.accepted
     where v.active and a.program_id = v_p
     order by v.airport_code, v.name
  loop
    v_denenen := v_denenen + 1;
    -- ⚠️ `update ... set tier` YAZMISTIM ve `uq_he` kısıtına tosladım:
    --     unique (user_id, program_id, coalesce(tier,''), coalesce(card_label,''))
    -- Kullanıcının o programda BAŞKA tier'li kaydı varsa güncelleme
    -- çakışıyor. Doğrusu: eksikse EKLE, denedikten sonra KENDİ
    -- eklediğimi geri al — kullanıcının gerçek kayıtlarına dokunma.
    v_ekledim := false;
    if not exists (select 1 from host_entitlements e
                    where e.user_id = v_u and e.program_id = v_p
                      and coalesce(e.tier,'') = coalesce(r.tier,'')) then
      insert into host_entitlements (user_id, program_id, tier, verified, self_reported_at)
      values (v_u, v_p, r.tier, false, now());
      v_ekledim := true;
    end if;

    if exists (select 1 from public.salon_misafir_karsilastirmasi(r.vid, v_u) t
                where t.bende_var) then
      v_v := r.vid;
      v_tier := r.tier;
      v_vardi := not v_ekledim;   -- hak zaten var mıydı, yoksa ben mi ekledim
      exit;
    end if;

    if v_ekledim then
      delete from host_entitlements
       where user_id = v_u and program_id = v_p
         and coalesce(tier,'') = coalesce(r.tier,'');
    end if;
  end loop;

  if v_v is null then
    -- Hakkı geri al, sonra DUR. Bu gerçek bir bulgu: beyan edilmiş bir
    -- kart HİÇBİR salonda "bende var" satırı üretmiyorsa, host o kartın
    -- nerede geçtiğini uygulamada hiç göremez.
    raise exception '216: PRIORITY_PASS hakki % salonun HICBIRINDE "bende var" satiri uretmedi — '
      'kart tipi ekseni kullaniciyi hic eslestirmiyor (host kartinin nerede gectigini goremez).',
      v_denenen;
  end if;

  v1 := public.hangi_kartimi_kullanayim(v_v, v_u);
  if (v1 ->> 'oneri') is null then
    raise exception '216: hak verildigi halde oneri URETILMEDI → %', left(v1::text, 300);
  end if;

  if not v_vardi then
    -- YALNIZ kendi ekledigim satiri geri al.
    delete from host_entitlements
     where user_id = v_u and program_id = v_p
       and coalesce(tier,'') = coalesce(v_tier,'');
    v2 := public.hangi_kartimi_kullanayim(v_v, v_u);
    if (v2 ->> 'oneri') is not null and (select count(*) from host_entitlements where user_id=v_u) = 0 then
      raise exception '216: hak geri alindigi halde oneri HALA var → %', left(v2::text,300);
    end if;
  end if;
  raise notice '216: oneri mutasyonla kanitli (hak var → oneri var)';
end $$;

-- 4) SIRALAMA ÜRÜN KARARINI UYGULUYOR MU
-- Ücretsiz seçenek varken ücretli önerilmemeli.
do $$
declare v_v uuid; v_u uuid; v_o jsonb; v_ucretsiz int;
begin
  select id into v_u from users limit 1;
  -- Sahne: kullanıcının hakkının GEÇTİĞİ bir salon (ad değil, özellik).
  select v.id into v_v
    from lounge_venues v
    join lounge_venue_acceptance a on a.venue_id = v.id and a.active and a.accepted
    join host_entitlements h on h.program_id = a.program_id and h.user_id = v_u
   where v.active
   order by v.airport_code, v.name
   limit 1;
  if v_v is null then
    -- Hakkı olan salon yoksa bu nöbetçinin sınayacağı bir şey yok.
    select v.id into v_v from lounge_venues v
      join lounge_venue_acceptance a on a.venue_id = v.id and a.active and a.accepted
     where v.active order by v.airport_code, v.name limit 1;
  end if;
  if v_u is null or v_v is null then
    raise notice '216: sahne yok (kullanici ya da kabul satirli salon) — atlandi'; return;
  end if;
  select count(*) into v_ucretsiz
    from public.salon_misafir_karsilastirmasi(v_v, v_u)
   where bende_var and misafir_hakki = 'Ucretsiz misafir hakki var';
  v_o := public.hangi_kartimi_kullanayim(v_v, v_u);
  if v_ucretsiz > 0 and (v_o -> 'oneri' ->> 'misafir_hakki') <> 'Ucretsiz misafir hakki var' then
    raise exception '216: ucretsiz secenek varken UCRETLI onerildi → %', left(v_o::text,300);
  end if;
  raise notice '216: siralama dogru (ucretsiz varsa once o onerilir)';
end $$;

-- 5) AİLE HAKKI KAYNAKLA UYUŞUYOR MU
-- Tablo-2 (IST dış hat, TK seferi): ELPL / Elite / M&S EC → "AİLE veya
-- bir misafir". Taşıyıcı boş bırakılırsa motor Star Alliance satırını
-- seçip aileyi düşürüyordu; bu nöbetçi o gerilemeyi yakalar.
do $$
declare v_v uuid; v_aile int;
begin
  -- 🔴 Ada değil KURALA bağlı: "ELPL/ELITE/MS_EC için aile hakkı olan
  -- TK_MS kuralı bulunan salon". Aranan özelliğin kendisi bu.
  select g.venue_id into v_v
    from lounge_guest_rules g
    join lounge_programs p on p.id = g.program_id
    join lounge_venues v on v.id = g.venue_id
   where p.code = 'TK_MS' and v.active
     and coalesce(g.card_tier,'') in ('ELPL','ELITE','MS_EC')
     and coalesce(g.family_allowed, false)
   order by v.airport_code, v.name
   limit 1;
  if v_v is null then
    raise exception '216: Tablo-2 aile hakki HICBIR salonda yazili degil — '
      'ELPL/ELITE/MS_EC icin family_allowed=true olan TK_MS kurali yok (veri boslugu).';
  end if;
  select count(*) into v_aile from public.salon_misafir_karsilastirmasi(v_v, null)
   where program='TK_MS' and kart_tipi in ('ELPL','ELITE','MS_EC') and aile_dahil;
  if v_aile = 0 then
    raise exception '216: Tablo-2''ye gore ELPL/Elite/MS_EC AILE hakkina sahip ama hicbirinde aile_dahil dogru degil';
  end if;
  raise notice '216: aile hakki kaynakla uyusuyor (% kart tipinde aile dahil)', v_aile;
end $$;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '216: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '216 OK - hangi kartimi kullanayim' as sonuc;
