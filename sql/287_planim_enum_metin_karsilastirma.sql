-- ============================================================
-- 287 · PLANIM EKRANI HİÇ AÇILMIYORMUŞ — `my_plan` HER ÇAĞRIDA HATA
-- 12 Eylül 2026
--
-- ÖLÇÜM (yerel `ll`, gerçek çağrı):
--     select public.my_plan('a1b2c3d4-…-00000000000f');
--     ERROR:  operator does not exist: plan_type <> text
--     LINE 19: …'ucretsiz_yukseltme', (v_g.id is not null and v_etkin <> v_satin…
--
-- 236'da `v_etkin` `plan_type` (enum), `v_satin` ise `text` olarak
-- bildirilmiş. PostgreSQL'de `enum <> text` diye bir işleç YOK; iki
-- taraf da TİPLİ olduğu için parser'ın "bilinmeyen sabit" kaçamağı da
-- devreye girmiyor. Yani bu satır KOŞULA BAĞLI DEĞİL — `jsonb_build_object`
-- her zaman değerlendiği için fonksiyon HER kullanıcı için, HER çağrıda
-- patlıyordu.
--
-- NASIL YAKALANDI: bu bir kod okuması değil, bir SAHNE çıktısı. Web
-- sahnesi `29_plan` ekranını çekerken köprü şu satırı kaydetti:
--     my_plan: operator does not exist: plan_type <> text
-- Ekran yine de çizildi (uygulama hatayı yutup varsayılana düşüyor),
-- bu yüzden EKRAN GÖRÜNTÜSÜNE BAKARAK anlaşılmazdı. Bir ekranın
-- "çalışıyor" görünmesi, altındaki çağrının çalıştığı anlamına gelmiyor.
--
-- 🆕 SINIF: "BİR EKRANIN AÇILMASI, O EKRANI BESLEYEN ÇAĞRININ
-- BAŞARILI OLDUĞUNU KANITLAMAZ — HATAYI YUTAN HER İSTEMCİ, SUNUCU
-- HATASINI BİR TASARIM SORUNU GİBİ GÖSTERİR."
--
-- ÇÖZÜM: tek karakterlik bir tip düzeltmesi — `v_etkin::text <> v_satin`.
-- Gövdenin geri kalanı 236'daki hâliyle BİREBİR aynı (veritabanından
-- `pg_get_functiondef` ile alındı, elle yeniden yazılmadı).
--
-- KOŞMA: Supabase → SQL Editor → tamamı → Run (tekrar koşulabilir).
-- DOĞRULAMA: `select public.my_plan();` bir jsonb döndürmeli, hata değil.
-- ============================================================
CREATE OR REPLACE FUNCTION public.my_plan(p_user uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := public.kimlik(p_user);
  -- 🔴 22 AGUSTOS: `text` idi, `etkin_plan()` `plan_type` donuyor.
  -- plpgsql atamada ortuk cevirdigi icin PATLAMIYORDU ama nobetci
  -- hakli: cagirici, cagirdigi seyin sozlesmesini yazmalidir —
  -- yoksa donus tipi degistigi gun sessizce yanlis calisir.
  v_satin text; v_etkin plan_type; v_p plan_catalog%rowtype;
  v_esik int; v_plan_hediye text; v_gun int;
  v_agir int; v_neden text;
  v_g plan_grants%rowtype;
  v_son timestamptz;
  v_kaldi int;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  select coalesce(u.plan::text,'yolcu') into v_satin from users u where u.id = v_uid;
  if not exists (select 1 from plan_catalog where plan::text = v_satin and aktif) then
    v_satin := 'yolcu';
  end if;

  v_esik := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_sessions'), 2);
  v_plan_hediye := coalesce((select value #>> '{}' from beta_settings where key='host_free_upgrade_plan'), 'sik_ucan');
  v_gun := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_days'), 30);

  v_etkin := public.etkin_plan(v_uid)::text;

  select * into v_g from plan_grants
   where user_id = v_uid and bitti_at is null and iptal_at is null and biter_at > now()
   limit 1;

  -- İlerleme sayacı: son hediyeden BU YANA (takvim ayı değil).
  select coalesce(max(coalesce(bitti_at, biter_at)), '-infinity'::timestamptz)
    into v_son from plan_grants where user_id = v_uid and kaynak='agirlama';
  select count(*) into v_agir
    from sessions s join requests r on r.id = s.request_id
   where r.host_id = v_uid and s.status='completed' and s.completed_at > v_son;

  if v_g.id is not null then
    v_kaldi := greatest(0, ceil(extract(epoch from (v_g.biter_at - now()))/86400)::int);
    v_neden := format('%s ayrıcalıkları %s gün daha senin — ücretsiz. %s tarihinde eski planına dönersin.',
                      (select ad from plan_catalog where plan = v_etkin),
                      v_kaldi,
                      to_char(timezone('Europe/Istanbul', v_g.biter_at), 'DD.MM.YYYY'));
  else
    v_kaldi := null;
    v_neden := case
      when v_agir > 0 then format('%s kişi ağırladın. %s ağırlamada üst plan 1 ay ücretsiz açılıyor.', v_agir, v_esik)
      else format('Birini ağırla — %s ağırlamada üst plan %s gün boyunca ücretsiz açılır.', v_esik, v_gun) end;
  end if;

  select * into v_p from plan_catalog where plan = v_etkin;

  return jsonb_build_object(
    'known', true,
    'satin_alinan', v_satin,
    'etkin', v_etkin,
    'ad', v_p.ad,
    'aylik_kredi', v_p.monthly_credits,
    'fiyat_try', v_p.price_try,
    'yillik_try', v_p.yillik_try,
    'haklar', v_p.perks,
    'kacirilan_sikligi', v_p.kacirilan_sikligi,
    'one_cikarma_ayda', v_p.one_cikarma_ayda,
    'yanma_uyarilari', to_jsonb(v_p.yanma_uyarilari),
    'ucus_dogrulama_ayda', v_p.ucus_dogrulama_ayda,
    'kart_siniri', v_p.kart_siniri,
    'oncelikli_destek', v_p.oncelikli_destek,
    'bu_ay_agirlama', v_agir,
    'esik', v_esik,
    'hediye_gun', v_gun,
    'ucretsiz_yukseltme', (v_g.id is not null and v_etkin::text <> v_satin),
    'hediye_biter', v_g.biter_at,
    'hediye_gun_kaldi', v_kaldi,
    'hediye_kaynak', v_g.kaynak,
    'neden', v_neden);
end $function$
