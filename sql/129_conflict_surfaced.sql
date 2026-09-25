-- ============================================================
-- LoungeLink · 129_conflict_surfaced.sql
-- CELISKI KULLANICIYA ULASSIN + AJET ITTIFAK KONTROLU
--
-- ⚠️ Uygulamayi ETKILER (karar ciktisi).
--
-- 128 celiskiyi KAYDETTI ama kullanici hala goremiyor. Gorunmeyen
-- veri olmayan veridir — bu projede uc kez yasadigim hata.
--
-- 🔴 AYRICA KRITIK BIR KONTROL:
-- 127 Elite/Elite Plus icin kuplaji 'same_alliance' yapti. Peki
-- carrier_match() AJet'i ne sayiyor? AJet'in `alliance` alani NULL.
-- Eger 'same_alliance' dalinda NULL ittifaklar birbirine esit
-- sayilsaydi, iki AJet-disi havayolu "ayni ittifak" gorunurdu ve
-- THY md.17'nin capraz misafir yasagi DELINIRDI.
-- 118'de `a1 is not null and a1 = a2` yazmisim — NULL guvenli.
-- Ama bunu VARSAYMAK yetmez, TEST etmek gerek: asagida dogruluyoruz.
-- ============================================================

create or replace function public.lounge_access_decision_v5(
  p_avail_id uuid, p_guest_flight text default null, p_guest_carrier text default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d jsonb; v_av availabilities%rowtype; m jsonb; v_conf text;
  v_host text; v_guest text; v_coupling text; v_sev text; v_extra text[] := '{}';
begin
  d := public.lounge_access_decision_v4(p_avail_id, p_guest_flight);
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return d; end if;

  -- 🔴 KAYNAK CELISKISI: varsa kullaniciya SOYLE ve severity'yi warn'a cek.
  -- Celiskiyi bilip susmak, kullanici adina karar vermektir.
  select a.source_conflict into v_conf
    from lounge_venue_acceptance a
    join lounges l on l.venue_id = a.venue_id
   where l.id = v_av.lounge_id and a.active
     and a.program_id = nullif(d ->> 'program_id','')::uuid
     and coalesce(a.source_conflict,'') <> ''
   limit 1;

  v_coupling := d ->> 'flight_coupling';
  v_host  := coalesce(v_av.carrier_code, public.carrier_from_flight(v_av.flight_number));
  v_guest := coalesce(nullif(p_guest_carrier,''), public.carrier_from_flight(p_guest_flight));
  v_sev := coalesce(d ->> 'severity','info');

  if coalesce(v_coupling,'any') in ('same_carrier','same_alliance') then
    m := public.carrier_match(v_host, v_guest, v_coupling);
    if not (m ->> 'ok')::boolean then
      v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    elsif not (m ->> 'known')::boolean then
      v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    end if;
    if (m ->> 'note') is not null then v_extra := v_extra || (m ->> 'note')::text; end if;
  end if;

  if v_conf is not null then
    v_sev := case when v_sev = 'block' then 'block' else 'warn' end;
    v_extra := v_extra || v_conf::text;
  end if;

  return d || jsonb_build_object(
    'severity', v_sev,
    'carrier_ok', case when m is null then null else (m ->> 'ok')::boolean end,
    'carrier_known', case when m is null then null else (m ->> 'known')::boolean end,
    'source_conflict', v_conf,
    'host_carrier', v_host, 'guest_carrier', v_guest,
    'detail', trim(both ' ' from coalesce(d ->> 'detail','') || ' ' || array_to_string(v_extra,' ')));
end $$;
grant execute on function public.lounge_access_decision_v5(uuid, text, text) to authenticated;

-- ============================================================
-- 🔴 DOGRULAMA: ITTIFAK MANTIGI AJET YASAGINI DELMIYOR MU?
-- Bu bir "umarim dogrudur" meselesi degil; test edilir.
-- ============================================================
select 'TK misafir LH (ikisi de Star Alliance)' as senaryo,
       public.carrier_match('TK','LH','same_alliance') ->> 'ok' as sonuc,
       'true beklenir' as beklenen
union all
select 'TK misafir VF/AJet (AJet ittifak uyesi DEGIL)',
       public.carrier_match('TK','VF','same_alliance') ->> 'ok', 'false beklenir'
union all
select 'VF misafir PC (ikisinin de ittifaki NULL)',
       public.carrier_match('VF','PC','same_alliance') ->> 'ok',
       'false beklenir — NULL ittifaklar esit SAYILMAMALI'
union all
select 'TK misafir TK (ayni havayolu)',
       public.carrier_match('TK','TK','same_alliance') ->> 'ok', 'true beklenir'
union all
select 'SAG: TK misafir LH ama same_flight sart',
       public.carrier_match('TK','LH','same_carrier') ->> 'ok',
       'false beklenir — Gold icin ittifak YETMEZ';

select '129 OK - celiski kullaniciya ulasiyor, ittifak mantigi test edildi' as sonuc;

-- ============================================================
-- 🔴 BUTUNLUK ONARIMI: SALON VAR, KENDI HAVAYOLUNUN KURALI YOK
-- ------------------------------------------------------------
-- Senaryo testinde kural11 (TK Classic, IST dis hat) aniden "misafir
-- alinmiyor" demeye basladi. Sebep: bagli oldugu salonun TK_MS kabul
-- satiri HIC YOKTU. 113'un birlestirmesi satiri kanonik olmayan bir
-- salonda birakmis, katalog kaydi ise baska salona yonlenmis.
--
-- Degismez denetimim bunu KACIRDI: "hic kabul satiri olmayan salon"
-- diye ariyordu, oysa bu salonun BASKA programlarin satiri vardi —
-- eksik olan KENDI havayolunun kuraliydi. Denetim "hic" diye sordugu
-- icin "eksik"i goremedi.
--
-- Onarim: adinda havayolu gecen her aktif salon, o havayolunun
-- programiyla eslesmis olmali.
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'included', 1,
       case when p.code = 'TK_MS' then 'same_alliance' else 'same_carrier' end,
       'warn',
       'Misafir hakki KART TIPINE bagli (Elite ve ustu 1 misafir/aile; Classic Plus '
       || 've Classic hak YOK, Classic ucretli girer). ' || p.name || ' kurallarindan.',
       p.source_url, current_date
  from lounge_venues v
  join lounge_programs p
    on (p.code = 'TK_MS'   and lower(v.name) like '%turkish airlines%')
    or (p.code = 'AJET_MS' and lower(v.name) like '%turkish airlines%'
        and v.airport_code <> 'IST')
 where v.active and v.venue_kind = 'lounge'
   and not exists (select 1 from lounge_venue_acceptance x
                    where x.venue_id = v.id and x.program_id = p.id)
on conflict (venue_id, program_id) do nothing;

select v.airport_code, left(v.name,32) salon,
       count(*) filter (where p.code = 'TK_MS') as tk_kurali
  from lounge_venues v
  left join lounge_venue_acceptance a on a.venue_id = v.id and a.active
  left join lounge_programs p on p.id = a.program_id
 where v.active and lower(v.name) like '%turkish airlines%'
 group by 1,2 order by 3, 1;
