-- ============================================================
-- LoungeLink · 172_resolver_full_definition.sql
-- 170'İN CANLIDA PATLAMASI: METİN AMELİYATINI BIRAKIYORUM
--
-- ⚠️ Uygulamayı ETKİLER (karar motorunun çekirdeği).
--
-- ------------------------------------------------------------
-- 🔴 NEDEN BU DOSYA VAR
-- ------------------------------------------------------------
-- 170 şu hatayla durdu: "tier geçişi daraltılamadı — gövde kalıbı
-- değişmiş". Sebebi net: 168 ve 170, fonksiyonun GÖVDESİNİ pg_proc'tan
-- okuyup METİN DEĞİŞTİRME (replace) ile yamalıyordu. Bu yöntem,
-- gövdenin bir karakterine kadar aynı olmasını şart koşar; iki ortam
-- arasındaki en küçük fark (bir boşluk, bir satır sonu, bir dosyanın
-- farklı sırada koşması) yamayı düşürür.
--
-- ÜÇÜNCÜ KEZ ISIRDI. Kendi kuralım: iki kez ısıran şey üçüncü kez
-- elle düzeltilmez — yöntem değişir. Bu dosya fonksiyonu BAŞTAN,
-- TAM METİNLE tanımlar. Artık hangi ortamda hangi sırayla koşulursa
-- koşulsun sonuç aynı: idempotent ve okunabilir.
--
-- Bu tanım 156→170 arasındaki BÜTÜN kararları içerir:
--   · kapsam (domestic/international/abroad) venue''dan türetilir
--   · Star Alliance çevirisi (157)
--   · taşıyıcı bilinmiyorsa kural elenmez, EN KISITLAYICI seçilir (163)
--   · 1. geçiş tam eşleşme · 2. geçiş TAŞIYICIYI gevşetir (tier korunur)
--     · 3. geçiş TIER''ı gevşetir ve yalnız tier''sız kurala düşer (170)
--   · süresi dolmuş kural elenir (161)
-- ============================================================

-- sqlcheck: allow-replace resolve_guest_rule  (dönüş tipi AYNI — jsonb)
create or replace function public.resolve_guest_rule(
  p_program_id uuid,
  p_venue_id   uuid    default null,
  p_tier       text    default null,
  p_carrier    text    default null,
  p_cabin      text    default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $BODY$

declare r lounge_guest_rules%rowtype; p lounge_programs%rowtype;
        v_alliance text; v_eff text; v_scope text; v_unknown boolean := false;
begin
  select * into p from lounge_programs where id = p_program_id;
  if not found then return jsonb_build_object('found', false); end if;

  select c.alliance into v_alliance from carriers c where c.code = p_carrier;
  v_eff := case
    when p_carrier is null then null
    when p_carrier = 'TK' then 'TK'
    when p_carrier = 'VF' then 'VF'
    when v_alliance = 'star_alliance' then 'STAR_ALLIANCE'
    else p_carrier end;
  v_unknown := (v_eff is null);

  if p_venue_id is not null then
    select case
             when coalesce(a.country,'') not in ('','TR','Türkiye','Turkiye','Turkey') then 'abroad'
             when v.scope in ('domestic','international') then v.scope
             else null end
      into v_scope
      from lounge_venues v join airports a on a.code = v.airport_code
     where v.id = p_venue_id;
  end if;

  select * into r from lounge_guest_rules x
   where x.program_id = p_program_id
     and (x.venue_id is null or x.venue_id = p_venue_id)
     and (x.venue_scope is null or x.venue_scope = v_scope)
     and (x.card_tier is null or x.card_tier = p_tier)
     -- 🔴 DEĞİŞEN TEK KOŞUL: taşıyıcı bilinmiyorsa taşıyıcıya bağlı
     -- kurallar da ADAY olur (elenmez). Hangisinin uygulanacağını
     -- aşağıdaki sıralama belirler ve orada EN KISITLAYICI kazanır.
     and (x.carrier is null or v_unknown or x.carrier = v_eff)
     and (x.cabin_class is null or x.cabin_class = p_cabin)
     and (x.effective_to is null or x.effective_to >= current_date)
   order by
     coalesce(x.venue_id = p_venue_id, false) desc,
     coalesce(x.card_tier = p_tier, false) desc,
     -- Taşıyıcı BİLİNİYORSA eskisi gibi en spesifik eşleşme kazanır.
     -- BİLİNMİYORSA en kısıtlayıcı (en az misafir, aile yok) kazanır:
     -- bilmemek cömertlik gerekçesi değildir.
     case when v_unknown then 0 else (case when x.carrier = v_eff then 0 else 1 end) end,
     case when v_unknown then coalesce(x.guest_allowance, 0) else 0 end,
     case when v_unknown then (case when coalesce(x.family_allowed,false) then 1 else 0 end) else 0 end,
     coalesce(x.venue_scope = v_scope, false) desc,
     coalesce(x.cabin_class = p_cabin, false) desc,
     coalesce(x.blocked_reason is not null, false) desc,
     x.created_at desc
   limit 1;

  -- 🔴 AYNI AİLENİN İKİNCİ YÜZÜ: KART TİPİ BİLİNMİYOR ya da o tier
  -- için kural yazılmamış. Tam eşleşme bulunamadıysa tier'ı yok sayıp
  -- programın EN KISITLAYICI kuralını uygularız — yine "bilmemek
  -- cömertlik gerekçesi değildir" ilkesi. Tam eşleşme semantiği
  -- bozulmasın diye bu İKİNCİ geçiştir; birincisi aynen korunur.
  -- 🔴 ÜÇÜNCÜ GEÇİŞ (168): taşıyıcı BİLİNİYOR ama o taşıyıcı için
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

  -- 170: AYRIM — tier BİLİNMİYORSA (p_tier null) herhangi bir tier'ın
  -- kuralına düşmek meşrudur ve en kısıtlayıcısı alınır (163'ün amacı).
  -- Ama tier BİLİNİYOR ve o tier için kural yoksa BAŞKA BİR TIER'IN
  -- kuralı ödünç ALINMAZ — Elite'e Classic'in satırını uygulamak
  -- hiçbir okumada doğru değil. O durumda yalnız tier'ı yazılmamış
  -- (card_tier is null) genel kural kullanılır.
  if not found then
    select * into r from lounge_guest_rules x
     where x.program_id = p_program_id
       and (p_tier is null or x.card_tier is null)
       and (x.venue_id is null or x.venue_id = p_venue_id)
       and (x.venue_scope is null or x.venue_scope = v_scope)
       and (x.carrier is null or v_unknown or x.carrier = v_eff)
       and (x.cabin_class is null or x.cabin_class = p_cabin)
       and (x.effective_to is null or x.effective_to >= current_date)
     order by coalesce(x.venue_id = p_venue_id, false) desc,
              coalesce(x.guest_allowance, 0),
              (case when coalesce(x.family_allowed,false) then 1 else 0 end),
              x.created_at desc
     limit 1;
    if found then
      v_unknown := true;   -- notu "kesin değil" olarak işaretle
    end if;
  end if;

  if not found then
    return jsonb_build_object(
      'found', false, 'program', p.name,
      'guest_allowance', case p.guest_default when 'included' then coalesce(p.guest_included_count,1) else 0 end,
      'family_allowed', false,
      'carrier_unknown', v_unknown,
      'note', 'Bu kart tipi için özel kural bulunamadı; program varsayılanı uygulandı.');
  end if;

  return jsonb_build_object(
    'found', true,
    'program', p.name,
    'tier', public.card_tier_label(r.card_tier),
    'tier_code', r.card_tier,
    'carrier_scope', r.carrier,
    'venue_scope', r.venue_scope,
    'carrier_unknown', v_unknown,
    'guest_allowance', coalesce(r.guest_allowance, 0),
    'family_allowed', coalesce(r.family_allowed, false),
    'paid_entry_allowed', coalesce(r.paid_entry_allowed, false),
    'same_flight_required', coalesce(r.guest_must_match_carrier, false),
    'blocked_reason', r.blocked_reason,
    'whitelist', case when r.guest_carrier_whitelist is not null
                      then to_jsonb(r.guest_carrier_whitelist) end,
    'entry_hours', r.earliest_entry_hours,
    'member_fee', nullif(r.member_entry_fee,''),
    'guest_fee', nullif(r.guest_entry_fee,''),
    'note', case when v_unknown
                 then coalesce(r.notes || ' ', '')
                      || 'Kart tipi veya uçuş bilgisi tam bilinmediği için EN KISITLAYICI kural uygulandı — kartını ve uçuşunu eklersen kesin cevabı veririz.'
                 else r.notes end,
    'headline', case
      when r.blocked_reason is not null then r.blocked_reason
      when coalesce(r.guest_allowance,0) > 0 and coalesce(r.family_allowed,false)
        then 'Ailen veya bir misafir götürebilirsin'
      when coalesce(r.guest_allowance,0) > 0
        then coalesce(r.guest_allowance,0)::text || ' misafir götürebilirsin'
      when coalesce(r.paid_entry_allowed,false)
        then 'Ücret ödeyerek girersin — misafir hakkın yok'
      else 'Girebilirsin ama misafir götüremezsin' end);
end 
$BODY$;

-- ---- KANIT: dört davranış da yerinde ----
do $$
declare v_pid uuid; v_dom uuid; j jsonb;
begin
  select id into v_pid from lounge_programs where code = 'TK_MS';
  select v.id into v_dom from lounge_venues v join airports a on a.code = v.airport_code
   where v.active and v.scope = 'domestic'
     and coalesce(a.country,'TR') in ('TR','Türkiye','Turkiye','Turkey') limit 1;
  if v_dom is null then raise notice '172: iç hat salonu yok, kanıt atlandı'; return; end if;

  -- (1) ELITE + başka taşıyıcı: kendi tier kuralına düşer, CLASSIC'inkine DEĞİL
  j := public.resolve_guest_rule(v_pid, v_dom, 'ELITE', 'VF', null);
  if coalesce((j ->> 'guest_allowance')::int, -1) < 1 then
    raise exception '172: ELITE+VF % misafir — en az 1 olmalı', j ->> 'guest_allowance';
  end if;

  -- (2) CLASSIC her koşulda 0
  j := public.resolve_guest_rule(v_pid, v_dom, 'CLASSIC', 'TK', null);
  if coalesce((j ->> 'guest_allowance')::int, 9) <> 0 then
    raise exception '172: CLASSIC % misafir — 0 olmalı', j ->> 'guest_allowance';
  end if;

  -- (3) Taşıyıcı bilinmiyorsa kural bulunmalı (163)
  j := public.resolve_guest_rule(v_pid, v_dom, 'CLPL', null, null);
  if not coalesce((j ->> 'found')::boolean, false) then
    raise exception '172: taşıyıcısız CLPL kuralsız kaldı';
  end if;

  -- (4) Tier bilinmiyorsa da bir kural çözülmeli
  j := public.resolve_guest_rule(v_pid, v_dom, null, 'TK', null);
  if not coalesce((j ->> 'found')::boolean, false) then
    raise exception '172: tiersız çözümleme kuralsız kaldı';
  end if;
end $$;

select '172 OK - resolver tam metinle tanimlandi' as sonuc;
