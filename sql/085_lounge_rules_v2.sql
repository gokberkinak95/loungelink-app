-- ============================================================
-- LoungeLink · 085_lounge_rules_v2.sql
--
-- 083 kural TABLOSUNU kurdu. Bu dosya üç eksiği kapatır:
--
-- 1) KURAL SETİ EKSİKTİ: AJet ve Star Alliance satırları hiç yoktu, giriş
--    saat pencereleri (IST iç hat 4/6 saat) ve charter engeli girilmemişti,
--    "misafir hakkı yok" satırlarına gereksiz "misafir aynı havayolunda
--    uçmalı" kısıtı yazılmıştı (hak 0 iken o kısıt anlamsız gürültü).
--
-- 2) 🔴 MODELİN UYGULAMAYA BAĞLANAMAZ OLMASI — asıl mesele buydu:
--    Kural matrisi HOST'un kart tipini ve kabin sınıfını istiyor. Ama
--    uygulama host'a bunları HİÇ SORMUYOR (yalnız erişim kaynağı +
--    misafir hakkı soruyoruz). Yani matris olduğu gibi hiçbir zaman
--    değerlendirilemezdi. Çözüm: karmaşıklığı BO'da tutup uygulamaya
--    TEK SATIRLIK KARAR vermek. availability_rule_snapshot() bir ilan
--    için "misafirin hangi havayolunda uçması gerekiyor + en erken kaç
--    saat önce + insan diliyle not" üretir. Uygulama matrisi hiç görmez.
--
-- 3) VERİ SAĞLIĞI: lounge_rules_health() eksik/bayat kuralları listeler.
--
-- ⚠️ UYGULAMAYA ETKİSİ YOK: yeni kolonlar nullable ve BOŞ; hiçbir mevcut
-- fonksiyon değişmiyor. Kural motorunun akışlara bağlanması ayrı adım.
-- ============================================================


-- ---------- 1) Anlamsız kısıtı temizle: hak 0 ise taşıyıcı şartı gürültü ----------
update lounge_guest_rules
   set guest_must_match_carrier = false, guest_carrier_whitelist = null
 where guest_allowance = 0 and guest_must_match_carrier = true;


-- ---------- 2) EKSİK KURALLAR ----------

-- AJet: Miles&Smiles kartıyla AJet seferinde salon kullanımı — misafir hakkı
-- tanımlı DEĞİL. "Bilinmiyor" ile "hak yok" farklı şeyler; bunu açıkça yazıyoruz.
insert into lounge_guest_rules
 (program_id, carrier, card_tier, guest_allowance, family_allowed,
  guest_must_match_carrier, paid_entry_allowed, notes)
select p.id, 'AJET', t.tier, 0, false, false, true,
       'AJet seferlerinde Miles&Smiles kart sahibi salona girebilir; MİSAFİR HAKKI TANIMLI DEĞİL. Misafir getirmek isteyen host AJet ilanı açmamalı.'
  from lounge_programs p, (values ('ELPL'),('ELITE'),('CLPL'),('CLASSIC')) as t(tier)
 where p.code = 'AJET_MS'
 on conflict do nothing;

-- Star Alliance Gold: dış hat salonu, misafir hakkı 1 ama AİLE hakkı yok
insert into lounge_guest_rules
 (program_id, carrier, card_tier, cabin_class, guest_allowance, family_allowed,
  guest_must_match_carrier, guest_carrier_whitelist, notes)
select p.id, 'STAR_ALLIANCE', 'ELPL', null, 1, false, false,
       array['TK','LH','OS','LX','SK','SN','A3','AC','UA','NH','SQ','TG','ET','MS','SA'],
       'Star Alliance Gold: dış hat salonunda 1 misafir; misafirin Star Alliance üyesi bir havayolunda uçması gerekir.'
  from lounge_programs p where p.code = 'TK_MS'
 on conflict do nothing;

-- IST iç hat: ücretli giriş pencereleri (4 saat / bağlantılıysa 6 saat)
insert into lounge_guest_rules
 (program_id, venue_id, carrier, card_tier, guest_allowance, family_allowed,
  paid_entry_allowed, earliest_entry_hours, notes)
select p.id, v.id, 'TK', 'CLASSIC', 0, false, true, 4,
       'IST iç hat: ücretli giriş mümkün, en erken kalkıştan 4 saat önce (bağlantılı yolcu 6 saat). Ücretli girenler yalnız Miles&Smiles bölümünü kullanabilir.'
  from lounge_programs p, lounge_venues v
 where p.code='TK_MS' and v.airport_code='IST' and v.scope='domestic'
 on conflict do nothing;

-- Charter: mutlak engel (bilet Business olsa bile salon hakkı yok)
insert into lounge_guest_rules
 (program_id, carrier, card_tier, cabin_class, guest_allowance, blocked_reason, notes)
select p.id, null, null, null, 0,
       'Charter seferde salon hakkı yok',
       'Charter (tarifesiz) seferlerde bilet sınıfı ne olursa olsun salon kullanımı yok.'
  from lounge_programs p where p.code='TK_MS'
 on conflict do nothing;


-- ============================================================
-- 3) UYGULAMA İÇİN TEK SATIRLIK KARAR
-- Karmaşıklık BO'da kalır; uygulama yalnız bu çıktıyı görür.
-- ============================================================
alter table availabilities add column if not exists guest_carrier_required text[];
alter table availabilities add column if not exists rule_entry_hours       numeric;
alter table availabilities add column if not exists rule_note              text;

-- Bir ilan için kuralları TEK karara indirger.
-- Uygulama bunu ilan açarken (bilgi notu) ve keşifte (kapı) kullanacak.
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.availability_rule_snapshot(uuid);
create or replace function public.availability_rule_snapshot(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_av availabilities%rowtype; v_prog text; v_r lounge_guest_rules%rowtype;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('known', false); end if;

  -- Program: ilanda seçilmişse onu kullan; yoksa host'un beyan ettiği
  -- erişim kaynağından tahmin et (Priority Pass / LoungeKey / DragonPass /
  -- havayolu programı). Beyan serbest metin olduğu için eşleşmezse "bilinmiyor".
  select p.code into v_prog
    from lounge_programs p
    left join profiles pr on pr.user_id = v_av.host_id
   where (v_av.program_id is not null and p.id = v_av.program_id)
      or (v_av.program_id is null and pr.access_source ilike '%' || replace(initcap(replace(p.code,'_',' ')),' ','%') || '%')
   limit 1;

  if v_prog is null then
    return jsonb_build_object('known', false,
      'note', 'Bu ilanın lounge programı belirlenemedi — kapıda teyit gerekir.');
  end if;

  select r.* into v_r
    from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
   where p.code = v_prog
     and (r.venue_id is null or r.venue_id = v_av.venue_id)
     and (r.carrier is null or r.carrier = coalesce(v_av.carrier, r.carrier))
     and r.guest_allowance > 0            -- misafir ALINABİLEN kural aranıyor
     and r.blocked_reason is null
   order by (r.venue_id is not null) desc, (r.carrier is not null) desc
   limit 1;

  if not found then
    return jsonb_build_object('known', true, 'guest_allowed', false,
      'note', 'Bu program/salon için kayıtlı misafir hakkı bulunmuyor.');
  end if;

  return jsonb_build_object(
    'known', true, 'guest_allowed', true, 'program', v_prog,
    'guest_carrier_required',
      case when v_r.guest_must_match_carrier and v_av.carrier is not null then to_jsonb(array[v_av.carrier])
           when v_r.guest_carrier_whitelist is not null then to_jsonb(v_r.guest_carrier_whitelist)
           else 'null'::jsonb end,
    'earliest_entry_hours', v_r.earliest_entry_hours,
    'note', v_r.notes
  );
end $$;
grant execute on function public.availability_rule_snapshot(uuid) to authenticated;

-- İlanın üzerindeki basit alanları kuraldan doldurur (ilan açılırken
-- çağrılacak — ŞİMDİ hiçbir yerden çağrılmıyor, app etkilenmiyor).
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.apply_rule_snapshot(uuid);
create or replace function public.apply_rule_snapshot(p_avail_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v jsonb; v_carriers text[];
begin
  v := public.availability_rule_snapshot(p_avail_id);
  if (v ->> 'known') = 'true' and (v ->> 'guest_allowed') = 'true' then
    if v -> 'guest_carrier_required' <> 'null'::jsonb then
      select array_agg(x) into v_carriers from jsonb_array_elements_text(v -> 'guest_carrier_required') as t(x);
    end if;
    update availabilities
       set guest_carrier_required = v_carriers,
           rule_entry_hours = nullif(v ->> 'earliest_entry_hours','')::numeric,
           rule_note = v ->> 'note'
     where id = p_avail_id;
  else
    update availabilities set rule_note = v ->> 'note' where id = p_avail_id;
  end if;
  return v;
end $$;
grant execute on function public.apply_rule_snapshot(uuid) to authenticated;

-- Misafir tarafı kapısı: "bu misafirin uçuşu bu ilana uygun mu?"
-- Tek boolean + insan diliyle sebep. Keşif ve istek ekranı bunu kullanacak.
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.guest_flight_fits(uuid, text);
create or replace function public.guest_flight_fits(p_avail_id uuid, p_flight_no text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_av availabilities%rowtype; v_carrier text;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('fits', true); end if;
  if v_av.guest_carrier_required is null or array_length(v_av.guest_carrier_required,1) is null then
    return jsonb_build_object('fits', true);          -- kural yok → serbest
  end if;
  v_carrier := upper(substring(coalesce(p_flight_no,'') from '^[A-Za-z]+'));
  if v_carrier = '' then
    return jsonb_build_object('fits', true, 'soft', true,
      'reason', format('Bu salonun kuralı: misafirin %s seferinde uçuyor olmalı. Uçuş numaranı eklersen kontrol edebiliriz.',
                        array_to_string(v_av.guest_carrier_required, ' / ')));
  end if;
  if v_carrier = any(v_av.guest_carrier_required) then
    return jsonb_build_object('fits', true);
  end if;
  return jsonb_build_object('fits', false,
    'reason', format('Bu salon yalnızca %s seferinde uçan misafirleri kabul ediyor; uçuşun %s.',
                      array_to_string(v_av.guest_carrier_required, ' / '), p_flight_no));
end $$;
grant execute on function public.guest_flight_fits(uuid, text) to authenticated;


-- ============================================================
-- 4) VERİ SAĞLIĞI — BO'da "eksik ne var?" listesi
-- ============================================================
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.lounge_rules_health();
create or replace function public.lounge_rules_health()
returns table (program text, issue text, detail text)
language sql stable security definer set search_path = public as $$
  -- hiç kuralı olmayan program
  select p.name, 'kural yok', 'Bu program için hiç kural girilmemiş'
    from lounge_programs p
   where p.active and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id)
  union all
  -- doğrulanmamış veya bayat program
  select p.name, 'bayat kural',
         coalesce('Son doğrulama: ' || p.checked_at::text, 'Hiç doğrulanmadı')
    from lounge_programs p
   where p.active and (p.checked_at is null or p.checked_at < current_date - 90)
  union all
  -- kaynak URL'i olmayan program (kural nereden geldi belirsiz)
  select p.name, 'kaynak yok', 'Resmî kaynak URL girilmemiş'
    from lounge_programs p where p.active and coalesce(p.source_url,'') = ''
  union all
  -- misafir hakkı olan ama taşıyıcı şartı belirsiz kural
  select p.name, 'taşıyıcı şartı belirsiz',
         format('kart=%s kabin=%s → hak %s ama misafir taşıyıcı kuralı tanımsız',
                coalesce(r.card_tier,'-'), coalesce(r.cabin_class,'-'), r.guest_allowance)
    from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
   where r.guest_allowance > 0 and not r.guest_must_match_carrier
     and r.guest_carrier_whitelist is null
  union all
  -- salonu olmayan havalimanı (ilan açılabilir ama kural bağlanamaz)
  select a.code, 'salon tanımı yok', 'Bu havalimanı için lounge_venues kaydı yok'
    from airports a
   where not exists (select 1 from lounge_venues v where v.airport_code = a.code)
     and exists (select 1 from availabilities av where av.airport_code = a.code);
$$;
grant execute on function public.lounge_rules_health() to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select (select count(*) from lounge_guest_rules) as kural_sayisi,
       (select count(*) from lounge_guest_rules where guest_allowance = 0 and guest_must_match_carrier) as anlamsiz_kisit;

-- Sağlık listesi (boş olması beklenmez — eksikleri göstermek için var)
select * from public.lounge_rules_health() order by program limit 20;

select '085 OK - kural seti tamamlandi, uygulamaya tek satirlik karar katmani hazir (app ETKILENMEDI)' as sonuc;
