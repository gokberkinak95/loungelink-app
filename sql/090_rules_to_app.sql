-- ============================================================
-- LoungeLink · 090_rules_to_app.sql
-- KURAL MOTORUNUN UYGULAMAYA BAĞLANMASI + ZİRAAT DÜZELTMESİ
--
-- 🔴 BU MIGRATION UYGULAMAYI ETKİLER (ilk kez). Ama var olan hiçbir RPC'nin
-- İMZASI ya da DAVRANIŞI değişmiyor — yalnız ÜÇ YENİ okuma fonksiyonu
-- ekleniyor. v1.85 ve öncesi sürümler bunları çağırmadığı için eski
-- kurulumlar aynen çalışmaya devam eder. Yeni davranış v1.86 ile gelir.
--
-- ------------------------------------------------------------
-- ÜRÜN KARARI (Gokberk, 6 Ağu) — KREDİ KARTLARINDA TEK TEK KURAL YOK
-- ------------------------------------------------------------
-- Kart programları (LoungeKey, Priority Pass, DragonPass) ve havayolları
-- (THY, AJet, Pegasus) için GERÇEK kural tablosu tutulur ve başvuru akışı
-- buna göre kapılanır.
--
-- Ama BANKA KARTI kaynaklı haklar "derya deniz": 20 banka, yüzlerce ürün,
-- segmente ve kampanyaya bağlı, üç ayda bir değişiyor. Bunların her birine
-- kural yazmak, tutulamayacak bir söz vermektir. Bu yüzden banka kartı
-- kaynağı için TEK BİR GENEL UYARI gösterilir:
--   · host ilan açarken   → "kartının lounge avantajını detaylıca incele"
--   · misafir başvururken → onay kutusu, "sohbette teyit et"
-- Metinler kodda DEĞİL beta_settings'te; BO'dan değiştirilebilir.
-- ============================================================


-- ============================================================
-- 1) ZİRAAT DÜZELTMESİ — resmî sayfadan (Bankkart Prestij Plus özellikleri)
--
-- 088'de İKİ HATA yapmıştım:
--   (a) Programı Priority Pass yazmıştım → GERÇEĞİ **LoungeKey**
--   (b) Misafir hakkını ana kotanın parçası saymıştım → GERÇEKTE misafir
--       hakkı AYRI BİR YILLIK HAVUZ (4 adet) ve AYLIK SINIRA TABİ DEĞİL
--
-- Resmî tablo:
--   Prestij       → lounge hakkı YOK
--   Prestij Plus  → yılda 8  (+4 misafir) · ayda 2 (+4 misafir, aylık sınırsız)
--   Plus Elite    → yılda 30 (+4 misafir) · ayda 4 (+4 misafir, aylık sınırsız)
--
-- Ürün açısından kritik iki madde:
--   · "Misafir hakkı kullanımı SADECE kart sahibinin hak kullanımı ile
--      AYNI ANDA yapılabilir." → host fiziksel olarak yanında olmalı.
--      Bizim kurgumuz zaten bunu gerektiriyor; ürün metninde vurgulanmalı.
--   · "Ücretsiz giriş hakları SADECE ASIL KARTLA kullanılabilir, ek kartla
--      kullanılamaz." → ek kart sahibi host olamaz. Bu, beyanda sorulması
--      gereken bir ayrım (bugün sorulmuyor).
--   · Plus Elite'te 8'den sonraki girişler kapıda TAHSİL EDİLİP 1 gün sonra
--      İADE ediliyor → misafir "ücret çekildi" görüp paniğe kapılabilir.
--      Bu, saha raporlarında 'admitted_paid' olarak görünecek ama aslında
--      ücretsiz. Not olarak yazıldı ki kural yanlış düzeltilmesin.
-- ============================================================
update lounge_card_products cp
   set program_id = (select id from lounge_programs where code = 'LOUNGEKEY'),
       quota_total = 8, quota_period = 'year',
       guest_consumes_quota = false,
       requires_preissued_pass = false,
       condition_type = 'segment',
       condition_note = 'Aylik en fazla 2 kullanim. Misafir hakki AYLIK SINIRA TABI DEGIL.',
       conditions = 'Yilda 8 kullanim + AYRI 4 misafir hakki. Misafir hakki yalniz kart sahibinin '
                 || 'hak kullanimiyla AYNI ANDA kullanilabilir. Yalniz ASIL kartla; ek kartla kullanilamaz. '
                 || 'LoungeKey mobil uygulamasindan karekod ile de kullanilabilir. Kartin yurt disi '
                 || 'e-ticaret/mail order islemlerine ACIK olmasi gerekir.',
       source_url = 'https://www.ziraatbank.com.tr/',
       checked_at = current_date,
       confidence = 'verified'
  from lounge_issuers i
 where i.id = cp.issuer_id and i.code = 'ZIRAAT' and cp.name = 'Prestij Plus';

update lounge_card_products cp
   set program_id = (select id from lounge_programs where code = 'LOUNGEKEY'),
       quota_total = 30, quota_period = 'year',
       guest_consumes_quota = false,
       requires_preissued_pass = false,
       condition_type = 'segment',
       condition_note = 'Aylik en fazla 4 kullanim. Misafir hakki AYLIK SINIRA TABI DEGIL.',
       conditions = 'Yilda 30 kullanim + AYRI 4 misafir hakki. Misafir hakki yalniz kart sahibinin '
                 || 'hak kullanimiyla AYNI ANDA kullanilabilir. Yalniz ASIL kartla. '
                 || '⚠ LoungeKey uygulamasi yillik hakki HER IKI segmentte de 8 gosterir; 8''den sonraki '
                 || 'girisler kapida TAHSIL EDILIP 1 gun sonra IADE edilir (LoungeKey POS''undan gecmesi sart). '
                 || 'Yani misafir "ucret cekildi" gorebilir ama giris aslinda ucretsizdir — saha raporunu '
                 || 'buna gore degerlendir.',
       source_url = 'https://www.ziraatbank.com.tr/',
       checked_at = current_date,
       confidence = 'verified'
  from lounge_issuers i
 where i.id = cp.issuer_id and i.code = 'ZIRAAT' and cp.name = 'Prestij Plus Elite';

-- Hakkı OLMAYAN segment de katalogda olmalı: host "Prestij'im var" derse
-- "hakkın yok" diyebilmeliyiz. Yokluğu bilmek de bilgidir.
insert into lounge_card_products
  (issuer_id, name, program_id, quota_total, quota_period, guest_consumes_quota,
   condition_type, condition_note, conditions, confidence, source_url, checked_at)
select i.id, 'Prestij', null, 0, 'year', false, 'none',
       'Bu segmentte lounge hakki yok.',
       'Resmi tabloda Prestij segmenti icin yillik/aylik hak tanimli degil.',
       'verified', 'https://www.ziraatbank.com.tr/', current_date
  from lounge_issuers i where i.code = 'ZIRAAT'
on conflict do nothing;

-- Misafir hakkı AYRI HAVUZ olan kartlar için kolonlar
alter table lounge_card_products add column if not exists guest_quota_total   smallint;
alter table lounge_card_products add column if not exists guest_quota_period  text;
alter table lounge_card_products add column if not exists guest_monthly_limited boolean not null default true;
alter table lounge_card_products add column if not exists primary_card_only   boolean not null default false;
alter table lounge_card_products add column if not exists guest_simultaneous_only boolean not null default true;

alter table lounge_card_products drop constraint if exists lcp_gq_period_chk;
alter table lounge_card_products add constraint lcp_gq_period_chk
  check (guest_quota_period is null or guest_quota_period in ('year','month','unlimited'));

update lounge_card_products cp
   set guest_quota_total = 4, guest_quota_period = 'year',
       guest_monthly_limited = false, primary_card_only = true,
       guest_simultaneous_only = true
  from lounge_issuers i
 where i.id = cp.issuer_id and i.code = 'ZIRAAT' and cp.name in ('Prestij Plus','Prestij Plus Elite');


-- ============================================================
-- 2) GENEL UYARI METİNLERİ — koda gömülmez, BO'dan değiştirilir
-- ============================================================
insert into beta_settings (key, value) values
 ('card_notice_host', to_jsonb(
   'Hakkın kredi kartından geliyor. Banka lounge koşulları karta, segmente ve '
   'kampanya dönemine göre değişir. İlanı yayınlamadan önce kartının güncel '
   'lounge avantajını ve MİSAFİR hakkını bankanın sayfasından teyit et — '
   'kalan hakkın bitmişse misafirin kapıda ücret ödeyebilir.'::text)),
 ('card_notice_guest', to_jsonb(
   'Bu ilandaki hak bir kredi kartı avantajından geliyor. Banka koşulları '
   'karta göre değiştiği için girişi baştan garanti edemiyoruz. Buluşmadan '
   'önce sohbette host''a misafir hakkının olduğunu ve kalan hakkını teyit et.'::text)),
 ('rule_notice_generic', to_jsonb(
   'Bu salonun misafir kurallarını henüz doğrulamadık. Host giriş anında '
   'yanında olmalı; kendi biniş kartın ve kimliğinle git. Misafir girişi '
   'ücretli olabilir — koşulları sohbette teyit et.'::text))
on conflict (key) do nothing;

create or replace function public.rule_notice(p_key text)
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select value #>> '{}' from beta_settings where key = p_key), '');
$$;
grant execute on function public.rule_notice(text) to authenticated;


-- ============================================================
-- 3) 🔴 APP KAPISI #1 — HOST İLAN AÇARKEN SALON SEÇİNCE
--
-- İlan HENÜZ YOK, bu yüzden lounge_access_decision (avail_id ister)
-- kullanılamaz. Bu fonksiyon host'un BEYAN ETTİĞİ hakla salonu eşleştirir.
-- Uygulama tek bir kutu çizer: {severity, headline, detail}.
-- ============================================================
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.lounge_hint_for_host(uuid);
create or replace function public.lounge_hint_for_host(p_lounge_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid      uuid := auth.uid();
  v_venue_id uuid;
  v_venue    lounge_venues%rowtype;
  v_prog     lounge_programs%rowtype;
  v_acc      lounge_venue_acceptance%rowtype;
  v_ent      host_entitlements%rowtype;
  v_card     lounge_card_products%rowtype;
  v_src      text;
  v_sev      text := 'info';
  v_head     text;
  v_notes    text[] := '{}';
begin
  if v_uid is null then return jsonb_build_object('severity','info'); end if;

  select l.venue_id into v_venue_id from lounges l where l.id = p_lounge_id;
  if v_venue_id is not null then select * into v_venue from lounge_venues where id = v_venue_id; end if;

  -- Host'un hakkı: önce yapılandırılmış kayıt, yoksa serbest metin beyanı
  select he.* into v_ent from host_entitlements he
   where he.user_id = v_uid order by he.verified desc, he.created_at limit 1;
  if v_ent.program_id is not null then
    select * into v_prog from lounge_programs where id = v_ent.program_id;
    if v_ent.card_product_id is not null then
      select * into v_card from lounge_card_products where id = v_ent.card_product_id;
    end if;
  else
    select pr.access_source into v_src from profiles pr where pr.user_id = v_uid;
    select * into v_prog from lounge_programs
     where id = public.match_program_by_text(v_src);
  end if;

  -- 🔴 BANKA KARTI KAYNAĞI → tek tek kural YOK, GENEL UYARI
  -- (Gokberk'in kararı: kart hakları derya deniz, söz veremeyiz.)
  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object(
      'severity', 'warn', 'kind', 'card_generic',
      'venue_name', v_venue.name,
      'headline', 'Kart avantajıyla açılan ilan',
      'detail', public.rule_notice('card_notice_host'));
  end if;

  if v_venue_id is not null then
    select * into v_acc from lounge_venue_acceptance
     where venue_id = v_venue_id and program_id = v_prog.id and active;
  end if;

  if v_acc.id is null then
    return jsonb_build_object(
      'severity', 'warn', 'kind', 'unknown',
      'venue_name', v_venue.name, 'program_name', v_prog.name,
      'headline', format('%s bu salonda doğrulanmadı', v_prog.name),
      'detail', public.rule_notice('rule_notice_generic'));
  end if;

  if not v_acc.accepted or v_acc.guest_policy = 'not_allowed' then
    return jsonb_build_object(
      'severity', 'block', 'kind', 'not_allowed',
      'venue_name', v_venue.name, 'program_name', v_prog.name,
      'headline', 'Bu salonda misafir alamazsın',
      'detail', coalesce(v_acc.conditions,
        'Bu salon/hak birleşiminde misafir hakkı yok. Başka bir salon seç.'));
  end if;

  if v_acc.guest_policy = 'paid' then
    v_sev  := 'warn';
    v_head := case when v_acc.guest_fee_amount is not null
      then format('Misafirin kapıda ~%s %s öder',
                  trim(to_char(v_acc.guest_fee_amount,'FM999990.00')),
                  coalesce(v_acc.guest_fee_currency,''))
      else 'Misafir girişi ücretli olabilir' end;
    v_notes := v_notes || ('İlanında bunu belirtmen, kapıda sürpriz yaşanmasını önler.')::text;
  elsif v_acc.guest_policy = 'unknown' then
    v_sev  := 'warn';
    v_head := 'Bu salonun misafir kuralı doğrulanmadı';
    v_notes := v_notes || public.rule_notice('rule_notice_generic');
  else
    v_sev  := 'ok';
    v_head := case when v_acc.guest_included_count > 0
      then format('Misafir hakkın var — %s kişi, ek ücret yok', v_acc.guest_included_count)
      else 'Misafir kabul ediliyor' end;
  end if;

  -- Misafirin uçuş bağı — host'un ilanını doğru kurgulaması için
  case coalesce(v_acc.guest_flight_coupling, v_prog.guest_flight_coupling, 'any')
    when 'same_flight' then
      v_notes := v_notes || ('Bu programda misafirin SENİNLE AYNI UÇUŞTA olması gerekiyor — ilanına uçuş numaranı ekle.')::text;
    when 'same_carrier' then
      v_notes := v_notes || ('Misafirin de aynı havayolunda uçuyor olmalı — uçuş numaranı eklersen eşleşme doğru çalışır.')::text;
    when 'same_alliance' then
      v_notes := v_notes || ('Misafirin ittifak üyesi bir havayolunda uçuyor olmalı.')::text;
    else null;
  end case;

  if coalesce(v_card.primary_card_only, false) then
    v_notes := v_notes || ('Bu hak yalnız ASIL kartla kullanılabilir; ek kartla kullanılamaz.')::text;
  end if;
  if coalesce(v_card.guest_simultaneous_only, true) and v_acc.guest_policy = 'included' then
    v_notes := v_notes || ('Misafirin seninle aynı anda giriş yapmalı; hakkını ödünç veremezsin.')::text;
  end if;
  if v_acc.max_stay_hours is not null then
    v_notes := v_notes || format('Salonda kalış ~%s saatle sınırlı.',
                                 trim(to_char(v_acc.max_stay_hours,'FM990.0')));
  end if;

  return jsonb_build_object(
    'severity', v_sev, 'kind', 'rule',
    'venue_name', v_venue.name, 'program_name', v_prog.name,
    'guest_policy', v_acc.guest_policy,
    'flight_coupling', coalesce(v_acc.guest_flight_coupling, v_prog.guest_flight_coupling, 'any'),
    'headline', v_head,
    'detail', array_to_string(v_notes, ' '));
end $$;
grant execute on function public.lounge_hint_for_host(uuid) to authenticated;


-- ============================================================
-- 4) 🔴 APP KAPISI #2 — MİSAFİR "İSTEK GÖNDER"E BASINCA
--
-- Misafirin KENDİ seyahatindeki uçuş numarası otomatik kullanılır.
-- Dönüş: can_request (engel var mı) + needs_ack (onay kutusu şart mı).
-- ============================================================
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.request_precheck(uuid);
create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_av     availabilities%rowtype;
  v_flight text;
  v_prog   lounge_programs%rowtype;
  d        jsonb;
  v_can    boolean := true;
  v_ack    boolean := false;
  v_head   text;
  v_detail text;
  v_kind   text := 'rule';
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then
    return jsonb_build_object('can_request', false, 'headline', 'İlan bulunamadı.');
  end if;

  -- Misafirin aynı havalimanı/tarihteki seyahatinden uçuş numarası
  select v.flight_number into v_flight
    from visits v
   where v.user_id = v_uid
     and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
     and coalesce(v.flight_number,'') <> ''
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v2(p_avail_id, v_flight);

  select * into v_prog from lounge_programs where id = (d ->> 'program_id')::uuid;

  -- 🔴 BANKA KARTI KAYNAĞI → kural yerine ONAY KUTUSU
  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object(
      'can_request', true, 'needs_ack', true, 'kind', 'card_generic',
      'severity', 'warn',
      'source_label', 'Kredi kartı avantajı',
      'headline', 'Bu ilandaki hak kredi kartından geliyor',
      'detail', public.rule_notice('card_notice_guest'));
  end if;

  v_head   := d ->> 'headline';
  v_detail := d ->> 'detail';

  if (d ->> 'severity') = 'block' then
    -- Engel YALNIZCA veri "block" demeye yetecek kadar güvenilirse uygulanır.
    -- enforcement='warn' olan satırlarda kullanıcı yine başvurabilir; bu,
    -- eksik kural verisiyle geçerli eşleşmeyi öldürmemek içindir.
    if (d ->> 'enforcement') = 'block' then
      v_can := false;
    else
      v_ack := true;
    end if;
  elsif (d ->> 'severity') = 'warn' then
    v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then
    v_ack := true;
    v_detail := public.rule_notice('rule_notice_generic');
  end if;

  return jsonb_build_object(
    'can_request', v_can,
    'needs_ack',   v_ack,
    'kind',        v_kind,
    'severity',    d ->> 'severity',
    'confidence',  d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy',
    'flight_coupling', d ->> 'flight_coupling',
    'source_label', coalesce(v_prog.name, 'Lounge hakkı'),
    'guest_fee_amount', d -> 'guest_fee_amount',
    'guest_fee_currency', d ->> 'guest_fee_currency',
    'headline',    v_head,
    'detail',      v_detail);
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;


-- ============================================================
-- 5) 🔴 APP KAPISI #3 — KEŞİF LİSTESİNDE ROZET + SIRALAMA
--
-- discover_availabilities'in İMZASINA DOKUNULMADI (app onu okuyor).
-- Bunun yerine liste geldikten sonra id'lerle bu fonksiyon çağrılır ve
-- rozetler istemcide birleştirilir. Böylece eski sürümler etkilenmez.
--
-- 💡 same_flight_match: misafirin uçuş numarası host'unkiyle AYNI.
-- Bu yalnız bir kural kontrolü değil — ürünün en güçlü anlatısı:
-- "yanındaki koltuktaki kişiyle uçuştan önce tanış."
-- ============================================================
-- Savunma amacli: bu fonksiyon BIRDEN COK dosyada tanimli.
-- Dosyalar tekrar calistirilabilsin diye her tanimin onunde drop var;
-- yoksa ESKI bir dosyayi YENI veritabaninda calistirmak 42P13 verir.
drop function if exists public.discovery_rule_badges(uuid[]);
create or replace function public.discovery_rule_badges(p_ids uuid[])
returns table (
  avail_id uuid, severity text, label text, detail text,
  same_flight_match boolean, sort_boost int
) language plpgsql stable security definer set search_path = public as $$
declare
  r        record;
  d        jsonb;
  v_flight text;
  v_sev    text;
  v_label  text;
  v_boost  int;
  v_same   boolean;
begin
  foreach avail_id in array coalesce(p_ids, '{}'::uuid[]) loop
    select * into r from availabilities where id = avail_id;
    continue when not found;

    select v.flight_number into v_flight
      from visits v
     where v.user_id = auth.uid()
       and v.airport_code = r.airport_code
       and v.visit_date = r.avail_date
       and coalesce(v.flight_number,'') <> ''
     order by v.created_at desc limit 1;

    d := public.lounge_access_decision_v2(avail_id, v_flight);

    v_same := coalesce(v_flight,'') <> ''
              and coalesce(r.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(r.flight_number,' ',''));

    v_sev := coalesce(d ->> 'severity', 'info');
    v_boost := 0;

    if v_same then
      v_label := 'AYNI UÇUŞ';
      v_boost := 100;                       -- en güçlü eşleşme sinyali
    elsif (d ->> 'fits') = 'false' then
      v_label := 'Uçuşun uygun değil';
      v_boost := -100;
    elsif (d ->> 'guest_policy') = 'paid' then
      v_label := 'Misafir girişi ücretli';
      v_boost := -20;
    elsif (d ->> 'guest_policy') = 'not_allowed' then
      v_label := 'Misafir alınmıyor';
      v_boost := -200;
    elsif (d ->> 'confidence') in ('unknown', 'assumed') then
      v_label := 'Kural doğrulanmadı';
      v_boost := -10;
    elsif (d ->> 'guest_policy') = 'included' then
      v_label := 'Misafir ücretsiz';
      v_boost := 20;
    else
      v_label := null;
    end if;

    severity := v_sev;
    label := v_label;
    detail := d ->> 'headline';
    same_flight_match := v_same;
    sort_boost := v_boost;
    return next;
  end loop;
end $$;
grant execute on function public.discovery_rule_badges(uuid[]) to authenticated;


-- ============================================================
-- 6) DOĞRULAMA
-- ============================================================
select i.name, cp.name, p.code as ag, cp.quota_total, cp.quota_period,
       cp.guest_quota_total, cp.guest_monthly_limited, cp.confidence
  from lounge_card_products cp
  join lounge_issuers i on i.id = cp.issuer_id
  left join lounge_programs p on p.id = cp.program_id
 where i.code = 'ZIRAAT' order by cp.name;

select key, left(value #>> '{}', 60) as metin_basi
  from beta_settings
 where key in ('card_notice_host','card_notice_guest','rule_notice_generic');

select '090 OK - kural motoru app kapilarina baglandi (3 yeni RPC), Ziraat duzeltildi' as sonuc;
