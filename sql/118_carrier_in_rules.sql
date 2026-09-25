-- ============================================================
-- LoungeLink · 118_carrier_in_rules.sql
-- TASIYICI KURAL MOTORUNA BAGLANIYOR
--
-- ⚠️ Uygulamayi ETKILER (karar mantigi).
--
-- 117 tasiyici alanini ekledi ama KARAR MOTORU hala ucus numarasindan
-- tahmin ediyordu. Alan eklemek, alani KULLANMAK degildir — 095'te
-- ayni hatayi yapmistim (saha raporu tablosu vardi, soru yoktu).
--
-- ------------------------------------------------------------
-- KURAL: "AYNI HAVAYOLU" NE DEMEK
-- ------------------------------------------------------------
--   same_carrier  -> misafirin tasiyicisi host'unkiyle AYNI OLMALI.
--                    TK ile AJet AYRI SAYILIR (THY md.17 + AJet kurali).
--   same_alliance -> ayni ittifak yeter (Star Gold icin).
--   same_flight   -> ayni sefer numarasi (DragonPass).
--   any           -> onemsiz (kart aglari).
--
-- 🔴 BILINMIYORSA ENGELLEME, UYAR. Tasiyici secilmemisse "uymuyor"
-- demek, bilmedigimiz icin kullaniciyi cezalandirmak olur. Uyari
-- veririz, karar kapida verilir.
-- ============================================================

create or replace function public.carrier_match(
  p_host_carrier text, p_guest_carrier text, p_coupling text
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare a1 text; a2 text;
begin
  if coalesce(p_coupling,'any') = 'any' then
    return jsonb_build_object('ok', true, 'known', true, 'note', null);
  end if;
  if coalesce(p_host_carrier,'') = '' or coalesce(p_guest_carrier,'') = '' then
    -- Bilinmiyor: AKIS DURMAZ, uyari cikar.
    return jsonb_build_object('ok', true, 'known', false,
      'note', 'Havayolu bilgisi eksik. Bu salonun kurali misafirin belirli bir '
           || 'havayolunda olmasini istiyor; giristen once birbirinizin ucusunu teyit edin.');
  end if;
  if p_host_carrier = p_guest_carrier then
    return jsonb_build_object('ok', true, 'known', true, 'note', null);
  end if;

  if p_coupling = 'same_alliance' then
    select alliance into a1 from carriers where code = p_host_carrier;
    select alliance into a2 from carriers where code = p_guest_carrier;
    if a1 is not null and a1 = a2 then
      return jsonb_build_object('ok', true, 'known', true,
        'note', 'Farkli havayollari ama AYNI ITTIFAK (' || a1 || ') — bu salon icin yeterli.');
    end if;
    return jsonb_build_object('ok', false, 'known', true,
      'note', 'Bu salon ittifak uyesi bir havayolunda ucmani istiyor; '
           || 'senin havayolun host''unkiyle ayni ittifakta degil.');
  end if;

  -- 🔴 TK <-> AJet: AYNI SIRKET, FARKLI TASIYICI. Kullanicilarin en cok
  -- yanildigi yer burasi ve iki resmi metin de acikca yasakliyor.
  if (p_host_carrier = 'TK' and p_guest_carrier = 'VF')
     or (p_host_carrier = 'VF' and p_guest_carrier = 'TK') then
    return jsonb_build_object('ok', false, 'known', true,
      'note', 'Turk Hava Yollari ve AJet AYRI TASIYICI sayilir: THY yolcusu AJet '
           || 'yolcusunu misafir edemez, AJet yolcusu da THY yolcusunu. Ikisi ayni '
           || 'gruba ait olsa da salon kurali boyle (THY md.17 ve AJet CIP kurallari).');
  end if;

  return jsonb_build_object('ok', false, 'known', true,
    'note', 'Bu salon misafirin host ile AYNI HAVAYOLUNDA ucmasini istiyor; '
         || 'sizin havayollariniz farkli.');
end $$;
grant execute on function public.carrier_match(text, text, text) to authenticated;

-- Karar motoruna bagla
create or replace function public.lounge_access_decision_v5(
  p_avail_id uuid, p_guest_flight text default null, p_guest_carrier text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d jsonb; v_av availabilities%rowtype; m jsonb;
  v_host text; v_guest text; v_coupling text; v_sev text; v_extra text[] := '{}';
begin
  d := public.lounge_access_decision_v4(p_avail_id, p_guest_flight);
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return d; end if;

  v_coupling := d ->> 'flight_coupling';
  v_host  := coalesce(v_av.carrier_code, public.carrier_from_flight(v_av.flight_number));
  v_guest := coalesce(nullif(p_guest_carrier,''), public.carrier_from_flight(p_guest_flight));

  -- same_flight zaten v4'te sefer numarasiyla degerlendirildi; burada
  -- yalniz TASIYICI duzeyindeki kuplajlari isliyoruz.
  if coalesce(v_coupling,'any') in ('same_carrier','same_alliance') then
    m := public.carrier_match(v_host, v_guest, v_coupling);
    v_sev := coalesce(d ->> 'severity','info');
    if not (m ->> 'ok')::boolean then
      v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    elsif not (m ->> 'known')::boolean then
      v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    end if;
    if (m ->> 'note') is not null then v_extra := v_extra || (m ->> 'note')::text; end if;
    return d || jsonb_build_object(
      'severity', v_sev,
      'carrier_ok', (m ->> 'ok')::boolean,
      'carrier_known', (m ->> 'known')::boolean,
      'host_carrier', v_host, 'guest_carrier', v_guest,
      'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_extra,' ')));
  end if;

  return d || jsonb_build_object('host_carrier', v_host, 'guest_carrier', v_guest);
end $$;
grant execute on function public.lounge_access_decision_v5(uuid, text, text) to authenticated;

-- request_precheck ve rozetler v5'e gecsin
create or replace function public.guest_carrier_for(p_avail_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(v.carrier_code, public.carrier_from_flight(v.flight_number))
    from visits v, availabilities a
   where a.id = p_avail_id and v.user_id = auth.uid()
     and v.airport_code = a.airport_code and v.visit_date = a.avail_date
   order by v.created_at desc limit 1;
$$;
grant execute on function public.guest_carrier_for(uuid) to authenticated;

select '118 OK - tasiyici kural motoruna baglandi' as sonuc;
