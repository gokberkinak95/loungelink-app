-- ============================================================
-- LoungeLink · 121_source_summary.sql
-- ERISIM KAYNAGI SECILIRKEN KURALI OZETLE
--
-- ⚠️ Uygulamayi ETKILER (yeni RPC).
--
-- 🔴 GOKBERK'IN ONERISI: host "Miles&Smiles" ya da "Priority Pass"
-- secerken o kaynagin kuralina dair kisa bir mesaj gorsun.
--
-- NEDEN DOGRU: host'un kurali OGRENDIGI an, ilani ACTIGI an degil
-- KAYNAGI SECTIGI andir. Kurali sonra soylemek, yanlis beklentiyle
-- ilerlemis bir host'u geri dondurmek demektir. Ustelik bu bilgi
-- host'un misafirine ne soyleyecegini de belirliyor.
--
-- 🔴 KREDI KARTI VE BILINMEYEN KAYNAKTA OZET YOK — bilerek.
-- Onlarda zaten "dogrulayamiyoruz" diyoruz; ustune bir de ozet
-- uydurmak, bilmedigimizi biliyormus gibi gostermek olur.
-- ============================================================

create or replace function public.access_source_summary(p_source text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare p lounge_programs%rowtype; v_pid uuid; v_tiers int; v_note text;
begin
  v_pid := public.match_program_by_text(p_source);
  if v_pid is null then
    return jsonb_build_object('known', false, 'summary', null);
  end if;
  select * into p from lounge_programs where id = v_pid;

  -- Banka karti: ozet YOK, genel uyari zaten var.
  if p.entitlement_model = 'bank_card' or p.code = 'BANK_CARD' then
    return jsonb_build_object('known', false, 'summary', null);
  end if;

  select count(*) into v_tiers from lounge_guest_rules r
   where r.program_id = p.id and r.card_tier is not null and r.venue_id is null
     and (r.effective_to is null or r.effective_to >= current_date);

  v_note := case p.guest_default
    when 'included'   then 'Misafir hakkı programa dahil.'
    when 'paid'       then case coalesce(p.fee_payer,'')
                             when 'member_card' then 'Misafir girişi ücretli ve ücret SENİN kartından çekilir.'
                             when 'guest_at_door' then 'Misafir girişi kapıda ücretli.'
                             else 'Misafir girişi ücretli olabilir.' end
    when 'not_allowed' then 'Bu programda misafir hakkı yok.'
    else 'Misafir politikası doğrulanmadı.' end;

  v_note := v_note || case coalesce(p.guest_flight_coupling,'any')
    when 'same_flight'   then ' Misafirin SENİNLE AYNI UÇUŞTA olmalı.'
    when 'same_carrier'  then ' Misafirin de aynı havayolunda uçuyor olmalı.'
    when 'same_alliance' then ' Misafirin ittifak üyesi bir havayolunda uçmalı.'
    else ' Misafirin hangi havayolunda uçtuğu önemsiz.' end;

  if v_tiers > 0 then
    v_note := v_note || ' Hakkın KART TİPİNE göre değişiyor — aşağıdan kart tipini seç.';
  end if;
  if p.max_stay_hours is not null then
    v_note := v_note || format(' Kalış ~%s saatle sınırlı.', trim(to_char(p.max_stay_hours,'FM990.0')));
  end if;

  return jsonb_build_object(
    'known', true,
    'program', p.name,
    'verified', p.coverage_status = 'verified',
    'needs_tier', v_tiers > 0,
    'summary', v_note,
    'source_url', p.source_url);
end $$;
grant execute on function public.access_source_summary(text) to authenticated;

select public.access_source_summary('Miles&Smiles Elite Plus');
select '121 OK - erisim kaynagi ozeti hazir' as sonuc;
