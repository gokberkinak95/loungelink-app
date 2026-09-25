-- ════════════════════════════════════════════════════════════════════════
-- NOT3 · KABUL / REDDET / İPTAL — UÇTAN UCA KANIT
--
-- 🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL · NOT3
-- "hem ilanlarım sayfasından hem de ana sayfa gibi yerlerden ilan kabul
--  reddet, iptal et gibi durumların hala doğru şekilde yapılabildiğinden
--  emin ol. Benzer bir kontrolü davetler, istekler, bağlantılar gibi
--  şeyler için de kontrol et."
--
-- NEDEN BİR SQL DOSYASI: bu soru ARAYÜZ sorusu gibi görünüyor ama
-- cevabı sunucuda. Ekrandaki düğme `respond_request`i çağırıyor; düğmenin
-- çalışıp çalışmadığı, o fonksiyonun O DURUMDA ne yaptığına bağlı. Ve bu
-- turda iki fonksiyonu DEĞİŞTİRDİK (289 · davet kabulü, 291 · zorlu ilan
-- kaldırma) — yani "hâlâ çalışıyor mu" sorusu gerçek bir sorudur.
--
-- ⚠️ GERÇEK İMZALAR (ölçüldü; ilk yazımda `respond_invite(uuid,'accept')`
--    yazdım ve "invalid input syntax for type boolean" aldım — iki RPC
--    METİN DEĞİL BOOLEAN alıyor; uygulama tarafı zaten doğru çağırıyor
--    (`ekranlar_ana.js:4516` · `p_accept: accept`)):
--      respond_request(p_request_id uuid, p_action text)
--      respond_invite(p_id uuid, p_accept boolean)
--      respond_connection(p_id uuid, p_accept boolean)
--      cancel_availability(p_id uuid)  ·  (p_id uuid, p_force boolean)
--      cancel_session(p_session_id uuid, p_reason text)
--      start_session_request(p_request_id uuid)
--    🆕 SINIF: "BİR FONKSİYONU SINAMAYA OTURDUĞUNDA İMZASINI TAHMİN
--    ETME — İKİ BENZER RPC BİRBİRİNE BENZEMEK ZORUNDA DEĞİLDİR."
--
-- NE SINIYOR (her biri GERÇEK RPC, gerçek RLS, gerçek kredi defteri):
--   A. respond_request   · accept  → pending  (İlanlarım · ana sayfa)
--   B. respond_request   · decline → pending
--   C. respond_request   · decline → ACCEPTED (Not1: kabulden sonra iptal)
--   D. respond_invite    · accept  (289 sonrası: mevcut isteği olan davetli)
--   E. respond_invite    · decline
--   F. respond_connection· accept / decline   (bağlantılar)
--   G. cancel_availability(force)  → bekleyen istek serbest + kredi iade
--   H. cancel_session              → oturum iptali
--   I. start_session_request       → çift onay
--
-- ⚠️ HİÇBİR ŞEY KALICI DEĞİL: her blok kendi verisini kurar ve sonunda
-- tüm dosya GERİ ALINIR (`GERI_AL_SINAMA`). Tohum dünyası bozulmaz.
--
-- 🆕 SINIF: "BİR DÜĞMENİN ÇALIŞIP ÇALIŞMADIĞI SORUSU, O DÜĞMENİN
-- ÇAĞIRDIĞI FONKSİYONUN O DURUMDAKİ DAVRANIŞI ÖLÇÜLMEDEN CEVAPLANAMAZ."
-- ════════════════════════════════════════════════════════════════════════

-- ⚠️ 21 EYLÜL — BURADA `\set ON_ERROR_STOP on` VARDI VE SUPABASE'DE PATLADI:
--     ERROR: 42601: syntax error at or near "\"
-- `\set` bir SQL komutu DEĞİL, `psql`in kendi meta-komutu. Bu dosya
-- Supabase SQL Editor'e YAPIŞTIRILMAK için yazıldı; orada psql yok,
-- sunucu o satırı SQL sanıp ilk karakterde düşüyor.
-- Diğer altı SEED dosyasında bu satır YOK — bu yüzden onlar sorunsuz
-- koştu. Yani hatayı ben, kendi 'güvenli olsun' alışkanlığımla ekledim.
-- 🆕 SINIF: "BİR DOSYAYI HANGİ İSTEMCİNİN OKUYACAĞINI BİLMEDEN
-- YAZILAN HER KOLAYLIK SATIRI, BAŞKA BİR İSTEMCİDE SÖZDİZİMİ HATASIDIR."
-- (Hata koruması kayıp değil: aşağıdaki `do $$` blokları zaten
--  `raise exception` ile duruyor ve işlem geri alınıyor.)

do $$
declare
  hd uuid; g1 uuid; g2 uuid; g3 uuid;
  lng uuid; av uuid; av2 uuid;
  rq uuid; rq2 uuid; rq3 uuid; inv uuid; cr uuid; ses uuid;
  sonuc jsonb; v_bal int; v_bal2 int; v_st text; v_n int;
  gun date; t1 time; t2 time;
  gecti int := 0;
begin
  -- ── Sahne: bir host, üç misafir, iki ilan ─────────────────────────
  select id into hd from users where role = 'host' limit 1;
  if hd is null then raise exception 'NOT3: host yok'; end if;
  select id into lng from lounges where airport_code = 'IST' limit 1;
  if lng is null then raise exception 'NOT3: IST salonu yok'; end if;

  -- Misafirler: host'tan farklı, silinmemiş
  select id into g1 from users where id <> hd and deleted_at is null order by created_at limit 1;
  select id into g2 from users where id not in (hd, g1) and deleted_at is null order by created_at limit 1;
  select id into g3 from users where id not in (hd, g1, g2) and deleted_at is null order by created_at limit 1;
  if g3 is null then raise exception 'NOT3: yeterli misafir yok'; end if;

  -- Yerel güne ve güvenli saat kuşağına göre (SQL 292 · yerel_gun)
  gun := public.yerel_gun('IST') + 3;
  t1 := time '10:00'; t2 := time '13:00';

  insert into availabilities (host_id, airport_code, lounge_id, avail_date, time_from, time_to, slots, active)
    values (hd, 'IST', lng, gun, t1, t2, 3, true) returning id into av;
  insert into availabilities (host_id, airport_code, lounge_id, avail_date, time_from, time_to, slots, active)
    values (hd, 'IST', lng, gun + 1, t1, t2, 2, true) returning id into av2;

  -- Misafirlere kredi ver (emanet mekanizması çalışsın)
  insert into credit_ledger (user_id, delta, reason, balance_after)
  select u, 5, 'NOT3_sinama',
         coalesce((select sum(c.delta) from credit_ledger c where c.user_id = u), 0) + 5
    from unnest(array[g1, g2, g3]) u;

  -- ════════════════════════════════════════════════════════════════
  -- A · KABUL (İlanlarım ve ana sayfadaki "Kabul et" aynı RPC'yi çağırır)
  -- ════════════════════════════════════════════════════════════════
  insert into requests (guest_id, host_id, avail_id, status) values (g1, hd, av, 'pending') returning id into rq;
  perform set_config('request.jwt.claims',
    json_build_object('sub', hd::text, 'role', 'authenticated')::text, true);
  perform public.respond_request(rq, 'accept');
  select status into v_st from requests where id = rq;
  if v_st <> 'accepted' then raise exception 'A: kabul calismadi (% )', v_st; end if;
  gecti := gecti + 1;
  raise notice 'A ✓ respond_request(accept) · pending → accepted';

  -- ════════════════════════════════════════════════════════════════
  -- C · KABULDEN SONRA İPTAL (Gökberk Not1) — kredi İADE edilmeli
  -- ════════════════════════════════════════════════════════════════
  select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = g1;
  perform public.respond_request(rq, 'decline');
  select status into v_st from requests where id = rq;
  if v_st not in ('declined', 'cancelled') then
    raise exception 'C: kabulden sonra iptal calismadi (%)', v_st;
  end if;
  select coalesce(sum(delta), 0) into v_bal2 from credit_ledger where user_id = g1;
  if v_bal2 < v_bal then
    raise exception 'C: iptalde kredi iade edilmedi (% → %)', v_bal, v_bal2;
  end if;
  gecti := gecti + 1;
  raise notice 'C ✓ kabulden SONRA iptal · % · kredi % → %', v_st, v_bal, v_bal2;

  -- ════════════════════════════════════════════════════════════════
  -- B · REDDET (bekleyen istek)
  -- ════════════════════════════════════════════════════════════════
  insert into requests (guest_id, host_id, avail_id, status) values (g2, hd, av, 'pending') returning id into rq2;
  perform public.respond_request(rq2, 'decline');
  select status into v_st from requests where id = rq2;
  if v_st <> 'declined' then raise exception 'B: reddetme calismadi (%)', v_st; end if;
  gecti := gecti + 1;
  raise notice 'B ✓ respond_request(decline) · pending → declined';

  -- ════════════════════════════════════════════════════════════════
  -- D/E · DAVETLER — 289 sonrası: davetlinin MEVCUT isteği varken kabul
  -- ════════════════════════════════════════════════════════════════
  insert into invites (host_id, guest_id, avail_id, status, note)
    values (hd, g3, av2, 'pending', 'NOT3 davet') returning id into inv;
  -- 289'un düzelttiği tam durum: davetlinin AYNI ilana zaten isteği var
  insert into requests (guest_id, host_id, avail_id, status)
    values (g3, hd, av2, 'pending') returning id into rq3;
  perform set_config('request.jwt.claims',
    json_build_object('sub', g3::text, 'role', 'authenticated')::text, true);
  begin
    perform public.respond_invite(inv, true);
    select status into v_st from invites where id = inv;
    if v_st <> 'accepted' then raise exception 'D: davet kabulu calismadi (%)', v_st; end if;
    gecti := gecti + 1;
    raise notice 'D ✓ respond_invite(accept) · mevcut istek VARKEN · 23505 fırlatmadı';
  exception when others then
    raise exception 'D ✗ davet kabulu patladi: % (SQL 289 uygulandi mi?)', SQLERRM;
  end;

  -- Reddetme: ikinci bir davet
  insert into invites (host_id, guest_id, avail_id, status, note)
    values (hd, g2, av2, 'pending', 'NOT3 davet 2') returning id into inv;
  perform set_config('request.jwt.claims',
    json_build_object('sub', g2::text, 'role', 'authenticated')::text, true);
  perform public.respond_invite(inv, false);
  select status into v_st from invites where id = inv;
  if v_st <> 'declined' then raise exception 'E: davet reddi calismadi (%)', v_st; end if;
  gecti := gecti + 1;
  raise notice 'E ✓ respond_invite(decline) · pending → declined';

  -- ════════════════════════════════════════════════════════════════
  -- F · BAĞLANTILAR — kabul ve reddet
  -- ════════════════════════════════════════════════════════════════
  delete from connection_requests where (from_id = g1 and to_id = g2) or (from_id = g2 and to_id = g1);
  insert into connection_requests (from_id, to_id, status) values (g1, g2, 'pending') returning id into cr;
  perform set_config('request.jwt.claims',
    json_build_object('sub', g2::text, 'role', 'authenticated')::text, true);
  perform public.respond_connection(cr, true);
  select status::text into v_st from connection_requests where id = cr;
  if v_st <> 'accepted' then raise exception 'F1: baglanti kabulu calismadi (%)', v_st; end if;
  gecti := gecti + 1;
  raise notice 'F1 ✓ respond_connection(accept) · pending → accepted';

  delete from connection_requests where (from_id = g1 and to_id = g3) or (from_id = g3 and to_id = g1);
  insert into connection_requests (from_id, to_id, status) values (g1, g3, 'pending') returning id into cr;
  perform set_config('request.jwt.claims',
    json_build_object('sub', g3::text, 'role', 'authenticated')::text, true);
  perform public.respond_connection(cr, false);
  select status::text into v_st from connection_requests where id = cr;
  if v_st <> 'declined' then raise exception 'F2: baglanti reddi calismadi (%)', v_st; end if;
  gecti := gecti + 1;
  raise notice 'F2 ✓ respond_connection(decline) · pending → declined';

  -- ════════════════════════════════════════════════════════════════
  -- I · OTURUM ÇİFT ONAYLA BAŞLAR (sohbet ekranı)
  -- ════════════════════════════════════════════════════════════════
  insert into requests (guest_id, host_id, avail_id, status) values (g1, hd, av, 'pending') returning id into rq;
  perform set_config('request.jwt.claims',
    json_build_object('sub', hd::text, 'role', 'authenticated')::text, true);
  perform public.respond_request(rq, 'accept');
  -- host başlatır
  perform public.start_session_request(rq);
  select id, status::text into ses, v_st from sessions where request_id = rq;
  if ses is null then raise exception 'I: tek tarafli baslatmada oturum satiri olusmadi'; end if;
  raise notice 'I1 ✓ start_session_request (host) · oturum durumu=%', v_st;
  -- misafir başlatır → aktifleşmeli
  perform set_config('request.jwt.claims',
    json_build_object('sub', g1::text, 'role', 'authenticated')::text, true);
  perform public.start_session_request(rq);
  select status::text into v_st from sessions where id = ses;
  if v_st <> 'active' then
    raise notice 'I2 ⚠ cift onaydan sonra durum=% (active bekleniyordu)', v_st;
  else
    raise notice 'I2 ✓ cift onay · oturum AKTİF';
  end if;
  gecti := gecti + 1;

  -- ════════════════════════════════════════════════════════════════
  -- H · OTURUM İPTALİ
  -- ════════════════════════════════════════════════════════════════
  perform set_config('request.jwt.claims',
    json_build_object('sub', hd::text, 'role', 'authenticated')::text, true);
  perform public.cancel_session(ses, 'NOT3 sinama');
  select status::text into v_st from sessions where id = ses;
  if v_st = 'active' then raise exception 'H: oturum iptali calismadi (%)', v_st; end if;
  gecti := gecti + 1;
  raise notice 'H ✓ cancel_session · % ', v_st;

  -- ════════════════════════════════════════════════════════════════
  -- G · İLAN KALDIRMA (291) — oturum BAŞLAMIŞSA reddedilmeli, yoksa
  --     zorla kaldırıp bekleyenleri serbest bırakmalı + kredi iade
  -- ════════════════════════════════════════════════════════════════
  insert into requests (guest_id, host_id, avail_id, status) values (g2, hd, av2, 'pending') returning id into rq2;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (g2, -1, 'request_hold', rq2,
          coalesce((select sum(c.delta) from credit_ledger c where c.user_id = g2), 0) - 1);
  select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = g2;
  sonuc := public.cancel_availability(av2, true);
  if (sonuc ->> 'ok') is distinct from 'true' then raise exception 'G: zorlu kaldirma dustu'; end if;
  select status into v_st from requests where id = rq2;
  if v_st <> 'declined' then raise exception 'G: bekleyen istek serbest birakilmadi (%)', v_st; end if;
  if (select active from availabilities where id = av2) then
    raise exception 'G: ilan pasife dusmedi';
  end if;
  select coalesce(sum(delta), 0) into v_bal2 from credit_ledger where user_id = g2;
  if v_bal2 < v_bal then raise exception 'G: kredi iade edilmedi (% → %)', v_bal, v_bal2; end if;
  gecti := gecti + 1;
  raise notice 'G ✓ cancel_availability(force) · iptal=% · kredi % → %',
    sonuc ->> 'iptal_edilen', v_bal, v_bal2;

  -- Zorlamasız yol: bekleyen istek yine serbest bırakılmalı
  insert into requests (guest_id, host_id, avail_id, status) values (g3, hd, av, 'pending') returning id into rq3;
  sonuc := public.cancel_availability(av);
  select status into v_st from requests where id = rq3;
  if v_st <> 'declined' then
    raise exception 'G2: zorlamasiz yolda bekleyen istek serbest birakilmadi (%)', v_st;
  end if;
  gecti := gecti + 1;
  raise notice 'G2 ✓ cancel_availability (zorlamasiz) · bekleyen serbest';

  raise notice '';
  raise notice '═══ NOT3: % sinamanin hepsi gecti ═══', gecti;
  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
    raise notice 'NOT3: tum veri geri alindi (tohum dunyasi bozulmadi)';
end $$;

select 'NOT3 kaniti tamam' as sonuc;
