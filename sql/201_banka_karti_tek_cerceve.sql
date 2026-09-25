-- ============================================================
-- 201 · BANKA / KREDİ KARTI — TEK ÇERÇEVE, TABLO DEĞİL
-- 17 Ağustos 2026
--
-- ⚠️ UYGULAMAYI ETKİLER: yeni RPC'ler (`bank_card_note`,
-- `set_card_bank_coverage`) ve kart kaydına tek bir alan. Mevcut
-- imzaların hiçbiri değişmiyor.
--
-- ------------------------------------------------------------
-- KARAR: BANKA BANKA TABLO TUTMUYORUZ
-- ------------------------------------------------------------
-- Gökberk haklı: Garanti / YKB / Akbank / QNB / İş ... her bankanın
-- her kartının lounge koşulunu tek tek tablolamak
--   (a) çok yüksek efor,
--   (b) sürekli bayatlayan bir veri (kampanya başlar, biter),
--   (c) ve BİZE AİT OLMAYAN bir sorumluluk üstlenmek.
-- Kaynak zaten bunu söylüyor: Priority Pass md.4/11/18 ve DragonPass
-- 5.4 "kartı bir banka üzerinden edindiysen yukarıdakiler geçerli
-- olmayabilir" diyor. Yani PROGRAMIN KENDİSİ bankaya yetki devrediyor.
-- Biz de aynı yerde durmalıyız.
--
-- 191'de açtığım `bank_program_overrides` tablosu SİLİNMİYOR ama
-- statüsü değişiyor: ZORUNLU VERİ değil, İSTEĞE BAĞLI ÜSTÜNE YAZMA.
-- Bir gün elimize resmî bir banka sayfası geçerse o satır genel
-- cümleyi ezer; geçmezse sistem eksiksiz çalışır. Bir bekçi bunu
-- kanıtlıyor (tablo BOŞken cevap üretiliyor mu).
--
-- ------------------------------------------------------------
-- 🔴 GELİŞTİRME — "BİLMİYORUZ" İLE "SORMADIK" AYNI ŞEY DEĞİL
-- ------------------------------------------------------------
-- Mevcut çerçevenin zayıf yanı şu: kullanıcıya "bankana sor" diyoruz
-- ve orada bırakıyoruz. Ama cevabı BİLEN biri var — kullanıcının
-- kendisi. Kendi kartının misafir ücretini ödeyip ödemediğini o
-- biliyor; biz asla bilemeyiz.
--
-- Bu yüzden çerçeveye ÜÇÜNCÜ bir katman ekliyorum: KULLANICI BEYANI.
-- Kart kaydına tek bir alan (`bank_covers_fee`: evet/hayır/bilmiyorum),
-- tek dokunuş. Beyan varsa motor onu KAYNAĞIYLA BİRLİKTE söyler
-- ("senin beyanın"), yoksa genel cümleye düşer.
--
-- Kazanç ölçülebilir: 5 bankanın 30 kartını araştırmak yerine, HER
-- kullanıcı kendi kartı için tek soruyu cevaplıyor ve cevap TAM DOĞRU
-- oluyor. Araştırma maliyeti sıfır, isabet oranı %100.
--
-- 🔴 AMA BEYAN BİR KANIT DEĞİLDİR ve öyle sunulmuyor: her cümlede
-- "senin beyanın" ibaresi ve "kapıda yine de teyit et" uyarısı duruyor.
-- Bu, 114'ün "kart güveni görünür olmalı" dersinin banka hâli.
--
-- ------------------------------------------------------------
-- ÇERÇEVENİN ÜÇ KATMANI — hepsi ayrı ayrı doğru olmalı
-- ------------------------------------------------------------
--   1. BİLİYORUZ      → programın resmî sayfasından, kaynaklı
--                       ("Priority Pass'te misafir ziyareti 30 €")
--   2. BANKA DEĞİŞTİREBİLİR → neyi değiştirebildiği tek tek yazılı
--                       (hangi plan · ücreti üstlenme · ziyaret kotası)
--   3. NE YAPMALISIN  → TEK eylem, muğlak değil
--                       ("kartını veren kurumun lounge sayfasına bak")
-- Üçünü birbirine karıştırmak, bugüne kadarki tek gerçek hataydı:
-- "bankana göre değişir" cümlesi bilineni de bilinmeyene katıyordu.
-- ============================================================


-- ============================================================
-- 1) ÇERÇEVE METİNLERİ — BO'dan düzenlenebilir, deploy gerekmez
-- ============================================================
insert into beta_settings (key, value) values
  ('bank_frame_can_change',
   to_jsonb('Kartını veren kurum şunları değiştirebilir: hangi üyelik planına sahip olduğun, yıllık kaç ücretsiz ziyaret hakkın olduğu ve misafir ücretini senin yerine üstlenip üstlenmediği.'::text)),
  ('bank_frame_action',
   to_jsonb('Kartını veren kurumun lounge/ayrıcalık sayfasına bak ya da müşteri hizmetlerine tek soru sor: "Misafir girişi benim kartımdan ücretlendiriliyor mu?"'::text)),
  ('bank_frame_short',
   to_jsonb('Koşulu kartını veren kurum belirler — tutar sana yansımayabilir.'::text)),
  ('bank_frame_declared_yes',
   to_jsonb('Beyanına göre bankan misafir ücretini üstleniyor. Bu senin beyanın; kapıda yine de teyit et.'::text)),
  ('bank_frame_declared_no',
   to_jsonb('Beyanına göre misafir ücreti senin kartından çekiliyor. Bunu misafirinle konuşmakta fayda var.'::text)),
  ('bank_frame_ask_user',
   to_jsonb('Bunu yalnız sen bilebilirsin: kartını veren kurum misafir ücretini üstleniyor mu?'::text))
on conflict (key) do update set value = excluded.value;


-- ============================================================
-- 2) KULLANICI BEYANI — kart kaydına TEK alan
-- ============================================================
alter table host_entitlements
  add column if not exists bank_covers_fee text;

alter table host_entitlements drop constraint if exists he_bank_covers_chk;
alter table host_entitlements add constraint he_bank_covers_chk
  check (bank_covers_fee is null or bank_covers_fee in ('yes','no','unknown'));

comment on column host_entitlements.bank_covers_fee is
  '201: KULLANICI BEYANI — kartı veren kurum misafir ücretini üstleniyor mu? '
  'yes | no | unknown | NULL(hiç sorulmadı). Bir kanıt değil, bir beyandır; '
  'motor her zaman "senin beyanın" diye etiketler.';

-- Yazma yolu. 🔴 SAHİPLİK ŞARTI: 193''ün dersi — kolon eklemek yazma
-- yolunu açmak değildir; ve yazma yolu sahibi doğrulamadan açılmaz.
create or replace function public.set_card_bank_coverage(p_entitlement_id uuid, p_value text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_val text := nullif(btrim(lower(coalesce(p_value,''))),'');
begin
  if v_val is not null and v_val not in ('yes','no','unknown') then
    raise exception 'gecersiz_deger';
  end if;
  select user_id into v_owner from host_entitlements where id = p_entitlement_id;
  if v_owner is null then raise exception 'kart_yok'; end if;
  if v_owner <> auth.uid() then raise exception 'not_owner'; end if;

  update host_entitlements
     set bank_covers_fee = v_val,
         self_reported_at = now()
   where id = p_entitlement_id;

  return jsonb_build_object('ok', true, 'bank_covers_fee', v_val);
end $$;
grant execute on function public.set_card_bank_coverage(uuid, text) to authenticated;


-- ============================================================
-- 3) TEK ÇERÇEVE FONKSİYONU
-- ============================================================
-- Bütün ekranlar (app kartı, keşif rozeti, istek ekranı, BO) buradan
-- okuyacak. Cümle BİR YERDE yazılı; değiştirmek isteyen BO'dan
-- `bank_frame_*` anahtarını değiştirir, kod dokunulmaz.
--
-- 🔴 `p_entitlement_id` İSTEĞE BAĞLI: verilmezse genel çerçeve döner
-- (keşif listesi gibi kart bilinmeyen yerler için). Verilirse beyan
-- katmanı da devreye girer.
create or replace function public.bank_card_note(
  p_program_code   text,
  p_entitlement_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_code  text := upper(btrim(coalesce(p_program_code,'')));
  p       lounge_programs%rowtype;
  v_plan  record;
  v_he    host_entitlements%rowtype;
  v_ovr   record;
  v_bilinen text;
  v_beyan   text := null;
  v_kaynak  text := null;
  v_guven   text := 'genel';
begin
  select * into p from lounge_programs where code = v_code and active;
  if not found then
    return jsonb_build_object('bank_dependent', false);
  end if;

  -- Bankaya bağlı olmayan programlarda (THY statüsü gibi) bu çerçeve
  -- HİÇ gösterilmez. Yanlış yerde gösterilen doğru bir uyarı, gürültüdür.
  if not (p.entitlement_model in ('card_network','bank_card')
          or v_code in ('PRIORITY_PASS','DRAGONPASS','LOUNGEKEY','DREAMFOLKS',
                        'EVERYLOUNGE','ONPASS','AMEX_GLOBAL','BANK_CARD','HIGHPASS','LOUNGEME')) then
    return jsonb_build_object('bank_dependent', false);
  end if;

  -- ---- KATMAN 1: BİLİYORUZ (kaynaklı) ----
  select pl.guest_visit_fee, pl.currency, pl.source_url
    into v_plan
    from program_plans pl
   where pl.active and pl.program_code = v_code
   order by pl.annual_fee nulls last
   limit 1;

  if v_plan.guest_visit_fee is not null then
    v_bilinen := p.name || ' plan sayfasına göre misafir ziyareti ziyaret başına '
              || v_plan.guest_visit_fee::text || ' ' || v_plan.currency
              || ' ve tutar ÜYENİN kartından tahsil edilir.';
    v_kaynak  := v_plan.source_url;
  elsif p.typical_guest_fee is not null then
    v_bilinen := p.name || ': misafir ziyareti ücretlidir (yaklaşık '
              || p.typical_guest_fee::text || ' ' || coalesce(p.guest_fee_currency,'EUR') || ').';
    v_kaynak  := p.source_url;
  else
    v_bilinen := p.name || ': misafir hakkının ve ücretinin ne olduğu program '
              || 'sayfasında tutara bağlanmamış.';
    v_kaynak  := p.source_url;
  end if;

  -- ---- KATMAN 3'ÜN ÜSTÜNE: KULLANICI BEYANI ----
  if p_entitlement_id is not null then
    select * into v_he from host_entitlements
     where id = p_entitlement_id and user_id = auth.uid();
    if found then
      if v_he.bank_covers_fee = 'yes' then
        v_beyan := (select value #>> '{}' from beta_settings where key = 'bank_frame_declared_yes');
        v_guven := 'beyan_var';
      elsif v_he.bank_covers_fee = 'no' then
        v_beyan := (select value #>> '{}' from beta_settings where key = 'bank_frame_declared_no');
        v_guven := 'beyan_var';
      else
        v_beyan := (select value #>> '{}' from beta_settings where key = 'bank_frame_ask_user');
        v_guven := 'beyan_yok';
      end if;

      -- ---- İSTEĞE BAĞLI ÜSTÜNE YAZMA (191'in tablosu) ----
      -- Tablo BOŞSA hiçbir şey olmaz; doluysa genel çerçeveyi EZER.
      if coalesce(v_he.bank_code,'') <> '' then
        select bo.guest_fee, bo.fee_payer, bo.source_url, bo.bank_name
          into v_ovr
          from bank_program_overrides bo
         where bo.active and bo.program_id = p.id
           and upper(bo.bank_code) = upper(v_he.bank_code)
           and (bo.card_product is null or bo.card_product = v_he.card_product)
         order by (bo.card_product is null)
         limit 1;
        if found then
          v_bilinen := coalesce(v_ovr.bank_name, v_he.bank_code) || ' için kayıtlı koşul: '
                    || case when v_ovr.guest_fee is not null
                            then 'misafir ücreti ' || v_ovr.guest_fee::text || ' EUR'
                            else 'misafir ücreti belirtilmemiş' end
                    || case when v_ovr.fee_payer is not null
                            then ' · ödeyen: ' || v_ovr.fee_payer else '' end || '.';
          v_kaynak := coalesce(v_ovr.source_url, v_kaynak);
          v_guven  := 'banka_kayitli';
        end if;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'bank_dependent', true,
    'program', p.name,
    'guven', v_guven,                        -- genel | beyan_yok | beyan_var | banka_kayitli
    'biliyoruz', v_bilinen,
    'banka_degistirebilir', (select value #>> '{}' from beta_settings where key = 'bank_frame_can_change'),
    'ne_yapmalisin', (select value #>> '{}' from beta_settings where key = 'bank_frame_action'),
    'kisa', (select value #>> '{}' from beta_settings where key = 'bank_frame_short'),
    'beyan', v_beyan,
    'beyan_degeri', v_he.bank_covers_fee,
    'kaynak_url', v_kaynak);
end $$;
grant execute on function public.bank_card_note(text, uuid) to authenticated, anon;


-- ============================================================
-- 4) KART LİSTESİ BEYANI DA DÖNDÜRSÜN
-- ============================================================
-- 🔴 App kart ekranında soruyu SORABİLMEK için önce cevabı BİLMESİ
-- gerekiyor. `my_access_cards()` bugüne kadar `bank_dependent` diyordu
-- ama beyanı döndürmüyordu — yani ekran "sordum mu sormadım mı"
-- bilmiyordu ve soruyu her açılışta yeniden sorardı.
drop function if exists public.my_access_cards();

create or replace function public.my_access_cards()
returns table (
  id uuid, program_code text, program_name text, tier text, card_label text,
  guest_capacity smallint, bank_code text, card_product text,
  verified boolean, bank_dependent boolean,
  -- 201:
  bank_covers_fee text, bank_note jsonb
)
language plpgsql stable security definer set search_path = public as $$
begin
  return query
  select he.id, p.code::text, p.name::text, he.tier::text, he.card_label::text,
         he.guest_capacity, he.bank_code::text, he.card_product::text,
         coalesce(he.verified, false),
         (p.entitlement_model in ('card_network','bank_card')
          or p.code in ('PRIORITY_PASS','DRAGONPASS','LOUNGEKEY','DREAMFOLKS',
                        'EVERYLOUNGE','ONPASS','AMEX_GLOBAL','BANK_CARD','HIGHPASS','LOUNGEME')),
         he.bank_covers_fee::text,
         public.bank_card_note(p.code, he.id)
    from host_entitlements he
    join lounge_programs p on p.id = he.program_id
   where he.user_id = auth.uid() and p.active
   order by he.verified desc nulls last, p.code, coalesce(he.card_label,'');
end $$;
grant execute on function public.my_access_cards() to authenticated;


-- ============================================================
-- BEKÇİLER
-- ============================================================

-- 1) BANKA TABLOSU BOŞKEN SİSTEM ÇALIŞIYOR MU
-- 🔴 Bu bekçinin tamamı "veri yokluğu bir arıza DEĞİLDİR"i kanıtlar.
-- `bank_program_overrides` bilerek boş; cevap yine de üç katmanlı gelmeli.
do $$
declare v_n int; v jsonb;
begin
  select count(*) into v_n from bank_program_overrides where active;
  v := public.bank_card_note('PRIORITY_PASS', null);
  if not coalesce((v ->> 'bank_dependent')::boolean, false) then
    raise exception '201: Priority Pass bankaya bagli isaretlenmedi';
  end if;
  if coalesce(v ->> 'biliyoruz','') = '' or coalesce(v ->> 'banka_degistirebilir','') = ''
     or coalesce(v ->> 'ne_yapmalisin','') = '' then
    raise exception '201: cerceveni ucu katmanindan biri BOS → %', v;
  end if;
  if position('30' in coalesce(v ->> 'biliyoruz','')) = 0 then
    raise exception '201: BILIYORUZ katmani tutari tasimiyor → %', v ->> 'biliyoruz';
  end if;
  raise notice '201: banka tablosu % satirken bile ucu katman doluyor (veri yoklugu ariza degil)', v_n;
end $$;

-- 2) BANKAYA BAĞLI OLMAYAN PROGRAMDA ÇERÇEVE GÖSTERİLMEMELİ
-- Yanlış yerde gösterilen doğru bir uyarı gürültüdür ve zamanla
-- kullanıcı BÜTÜN uyarıları okumaz hâle gelir.
do $$
declare v jsonb;
begin
  v := public.bank_card_note('TK_MS', null);
  if coalesce((v ->> 'bank_dependent')::boolean, false) then
    raise exception '201: THY statusunde banka cercevesi gosteriliyor — gurultu';
  end if;
  v := public.bank_card_note('AJET_MS', null);
  if coalesce((v ->> 'bank_dependent')::boolean, false) then
    raise exception '201: AJet statusunde banka cercevesi gosteriliyor — gurultu';
  end if;
  raise notice '201: havayolu statulerinde banka cercevesi GOSTERILMIYOR';
end $$;

-- 3) BEYAN YOLU UÇTAN UCA ÇALIŞIYOR MU
do $$
declare v_uid uuid; v_he uuid; v jsonb; v_prog uuid;
begin
  select id into v_uid from users where email like 'kmisafir1%' limit 1;
  select id into v_prog from lounge_programs where code = 'PRIORITY_PASS';
  if v_uid is null or v_prog is null then
    raise notice '201: seed yok — beyan kanidi atlandi'; return;
  end if;

  insert into host_entitlements (user_id, program_id, origin, card_label, bank_code)
  values (v_uid, v_prog, 'declared', '201-bekci', 'TESTBANK')
  returning id into v_he;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role','authenticated')::text, true);

  -- (a) beyan YOKKEN: soru sorulmalı
  v := public.bank_card_note('PRIORITY_PASS', v_he);
  if coalesce(v ->> 'guven','') <> 'beyan_yok' then
    perform set_config('request.jwt.claims','{}',true);
    delete from host_entitlements where id = v_he;
    raise exception '201: beyan yokken guven "%s" (beyan_yok bekleniyor)', v ->> 'guven';
  end if;

  -- (b) beyan YAZILINCA: cümle değişmeli
  perform public.set_card_bank_coverage(v_he, 'yes');
  v := public.bank_card_note('PRIORITY_PASS', v_he);
  if coalesce(v ->> 'guven','') <> 'beyan_var'
     or position('beyan' in lower(coalesce(v ->> 'beyan',''))) = 0 then
    perform set_config('request.jwt.claims','{}',true);
    delete from host_entitlements where id = v_he;
    raise exception '201: beyan yazildi ama cevap degismedi → %', v;
  end if;

  -- (c) BEYAN BİR KANIT DEĞİL: "kapıda teyit" uyarısı kalmalı
  if position('teyit' in lower(coalesce(v ->> 'beyan',''))) = 0 then
    perform set_config('request.jwt.claims','{}',true);
    delete from host_entitlements where id = v_he;
    raise exception '201: beyan cumlesinde "kapida teyit et" uyarisi YOK — beyan kanit gibi sunuluyor';
  end if;

  -- (d) BAŞKASININ KARTINA YAZILAMAMALI
  declare v_bloklandi boolean := false; v_other uuid;
  begin
    select id into v_other from users where id <> v_uid limit 1;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_other, 'role','authenticated')::text, true);
    begin
      perform public.set_card_bank_coverage(v_he, 'no');
    exception when others then v_bloklandi := true;
    end;
    if not v_bloklandi then
      perform set_config('request.jwt.claims','{}',true);
      delete from host_entitlements where id = v_he;
      raise exception '201: BASKASININ kartina beyan yazilabiliyor';
    end if;
  end;

  perform set_config('request.jwt.claims','{}',true);
  delete from host_entitlements where id = v_he;
  raise notice '201: beyan yolu uctan uca calisiyor (yok → var → kanit degil → sahiplik korumali)';
end $$;

-- 4) my_access_cards BEYANI VE ÇERÇEVEYİ TAŞIYOR MU
do $$
declare v_res text;
begin
  select pg_get_function_result(oid) into v_res from pg_proc
   where proname = 'my_access_cards' and pronamespace = 'public'::regnamespace;
  if position('bank_covers_fee' in v_res) = 0 or position('bank_note' in v_res) = 0 then
    raise exception '201: my_access_cards beyani/cerceveyi DONDURMUYOR → %', v_res;
  end if;
  raise notice '201: my_access_cards beyan + cerceve tasiyor';
end $$;

-- 5) ÇERÇEVE METİNLERİ BO''DAN DEĞİŞTİRİLEBİLİR (tek kaynak kanıtı)
do $$
declare v_eski text; v jsonb;
begin
  select value #>> '{}' into v_eski from beta_settings where key = 'bank_frame_short';
  update beta_settings set value = to_jsonb('201-mutasyon'::text) where key = 'bank_frame_short';
  v := public.bank_card_note('DRAGONPASS', null);
  if coalesce(v ->> 'kisa','') <> '201-mutasyon' then
    update beta_settings set value = to_jsonb(v_eski) where key = 'bank_frame_short';
    raise exception '201: cerceve metni BO ayarindan okunmuyor — kodda gomulu';
  end if;
  update beta_settings set value = to_jsonb(v_eski) where key = 'bank_frame_short';
  raise notice '201: cerceve metinleri BO ayarindan okunuyor (deploy gerekmez)';
end $$;

select '201 OK - banka/kart cercevesi tek kaynakta, beyan katmani acildi' as sonuc;
