-- ============================================================
-- 288 · GÜVEN EŞİĞİ ÖZELLİĞİ HİÇ ÇALIŞMIYORMUŞ — `profiles.trust_score` YOK
-- 12 Eylül 2026
--
-- ÖLÇÜM: sahne dünyasına bir ilana güven eşiği koyup istek göndermeyi
-- denedim; tohum betiği şu hatayla düştü:
--
--     ERROR: column pr.trust_score does not exist
--
-- Sebep 246'da iki yerde: güven puanı `profiles` tablosunda DEĞİL,
-- `trust_scores` tablosunda (`trust_scores.score`). İki çağrı da
-- olmayan bir kolonu okuyor:
--
--   1) `ilan_guven_esigi_yaz(...)` → dönüş nesnesindeki "şu an görebilen"
--      sayımı. Yani HOST bir ilana güven eşiği koymak istediğinde
--      fonksiyon HER ZAMAN hata veriyor; özellik hiç çalışmamış.
--   2) `trg_istek_guven_esigi()` → eşiği UYGULAYAN tetikleyici. `min_trust`
--      sıfırdan büyük olan bir ilana istek gönderilirse tetikleyici
--      patlıyor ve misafir isteği hiç gönderilemiyor — üstelik kullanıcı
--      sebebini göremiyor, çünkü bu bir Postgres kolon hatası, bizim
--      hata kodlarımızdan biri değil.
--
-- (2) daha ağır: (1) bozuk olduğu için canlıda eşik konulamamış olabilir,
-- ama eşik başka bir yoldan yazıldıysa O İLANA HİÇ İSTEK GİDEMEZ.
--
-- 🆕 SINIF: "BİR ÖZELLİĞİN KODU YAZILMIŞ OLMASI ONUN ÇALIŞTIĞINI
-- GÖSTERMEZ — HİÇ ÇAĞRILMAMIŞ BİR YOL, YAZILMAMIŞ BİR YOLDAN DAHA
-- TEHLİKELİDİR, ÇÜNKÜ YAPILMIŞ SAYILIR."
--
-- ÇÖZÜM: iki okuma da `trust_scores.score`a çevrildi. Gövdenin geri
-- kalanı 246'daki hâliyle birebir.
--
-- KOŞMA: Supabase → SQL Editor → tamamı → Run (tekrar koşulabilir).
-- DOĞRULAMA:
--   select public.ilan_guven_esigi_yaz('<ilan-id>', 30);   → jsonb dönmeli
-- ============================================================
create or replace function public.ilan_guven_esigi_yaz(p_avail_id uuid, p_esik int)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare v_uid uuid := auth.uid(); v_host uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_esik is null or p_esik < 0 or p_esik > 100 then
    raise exception 'gecersiz_deger' using hint = 'Guven esigi 0 ile 100 arasinda olmali.';
  end if;
  select host_id into v_host from availabilities where id = p_avail_id;
  if v_host is null then raise exception 'availability_not_found'; end if;
  if v_host <> v_uid then raise exception 'not_owner'; end if;

  perform public.motor_yazimi_ac();   -- 243: min_trust motor kolonlari arasinda
  update availabilities set min_trust = p_esik where id = p_avail_id;

  return jsonb_build_object('ok', true, 'min_trust', p_esik,
    'su_an_gorebilen', (select count(*) from trust_scores ts
                         where coalesce(ts.score, 0) >= p_esik));
end $f$;
grant execute on function public.ilan_guven_esigi_yaz(uuid, int) to authenticated;

create or replace function public.trg_istek_guven_esigi()
returns trigger language plpgsql security definer set search_path = public as $f$
declare v_esik int; v_puan int;
begin
  select coalesce(a.min_trust, 0) into v_esik from availabilities a where a.id = new.avail_id;
  if coalesce(v_esik, 0) = 0 then return new; end if;
  select coalesce(ts.score, 0) into v_puan from trust_scores ts where ts.user_id = new.guest_id;
  if coalesce(v_puan, 0) < v_esik then
    raise exception 'guven_esigi_altinda'
      using detail = format('guven skoru %s, esik %s', coalesce(v_puan,0), v_esik),
            hint   = 'Bu ilan icin gereken guven skoruna henuz ulasmadin. '
                  || 'Kimligini dogrulayarak ve oturum tamamlayarak yukseltebilirsin.';
  end if;
  return new;
end $f$;
