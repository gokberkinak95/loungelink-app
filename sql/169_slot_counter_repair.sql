-- ============================================================
-- LoungeLink · 169_slot_counter_repair.sql
-- 166'NIN KANIT BLOĞU YANLIŞ YAZILMIŞTI — ÜRÜN DEĞİL TEST HATASI
--
-- ⚠️ Uygulamayı ETKİLEMEZ (sayaç onarımı + doğru test).
--
-- ------------------------------------------------------------
-- 🔴 NE OLDU
-- ------------------------------------------------------------
-- Gökberk'in Supabase'inde 166 şu hatayla durdu:
--   "bir iptal sonrası filled 2 — ÇİFTE AZALTMA hâlâ var (1 olmalı)"
--
-- İlk teşhisim yanlıştı ("trigger sende yok"). Yerel PG'de trigger'ı
-- düşürüp taklit ettim: o durumda filled 0'da kalıyor, 2 olmuyor.
-- Yani trigger ÇALIŞIYOR. Gerçek sebep testin kendisi:
--
--   166'nın kanıt bloğu `slots >= 2` olan HERHANGİ bir ilan seçip
--   iki kabul ekliyor ve "filled 2 olmalı" diyor. Bu, ilanın BOŞ
--   olduğunu varsayar. Benim sandbox'ımda ilanlar boştu; canlıda
--   o ilanın ZATEN kabul edilmiş isteği vardı. Dolayısıyla:
--     başlangıç 1 + iki yeni kabul = 3 → tavan(slots) ile 2
--     bir iptal → 2 (doğru!) ama test 1 bekliyordu.
--
-- Yani ürün doğru davranıyordu, test yanlış ölçüyordu. Bu, kendi
-- kurduğum "testin geçmesi ölçtüğünü ölçtüğü anlamına gelmez"
-- kuralının ters yüzü: TESTİN PATLAMASI da ürünün bozuk olduğu
-- anlamına gelmez.
--
-- DERS (kalıcı): mutlak değer beklemek yerine FARK ölçülür.
-- Başlangıç durumu her ortamda farklıdır; delta her yerde aynıdır.
-- ============================================================

-- ---- 1) GÜVENCE: trigger gerçekten yerinde mi ----
-- 166 cancel_request'teki elle azaltmayı kaldırdı; artık tek gerçek
-- kaynak trigger. Yoksa iptal edilen slot HİÇ boşalmaz — bu yüzden
-- varlığı artık varsayım değil, KONTROL.
do $$
begin
  if not exists (
    select 1 from pg_trigger
     where tgrelid = 'requests'::regclass
       and tgname = 'trg_requests_sync_filled'
       and not tgisinternal)
  then
    raise exception '169: trg_requests_sync_filled YOK — cancel_request elle azaltmayı bıraktığı için '
                    'slotlar boşalmaz. Önce bu trigger''ı oluşturan migration koşulmalı.';
  end if;
  raise notice '169: slot senkron trigger''ı yerinde ✓';
end $$;

-- ---- 2) ONARIM: sayacı gerçeğe eşitle ----
-- Geçmişte elle azaltma ile trigger birlikte çalıştığı dönemde
-- bazı ilanların sayacı kaymış olabilir (çifte azaltma yaşandıysa
-- OLDUĞUNDAN DÜŞÜK). Tek seferlik yeniden hesap.
do $$
declare n int;
begin
  with dogru as (
    select a.id,
           least(a.slots, (select count(*) from requests r
                            where r.avail_id = a.id
                              and r.status in ('accepted','completed'))) as gercek
      from availabilities a)
  update availabilities a
     set filled = d.gercek, updated_at = now()
    from dogru d
   where a.id = d.id and coalesce(a.filled,0) is distinct from d.gercek;
  get diagnostics n = row_count;
  raise notice '169: % ilanın slot sayacı gerçeğe eşitlendi', n;
end $$;

-- ---- 3) DOĞRU TEST: mutlak değil FARK ölçülür ----
-- Aynı iddia, ortamdan bağımsız biçimde: iki kabul eklenince sayaç
-- (tavana takılmadıysa) iki artar; bir iptal edilince BİR azalır.
-- Tavana takılma ihtimaline karşı kapasitesi yeterli bir ilan seçilir.
do $$
declare v_av uuid; v_h uuid; v_g1 uuid; v_g2 uuid; v_r1 uuid;
        v_base int; v_after int; v_cancel int;
begin
  select a.id, a.host_id, coalesce(a.filled,0)
    into v_av, v_h, v_base
    from availabilities a
   where a.active and a.slots - coalesce(a.filled,0) >= 2
   limit 1;
  if v_av is null then
    raise notice '169: 2 boş slotu olan ilan yok — delta testi atlandı (ürün hatası değil)';
    return;
  end if;

  select id into v_g1 from users where email like 'kmisafir1%' limit 1;
  select id into v_g2 from users where email like 'kmisafir2%' limit 1;
  if v_g1 is null or v_g2 is null then
    raise notice '169: seed misafirleri yok — delta testi atlandı';
    return;
  end if;

  insert into requests (avail_id, guest_id, host_id, status)
       values (v_av, v_g1, v_h, 'accepted') returning id into v_r1;
  insert into requests (avail_id, guest_id, host_id, status)
       values (v_av, v_g2, v_h, 'accepted');

  select coalesce(filled,0) into v_after from availabilities where id = v_av;
  if v_after - v_base <> 2 then
    delete from requests where avail_id = v_av and guest_id in (v_g1, v_g2);
    raise exception '169: iki kabul sayacı % artırmalıydı, % artırdı (başlangıç %)',
                    2, v_after - v_base, v_base;
  end if;

  update requests set status = 'cancelled' where id = v_r1;
  select coalesce(filled,0) into v_cancel from availabilities where id = v_av;

  delete from requests where avail_id = v_av and guest_id in (v_g1, v_g2);

  if v_after - v_cancel <> 1 then
    raise exception '169: bir iptal sayacı TAM 1 azaltmalıydı, % azalttı — '
                    'çifte azaltma veya trigger sorunu', v_after - v_cancel;
  end if;
  raise notice '169: slot deltası doğru (iki kabul +2, bir iptal -1) ✓';
end $$;

select '169 OK - sayac onarildi, test delta ile olculuyor' as sonuc;
