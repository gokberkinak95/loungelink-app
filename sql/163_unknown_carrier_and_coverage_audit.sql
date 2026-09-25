-- ============================================================
-- LoungeLink · 163_unknown_carrier_and_coverage_audit.sql
-- KOMBİNATORYAL DENETİMİN ORTAYA ÇIKARDIĞI SİSTEMİK HATA
--
-- ⚠️ Uygulamayı ETKİLER (karar motorunun çekirdeği).
--
-- ------------------------------------------------------------
-- 🔴 BULGU: TAŞIYICISI BİLİNMEYEN İLANDA MOTOR SUSUYOR
-- ------------------------------------------------------------
-- Kabul edilen her (program × kart tipi × salon) üçlüsü tarandı:
-- 607 kombinasyonun 290'ında (%48) "kural bulunamadı" dönüyordu.
-- Kök neden tek bir satırdı:
--
--     and (x.carrier is null or x.carrier = v_eff)
--
-- İlanın taşıyıcısı BİLİNMİYORSA (uçuş numarası isteğe bağlı!)
-- v_eff null olur ve `x.carrier = null` hiçbir zaman doğru
-- olmadığı için TAŞIYICIYA BAĞLI TÜM KURALLAR ELENİR. TK_MS'in
-- 196 kuralının neredeyse tamamı taşıyıcı taşıdığından, uçuş
-- numarası girilmemiş bir ilanda motor kural bulamaz ve karar
-- PROGRAM VARSAYILANINA düşer — yani "misafir hakkın var".
--
-- Sonuç, CLPL zaman bombasının genelleşmiş hali: Classic Plus
-- host uçuş numarası yazmadan ilan açtığında sistem ona misafir
-- alabileceğini söylüyordu. Bu ailenin üçüncü örneği: "eşleşmeyen
-- filtre, kuralı zayıflatmak yerine sessizce YOK EDİYOR".
--
-- ------------------------------------------------------------
-- İLKE: BİLMEMEK, CÖMERT DAVRANMAK İÇİN GEREKÇE DEĞİLDİR
-- ------------------------------------------------------------
-- Taşıyıcı bilinmiyorsa iki seçenek var: (a) kuralları yok sayıp
-- en cömert varsayılana düşmek (bugünkü hata) (b) uygulanabilir
-- kuralların EN KISITLAYICISINI uygulayıp bunu kullanıcıya
-- söylemek. Doğrusu (b): kapıda geri çevrilen misafir, uygulamada
-- "belki" görmüş olmaktan çok daha ağır bir zarardır. Kullanıcıya
-- da çıkış yolu veriyoruz: uçuş numarasını gir, kural netleşsin.
-- ============================================================

-- sqlcheck: allow-replace resolve_guest_rule  (dönüş tipi AYNI — jsonb)
create or replace function public.resolve_guest_rule(
  p_program_id uuid,
  p_venue_id   uuid    default null,
  p_tier       text    default null,
  p_carrier    text    default null,
  p_cabin      text    default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
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
  if not found then
    select * into r from lounge_guest_rules x
     where x.program_id = p_program_id
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
end $$;

-- ---- KANIT: aynı üçlü, taşıyıcı bilinmeden ARTIK doğru cevabı verir ----
do $$
declare a jsonb; b jsonb; v_ist uuid; v_pid uuid;
begin
  select id into v_pid from lounge_programs where code = 'TK_MS';
  select id into v_ist from lounge_venues
   where active and airport_code = 'IST' and name ilike '%İç Hat%' limit 1;

  -- CLPL + taşıyıcı BİLİNMİYOR → misafir hakkı 0 olmalı (eskiden kural
  -- bulunamıyor, karar program varsayılanına düşüyordu)
  a := public.resolve_guest_rule(v_pid, v_ist, 'CLPL', null, null);
  if not coalesce((a ->> 'found')::boolean, false) then
    raise exception '163: CLPL taşıyıcısız hâlâ kuralsız';
  end if;
  if coalesce((a ->> 'guest_allowance')::int, 9) <> 0 then
    raise exception '163: CLPL taşıyıcısız misafir hakkı 0 olmalı, % geldi', a ->> 'guest_allowance';
  end if;

  -- Taşıyıcı BİLİNİYORSA davranış değişmemeli (ELPL + TK → 1 misafir)
  b := public.resolve_guest_rule(v_pid, v_ist, 'ELPL', 'TK', null);
  if coalesce((b ->> 'guest_allowance')::int, 0) < 1 then
    raise exception '163: ELPL/TK regresyonu — misafir hakkı kayboldu';
  end if;
end $$;

-- ============================================================
-- KALICI KAPSAM DENETİMİ
-- Bu turda bulunan üç hata sınıfı da "kimse bakmadığı için sessizce
-- yaşayan veri" idi. rule_coverage_audit() bunları RAKAMLA raporlar;
-- SEED sonunda çağrılır ve eşik aşılırsa migration DURUR.
-- ============================================================
drop function if exists public.rule_coverage_audit();
create or replace function public.rule_coverage_audit()
returns table (kontrol text, deger int, esik int, sonuc text)
language plpgsql stable security definer set search_path = public as $$
begin
  -- 1) Kabul edilen her program×tier×salon üçlüsünde kural bulunuyor mu?
  kontrol := 'Kuralsız kalan kabul kombinasyonu (taşıyıcısız)';
  select count(*) into deger from (
    select p.id pid, t.tier, v.id vid
      from lounge_programs p
      cross join lateral (select distinct card_tier tier from lounge_guest_rules r
                           where r.program_id = p.id and r.card_tier is not null
                          union select null) t
      cross join lounge_venues v
     where p.active and v.active
       and exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.program_id = p.id and a.active)) c
   where not (public.resolve_guest_rule(c.pid, c.vid, c.tier, null, null) ->> 'found')::boolean;
  -- Kalan boşluk YALNIZ hiç kural yazılmamış programlardan gelmeli
  -- (BUSINESS_TICKET, PRIMECLASS, IGA_LOUNGE, AMEX_GLOBAL, PLAZA_PREMIUM).
  -- Eşik onların salon sayısı kadardır; TK_MS/AJET_MS burada görünürse
  -- gerçek bir regresyon var demektir.
  esik := 20;
  sonuc := case when deger <= esik then '✓' else '✗ KAPSAM BOŞLUĞU' end;
  return next;

  -- 2) Pasif venue'ya bağlı (erişilemez) kural — veri çöplüğü göstergesi
  kontrol := 'Pasif salona bağlı erişilemez kural';
  select count(*) into deger from lounge_guest_rules r
    join lounge_venues v on v.id = r.venue_id where not v.active;
  esik := 80;
  sonuc := case when deger <= esik then '✓' else '✗ TEMİZLİK GEREK' end;
  return next;

  -- 3) Kaynaklı görünen ama tek kuralı olmayan program (162'nin
  --    "doğrulandı" rozetini hak etmeyen program)
  kontrol := 'checked_at dolu ama kuralı olmayan program';
  select count(*) into deger from lounge_programs p
   where p.active and p.checked_at is not null
     and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);
  esik := 3;
  sonuc := case when deger <= esik then '✓' else '✗ SAHTE DOĞRULAMA RİSKİ' end;
  return next;

  -- 4) Aktif salonu olmayan havalimanı (keşifte boş çıkan şehir)
  kontrol := 'Aktif salonu olmayan havalimanı';
  select count(*) into deger from airports a
   where not exists (select 1 from lounge_venues v where v.airport_code = a.code and v.active);
  esik := 4;
  sonuc := case when deger <= esik then '✓' else '✗ KATALOG EKSİĞİ' end;
  return next;

  -- 5) Kabul satırı olmayan aktif salon (hiçbir kartla girilemeyen salon)
  kontrol := 'Hiçbir programın kabul etmediği aktif salon';
  select count(*) into deger from lounge_venues v
   where v.active and not exists (select 1 from lounge_venue_acceptance a
                                   where a.venue_id = v.id and a.active);
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '✗ ERİŞİLEMEZ SALON' end;
  return next;
end $$;
grant execute on function public.rule_coverage_audit() to authenticated;

select '163 OK - tasiyicisiz karar duzeltildi + kapsam denetimi' as sonuc;
