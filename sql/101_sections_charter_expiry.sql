-- ============================================================
-- LoungeLink · 101_sections_charter_expiry.sql
-- KALAN ÜÇ BOŞLUK
--
-- ⚠️ Uygulamayı ETKİLER (veri + karar metni). App sürümü gerekmez:
-- host'un gördüğü salon listesi ve kural metni sunucudan geliyor.
--
-- 1) BÖLÜM SEÇİMİNİ HOST'A SORUYORDUK — AMA HOST SEÇMİYOR
-- 2) CHARTER ENGELİ VERİDE VAR, TESPİT EDEN YOK
-- 3) TARİFE 31 ARALIK 2026'DA SESSİZCE BİTİYOR
-- ============================================================


-- ============================================================
-- 1) BÖLÜM: SORMA, TÜRET
--
-- 🔴 SORUN: IST salonlarını Business / Miles&Smiles diye ikiye ayırdım
-- ve host'a SEÇTİRDİM. Ama hangi bölüme gireceğine KAPIDAKİ GÖREVLİ
-- karar veriyor (bilet sınıfı + kart tipine göre), host değil. Host'a
-- kontrol edemediği bir şeyi seçtirmek, yanlış seçimi de ona yüklüyor.
--
-- ÇÖZÜM: bölümler artık ALT KAYIT. Katalogda salonun TEK adı görünür
-- ("Turkish Airlines Lounge — Dış Hat"). Bölüm kararını motor verir ve
-- host'a EYLEM olarak söyler: "misafirle girmek için Miles&Smiles
-- bölümünü iste". Çünkü LoungeLink'te host HER ZAMAN misafirle giriyor;
-- yani doğru bölüm her zaman misafire izin veren bölümdür.
-- ============================================================
alter table lounge_venues add column if not exists section_of uuid references lounge_venues(id);
comment on column lounge_venues.section_of is
  'Bu satir bir salonun BOLUMU ise ust salonun id''si. Bolumler katalogda '
  'GORUNMEZ; host salonu secer, bolumu karar motoru turetir.';

-- Bölümü olan her salon için üst kayıt (section = null) yarat
-- 🔴 KORUMA KOSULU KISITLA AYNI OLMALI.
-- Benzersiz indeks: (airport_code, name, coalesce(section,'')) — TERMINAL YOK.
-- Onceki halde `not exists` terminali de karsilastiriyordu: koruma geciyor,
-- indeks reddediyordu (23505). Ayni tuzak 099'da da vardi.
-- Kontrol artik indeksin gordugu uc alani kullaniyor; ustune `on conflict`
-- ile ikinci bir emniyet var (dosya tekrar calistirilabilsin diye).
insert into lounge_venues (airport_code, name, terminal, operator, scope, venue_kind, notes)
select distinct on (v.airport_code, lower(trim(v.name)))
       v.airport_code, v.name, v.terminal, v.operator, v.scope, 'lounge',
       'Bolumlu salon. Misafir hakki bolume gore degisir; bolum karar motorunda turetilir.'
  from lounge_venues v
 where v.section is not null and v.section_of is null
   and not exists (select 1 from lounge_venues u
                    where u.airport_code = v.airport_code
                      and lower(trim(u.name)) = lower(trim(v.name))
                      and u.section is null)
 order by v.airport_code, lower(trim(v.name)), v.id
on conflict (airport_code, name, coalesce(section, '')) do nothing;

-- Ust salon eslemesi de ayni uc alanla (terminal DEGIL).
update lounge_venues v set section_of = u.id
  from lounge_venues u
 where v.section is not null and v.section_of is null
   and u.section is null
   and u.airport_code = v.airport_code
   and lower(trim(u.name)) = lower(trim(v.name))
   and u.id <> v.id;

-- 🔴 Bölümler katalogdan çıkar; host yalnız ÜST salonu görür
update lounges l set active = false
  from lounge_venues v
 where l.venue_id = v.id and v.section_of is not null and l.active;

-- 099'dan sonra ad zaten terminali tasiyor; tekrar eklemiyoruz.
insert into lounges (airport_code, name, terminal, active, venue_id)
select v.airport_code::char(3), v.name, v.terminal, true, v.id
  from lounge_venues v
 where v.venue_kind = 'lounge' and v.section is null and v.section_of is null
   and not exists (select 1 from lounges l where l.venue_id = v.id);
update lounge_venues v set legacy_lounge_id = l.id
  from lounges l where v.legacy_lounge_id is null and l.venue_id = v.id;

-- Üst salon için kabul satırı: MİSAFİRE İZİN VEREN bölümden türetilir
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, max_stay_hours, earliest_entry_hours, enforcement,
   conditions, source_url, checked_at)
select u.id, a.program_id, a.accepted, a.guest_policy, a.guest_included_count,
       a.guest_flight_coupling, a.max_stay_hours, a.earliest_entry_hours, a.enforcement,
       coalesce(a.conditions,'') || ' 🔴 Bu salon BÖLÜMLÜ: misafirle girmek için '
         || 'girişte MILES&SMILES bölümünü iste. Business bölümünde misafir/aile '
         || 'hakkı yoktur; Business bileti olsa bile misafir götürecek yolcu '
         || 'Miles&Smiles bölümüne yönlendirilmelidir.',
       a.source_url, a.checked_at
  from lounge_venues c
  join lounge_venues u on u.id = c.section_of
  join lounge_venue_acceptance a on a.venue_id = c.id
 where c.section = 'miles_smiles'
on conflict (venue_id, program_id) do update set
  guest_policy = excluded.guest_policy,
  guest_included_count = excluded.guest_included_count,
  conditions = excluded.conditions, checked_at = excluded.checked_at;


-- ============================================================
-- 2) CHARTER
--
-- 🔴 THY: "Charter seferde seyahat eden yolcunun THY business class
-- bileti VEYA STATÜ KARTI OLSA DAHİ salon kullanım hakkı bulunmamaktadır."
--
-- Charter'ı uçuş numarasından güvenilir biçimde ANLAYAMAYIZ (tarifeli
-- ve charter aynı kod aralığını kullanabiliyor). Uydurma bir tespit
-- yazmak yerine HOST'A SORUYORUZ — tek kutu, varsayılan "tarifeli".
-- Bilmediğimizi tahmin etmek yerine sormak, bu üründe hep daha ucuz.
-- ============================================================
alter table availabilities add column if not exists is_charter boolean;
comment on column availabilities.is_charter is
  'Host beyani: bu sefer charter mi? Charter''da THY/AJet salon hakki YOKTUR '
  '(business bileti ya da statu karti olsa bile). null = sorulmadi.';

create or replace function public.charter_note(p_avail_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select case
    when a.is_charter is true then jsonb_build_object(
      'blocked', true,
      'note', 'Charter seferde THY/AJet salon kullanim hakki YOKTUR — business bileti '
           || 'ya da statu karti olsa bile. Istisna: charter anlasmasi yapan acente '
           || 'yolcularina salon hakki satin almissa gecerlidir; bunu acentenden teyit et.')
    when a.is_charter is null then jsonb_build_object(
      'blocked', false,
      'note', 'Seferin tarifeli mi charter mi belirtilmemis. Charter seferde salon hakki '
           || 'olmaz — emin degilsen biletini kontrol et.')
    else jsonb_build_object('blocked', false, 'note', null)
  end
  from availabilities a where a.id = p_avail_id;
$$;
grant execute on function public.charter_note(uuid) to authenticated;


-- ============================================================
-- 3) TARİFENİN SON KULLANMA TARİHİ
--
-- 🔴 THY ve AJet tarifeleri "1 Haziran 2026 – 31 Aralık 2026" aralığı
-- için yayınlandı ve kurallara effective_to = 2026-12-31 yazdım.
-- O tarihten sonra `lounge_guest_rules` sorgusu BOŞ dönecek ve motor
-- sessizce program varsayılanına düşecek — yani yanlış bir cevabı
-- kimseye haber vermeden vermeye başlayacak.
-- Sessiz bozulma, gürültülü bozulmadan çok daha tehlikelidir.
-- ============================================================
create or replace function public.rules_expiring(p_days int default 45)
returns table (program text, card_tier text, effective_to date, kalan_gun int)
language sql stable security definer set search_path = public as $$
  select p.name, r.card_tier, r.effective_to,
         (r.effective_to - current_date)::int
    from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
   where r.effective_to is not null
     and r.effective_to <= current_date + p_days
   order by r.effective_to, p.name;
$$;
grant execute on function public.rules_expiring(int) to authenticated;

-- Sağlık raporuna eklensin ki BO'da görünsün
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.lounge_rules_health();
create or replace function public.lounge_rules_health()
returns table (alan text, sorun text, ayrinti text, agirlik int)
language sql stable security definer set search_path = public as $$
  select v.airport_code || ' · ' || v.name, 'kabul matrisi bos',
         'Bu salon icin hicbir program kabul satiri yok', 1
    from lounge_venues v
   where v.active and v.section_of is null and not exists (
         select 1 from lounge_venue_acceptance a where a.venue_id = v.id)
  union all
  select v.airport_code || ' · ' || v.name, 'kabul dogrulanmadi',
         p.name || ' — ' || coalesce('son dogrulama ' || a.checked_at::text, 'hic dogrulanmadi'), 2
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where a.active and (a.checked_at is null or a.checked_at < current_date - 90)
  union all
  select v.airport_code || ' · ' || v.name, 'misafir politikasi bilinmiyor',
         p.name || ' — lounge gorusmesinde sorulacak', 2
    from lounge_venue_acceptance a
    join lounge_venues v on v.id = a.venue_id
    join lounge_programs p on p.id = a.program_id
   where a.active and a.accepted and a.guest_policy = 'unknown'
  union all
  -- 🔴 YENİ: son kullanma tarihi yaklasan tarife
  select p.name, 'tarife bitiyor',
         coalesce(r.card_tier,'tum kartlar') || ' — ' || r.effective_to::text
         || ' tarihinde bitiyor (' || (r.effective_to - current_date)::text || ' gun). '
         || 'Yenilenmezse kural motoru SESSIZCE program varsayilanina duser.', 1
    from lounge_guest_rules r join lounge_programs p on p.id = r.program_id
   where r.effective_to is not null and r.effective_to <= current_date + 45
  union all
  select p.name, 'program modeli eksik',
         'entitlement_model / guest_default / guest_flight_coupling bos', 1
    from lounge_programs p
   where p.active and (p.entitlement_model is null or p.guest_default is null
                       or p.guest_flight_coupling is null)
  union all
  select p.name, 'kaynak yok', 'Resmi kaynak URL girilmemis', 3
    from lounge_programs p where p.active and coalesce(p.source_url,'') = ''
  union all
  select p.name, 'takma ad yok',
         'Host beyanindan bu program hicbir zaman eslesmez', 2
    from lounge_programs p
   where p.active and not exists (
         select 1 from lounge_program_aliases a where a.program_id = p.id)
  union all
  select p.name, 'kim oduyor belirsiz',
         'fee_payer bos — misafire "kapida oder" mi "host''un kartindan" mi diyecegimizi bilmiyoruz', 2
    from lounge_programs p
   where p.active and p.guest_default = 'paid' and p.fee_payer is null
  union all
  select a.airport_code::text, 'salon tanimi yok',
         'Bu havalimaninda ilan var ama lounge_venues kaydi yok', 1
    from availabilities a
   where not exists (select 1 from lounge_venues v where v.airport_code = a.airport_code)
   group by a.airport_code
  union all
  select l.airport_code || ' · ' || l.name, 'salon eslesmedi',
         'lounges kaydinin lounge_venues karsiligi yok', 1
    from lounges l where l.venue_id is null and l.active;
$$;
grant execute on function public.lounge_rules_health() to authenticated;


-- ============================================================
-- 4) KARAR MOTORUNA charter + tarife uyarisi
-- ============================================================
create or replace function public.lounge_access_decision_v4(
  p_avail_id uuid, p_guest_flight text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d jsonb; ch jsonb; v_sev text; v_extra text[] := '{}';
  v_prog_id uuid; v_exp date;
begin
  d  := public.lounge_access_decision_v3(p_avail_id, p_guest_flight);
  ch := public.charter_note(p_avail_id);
  v_sev := coalesce(d ->> 'severity','info');
  v_prog_id := nullif(d ->> 'program_id','')::uuid;

  if (ch ->> 'blocked')::boolean then
    return d || jsonb_build_object('severity','block','guest_policy','not_allowed',
      'headline','Charter seferde salon hakkı yok',
      'detail', ch ->> 'note');
  elsif (ch ->> 'note') is not null then
    v_extra := v_extra || (ch ->> 'note');
  end if;

  -- Tarifesi bitmis kural: motor sessizce varsayilana dusmus olabilir
  select max(r.effective_to) into v_exp
    from lounge_guest_rules r where r.program_id = v_prog_id and r.effective_to is not null;
  if v_exp is not null and v_exp < current_date then
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || format(
      'Bu programın yayınlanmış kural dönemi %s tarihinde sona erdi; güncel koşulları kapıda teyit et.',
      v_exp);
  end if;

  return d || jsonb_build_object('severity', v_sev,
    'charter', ch -> 'blocked',
    'rules_expired', (v_exp is not null and v_exp < current_date),
    'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_extra,' ')));
end $$;
grant execute on function public.lounge_access_decision_v4(uuid, text) to authenticated;

-- App kapisini v4'e bagla (imza degismiyor)
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.request_precheck(uuid);
create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('can_request', false, 'headline','İlan bulunamadı.'); end if;

  select v.flight_number into v_flight from visits v
   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date and coalesce(v.flight_number,'') <> ''
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v4(p_avail_id, v_flight);
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object('can_request', true, 'needs_ack', true, 'kind','card_generic',
      'severity','warn','source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor',
      'detail', public.rule_notice('card_notice_guest'));
  end if;

  if (d ->> 'severity') = 'block' then
    if (d ->> 'enforcement') = 'block' then v_can := false; else v_ack := true; end if;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;
  end if;

  return jsonb_build_object('can_request', v_can, 'needs_ack', v_ack, 'kind','rule',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'guest_fee_amount', d -> 'guest_fee_amount',
    'guest_fee_currency', d ->> 'guest_fee_currency',
    'headline', d ->> 'headline', 'detail', d ->> 'detail');
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;


-- ============================================================
-- 4b) HOST'UN CHARTER BEYANI
-- create_availability imzasina dokunmuyoruz (10+ cagri noktasi var);
-- ilan olustuktan sonra bu kucuk RPC ile isaretleniyor. Sahiplik
-- kontrolu sunucuda: baskasinin ilanini isaretleyemezsin.
-- ============================================================
create or replace function public.set_availability_charter(
  p_avail_id uuid, p_is_charter boolean
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_host uuid;
begin
  select host_id into v_host from availabilities where id = p_avail_id;
  if not found then raise exception 'not_found'; end if;
  if v_host <> auth.uid() then raise exception 'not_owner'; end if;
  update availabilities set is_charter = p_is_charter where id = p_avail_id;
  return jsonb_build_object('ok', true, 'is_charter', p_is_charter);
end $$;
grant execute on function public.set_availability_charter(uuid, boolean) to authenticated;


-- ============================================================
-- 5) DOGRULAMA
-- ============================================================
select v.airport_code, v.name, coalesce(v.section,'-') as bolum,
       case when v.section_of is not null then 'ALT BOLUM (katalog disi)' else 'katalogda' end as durum
  from lounge_venues v where v.airport_code = 'IST' order by v.name, v.section;

select * from public.rules_expiring(400);

select count(*) filter (where section_of is null) as katalog_salonu,
       count(*) filter (where section_of is not null) as alt_bolum
  from lounge_venues where active;

select '101 OK - bolum turetiliyor, charter soruluyor, tarife bitisi uyariyor' as sonuc;
