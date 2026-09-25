-- ============================================================
-- LoungeLink · 116_badges_gate_and_sort.sql
-- ROZET BIR SUS DEGIL, BIR KAPI OLMALI + KESIF SIRALAMASI
--
-- ⚠️ Uygulamayi ETKILER (rozet cikti + siralama).
--
-- ------------------------------------------------------------
-- 🔴 SORUN 1: ROZET HAYIR DIYOR, BUTON EVET DIYOR
-- ------------------------------------------------------------
-- Gokberk cihazda gordu: "Bu ilan misafir alamiyor" ve "Ucusun bu
-- ilana uymuyor" rozetleri cikiyor ama ALTINDAKI "Istek Gonder" ve
-- "Seyahat Ekle" butonlari AKTIF.
--
-- Kullaniciya ayni anda iki celiskili sinyal veriyoruz. Kullanici
-- BUTONA guvenir — cunku buton eylemdir, rozet suslemedir. Tiklar,
-- sonra reddedilir ya da daha kotusu KAPIDA cevrilir.
--
-- `discovery_rule_badges` bugune kadar yalniz ETIKET donduruyordu.
-- Artik BASVURULABILIR MI sorusunun cevabini da donduruyor —
-- request_precheck ile AYNI mantikla, ki iki yer farkli karar vermesin.
--
-- ------------------------------------------------------------
-- 🔴 SORUN 2: KESIFTE SIRALAMA ANLAMSIZ
-- ------------------------------------------------------------
-- Istenen sira (ve dogrusu):
--   1. BASVURABILECEGIN ilanlar   — kendi icinde eslesme puanina gore
--   2. Seyahatinin DISINDAKILER   — kendi icinde eslesme puanina gore
--   3. BASVURAMAYACAKLARIN        — en altta
-- Gerekce: kullanicinin ilk gordugu sey YAPABILECEGI sey olmali.
-- Yapamayacagi bir ilani basa koymak, ona once umut verip sonra
-- geri almaktir.
-- ============================================================

drop function if exists public.discovery_rule_badges(uuid[]);

create or replace function public.discovery_rule_badges(p_ids uuid[])
returns table (
  avail_id uuid, severity text, label text, info text, detail text,
  same_flight_match boolean, blocks_request boolean, sort_boost int
) language plpgsql stable security definer set search_path = public as $$
declare
  r record; d jsonb; b jsonb; v_flight text; v_key text;
  v_boost int; v_same boolean; v_block boolean; v_prog lounge_programs%rowtype;
begin
  foreach avail_id in array coalesce(p_ids, '{}'::uuid[]) loop
    select * into r from availabilities where id = avail_id;
    continue when not found;

    select v.flight_number into v_flight from visits v
     where v.user_id = auth.uid() and v.airport_code = r.airport_code
       and v.visit_date = r.avail_date and coalesce(v.flight_number,'') <> ''
     order by v.created_at desc limit 1;

    -- 118/119: tasiyici da karara girsin. Rozet ile precheck AYNI
    -- fonksiyonu cagirmali; farkli surum cagirirlarsa rozet "olur" derken
    -- buton "olmaz" der ve bugunku celiski geri gelir.
    d := public.lounge_access_decision_v5(avail_id, v_flight, public.guest_carrier_for(avail_id));
    select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

    v_same := coalesce(v_flight,'') <> '' and coalesce(r.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(r.flight_number,' ',''));

    -- 🔴 request_precheck ILE AYNI MANTIK. Iki yer farkli karar verirse
    -- rozet "hayir" derken buton "evet" der — bugunku hatanin ta kendisi.
    -- 🔴 COALESCE SART. `carrier_ok` anahtari yoksa karsilastirma NULL
    -- doner, `false or null` = NULL olur ve blocks_request NULL cikar.
    -- JS'te null falsy oldugu icin BUGUN calisir — ama yarin biri
    -- `=== false` yazarsa sessizce bozulur. Uc degerli mantik, boolean
    -- bekleyen bir arayuze sizmamali.
    v_block := coalesce((d ->> 'severity') = 'block' and (d ->> 'enforcement') = 'block', false)
               or coalesce((d ->> 'carrier_ok') = 'false', false)
               or coalesce((d ->> 'charter') = 'true', false);
    -- Banka karti yolunda ASLA engellemeyiz (urun karari: genel uyari).
    if v_prog.id is null or v_prog.entitlement_model = 'bank_card' then
      v_block := false;
    end if;

    v_boost := 0;
    if v_block then                                  v_key := 'guest_none';  v_boost := -1000;
    elsif v_same then                                v_key := 'same_flight'; v_boost := 100;
    elsif (d ->> 'fits') = 'false' then              v_key := 'flight_bad';  v_boost := -100;
    elsif (d ->> 'guest_policy') = 'not_allowed' then v_key := 'guest_none'; v_boost := -200;
    elsif (d ->> 'guest_policy') = 'paid' then       v_key := 'guest_paid';  v_boost := -20;
    elsif (d ->> 'confidence') in ('unknown','assumed') then v_key := 'unverified'; v_boost := -10;
    elsif (d ->> 'guest_policy') = 'included' then   v_key := 'guest_free';  v_boost := 20;
    else v_key := null;
    end if;

    b := case when v_key is null then null else public.badge_text(v_key) end;

    severity := coalesce(d ->> 'severity','info');
    label    := b ->> 'label';
    info     := b ->> 'info';
    detail   := d ->> 'headline';
    same_flight_match := v_same;
    blocks_request := v_block;
    sort_boost := v_boost;
    return next;
  end loop;
end $$;
grant execute on function public.discovery_rule_badges(uuid[]) to authenticated;

select '116 OK - rozet artik kapi; siralama app tarafinda' as sonuc;
