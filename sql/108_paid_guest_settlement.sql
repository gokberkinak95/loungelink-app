-- ============================================================
-- LoungeLink · 108_paid_guest_settlement.sql
-- UCRETLI MISAFIRDE HESAPLASMA (B secenegi)
--
-- ⚠️ Uygulamayi ETKILER. Yeni tetikleyici + ayar + RPC.
--
-- ------------------------------------------------------------
-- KARAR (Gokberk, B secenegi)
-- ------------------------------------------------------------
-- Priority Pass / LoungeKey / DragonPass'te misafir ucreti HOST'UN
-- KARTINDAN cekiliyor. Yani host, tanimadigi biri icin ~30-35 USD
-- oduyor. Bugune kadar misafire "host senin icin odeyecek" uyarisini
-- gosteriyor ama KARSILIGINDA HICBIR SEY ISTEMIYORDUK.
--
-- Karar verilmis ama kodu yazilmamis bir sey, en pahali haldir:
-- host iyi niyetle bir iki kez oder, sonra ilan acmayi birakir.
-- Darbogazimiz zaten ARZ; host'u yormak dogrudan urunu oldurur.
--
-- NEDEN KREDI, NEDEN GERCEK PARA DEGIL:
--   · Uygulama ICINDE gercek para/dijital urun satisi Google Play ve
--     App Store'un kendi faturalamasini zorunlu kilar (%15-30 komisyon).
--   · Kredi zaten var olan bir mekanizma; yeni altyapi gerekmiyor.
--   · Kredi TAZMINAT DEGIL, TESEKKURDUR. Urun dilinde de oyle geciyor —
--     35 USD'yi karsiladigi izlenimi vermek yanlis beklenti olur.
--
-- UC KOSUL (karar notunda yazili):
--   1. Misafir ISTEK GONDERMEDEN ONCE ne olacagini gorur.
--   2. Kredi "tesekkur" diye gecer, tazminat denmez.
--   3. Saha raporu gercek tutari olcer; uc ay sonra TAHMINLE degil
--      OLCUMLE karar veririz.
-- ============================================================

insert into beta_settings (key, value) values
  ('paid_guest_credit', to_jsonb(3)),
  ('paid_guest_notice', to_jsonb(
     'Bu ilanda misafir girisi ucretli ve ucret host''un kartindan cekiliyor. '
  || 'Istegin kabul edilirse hesabindan {n} kredi host''a aktarilacak. Bu bir '
  || 'tesekkur; gercek ucreti karsilamaz.'::text))
on conflict (key) do nothing;

-- Ucretli misafir mi, kac kredi?
create or replace function public.paid_guest_credit(p_avail_id uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare d jsonb; v_n int;
begin
  d := public.lounge_access_decision_v4(p_avail_id, null);
  -- 🔴 YALNIZ 'member_card' HALINDE. 'guest_at_door'da misafir zaten
  -- kendi cebinden oduyor; ustune kredi almak CIFTE ODEME olur.
  if (d ->> 'guest_policy') <> 'paid' or coalesce(d ->> 'fee_payer','') <> 'member_card' then
    return 0;
  end if;
  select coalesce((value #>> '{}')::int, 3) into v_n
    from beta_settings where key = 'paid_guest_credit';
  return coalesce(v_n, 3);
end $$;
grant execute on function public.paid_guest_credit(uuid) to authenticated;

-- Kabul aninda aktarim
create or replace function public.trg_settle_paid_guest()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_n int; v_bal int;
begin
  -- 🔴 `coalesce(old.status,'')` YANLIS: status bir ENUM ve '' o enum'da
  -- YOK. PostgreSQL bos dizeyi request_status'a cevirmeye calisip
  -- "invalid input value for enum" veriyordu — yani KABUL ETME AKISI
  -- TAMAMEN KIRILIYORDU. Iki hesapli E2E testi bunu ilk kosuda yakaladi;
  -- statik denetimlerin hicbiri goremezdi.
  -- Enumlarda null kontrolu icin `is distinct from` kullanilir.
  if new.status <> 'accepted' or old.status is not distinct from 'accepted' then
    return new;
  end if;
  v_n := public.paid_guest_credit(new.avail_id);
  if v_n <= 0 then return new; end if;

  -- Ayni istek icin IKI KEZ aktarma. Kabul geri alinip tekrar
  -- verilirse kullanici iki kez odemesin.
  if exists (select 1 from credit_ledger
              where reason = 'paid_guest_thanks:' || new.id::text) then
    return new;
  end if;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = new.guest_id;
  -- Kredisi yetmiyorsa AKISI DURDURMA. Bulusma zaten kabul edildi;
  -- burada hata firlatmak, kural disi bir sebeple kabulu iptal ederdi.
  if v_bal < v_n then
    insert into notifications (user_id, category, title, body)
    values (new.guest_id, 'credits', 'Kredi yetersiz',
            'Ucretli misafir ilanina kabul edildin ama tesekkur kredin yetmedi. '
         || 'Host''a bunu sohbette belirtmen iyi olur.');
    return new;
  end if;

  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (new.guest_id, -v_n, 'paid_guest_thanks:' || new.id::text, v_bal - v_n);

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = new.host_id;
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (new.host_id, v_n, 'paid_guest_thanks:' || new.id::text, v_bal + v_n);

  insert into notifications (user_id, category, title, body) values
    (new.host_id, 'credits', 'Tesekkur kredisi',
     'Ucretli misafir ilanin icin ' || v_n || ' kredi aktarildi.'),
    (new.guest_id, 'credits', 'Tesekkur kredisi gonderildi',
     'Host senin icin giris ucreti odeyecek; ' || v_n || ' kredi ona aktarildi.');
  return new;
end $$;

drop trigger if exists trg_settle_paid_guest on requests;
create trigger trg_settle_paid_guest
  after update of status on requests
  for each row execute function public.trg_settle_paid_guest();

-- Misafir ISTEK GONDERMEDEN ONCE gorsun
create or replace function public.request_precheck(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_av availabilities%rowtype; v_flight text;
  v_prog lounge_programs%rowtype; d jsonb; v_can boolean := true; v_ack boolean := false;
  v_credit int; v_bal int;
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

  if v_prog.id is null or v_prog.entitlement_model = 'bank_card' or v_prog.code = 'BANK_CARD' then
    return jsonb_build_object('can_request', true, 'needs_ack', true, 'kind','card_generic',
      'severity','warn','source_label','Kredi kartı avantajı',
      'headline','Bu ilandaki hak kredi kartından geliyor',
      'credit_cost', 0,
      'detail', public.rule_notice('card_notice_guest'));
  end if;

  if (d ->> 'severity') = 'block' then
    if (d ->> 'enforcement') = 'block' then v_can := false; else v_ack := true; end if;
  elsif (d ->> 'severity') = 'warn' then v_ack := true;
  elsif (d ->> 'confidence') = 'unknown' then v_ack := true;
  end if;

  return jsonb_build_object(
    'can_request', v_can, 'needs_ack', v_ack, 'kind','rule',
    'severity', d ->> 'severity', 'confidence', d ->> 'confidence',
    'guest_policy', d ->> 'guest_policy', 'fee_payer', d ->> 'fee_payer',
    'flight_coupling', d ->> 'flight_coupling',
    'source_label', coalesce(v_prog.name,'Lounge hakkı'),
    'credit_cost', v_credit,
    'credit_balance', v_bal,
    'credit_note', case when v_credit > 0
      then replace(public.rule_notice('paid_guest_notice'), '{n}', v_credit::text) end,
    'headline', d ->> 'headline', 'detail', d ->> 'detail');
end $$;
grant execute on function public.request_precheck(uuid) to authenticated;

select '108 OK - ucretli misafirde tesekkur kredisi kuruldu' as sonuc;

-- ============================================================
-- 🔴 E2E TESTININ YAKALADIGI IKINCI HATA
-- submit_field_report (095) sunu diyordu:
--     on conflict (session_id, reporter_id) do nothing
-- ama o iki kolonda BENZERSIZ KISIT YOK. PostgreSQL:
--     "there is no unique or exclusion constraint matching the
--      ON CONFLICT specification"
-- Yani SAHA RAPORU HIC KAYDEDILEMIYORDU. Kural verisini kendi
-- kullanimiyla buyuten dongu, ilk adiminda kirikti — ve bunu ancak
-- gercek bir oturumu bastan sona kosunca gorduk.
-- ============================================================
create unique index if not exists uq_field_report_once
  on lounge_field_reports (session_id, reporter_id);
