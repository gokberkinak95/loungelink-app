-- ============================================================
-- LoungeLink · 115_quota_who_says.sql
-- SAYAC MI, GENEL MESAJ MI? — IKISI DE, AMA FARKLI KISIYE
--
-- ⚠️ Uygulamayi ETKILER (metin + karar ciktisi).
--
-- ------------------------------------------------------------
-- URUN KARARI
-- ------------------------------------------------------------
-- Gokberk sordu: "kartin kotasini sayacla mi gosterelim yoksa
-- 'bu kart yilda 4 misafir hakki tasir' gibi genel bir mesajla mi?"
--
-- Cevap: SORU YANLIS KURULMUS. Onemli olan sayac mi metin mi degil,
-- KIMIN SOYLEDIGI. Ayni bilgi host icin arac, misafir icin VAAT.
--
--   HOST icin sayac DEGERLI: kendi hakkini takip etmesine yarar.
--   Ama sayi BIZIM iddiamiz degil, ONUN BEYANI. "5/8 hakkin kaldi"
--   diye yazarsak biz soylemis oluruz; yanlissa bize kizar.
--   Dogrusu: "Kendi beyanina gore 5/8." Ayni sayi, farkli sahip.
--
--   MISAFIR icin sayi ZARARLI. Misafir "host'un 4 hakki var" diye
--   okur, guvenir, kapida cikarsa bize kizar. Oysa o sayiyi ne biz
--   dogruladik ne banka teyit etti. Misafire SEKLI soyleyecegiz,
--   SAYIYI degil: "bu kartta misafir hakki SINIRLI".
--
-- KURAL: dogrulanmamis bir sayiyi, o sayiyi BEYAN ETMEYEN kisiye
-- gostermeyiz. Beyan edene gosteririz — cunku o zaten biliyor,
-- biz sadece hatirlatiyoruz.
--
-- ------------------------------------------------------------
-- ENGELLEME: HAYIR
-- ------------------------------------------------------------
-- Dogrulanmamis kart ilan acmayi ENGELLEMEZ ve engellememeli.
-- Gerekcesi: bilmiyor olmamiz, kullanicinin hakki olmadigi anlamina
-- gelmez. Bizim veri eksigimizi kullanicinin onune duvar olarak
-- koymak, kendi kusurumuzu ona fatura etmektir.
-- Engel YALNIZ kanitli kural ihlallerinde: IST dis hat Business
-- bolumu, AJet@IST, charter, THY salonunda kart agi.
-- ============================================================

insert into beta_settings (key, value) values
 ('quota_note_host', to_jsonb(
   'Kendi beyanina gore {left}/{total} misafir hakkin kaldi. Bu sayiyi sen '
|| 'girdin — kart kosullari degisebiliyor, ara sira bankandan teyit et.'::text)),
 ('quota_note_guest_shape', to_jsonb(
   'Host''un kartinda misafir hakki SINIRLI sayidadir ve donem icinde '
|| 'tukenebilir. Kac hakki kaldigini biz dogrulayamiyoruz — bulusmadan '
|| 'once host ile teyit edin.'::text)),
 ('quota_note_guest_exhausted', to_jsonb(
   'Host kendi beyanina gore bu donemki misafir hakkini TUKETMIS gorunuyor. '
|| 'Yine de basvurabilirsin ama giris ucretli olabilir ya da kabul '
|| 'edilmeyebilir; bulusmadan once mutlaka konusun.'::text))
on conflict (key) do update set value = excluded.value;

-- Host'un gordugu: sayi + KIMIN beyani oldugu
create or replace function public.my_quota_line()
returns text language plpgsql stable security definer set search_path = public as $$
declare q jsonb; v text;
begin
  select public.entitlement_remaining(he.id) into q
    from host_entitlements he
   where he.user_id = auth.uid()
   order by he.self_reported_at desc nulls last limit 1;
  if q is null or (q ->> 'known') is distinct from 'true' then return null; end if;
  if (q ->> 'unlimited')::boolean then return null; end if;
  v := public.rule_notice('quota_note_host');
  return replace(replace(v, '{left}', coalesce(q ->> 'left','?')),
                 '{total}', coalesce(q ->> 'total','?'));
end $$;
grant execute on function public.my_quota_line() to authenticated;

-- Misafirin gordugu: SEKIL, sayi DEGIL
create or replace function public.guest_quota_note(p_host_id uuid)
returns text language plpgsql stable security definer set search_path = public as $$
declare q jsonb;
begin
  select public.entitlement_remaining(he.id) into q
    from host_entitlements he
   where he.user_id = p_host_id
   order by he.self_reported_at desc nulls last limit 1;
  if q is null or (q ->> 'known') is distinct from 'true' then return null; end if;
  if (q ->> 'unlimited')::boolean then return null; end if;
  -- 🔴 SAYIYI DEGIL, DURUMU dondururuz. Tek istisna: hak TUKENMISSE
  -- bu bir UYARIDIR, vaat degil — misafirin bilmesi onu korur.
  if coalesce((q ->> 'left')::int, 1) <= 0 then
    return public.rule_notice('quota_note_guest_exhausted');
  end if;
  return public.rule_notice('quota_note_guest_shape');
end $$;
grant execute on function public.guest_quota_note(uuid) to authenticated;

-- request_precheck: misafire kota SEKLINI ekle, sayiyi ASLA
create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
  v_credit int; v_bal int; v_qnote text; v_cnote text;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('can_request', false, 'headline','İlan bulunamadı.'); end if;

  select v.flight_number into v_flight from visits v
   where v.user_id = v_uid and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date and coalesce(v.flight_number,'') <> ''
   order by v.created_at desc limit 1;

  d := public.lounge_access_decision_v4(p_avail_id, v_flight);
  select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;
  v_credit := public.paid_guest_credit(p_avail_id);
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  v_qnote := public.guest_quota_note(v_av.host_id);
  v_cnote := public.card_confidence_note(v_av.host_id);

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object('can_request', true, 'needs_ack', true, 'kind','card_generic',
      'severity','warn','source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor',
      'credit_cost', 0,
      'detail', trim(both ' ' from public.rule_notice('card_notice_guest')
                  || ' ' || coalesce(v_qnote,'') || ' ' || coalesce(v_cnote,'')));
  end if;

  if (d ->> 'severity') = 'block' then
    if (d ->> 'enforcement') = 'block' then v_can := false; else v_ack := true; end if;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;
  end if;
  if v_qnote is not null or v_cnote is not null then v_ack := true; end if;

  return jsonb_build_object(
    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'credit_cost', v_credit, 'credit_balance', v_bal,
    'credit_note', case when v_credit > 0
      then replace(public.rule_notice('paid_guest_notice'), '{n}', v_credit::text) end,
    'headline', d ->> 'headline',
    'detail', trim(both ' ' from coalesce(d ->> 'detail','')
                || ' ' || coalesce(v_qnote,'') || ' ' || coalesce(v_cnote,'')));
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;

select '115 OK - sayac host''a, sekil misafire' as sonuc;
