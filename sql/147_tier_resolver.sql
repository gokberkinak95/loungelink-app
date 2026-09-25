-- ============================================================
-- LoungeLink · 147_tier_resolver.sql
-- TEK COZUMLEYICI: KART + TASIYICI + KABIN + SALON
--
-- ⚠️ Uygulamayi ETKILER (kural cozumleme merkezi).
--
-- ------------------------------------------------------------
-- 🔴 NEDEN TEK FONKSIYON
-- ------------------------------------------------------------
-- 146 tasiyici boyutunu VERIYE ekledi. Ama veri girmek yetmez —
-- bu projede uc kez yasadim: promo tablosu vardi ekrani yoktu,
-- flight.js yazildi cagrilmadi, blocks tablosu vardi kesif bakmiyordu.
--
-- Simdi kural cozumleme UC AYRI yerde yapiliyor:
--   lounge_access_decision_v3/v4/v5, guide_lounges, request_precheck
-- Her biri kendi ORDER BY'ini yaziyor. Uc farkli yerde ayni mantigi
-- tekrarlamak, uc farkli cevap uretme riskidir — ve 144'te tam bunu
-- yasadik (NULL siralama tuzagi yalniz bir yerde vardi).
--
-- Bu fonksiyon TEK KAYNAK olur; digerleri onu cagirir.
--
-- ------------------------------------------------------------
-- COZUMLEME ONCELIGI (en spesifikten genele)
--   1. salon + kart tipi + tasiyici   ← en kesin
--   2. salon + kart tipi
--   3. kart tipi + tasiyici           ← 146'nin ekledigi boyut
--   4. kart tipi
--   5. kabin sinifi
--   6. program varsayilani
--
-- 🔴 Her karsilastirma COALESCE'li: NULL, DESC siralamada basa cikar
-- ve 144'te bu yuzden Elite Plus'a "misafir goturemezsin" dedik.
-- ============================================================

create or replace function public.resolve_guest_rule(
  p_program_id uuid,
  p_venue_id   uuid    default null,
  p_tier       text    default null,
  p_carrier    text    default null,
  p_cabin      text    default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r lounge_guest_rules%rowtype; p lounge_programs%rowtype; v_alliance text; v_eff text;
begin
  select * into p from lounge_programs where id = p_program_id;
  if not found then return jsonb_build_object('found', false); end if;

  -- Tasiyici STAR ALLIANCE uyesi mi? THY disi bir Star uyesiyle
  -- ucuyorsan kural DEGISIR (aile hakki dusen) — Tablo-2.
  select c.alliance into v_alliance from carriers c where c.code = p_carrier;
  v_eff := case
    when p_carrier is null then null
    when p_carrier = 'TK' then 'TK'
    when p_carrier = 'VF' then 'VF'
    when v_alliance = 'star_alliance' then 'STAR_ALLIANCE'
    else p_carrier end;

  select * into r from lounge_guest_rules x
   where x.program_id = p_program_id
     and (x.venue_id is null or x.venue_id = p_venue_id)
     and (x.card_tier is null or x.card_tier = p_tier)
     and (x.carrier is null or x.carrier = v_eff)
     and (x.cabin_class is null or x.cabin_class = p_cabin)
     and (x.effective_to is null or x.effective_to >= current_date)
   order by
     -- 🔴 coalesce SART: bkz. 144/145. NULL karsilastirma DESC'te basa ciplar.
     coalesce(x.venue_id = p_venue_id, false) desc,
     coalesce(x.card_tier = p_tier, false) desc,
     coalesce(x.carrier = v_eff, false) desc,
     coalesce(x.cabin_class = p_cabin, false) desc,
     x.created_at desc
   limit 1;

  if not found then
    return jsonb_build_object(
      'found', false, 'program', p.name,
      'guest_allowance', case p.guest_default when 'included' then coalesce(p.guest_included_count,1) else 0 end,
      'family_allowed', false,
      'note', 'Bu kart tipi için özel kural bulunamadı; program varsayılanı uygulandı.');
  end if;

  return jsonb_build_object(
    'found', true,
    'program', p.name,
    'tier', public.card_tier_label(r.card_tier),
    'carrier_scope', r.carrier,
    'guest_allowance', coalesce(r.guest_allowance, 0),
    'family_allowed', coalesce(r.family_allowed, false),
    'paid_entry_allowed', coalesce(r.paid_entry_allowed, false),
    'same_flight_required', coalesce(r.guest_must_match_carrier, false),
    'note', r.notes,
    -- 🔴 KULLANICIYA TEK CUMLE: kararin ozeti. Ayrinti notta.
    'headline', case
      when coalesce(r.guest_allowance,0) > 0 and coalesce(r.family_allowed,false)
        then 'Ailen veya bir misafir götürebilirsin'
      when coalesce(r.guest_allowance,0) > 0
        then coalesce(r.guest_allowance,0)::text || ' misafir götürebilirsin'
      when coalesce(r.paid_entry_allowed,false)
        then 'Ücret ödeyerek girersin — misafir hakkın yok'
      else 'Girebilirsin ama misafir götüremezsin' end);
end $$;
grant execute on function public.resolve_guest_rule(uuid, uuid, text, text, text) to anon, authenticated;

-- ---- REHBER ARTIK TEK COZUMLEYICIYI KULLANIYOR ----
create or replace function public.guide_lounges(
  p_airport text, p_program_code text default null, p_tier text default null,
  p_carrier text default null, p_cabin text default null
) returns table (
  venue_id uuid, lounge_name text, scope text, terminal text,
  amenities jsonb, verdict text, headline text, detail text,
  guest_count int, confidence text, source_url text
) language plpgsql stable security definer set search_path = public as $$
declare r record; a lounge_venue_acceptance%rowtype; g jsonb; v_pid uuid;
begin
  v_pid := case when p_program_code is null then null
                else (select id from lounge_programs where code = p_program_code) end;

  for r in
    select v.*,
           case when v.section = 'business' and v.name !~* 'business' then v.name || ' — Business'
                when v.section = 'miles_smiles' and v.name !~* 'miles' then v.name || ' — Miles&Smiles'
                else v.name end as disp_name
      from lounge_venues v
     where v.airport_code = upper(p_airport) and v.active and v.venue_kind = 'lounge'
       and not exists (select 1 from lounge_venues c where c.section_of = v.id and c.active)
     order by (v.section is null) desc, v.name
  loop
    venue_id := r.id; lounge_name := r.disp_name;
    scope := coalesce(r.scope,''); terminal := coalesce(r.terminal,'');
    amenities := coalesce(r.amenities, '{}'::jsonb);

    select * into a from lounge_venue_acceptance x
     where x.venue_id = r.id and x.active
       and (v_pid is null or x.program_id = v_pid)
     order by coalesce(x.program_id = v_pid, false) desc, x.is_placeholder,
              x.checked_at desc nulls last
     limit 1;

    if v_pid is null then
      verdict := 'info'; headline := null;
      detail := (select string_agg(distinct p.name, ' · ')
                   from lounge_venue_acceptance x join lounge_programs p on p.id = x.program_id
                  where x.venue_id = r.id and x.active);
      guest_count := null; confidence := null; source_url := null;
      return next; continue;
    end if;

    if not found then
      verdict := 'no'; headline := 'Bu kartla girilmiyor';
      detail := 'Bu salon seçtiğin programı kabul etmiyor.';
      guest_count := 0; confidence := 'verified'; source_url := null;
      return next; continue;
    end if;

    g := public.resolve_guest_rule(a.program_id, r.id, p_tier, p_carrier, p_cabin);
    guest_count := (g ->> 'guest_allowance')::int;
    confidence := case when a.is_placeholder then 'unknown'
                       when a.checked_at is not null then 'verified' else 'assumed' end;
    source_url := a.source_url;

    if a.guest_policy = 'not_allowed' and guest_count = 0 then
      verdict := 'self_only'; headline := g ->> 'headline';
    elsif guest_count = 0 and (g ->> 'paid_entry_allowed')::boolean then
      verdict := 'paid'; headline := g ->> 'headline';
    elsif guest_count = 0 then
      verdict := 'self_only'; headline := g ->> 'headline';
    elsif a.guest_policy = 'paid' then
      verdict := 'paid'; headline := 'Misafir ücretli';
    else
      verdict := 'yes'; headline := g ->> 'headline';
    end if;
    detail := public.clip_text(coalesce(g ->> 'note', a.conditions, ''), 130);
    return next;
  end loop;
end $$;
grant execute on function public.guide_lounges(text, text, text, text, text) to anon, authenticated;

select '147 OK - tek cozumleyici kuruldu' as sonuc;
