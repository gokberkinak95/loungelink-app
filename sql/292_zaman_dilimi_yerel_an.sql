-- ════════════════════════════════════════════════════════════════════════
-- 292 · ZAMAN DİLİMİ: DUVAR SAATİ ≠ UTC
--
-- 🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL (timezone brief'i) + BİNİŞ KARTI ANALİZİ
-- "UTC/ISO-8601 timezone düzeltmesi … 3 saatlik tolerans kuralı."
--
-- ÖLÇÜM (yerel Postgres, Europe/Istanbul = UTC+3):
--   `avail_date date` + `time_from/time_to time WITHOUT time zone`
--   → bu saatler HAVALİMANININ DUVAR SAATİ. Sunucu ise UTC.
--   Karşılaştırmalar ikisini karıştırıyordu. Kayma: TAM 3.00 SAAT.
--
--   · SQL 080 ilanı ölü sayma anı   20:00 UTC · doğrusu 17:00 UTC → 3.00 sa geç
--   · Radar 10:00 IST'te            "kimse yok" (YANLIŞ, doğru: var)
--     Radar 23:00 IST'te            "host var"  (YANLIŞ, ilan 21:00'de kapandı)
--   · `lounge_access_decision_v3` · en erken giriş kuralı:
--       ilan 09:00 IST · uçuş 14:20 IST · salon 3 saat önce alıyor
--       MEVCUT KOD : 09:00 UTC vs 08:20 UTC → "UYGUN"        ← YANLIŞ
--       DOĞRUSU    : 06:00 UTC vs 08:20 UTC → "KURAL İHLALİ"
--     Yani ürün, kapıda geri çevrilecek bir ilanı ONAYLIYORDU.
--
-- ETKİ ALANI (ETKIN_TANIMLAR.sql üzerinde fonksiyon fonksiyon sayıldı):
--   6 canlı nesne · 15 yer
--     lounge_radar_people        4
--     lounge_radar_count         4
--     venue_inbound_wave         3
--     lounge_access_decision_v3  1   ← kural motorunun kendisi
--     expire_stale_sessions      2   ← bayat oturum + kredi iadesi
--     yarinki_lounge_hatirlat    1   ← "yarın" UTC'nin yarınıydı
--
-- DOĞRU DESEN ÜRÜNDE ZATEN VARDI: `sql/199:96`
--     (a.avail_date + a.time_from) at time zone coalesce(v_tz,'Europe/Istanbul')
-- Yani sorun mimari değil YAYILMA idi. Bu dosya deseni tek bir yere
-- (`yerel_an`) koyuyor ve dört nesneyi ona bağlıyor.
--
-- 🆕 SINIF: "DOĞRU DESEN ÜRÜNDE ZATEN VARSA SORUN MİMARİ DEĞİL
-- YAYILMADIR — VE YAYILMAYI İNSAN DEĞİL NÖBETÇİ SAĞLAR."
--
-- ⚠️ KOLONLAR DEĞİŞMİYOR. `time without time zone` doğru tercih:
-- kullanıcı "09:00'da salonda olacağım" derken havalimanının saatini
-- söylüyor. Yanlış olan kolon değil, onu UTC sanan KARŞILAŞTIRMAYDI.
--
-- ⚠️ `airports.timezone` ÖLÇÜLDÜ: 222/222 dolu, hiç boş yok — veri
-- taşımaya gerek yok. `coalesce` yine duruyor: yeni bir havalimanı
-- boş zaman dilimiyle eklenirse ürün patlamaz, İstanbul'a düşer.
--
-- Tekrar koşulabilir. Kendi sınamasını taşır (GMT+3 / GMT+0 · TK1979).
-- ════════════════════════════════════════════════════════════════════════

-- ── 1 · TEK DOĞRU DÖNÜŞÜM, TEK YERDE ───────────────────────────────────

-- Havalimanının duvar saatindeki bir (tarih, saat) çiftini GERÇEK ANA çevirir.
-- `stable`: `airports` tablosunu okur, `immutable` olamaz.
create or replace function public.yerel_an(p_date date, p_time time, p_airport text)
returns timestamptz
language sql stable security definer set search_path = public as $fn$
  select (p_date + p_time) at time zone coalesce(
           (select a.timezone from airports a where a.code = upper(trim(p_airport))),
           'Europe/Istanbul');
$fn$;

-- Havalimanında ŞU AN hangi gün? (UTC'de gün dönmüş olabilir.)
create or replace function public.yerel_gun(p_airport text)
returns date
language sql stable security definer set search_path = public as $fn$
  select (now() at time zone coalesce(
            (select a.timezone from airports a where a.code = upper(trim(p_airport))),
            'Europe/Istanbul'))::date;
$fn$;

-- Havalimanında ŞU AN saat kaç? (duvar saati)
create or replace function public.yerel_saat(p_airport text)
returns time
language sql stable security definer set search_path = public as $fn$
  select (now() at time zone coalesce(
            (select a.timezone from airports a where a.code = upper(trim(p_airport))),
            'Europe/Istanbul'))::time;
$fn$;

comment on function public.yerel_an(date, time, text) is
  'Havalimanı duvar saatindeki (tarih,saat) → gerçek an. UTC ile kıyas yapacak HER yer bunu kullanır.';
comment on function public.yerel_gun(text) is 'Havalimanında şu anki yerel tarih.';
comment on function public.yerel_saat(text) is 'Havalimanında şu anki yerel duvar saati.';

grant execute on function public.yerel_an(date, time, text) to authenticated, anon;
grant execute on function public.yerel_gun(text) to authenticated, anon;
grant execute on function public.yerel_saat(text) to authenticated, anon;

-- ── 2 · DÖRT NESNE · 12 YER ────────────────────────────────────────────
-- Gövdeler `ETKIN_TANIMLAR.sql`den ALINDI ve yalnız ölçülen satırlar
-- değiştirildi (bkz. uretecler/zaman_dilimi_292.py — değişiklik sayısı
-- doğrulanır, tutmazsa dosya hiç üretilmez).

-- ── lounge_radar_people ─────────────────────────────────────────────
create or replace function public.lounge_radar_people()
returns table (
  user_id uuid, name text, profession text, bio text,
  badge text, score int, photo_url text,
  same_flight boolean, rel text, lounge_name text
)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_air text; v_from time; v_to time; v_flight text;
  v_me_women boolean; v_me_gender text; v_me_share boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select coalesce(p.location_sharing, false) into v_me_share from profiles p where p.user_id = v_uid;
  if not v_me_share then return; end if;

  -- bağlam: bugün, şu anı kapsayan ilan veya trip
  select a.airport_code, a.time_from, a.time_to into v_air, v_from, v_to
    from availabilities a
   where a.host_id = v_uid and a.active
     and a.avail_date = public.yerel_gun(a.airport_code)
     and a.time_from <= public.yerel_saat(a.airport_code)
     and public.yerel_saat(a.airport_code) <= a.time_to
   limit 1;

  if v_air is null then
    select v.airport_code, v.time_from, v.time_to, v.flight_number into v_air, v_from, v_to, v_flight
      from visits v
     where v.user_id = v_uid
       and v.visit_date = public.yerel_gun(v.airport_code)
       and v.time_from <= public.yerel_saat(v.airport_code)
       and public.yerel_saat(v.airport_code) <= v.time_to
     limit 1;
  end if;

  if v_air is null then return; end if;

  select coalesce(pr.women_safety_mode, false), u.gender into v_me_women, v_me_gender
    from profiles pr join users u on u.id = pr.user_id where pr.user_id = v_uid;

  return query
  with present as (
    -- aynı havalimanında, bugün, örtüşen saatte olan HERKES (host + guest)
    select v.user_id as uid, v.flight_number as flight, null::uuid as lid
      from visits v
     where v.visit_date = public.yerel_gun(v_air)
       and v.airport_code = v_air
       and v.time_from < v_to and v_from < v.time_to
       and v.user_id <> v_uid
    union
    select a.host_id as uid, null::text as flight, a.lounge_id as lid
      from availabilities a
     where a.active and a.avail_date = public.yerel_gun(v_air)
       and a.airport_code = v_air
       and a.time_from < v_to and v_from < a.time_to
       and a.host_id <> v_uid
  )
  select distinct on (pe.uid)
    pe.uid,
    pr.name,
    pr.profession,
    case when pr.profile_visibility = 'Connections'
              and not exists (select 1 from connection_requests c
                               where c.status='accepted'
                                 and ((c.from_id=v_uid and c.to_id=pe.uid)
                                   or (c.to_id=v_uid and c.from_id=pe.uid)))
         then null else pr.bio end as bio,
    ts.badge,
    ts.score,
    -- foto yalnızca bağlantılıysa (mevcut gizlilik kuralı)
    case when pr.photo_connections_only
              and not exists (select 1 from connection_requests c
                               where c.status='accepted'
                                 and ((c.from_id=v_uid and c.to_id=pe.uid)
                                   or (c.to_id=v_uid and c.from_id=pe.uid)))
         then null else pr.photo_url end as photo_url,
    (v_flight is not null and pe.flight = v_flight) as same_flight,
    coalesce((select c.status::text from connection_requests c
               where (c.from_id=v_uid and c.to_id=pe.uid)
                  or (c.to_id=v_uid and c.from_id=pe.uid)
               order by c.created_at desc limit 1), 'none') as rel,
    l.name as lounge_name
  from present pe
  join profiles pr on pr.user_id = pe.uid
  join users u on u.id = pe.uid
  left join trust_scores ts on ts.user_id = pe.uid
  left join lounges l on l.id = pe.lid
  where u.deleted_at is null
    -- opt-in: konum paylaşımı kapalı olan radara girmez
    and coalesce(pr.location_sharing, false)
    -- gölge kısıt: 029'daki FONKSIYON (profiles kolonu değil)
    and is_visible(pe.uid)
    -- profil görünürlüğü 'nobody' ise hiç gösterme
    -- 'Connections' gizli degil; bio kilitlenir ama kisi listede gorunur (mevcut kural)
    -- kadın güvenlik modu: çift yönlü
    and (not v_me_women or u.gender = 'female')
    and (not coalesce(pr.women_safety_mode,false) or v_me_gender = 'female')
    -- engelleme
    and not exists (
      select 1 from blocks b
       where (b.blocker = v_uid and b.blocked = pe.uid)
          or (b.blocker = pe.uid and b.blocked = v_uid))
  order by pe.uid, ts.score desc nulls last;
end $$;

-- ── lounge_radar_count ─────────────────────────────────────────────
create or replace function public.lounge_radar_count()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ctx record;
  v_count int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- Kullanıcının ŞU ANKİ bağlamı: bugün, şu saati kapsayan trip veya ilan
  select coalesce(a.airport_code, v.airport_code) as airport,
         a.lounge_id as lounge_id,
         coalesce(a.time_from, v.time_from) as t_from,
         coalesce(a.time_to,   v.time_to)   as t_to
    into v_ctx
    from (select 1) x
    left join availabilities a
      on a.host_id = v_uid and a.active
     and a.avail_date = public.yerel_gun(a.airport_code)
     and a.time_from <= public.yerel_saat(a.airport_code)
     and public.yerel_saat(a.airport_code) <= a.time_to
    left join visits v
      on v.user_id = v_uid
     and v.visit_date = public.yerel_gun(v.airport_code)
     and v.time_from <= public.yerel_saat(v.airport_code)
     and public.yerel_saat(v.airport_code) <= v.time_to
   limit 1;

  if v_ctx.airport is null then
    return jsonb_build_object('active', false);
  end if;

  -- Konum paylaşımı KAPALIYSA: radar çalışmaz ama app'e "açabilirsin" sinyali dön.
  -- Varsayılan false (001) — gizlilik açısından doğru, opt-in olmalı.
  -- App bu durumda "Radarı aç" kartı gösterir; kullanıcı bilinçli açar.
  if not coalesce((select location_sharing from profiles where user_id = v_uid), false) then
    return jsonb_build_object(
      'active', false,
      'reason', 'location_off',
      'can_enable', true,          -- app: "Radarı aç" kartı göster
      'airport', v_ctx.airport
    );
  end if;

  select count(*) into v_count from lounge_radar_people();

  return jsonb_build_object(
    'active', true,
    'airport', v_ctx.airport,
    'lounge_id', v_ctx.lounge_id,
    'count', v_count,
    'time_from', v_ctx.t_from,
    'time_to', v_ctx.t_to
  );
end $$;

-- ── venue_inbound_wave ─────────────────────────────────────────────
create or replace function public.venue_inbound_wave(
  p_lounge_id uuid, p_saat int default 72, p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid; v_ap text; v_k int := public.partner_k(); v_satir jsonb;
begin
  v_uid := public.partner_gate(p_user, p_lounge_id);
  select airport_code into v_ap from lounges where id = p_lounge_id;
  if v_ap is null then return jsonb_build_object('known', false); end if;

  select jsonb_agg(x order by (x ->> 'saat'))
    into v_satir
  from (
    -- 🔴 `group by 1` YAZMIŞTIM VE NÖBETÇİ YAKALADI:
    --     ERROR: aggregate functions are not allowed in GROUP BY
    -- Çünkü 1. seçim öğesi, İÇİNDE toplama fonksiyonu barındıran
    -- `jsonb_build_object(...)`. Konum numarasıyla gruplamak kısa
    -- yoldur ama ifadenin ne olduğunu gizler; ifadeyi AÇIKÇA yazmak
    -- hem çalışır hem okunur.
    select jsonb_build_object(
             'saat', to_char(date_trunc('hour',
                 coalesce(v.scheduled_departure, public.yerel_an(v.visit_date, v.time_from, v.airport_code))),
               'YYYY-MM-DD HH24:00'),
             'yolcu', count(distinct v.user_id)::int,
             'terminal', coalesce(mode() within group (order by v.terminal), '—')
           ) as x
      from visits v
      join users u on u.id = v.user_id
     where v.airport_code = v_ap
       and coalesce(v.scheduled_departure, public.yerel_an(v.visit_date, v.time_from, v.airport_code))
           between now() and now() + make_interval(hours => p_saat)
       and coalesce(u.is_staff,false) = false
       and u.deleted_at is null
     group by date_trunc('hour',
         coalesce(v.scheduled_departure, public.yerel_an(v.visit_date, v.time_from, v.airport_code)))
    having count(distinct v.user_id) >= v_k
  ) q;

  return jsonb_build_object(
    'known', true, 'havalimani', v_ap, 'saat', p_saat, 'k_esigi', v_k,
    'saatler', coalesce(v_satir, '[]'::jsonb),
    'not', 'Yalnız uygulamaya seyahat girmiş yolcular sayılır — havalimanının toplam trafiği DEĞİLDİR.');
end $fn$;

-- ── lounge_access_decision_v3 ─────────────────────────────────────────────
create or replace function public.lounge_access_decision_v3(
  p_avail_id     uuid,
  p_guest_flight text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d          jsonb;
  v_av       availabilities%rowtype;
  v_ent      host_entitlements%rowtype;
  v_prog_id  uuid;
  v_rule     lounge_guest_rules%rowtype;
  v_venue_id uuid;
  v_needs_tier boolean := false;
  v_extra    text[] := '{}';
  v_sev      text;
  v_policy   text;
  v_count    smallint;
  v_payer    text;
  v_stay     numeric;
  v_entry    numeric;
  v_dur      numeric;
  v_dep      timestamptz;
  v_head     text;
begin
  d := public.lounge_access_decision_v2(p_avail_id, p_guest_flight);
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return d; end if;

  v_venue_id := public.resolve_venue_for_availability(p_avail_id);
  v_prog_id  := nullif(d ->> 'program_id','')::uuid;
  v_sev      := coalesce(d ->> 'severity','info');
  v_policy   := d ->> 'guest_policy';
  v_count    := coalesce((d ->> 'guest_included_count')::smallint, 0);
  v_stay     := nullif(d ->> 'max_stay_hours','')::numeric;
  v_entry    := nullif(d ->> 'earliest_entry_hours','')::numeric;

  select he.* into v_ent from host_entitlements he
   where he.user_id = v_av.host_id
     and (v_prog_id is null or he.program_id = v_prog_id)
   order by he.verified desc, he.self_reported_at desc nulls last limit 1;

  -- ---------- KART TİPİ ----------
  if v_prog_id is not null then
    v_needs_tier := public.program_needs_tier(v_prog_id);
  end if;

  if v_needs_tier and coalesce(v_ent.tier,'') = '' then
    -- 🔴 EN ÖNEMLİ DAVRANIŞ: tier bilinmiyorsa EN İYİ İHTİMALİ VARSAYMA.
    -- Eskiden motor ilk kurali seciyordu (cogu zaman Elite Plus) ve
    -- Classic Plus'li host'a "misafir hakkin var" diyordu.
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || ('Kart tipini bilmiyoruz. Bu programda misafir hakkı KART TİPİNE göre değişiyor '
                       || '(ör. Classic Plus''ta misafir hakkı YOK). Profil → Lounge Erişim''den kart tipini seç.')::text;
  elsif v_needs_tier then
    select r.* into v_rule
      from lounge_guest_rules r
     where r.program_id = v_prog_id
       and r.card_tier = v_ent.tier
       and (r.venue_id is null or r.venue_id = v_venue_id)
       and (r.effective_from is null or r.effective_from <= current_date)
       and (r.effective_to   is null or r.effective_to   >= current_date)
     order by (r.venue_id is not null) desc, r.created_at
     limit 1;

    if v_rule.id is not null then
      -- Kural, salon kabulunun UZERINE yazar: salon "1 misafir" dese de
      -- Classic Plus'in hakki yoksa hak YOKTUR.
      if v_rule.blocked_reason is not null then
        v_sev := 'block'; v_policy := 'not_allowed'; v_count := 0;
        v_extra := v_extra || v_rule.blocked_reason;
      elsif v_rule.guest_allowance = 0 and v_policy = 'included' then
        v_policy := case when v_rule.paid_entry_allowed then 'paid' else 'not_allowed' end;
        v_count  := 0;
        v_sev    := case when v_policy = 'not_allowed' then 'block' else 'warn' end;
        v_extra  := v_extra || format('Kart tipin (%s): bu kartla misafir hakkı yok.',
                                      coalesce(v_ent.tier,'?'));
        -- 🔴 104: BASLIK DA DEGISMELI. Eskiden yalniz severity ve policy
        -- degisiyordu; baslik salon kabulunden gelen "Misafir hakkın var
        -- (1 kişi)" olarak KALIYORDU. Kullanici "engellendi" rozetiyle
        -- "hakkın var" cumlesini yan yana goruyordu. Celiskili bir ekran,
        -- yanlis ekrandan daha kotudur: hangisine inanacagini bilemez.
        -- 🔴 105: IKI DURUM AYRI CUMLE ISTER.
        -- 'paid': misafir GIREBILIR ama ucret oder. 'not_allowed': giremez.
        -- 104'te ikisini de "goturemezsin" diye yazmistim; kullanici
        -- "ucretli" rozetiyle "goturemezsin" cumlesini yan yana goruyordu.
        -- 🔴 134: HAM KOD DEGIL INSAN DILI. `v_ent.tier` bizim veritabani
        -- kodumuz (CLPL, ELPL...); kullanicinin kartinin uzerinde
        -- "Classic Plus" yaziyor. 120'de precheck'i duzeltmistim ama
        -- BURAYI atlamistim — ve kesif ROZETLERI bu basligi gosteriyor.
        -- Ic kodun bir ekrandan silinmesi yetmez; SIZDIGI HER YERDEN
        -- silinmeli. "Baska nerede uretiliyor" diye sormayi atlamisim.
        v_head := case when v_policy = 'paid'
          then format('%s kartında misafir hakkı yok — misafirin ücret ödeyerek girebilir',
                      coalesce(public.card_tier_label(v_ent.tier), 'Bu kart'))
          else format('%s kartıyla misafir götüremezsin',
                      coalesce(public.card_tier_label(v_ent.tier), 'Bu kart')) end;
      else
        v_count := least(v_count, greatest(v_rule.guest_allowance, 0));
        if v_rule.family_allowed then
          v_extra := v_extra || ('Aile hakkın da var (eş + 25 yaşından gün almamış çocuklar) — '
                             || 'ama aile hakkı, tanışmak için gelen bir misafirin yerine geçmez.')::text;
        end if;
      end if;
      v_entry := coalesce(v_rule.earliest_entry_hours, v_entry);
      if v_rule.notes is not null then v_extra := v_extra || v_rule.notes; end if;
    end if;
  end if;

  -- ---------- KİM ÖDÜYOR ----------
  if v_policy = 'paid' then
    select coalesce(a.fee_payer, p.fee_payer, 'unknown') into v_payer
      from lounge_programs p
      left join lounge_venue_acceptance a
        on a.program_id = p.id and a.venue_id = v_venue_id
     where p.id = v_prog_id;
    v_extra := v_extra || coalesce(
      public.rule_notice(case v_payer
        when 'member_card'   then 'fee_note_member_card'
        when 'guest_at_door' then 'fee_note_guest_at_door'
        else 'rule_notice_generic' end), '');

    -- 🔴 105: BASLIK DA "KIM ODUYOR"A UYMALI.
    -- 086'nin basligi her ucretli durumda "kapida tahsil edilir" diyordu.
    -- Priority Pass / LoungeKey / DragonPass'te ucret KAPIDA MISAFIRDEN
    -- DEGIL, HOST'UN KARTINDAN cekiliyor. Misafire "kapida odeyeceksin"
    -- demek, ona ait olmayan bir maliyeti ustlendirmek olur; host'a da
    -- kendi odeyecegini gizler. Iki taraf da yanlis bilgilenirdi.
    if v_head is null then
      v_head := case v_payer
        when 'member_card'   then 'Misafir girişi ücretli — ücret host''un kartından çekilir'
        when 'guest_at_door' then coalesce(d ->> 'headline', 'Misafir girişi kapıda ücretli')
        else 'Misafir girişi ücretli olabilir — koşulları teyit edin' end;
    end if;
  end if;

  -- ---------- SAAT KONTROLLERİ ----------
  v_dur := extract(epoch from (v_av.time_to - v_av.time_from)) / 3600.0;
  if v_stay is not null and v_dur > v_stay + 0.25 then
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || format(
      'İlanın %s saatlik ama bu salonda kalış ~%s saatle sınırlı. Süreyi kısaltmayı düşün.',
      trim(to_char(v_dur,'FM990.0')), trim(to_char(v_stay,'FM990.0')));
  end if;

  if v_entry is not null and coalesce(v_av.flight_number,'') <> '' then
    select fc.scheduled_departure into v_dep
      from flight_cache fc
     where upper(replace(fc.flight_no,' ','')) = upper(replace(v_av.flight_number,' ',''))
       and fc.flight_date = v_av.avail_date;
    if v_dep is not null then
      if public.yerel_an(v_av.avail_date, v_av.time_from, v_av.airport_code)
           < (v_dep - make_interval(mins => (v_entry*60)::int)) then
        v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
        v_extra := v_extra || format(
          'Salona en erken kalkıştan %s saat önce girilebiliyor; ilanın bundan erken başlıyor.',
          trim(to_char(v_entry,'FM990.0')));
      end if;
    else
      v_extra := v_extra || format(
        'Salona en erken kalkıştan %s saat önce girilebiliyor — uçuş saatini doğrulayamadığımız için kontrol edilemedi.',
        trim(to_char(v_entry,'FM990.0')));
    end if;
  end if;

  -- ---------- SLOT × MİSAFİR HAKKI ----------
  if v_policy = 'included' and v_count > 0 and coalesce(v_av.slots,1) > v_count then
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || format(
      'İlanında %s kişilik yer var ama bu hakla en fazla %s misafir sokabilirsin.',
      v_av.slots, v_count);
  end if;

  return d || jsonb_build_object(
    'severity', v_sev,
    'headline', coalesce(v_head, d ->> 'headline'),
    'guest_policy', v_policy,
    'guest_included_count', v_count,
    'host_tier', v_ent.tier,
    'tier_required', v_needs_tier,
    'fee_payer', v_payer,
    'listing_hours', round(v_dur, 1),
    'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_extra, ' ')));
end $$;

-- ── expire_stale_sessions ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.expire_stale_sessions()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_req int := 0; v_sess int := 0;
begin
  -- (a) Hiç başlatılmamış kabuller: kimse gelmedi ya da unutuldu → cezasız
  --     kapanış + kredi iadesi.
  with stale as (
    select r.id, r.guest_id
      from requests r
      join availabilities a on a.id = r.avail_id
      left join sessions s on s.request_id = r.id
     where r.status = 'accepted' and s.id is null
       and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours'
  ), upd as (
    update requests set status = 'cancelled' where id in (select id from stale) returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select u.guest_id, 1, 'expired_refund', u.id,
         coalesce((select sum(delta) from credit_ledger c where c.user_id = u.guest_id), 0) + 1
    from upd u;
  get diagnostics v_req = row_count;

  -- (b) Tek taraf başlatmış ama diğeri hiç gelmemiş → 'expired'.
  --     Başlatan taraf "geldim" beyanındadır; gelmeyen no_show işaretlenir.
  update sessions s
     set status = 'expired',
         completed_at = now(),
         cancel_reason = 'no_show',
         no_show_user_id = case when s.host_started_at is null then r.host_id else r.guest_id end
    from requests r, availabilities a
   where r.id = s.request_id and a.id = r.avail_id
     and s.status = 'pending'
     and r.status = 'accepted'   -- 280/K2: iptal edilmiş isteğin yetim oturumu no_show DEĞİL
     and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours';
  get diagnostics v_sess = row_count;

  -- Etkilenenlerin güvenini tazele
  perform public.recompute_trust(u) from (
    select distinct no_show_user_id as u from sessions
     where cancel_reason = 'no_show' and no_show_user_id is not null
       and completed_at > now() - interval '1 day'
  ) x where u is not null;

  -- 🔴 187-noshow: (b) bloğu oturumu 'expired' yapıyordu ama
  -- isteği 'accepted' BIRAKIYOR ve krediyi iade ETMİYORDU.
  -- Sonuç: misafirin kredisi sonsuza kilitli; sync_availability_filled
  -- filled'ı accepted sayısından türettiği için host'un slotu da
  -- sonsuza dolu — tek no-show ilanı kalıcı olarak öldürüyordu.
  with kapanan as (
    select r.id, r.guest_id
      from requests r
      join sessions s2 on s2.request_id = r.id
     where r.status = 'accepted'
       and s2.status = 'expired'
       and s2.cancel_reason = 'no_show'
  ), iade as (
    update requests set status = 'cancelled'
     where id in (select id from kapanan)
    returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select i.guest_id, 1, 'no_show_refund', i.id,
         coalesce((select sum(c.delta) from credit_ledger c
                    where c.user_id = i.guest_id), 0) + 1
    from iade i
   where not exists (select 1 from credit_ledger c2
                      where c2.ref_id = i.id and c2.reason = 'no_show_refund');

  perform public.tek_tarafli_oturumlari_kapat();
  return jsonb_build_object('ok', true, 'expired_requests', v_req, 'expired_sessions', v_sess);
end $function$;

-- ── yarinki_lounge_hatirlat ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.yarinki_lounge_hatirlat()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_n int := 0; r record;
begin
  for r in
    select q.id as req_id, x.uid, a.airport_code, a.time_from
      from requests q
      join availabilities a on a.id = q.avail_id
      cross join lateral (values (q.host_id), (q.guest_id)) as x(uid)
     where q.status = 'accepted'
       and a.avail_date = public.yerel_gun(a.airport_code) + 1
       and not exists (select 1 from notifications n
                        where n.user_id = x.uid and n.ref_type = 'trip_reminder'
                          and n.ref_id = q.id)
  loop
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (r.uid, 'sessions', 'Yarın lounge günün ✈',
            r.airport_code || ' · ' || coalesce(to_char(r.time_from, 'HH24:MI'), '')
              || ' — buluşmadan önce sohbetten haberleşin.',
            r.req_id, 'trip_reminder');
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'hatirlatilan', v_n);
end $function$;


-- ── 4 · KENDİ SINAMASI · GMT+3 / GMT+0 · TK1979 ────────────────────────
-- Brief'teki sınır vakası: aynı duvar saati iki farklı zaman diliminde
-- iki farklı GERÇEK AN'dır. Sınama bunu hem IST (UTC+3) hem LHR (UTC+1/0)
-- üzerinde doğruluyor ve eski davranışın yanlış olduğunu da gösteriyor.
do $$
declare
  v_ist timestamptz; v_utc_gibi timestamptz; v_lhr timestamptz; v_fark numeric;
  v_tz_ist text; v_tz_lhr text;
begin
  select timezone into v_tz_ist from airports where code = 'IST';
  if v_tz_ist is null then raise exception '292: IST havalimani yok'; end if;

  -- 1) IST · 13 Eylül 18:00 duvar saati → 15:00 UTC olmalı (yaz saati UTC+3)
  v_ist := public.yerel_an(date '2026-09-13', time '18:00', 'IST');
  if (v_ist at time zone 'UTC')::time <> time '15:00' then
    raise exception '292: IST 18:00 → UTC % (15:00 bekleniyordu)', (v_ist at time zone 'UTC')::time;
  end if;

  -- 2) ESKİ DAVRANIŞ YANLIŞTI: düz cast 18:00 UTC verir, fark 3 saat
  v_utc_gibi := (date '2026-09-13' + time '18:00') at time zone 'UTC';
  v_fark := extract(epoch from (v_utc_gibi - v_ist)) / 3600.0;
  if v_fark <> 3 then
    raise exception '292: beklenen kayma 3 saat, olculen %', v_fark;
  end if;
  raise notice '292 sinama 1-2: IST duvar 18:00 = 15:00 UTC · eski davranisin kaymasi % saat', v_fark;

  -- 3) AYNI DUVAR SAATİ, BAŞKA DİLİM: LHR varsa 18:00'i farklı ana çevirmeli
  select timezone into v_tz_lhr from airports where code = 'LHR';
  if v_tz_lhr is not null then
    v_lhr := public.yerel_an(date '2026-09-13', time '18:00', 'LHR');
    if v_lhr = v_ist then
      raise exception '292: LHR ve IST ayni ana dustu — dilim okunmuyor';
    end if;
    raise notice '292 sinama 3: ayni duvar saati IST=% LHR=% (fark % saat)',
      v_ist, v_lhr, round(extract(epoch from (v_lhr - v_ist))/3600.0, 2);
  else
    raise notice '292 sinama 3: LHR katalogda yok, atlandi';
  end if;

  -- 4) BİLİNMEYEN HAVALİMANI ÜRÜNÜ PATLATMAZ — İstanbul'a düşer
  if public.yerel_an(date '2026-09-13', time '18:00', 'ZZZ') <> v_ist then
    raise exception '292: bilinmeyen havalimani Istanbul a dusmedi';
  end if;

  -- 5) GÜN DÖNÜMÜ: 01:00 IST = onceki gun 22:00 UTC → `yerel_gun` UTC ile
  --    ayni gunu dondurmemeli. Sabit bir anla dogruluyoruz (now() degil).
  if (timestamptz '2026-09-13 22:00:00+00' at time zone v_tz_ist)::date
     <> date '2026-09-14' then
    raise exception '292: gun donumu yanlis — 22:00 UTC IST de 14 Eylul olmali';
  end if;
  raise notice '292 sinama 5: gun donumu OK (22:00 UTC = IST 14 Eylul 01:00)';

  -- 6) EN ERKEN GİRİŞ KURALI artık doğru tarafta:
  --    ilan 09:00 IST · uçuş 14:20 IST · salon 3 saat önce alıyor → İHLAL
  if not (public.yerel_an(date '2026-09-13', time '09:00', 'IST')
          < public.yerel_an(date '2026-09-13', time '14:20', 'IST') - interval '3 hours') then
    raise exception '292: en erken giris kurali hala ihlali yakalamiyor';
  end if;
  --    ilan 12:00 IST ise UYGUN olmalı (14:20 - 3sa = 11:20)
  if (public.yerel_an(date '2026-09-13', time '12:00', 'IST')
      < public.yerel_an(date '2026-09-13', time '14:20', 'IST') - interval '3 hours') then
    raise exception '292: 12:00 ilani yanlis sekilde ihlal sayildi';
  end if;
  raise notice '292 sinama 6: en erken giris kurali iki yonde de dogru';
end $$;

-- ── 5 · ARTIK KİMSE DUVAR SAATİNİ now() İLE KIYASLAMIYOR ───────────────
-- Kaynak tarafındaki nöbetçi: rnapp/zaman_dilimi_check.py (tavan 0).
select '292 kuruldu · yerel_an/yerel_gun/yerel_saat + 6 nesne (15 yer)' as sonuc;
