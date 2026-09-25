-- ============================================================
-- LoungeLink · 155_member_cost_visible.sql
-- HOST'UN KENDİ MALİYETİ GÖRÜNÜR OLMALI
--
-- ⚠️ Uygulamayi ETKILER (host uyarisi + rehber cikti).
--
-- ------------------------------------------------------------
-- 🔴 154'TE VERIYI EKLEDIM — SIMDI MOTORA BAGLIYORUM
-- ------------------------------------------------------------
-- Bu projede uc kez ayni hatayi yaptim: tabloyu kurup ekrani unutmak.
-- (promo tablosu vardi ekrani yoktu, flight.js yazildi cagrilmadi,
-- blocks tablosu vardi kesif ona bakmiyordu.)
-- 154 `member_entry_fee` kolonunu ekledi; kimse okumuyorsa yok demektir.
--
-- 🔴 NEDEN ONEMLI: bir host Priority Pass Standard ile ilan acarsa
-- kendisi 30 EUR, misafiri 30 EUR oder — toplam 60 EUR. Uygulamamiz
-- ona "misafir goturebilirsin" deyip bu tutari soylemezse, host
-- kapida beklemedigi bir faturayla karsilasir.
--
-- Bir host'u kaybetmenin en hizli yolu, beklemedigi bir fatura.
-- Ve kaybedilen host geri gelmez — arkadaslarina da anlatir.
-- ============================================================

create or replace function public.entry_cost_note(
  p_program_id uuid, p_tier text default null
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r lounge_guest_rules%rowtype; p lounge_programs%rowtype;
begin
  select * into p from lounge_programs where id = p_program_id;
  select * into r from lounge_guest_rules x
   where x.program_id = p_program_id
     and (p_tier is null or x.card_tier = p_tier or x.card_tier is null)
     and (x.effective_to is null or x.effective_to >= current_date)
   order by coalesce(x.card_tier = p_tier, false) desc, x.card_tier nulls last
   limit 1;

  if not found or (coalesce(r.member_entry_fee,'') = '' and coalesce(r.guest_entry_fee,'') = '') then
    return jsonb_build_object('has_cost', false);
  end if;

  return jsonb_build_object(
    'has_cost', true,
    'program', p.name,
    'tier', public.card_tier_label(r.card_tier),
    'member_fee', nullif(r.member_entry_fee,''),
    'guest_fee', nullif(r.guest_entry_fee,''),
    'free_visits', r.member_free_visits,
    -- 🔴 BASLIK EN KOTU DURUMU SOYLER, ortalamayi degil.
    -- "Bazen ucretsiz olabilir" demek, host'u ucretsiz sanmaya iter.
    -- Beklenenden ucuza cikmak surpriz degil; pahaliya cikmak surprizdir.
    'headline', case
      when coalesce(r.member_entry_fee,'') <> '' and coalesce(r.guest_entry_fee,'') <> ''
        then 'Bu hakla hem kendi girişin hem misafirin ücretli olabilir'
      when coalesce(r.guest_entry_fee,'') <> ''
        then 'Misafir girişi ücretli — ücret senin kartından çekilir'
      else 'Kendi girişin ücretli olabilir' end,
    'detail', r.notes);
end $$;
grant execute on function public.entry_cost_note(uuid, text) to anon, authenticated;

-- ---- HOST ERISIM OZETI: maliyeti de sSoyler ----
drop function if exists public.access_source_summary(text);
create or replace function public.access_source_summary(p_source text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_pid uuid; v_tier text; v_cost jsonb; v_prog lounge_programs%rowtype;
begin
  select p.id into v_pid from lounge_programs p
   where p.active and (
     (p_source ilike '%priority%' and p.code = 'PRIORITY_PASS') or
     (p_source ilike '%dragon%'   and p.code = 'DRAGONPASS')    or
     (p_source ilike '%loungekey%' and p.code = 'LOUNGEKEY')    or
     (p_source ilike '%kart%'     and p.code = 'BANK_CARD')     or
     (p_source ilike '%havayolu%' and p.code = 'TK_MS'))
   limit 1;
  if v_pid is null then return jsonb_build_object('known', false); end if;

  select * into v_prog from lounge_programs where id = v_pid;
  select he.tier into v_tier from host_entitlements he
   where he.user_id = auth.uid() and he.program_id = v_pid limit 1;
  v_cost := public.entry_cost_note(v_pid, v_tier);

  return jsonb_build_object(
    'known', true,
    'program', v_prog.name,
    'verified', false,
    'summary', coalesce(v_cost ->> 'detail',
                        'Bu hakkın koşulları kartını veren kuruma göre değişir.'),
    -- 🔴 Host ilan acmadan ONCE gormeli. Sonra soylemek gec.
    'cost_warning', case when (v_cost ->> 'has_cost')::boolean
                         then v_cost ->> 'headline' end,
    'member_fee', v_cost ->> 'member_fee',
    'guest_fee', v_cost ->> 'guest_fee',
    'free_visits', v_cost -> 'free_visits');
end $$;
grant execute on function public.access_source_summary(text) to authenticated;

-- ---- REHBER: uyelik seviyesi secilince maliyeti de gosterir ----
create or replace function public.guide_cost(p_program_code text, p_tier text default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select public.entry_cost_note(
    (select id from lounge_programs where code = p_program_code), p_tier);
$$;
grant execute on function public.guide_cost(text, text) to anon, authenticated;

select (public.guide_cost('PRIORITY_PASS','PP_STANDARD') ->> 'headline') as pp_standard,
       (public.guide_cost('PRIORITY_PASS','PP_PRESTIGE') ->> 'headline') as pp_prestige,
       (public.guide_cost('DRAGONPASS','DP_CLASSIC') ->> 'member_fee')   as dp_classic;

select '155 OK - host maliyeti gorunur' as sonuc;
