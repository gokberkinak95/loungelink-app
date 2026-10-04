-- ============================================================================
-- 316 · SAATİ GEÇMİŞ BEKLEYEN İSTEK 5 DAKİKADA KAPANIR + DOĞRU BİLDİRİM  (4 Ekim 2026)
--
-- BULGU (uçtan uca test · Ana sayfa · host): ilanın saati geçmiş BEKLEYEN
-- istekler host'un ana sayfasında "Misafiri kabul et" düğmesiyle duruyordu;
-- düğme sunucudan `availability_expired` alıyordu (doğru), ama istek
-- `bayat_istekleri_iade_et()` saat başı cron'da koşana kadar açık kalıyor,
-- misafirin kredisi o süre tutuluyordu. pg_cron kapalı bir ortamda (yerel
-- dünya ölçüldü: 5 istek · 5 kredi) HİÇ kapanmıyordu.
--
-- DÜZELTME
--  1) expire_stale_sessions (5 dakikalık ortak süpürge; uygulama + ll-supurge)
--     sonunda bayat_istekleri_iade_et()'i de çağırır. Sonuç: 'bayat_istek'.
--  2) bayat_istekleri_iade_et bildirimi: bildir() ile TR+EN, sebep doğru
--     (ilanın saati geçti / N saat yanıt yok), salon adıyla.
--  3) YÜK TESTİ: süpürge freni `for update` ile her ana sayfa açılışını tek
--     sıraya diziyordu (10 eşzamanlı kullanıcı: p50 2,2 sn · 80: 22,8 sn).
--     Damga tazeyse kilitsiz dönüş + `for update skip locked`.
-- Gövdeler CANLI tanımın üstüne eklendi (pg_get_functiondef), yeniden yazılmadı.
-- Supabase SQL Editor: tek ifade = tek fonksiyon; dosya tekrar koşulabilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.bayat_istekleri_iade_et()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_saat int := coalesce((select (value #>> '{}')::int from beta_settings
                           where key = 'bayat_istek_saat'), 72);
  r record; v_kredi boolean; v_bal int; v_kapatilan int := 0; v_iade int := 0;
begin
  perform public.motor_yazimi_ac();

  for r in
    select req.id, req.guest_id,
           public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() as saat_gecti,
           public.salon_etiketi(req.avail_id) as salon
      from requests req
      join availabilities a on a.id = req.avail_id
     where req.status = 'pending'
       and req.responded_at is null
       -- 🔴 300/B4: UTC tarihi değil, havalimanının yerel saati. Eskiden
       -- saati geçmiş bir ilanın bekleyen isteği ertesi UTC gününe kadar
       -- açık kalıyordu (kredi tutulu, host cevap veremez).
       and (public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now()
            or req.created_at < now() - make_interval(hours => v_saat))
  loop
    -- Satır satır: bir satır bir iş kuralına takılırsa toplu iş çökmesin.
    begin
      update requests
         set status = 'cancelled',
             responded_at = now(),
             decision_note = coalesce(decision_note,
               'Host süresinde yanıtlamadı — istek otomatik kapatıldı (274).')
       where id = r.id and status = 'pending';
      if not found then continue; end if;
      v_kapatilan := v_kapatilan + 1;

      -- İADE yalnız gerçekten kredi düşülmüşse ve daha önce iade
      -- edilmemişse. `request_free_tier` satırları burada kasıtla dışarıda:
      -- harcanmayan kredi iade edilmez.
      if exists (select 1 from credit_ledger cl
                  where cl.ref_id = r.id and cl.reason in ('request_hold','invite_hold') and cl.delta < 0)
         and not exists (select 1 from credit_ledger cl
                          where cl.ref_id = r.id and cl.reason = 'request_stale_refund')
      then
        select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = r.guest_id;
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
        values (r.guest_id, public.tutulan_kredi(r.id), 'request_stale_refund', r.id,
                v_bal + public.tutulan_kredi(r.id),
                format('%s saat içinde yanıt gelmedi', v_saat));
        v_iade := v_iade + 1;
      end if;

      -- 316 · Eskiden TEK DİLLİ ve çoğu zaman YANLIŞ SEBEPLE: ilan 5 saat sonra
      -- bitse bile "72 saat içinde yanıtlanmadı" yazıyordu.
      v_kredi := exists (select 1 from credit_ledger cl
                          where cl.ref_id = r.id and cl.reason = 'request_stale_refund' and cl.delta > 0);
      if r.saat_gecti then
        perform public.bildir(r.guest_id, 'requests',
          'İsteğin kapandı',
          coalesce(r.salon || ' · ', '') || 'İlanın saati geçti, host yanıt veremedi.' || case when v_kredi then ' Kredin iade edildi.' else '' end || ' Keşfet''te başka ilanlar var.',
          'Your request closed',
          coalesce(r.salon || ' · ', '') || 'The listing time passed before the host replied.' || case when v_kredi then ' Your credit was refunded.' else '' end || ' There are other listings in Discover.',
          'request', r.id);
      else
        perform public.bildir(r.guest_id, 'requests',
          'İsteğin kapandı',
          coalesce(r.salon || ' · ', '') || format('%s saat içinde yanıt gelmedi.', v_saat) || case when v_kredi then ' Kredin iade edildi.' else '' end || ' Yeni istek gönderebilirsin.',
          'Your request closed',
          coalesce(r.salon || ' · ', '') || format('No reply within %s hours.', v_saat) || case when v_kredi then ' Your credit was refunded.' else '' end || ' You can send a new request.',
          'request', r.id);
      end if;
    exception when others then
      raise notice '274: istek % kapatilamadi: %', r.id, sqlerrm;
    end;
  end loop;

  return jsonb_build_object('ok', true, 'kapatilan', v_kapatilan,
                            'iade_edilen', v_iade, 'esik_saat', v_saat);
end $function$;

CREATE OR REPLACE FUNCTION public.expire_stale_sessions(p_kaynak text DEFAULT 'uygulama'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_req int := 0; v_sess int := 0;
  v_son timestamptz;
  v_sonuc jsonb;
  v_bayat jsonb;
begin
  -- ── FREN (298) ────────────────────────────────────────────────────
  -- `for update` ile alıyoruz: iki istemci aynı anda çağırırsa ikincisi
  -- birincinin damgasını bekler ve "atlandi" döner. pg_cron ile uygulama
  -- tetiği AYNI FRENİ paylaşır — ikisi birden açık olsa bile gövde
  -- 5 dakikada bir koşar.
  --
  -- 🔴 316 · YÜK TESTİ — FREN TEK SIRAYA DİZİYORDU. Her ana sayfa açılışı bu
  -- fonksiyonu çağırıyor; `for update` gövde koşarken (ölçek dünyasında
  -- 150-250 ms, veriyle büyür) TÜM eşzamanlı açılışları aynı satırda
  -- bekletiyordu: 10 kullanıcıda ana sayfa p50 2,2 sn, 80'de 22,8 sn.
  -- Artık: (1) damga tazeyse KİLİTSİZ dön, (2) kilidi `skip locked` ile al —
  -- başkası zaten süpürüyorsa beklemeden "atlandi" dön.
  select son_kosum into v_son from public.supurge_damgasi
   where ad = 'expire_stale_sessions';

  if v_son is not null and v_son > now() - interval '5 minutes' then
    return jsonb_build_object('ok', true, 'durum', 'atlandi',
                              'kaynak', p_kaynak,
                              'sonraki', v_son + interval '5 minutes');
  end if;

  if v_son is not null then
    select son_kosum into v_son from public.supurge_damgasi
     where ad = 'expire_stale_sessions' for update skip locked;
    if not found then
      return jsonb_build_object('ok', true, 'durum', 'atlandi', 'kaynak', p_kaynak,
                                'neden', 'baska_supurge_kosuyor');
    end if;
    if v_son > now() - interval '5 minutes' then   -- kilidi beklerken biri koştuysa
      return jsonb_build_object('ok', true, 'durum', 'atlandi',
                                'kaynak', p_kaynak,
                                'sonraki', v_son + interval '5 minutes');
    end if;
  end if;

  insert into public.supurge_damgasi (ad, son_kosum, kaynak)
  values ('expire_stale_sessions', now(), p_kaynak)
  on conflict (ad) do update set son_kosum = now(), kaynak = excluded.kaynak;

  -- ── GÖVDE ─────────────────────────────────────────────────────────
  --
  -- 🔴🔴 299/A2 — 298'DE KENDİ DÜŞÜRDÜĞÜM DÖRT ADIM GERİ KONULDU.
  --
  -- 298'de bu fonksiyonun başına freni takarken gövdeyi de yeniden
  -- yazdım ve 292'nin gövdesindeki DÖRT ADIMI düşürdüm. `drift_check.py`
  -- ikisini gösterdi (`perform public…`), kalan ikisini ben okuyarak
  -- buldum. Düşenler:
  --
  --   1) (b) bloğundaki `r.status = 'accepted'` KAPISI.
  --      280/K2'nin koyduğu kapı: iptal edilmiş isteğin yetim oturumu
  --      no_show DEĞİLDİR. Düşünce, iptal edilmiş bir isteğin arkasında
  --      kalan oturum yüzünden masum bir tarafa no_show yazılıyordu.
  --
  --   2) `perform public.recompute_trust(u) …`
  --      no_show işaretlenen tarafın güven puanı tazelenmiyordu. Yani
  --      ceza yazılıyor ama puana yansımıyordu.
  --
  --   3) (c) BLOĞUNUN TAMAMI — 187-noshow'un kapattığı hata.
  --      (b) oturumu 'expired' yapıyor ama isteği 'accepted' BIRAKIYOR.
  --      Bloksuz hali: misafirin kredisi sonsuza kilitli, host'un slotu
  --      sonsuza dolu (`sync_availability_filled` filled'ı accepted
  --      sayısından türetiyor). TEK BİR NO-SHOW İLANI KALICI OLARAK
  --      ÖLDÜRÜYORDU. 298 bunu geri getirmişti.
  --
  --   4) `perform public.tek_tarafli_oturumlari_kapat();`
  --
  -- 🆕 SINIF: "BİR FONKSİYONUN BAŞINA KAPI TAKARKEN GÖVDESİNİ YENİDEN
  -- YAZMA — ELDEKİ TANIMIN ÜSTÜNE EKLE. YENİDEN YAZMAK, GÖRMEDİĞİN HER
  -- ESKİ DÜZELTMEYİ SESSİZCE GERİ ALIR."
  --
  -- (a) Hiç başlatılmamış kabuller: kimse gelmedi ya da unutuldu →
  --     cezasız kapanış + kredi iadesi.
  --     🔴 İade tutarı artık sabit 1 değil: GERÇEKTEN TUTULAN kadar.
  with stale as (
    select r.id, r.guest_id
      from requests r
      join availabilities a on a.id = r.avail_id
      left join sessions s on s.request_id = r.id
     where r.status = 'accepted'
       -- 🔴 300/B2: `s.id is null` davet kabulünün açtığı BOŞ oturumu
       -- görmüyordu (293). Hiç kimse başlatmadıysa, oturum yok sayılır.
       and (s.id is null
            or (s.status = 'pending' and s.host_started_at is null
                and s.guest_started_at is null))
       and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours'
  ), upd as (
    update requests set status = 'cancelled' where id in (select id from stale) returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select u.guest_id, public.tutulan_kredi(u.id), 'expired_refund', u.id,
         coalesce((select sum(delta) from credit_ledger c where c.user_id = u.guest_id), 0)
           + public.tutulan_kredi(u.id)
    from upd u;
  get diagnostics v_req = row_count;
  -- 300/B2: iptal edilen isteğin arkasındaki boş oturum → 'expired' (no_show DEĞİL).
  update sessions s set status = 'expired', completed_at = now(), cancel_reason = 'not_started'
    from requests r
   where r.id = s.request_id and r.status = 'cancelled'
     and s.status = 'pending' and s.host_started_at is null and s.guest_started_at is null;

  -- (b) Tek taraf başlatmış ama diğeri hiç gelmemiş → 'expired'.
  --     `r.status = 'accepted'` KAPISI 280/K2'den; 299'da geri kondu.
  update sessions s
     set status = 'expired',
         completed_at = now(),
         cancel_reason = 'no_show',
         no_show_user_id = case when s.host_started_at is null then r.host_id else r.guest_id end
    from requests r, availabilities a
   where r.id = s.request_id and a.id = r.avail_id
     and s.status = 'pending'
     and r.status = 'accepted'
     and (s.host_started_at is null) <> (s.guest_started_at is null)
     and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours';
  get diagnostics v_sess = row_count;

  -- Etkilenenlerin güvenini tazele (292'den; 298'de düşmüştü).
  perform public.recompute_trust(u) from (
    select distinct no_show_user_id as u from sessions
     where cancel_reason = 'no_show' and no_show_user_id is not null
       and completed_at > now() - interval '1 day'
  ) x where u is not null;

  -- (c) 187-noshow · 298'de TAMAMEN DÜŞMÜŞTÜ, geri konuldu.
  --     (b) oturumu kapatır ama isteği 'accepted' bırakır; burada istek
  --     de kapanır ve kredi iade edilir. Yoksa kredi de slot da sonsuza
  --     kilitli kalır.
  with kapanan as (
    select r.id, r.guest_id
      from requests r
      join sessions s2 on s2.request_id = r.id
     where r.status = 'accepted'
       and s2.status = 'expired'
       and s2.cancel_reason = 'no_show'
  ), iade as (
    update requests set status = 'cancelled'
     where id in (select id from kapanan)
    returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select i.guest_id, public.tutulan_kredi(i.id), 'no_show_refund', i.id,
         coalesce((select sum(c.delta) from credit_ledger c
                    where c.user_id = i.guest_id), 0) + public.tutulan_kredi(i.id)
    from iade i
   where not exists (select 1 from credit_ledger c2
                      where c2.ref_id = i.id and c2.reason = 'no_show_refund');

  perform public.tek_tarafli_oturumlari_kapat();

  -- 316 · Saati geçmiş / bayatlamış BEKLEYEN istekler. Bu iş yalnız saat
  -- başı cron'daydı (274): ilan bittikten sonra 1 saate kadar host'a ölü bir
  -- 'Kabul et' düğmesi gösteriliyor, misafirin kredisi tutulu kalıyordu;
  -- pg_cron kapalıysa HİÇ kapanmıyordu. Artık 5 dakikalık süpürgeyle koşar.
  v_bayat := public.bayat_istekleri_iade_et();

  v_sonuc := jsonb_build_object('ok', true, 'durum', 'kosuldu',
                                'kaynak', p_kaynak,
                                'iptal_edilen', v_req, 'suresi_dolan', v_sess,
                                'bayat_istek', coalesce((v_bayat->>'kapatilan')::int, 0));

  -- Sonucu damgaya yaz: panelde "en son koşum NE YAPTI" görünsün.
  update public.supurge_damgasi
     set son_sonuc = v_sonuc, ardisik_hata = 0
   where ad = 'expire_stale_sessions';

  return v_sonuc;
exception
  when others then
    -- ⚠️ BURADA `update` DEĞİL `insert … on conflict` KULLANILIYOR VE
    -- BUNUN SEBEBİ ÖNEMLİ: plpgsql'de bir istisna, bloğun BAŞINDAN
    -- itibaren her şeyi geri alır — yukarıdaki damga `insert`i DAHİL.
    -- Yani handler'a girildiğinde satır ARTIK YOKTUR; `update` 0 satır
    -- günceller ve hata izi sessizce kaybolur. Tam da görünür kılmaya
    -- çalıştığımız şeyi kaybederdik.
    --
    -- 🆕 SINIF: "BİR HATA KAYDINI, HATANIN GERİ ALDIĞI SATIRIN ÜSTÜNE
    -- YAZAMAZSIN — HANDLER'DA HER ZAMAN YENİDEN OLUŞTURMAYA HAZIR OL."
    --
    -- Hatayı istisna olarak ATMIYORUZ, jsonb olarak DÖNÜYORUZ: çağıran
    -- `ok=false` görür, damga kalıcı olur ve `bo_supurge_sagligi()`
    -- onu gösterir. Yutmak değil — yerini değiştirmek.
    insert into public.supurge_damgasi (ad, son_kosum, kaynak, ardisik_hata, son_hata, son_hata_an)
    values ('expire_stale_sessions', coalesce(v_son, now() - interval '1 hour'),
            p_kaynak, 1, left(SQLERRM, 400), now())
    on conflict (ad) do update
      set ardisik_hata = public.supurge_damgasi.ardisik_hata + 1,
          kaynak       = excluded.kaynak,
          son_hata     = excluded.son_hata,
          son_hata_an  = excluded.son_hata_an;
    return jsonb_build_object('ok', false, 'durum', 'hata',
                              'kaynak', p_kaynak, 'hata', left(SQLERRM, 400));
end $function$;

-- ── DOĞRULAMA ───────────────────────────────────────────────────────────────
select 'expire_stale_sessions bayat adimi' as kontrol,
       position('bayat_istekleri_iade_et' in pg_get_functiondef('public.expire_stale_sessions(text)'::regprocedure)) > 0 as tamam
union all
select 'supurge freni beklemesiz',
       position('skip locked' in pg_get_functiondef('public.expire_stale_sessions(text)'::regprocedure)) > 0
union all
select 'bayat bildirimi iki dilli',
       position('Your request closed' in pg_get_functiondef('public.bayat_istekleri_iade_et()'::regprocedure)) > 0;
-- Beklenen: üç satır da tamam = true.
