-- ============================================================
-- LoungeLink · 149_multi_entitlement.sql
-- BIRDEN COK HAK: HANGISI KAZANIR?
--
-- ⚠️ Uygulamayi ETKILER (karar mantigi).
--
-- ------------------------------------------------------------
-- 🔴 GOKBERK'IN YAKALADIGI BOSLUK
-- ------------------------------------------------------------
-- "Host'un Priority Pass'i VARSA ve ayni zamanda Elite Plus ise?
--  Ya da Priority Pass VARSA ve Classic Plus ise?"
--
-- Bugune kadar motor TEK bir hak sagalayicisi varsayiyordu. Oysa
-- gercek dunyada cogu sik ucan kiside IKI-UC hak birden var ve
-- HANGISININ kullanilacagi salona gore degisir:
--
--   · Classic Plus + Priority Pass, THY salonunda -> CLPL kazanir
--     ama misafir HAKKI YOK. Priority Pass o salonda gecmiyor.
--   · Classic Plus + Priority Pass, iGA Lounge'da -> PP kazanir,
--     CLPL orada gecersiz. Misafir PP kurallarina tabi.
--   · Elite Plus + Priority Pass, THY salonunda -> ELPL kazanir
--     (aile hakki var), PP'ye gerek yok.
--
-- 🔴 SECIM ILKESI: "en cok misafir veren" DEGIL, "o salonda GECERLI
-- olan ve en az riskli olan". Kullaniciyi kapida en az sasirtacak
-- cevap dogru cevaptir — cok misafir vaat edip geri cevrilmektense,
-- az vaat edip iceri girmek iyidir.
--
-- Siralama: (1) salonda gecerli mi, (2) dogrulanmis mi,
-- (3) misafir hakki, (4) ucretsiz mi.
-- ============================================================

create or replace function public.best_entitlement(
  p_venue_id uuid,
  p_program_codes text[],
  p_tier text default null,
  p_carrier text default null,
  p_cabin text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  c record; g jsonb; best jsonb := null; best_score int := -1; v_score int;
  alts jsonb := '[]'::jsonb; n_valid int := 0;
begin
  for c in
    select p.id, p.code, p.name, a.guest_policy, a.is_placeholder,
           a.checked_at, a.fee_payer, a.conditions
      from unnest(coalesce(p_program_codes, '{}'::text[])) pc
      join lounge_programs p on p.code = pc and p.active
      left join lounge_venue_acceptance a
             on a.venue_id = p_venue_id and a.program_id = p.id and a.active
  loop
    if c.guest_policy is null then
      -- Bu program BU SALONDA gecmiyor. Sessizce atlamak yerine
      -- alternatif listesine "gecmiyor" diye yaziyoruz: kullanici
      -- neden o kartinin kullanilmadigini gormeli.
      alts := alts || jsonb_build_object('program', c.name, 'valid', false,
                                          'why', 'Bu salonda geçerli değil');
      continue;
    end if;
    n_valid := n_valid + 1;
    g := public.resolve_guest_rule(c.id, p_venue_id, p_tier, p_carrier, p_cabin);

    -- 🔴 PUANLAMA: once GECERLILIK ve GUVEN, sonra misafir sayisi.
    -- "En cok misafir veren"i secmek cazip ama yanlis: dogrulanmamis
    -- bir kaynaga dayanip 2 misafir vaat etmektense, dogrulanmis bir
    -- kaynaga dayanip 1 misafir demek daha az zarar verir.
    v_score := 0
      + case when not c.is_placeholder and c.checked_at is not null then 40 else 0 end
      + case when c.guest_policy = 'included' then 20
             when c.guest_policy = 'paid' then 8 else 0 end
      + least(coalesce((g ->> 'guest_allowance')::int, 0), 3) * 5
      + case when coalesce((g ->> 'family_allowed')::boolean, false) then 6 else 0 end
      + case when coalesce(c.fee_payer,'') = '' then 3 else 0 end;

    alts := alts || jsonb_build_object(
      'program', c.name, 'valid', true,
      'guests', (g ->> 'guest_allowance')::int,
      'family', (g ->> 'family_allowed')::boolean,
      'headline', g ->> 'headline');

    if v_score > best_score then
      best_score := v_score;
      best := g || jsonb_build_object('program_code', c.code, 'program', c.name,
                                      'guest_policy', c.guest_policy,
                                      'fee_payer', c.fee_payer,
                                      'verified', (not c.is_placeholder and c.checked_at is not null));
    end if;
  end loop;

  if best is null then
    return jsonb_build_object('found', false, 'valid_count', 0, 'alternatives', alts,
      'headline', 'Bu salonda geçerli bir hakkın görünmüyor',
      'detail', 'Seçtiğin hakların hiçbiri bu salonda kabul edilmiyor.');
  end if;

  return best || jsonb_build_object(
    'found', true, 'valid_count', n_valid, 'alternatives', alts,
    -- Birden fazla gecerli hak varsa kullaniciya SOYLE: hangisini
    -- kullandigimizi bilmezse, kapida farkli bir kart uzatabilir.
    'multi_note', case when n_valid > 1
      then 'Birden fazla hakkın geçerli; en güvenlisini gösteriyoruz: ' || (best ->> 'program')
      end);
end $$;
grant execute on function public.best_entitlement(uuid, text[], text, text, text) to anon, authenticated;

-- ---- CAPRAZLAMA OZ-TESTI ----
create or replace function public.multi_entitlement_check()
returns table (senaryo text, secilen text, misafir text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare c record; g jsonb; v_ist_tk uuid; v_iga uuid;
begin
  select v.id into v_ist_tk from lounge_venues v
   where v.airport_code='IST' and v.active and v.name ilike '%turkish%'
     and coalesce(v.section,'') = 'miles_smiles' limit 1;
  select v.id into v_iga from lounge_venues v
   where v.airport_code='IST' and v.active and v.name ilike '%iga lounge%' limit 1;

  for c in select * from (values
    ('THY salonu · ELPL + PriorityPass', v_ist_tk, array['TK_MS','PRIORITY_PASS'],'ELPL','TK'),
    ('THY salonu · CLPL + PriorityPass', v_ist_tk, array['TK_MS','PRIORITY_PASS'],'CLPL','TK'),
    ('THY salonu · yalniz PriorityPass', v_ist_tk, array['PRIORITY_PASS'],        null,  'TK'),
    ('iGA salonu · CLPL + PriorityPass', v_iga,    array['TK_MS','PRIORITY_PASS'],'CLPL','TK'),
    ('iGA salonu · ELPL tek basina',     v_iga,    array['TK_MS'],                'ELPL','TK'),
    ('THY salonu · uc hak birden',       v_ist_tk, array['TK_MS','PRIORITY_PASS','DRAGONPASS'],'ELITE','TK')
  ) as t(ad, vid, progs, tier, carrier)
  loop
    g := public.best_entitlement(c.vid, c.progs, c.tier, c.carrier, null);
    senaryo := c.ad;
    secilen := coalesce(g ->> 'program', '(yok)');
    misafir := coalesce(g ->> 'guest_allowance','-')
            || case when coalesce((g ->> 'family_allowed')::boolean,false) then ' +aile' else '' end;
    sonuc := coalesce(g ->> 'headline','-');
    return next;
  end loop;
end $$;
grant execute on function public.multi_entitlement_check() to authenticated;

select * from public.multi_entitlement_check();
select '149 OK - coklu hak cozumlemesi kuruldu' as sonuc;
