-- ============================================================================
-- LoungeLink · 231_kurucu_cember_sayaci.sql                (21 Ağustos 2026)
--
-- CANLI SOSYAL KANIT — AMA UYDURMADAN VE KENDİ AYAĞIMIZA SIKMADAN
--
-- Site "Kurucu çemberdeki ilk 100 host şunu alır" diyor. Bir sayaç
-- ("100'den 37'si doldu") dönüşümü en çok artıran şeydir; ama bu
-- projede sabit bir sayı yazmak iki kez yanlış olurdu:
--   · bugün yalan olur,
--   · yarın kendiliğinden eskir.
--
-- Ben de Gökberk'e "gerçek sayıyı söyle, koyayım" dedim. Bu yanlış
-- teklif: sayı BENDEN değil, VERİTABANINDAN gelmeli — ve o zaman
-- kimsenin bir şey söylemesi gerekmez.
--
-- 🔴 AMA BİR TUZAK VAR VE ÇÖZÜMÜ SİTEDE DEĞİL BURADA OLMALI:
-- liste 3 kişiyken "100'den 3'ü doldu" yazmak, sosyal kanıtın TERSİNİ
-- yapar — ziyaretçiye "burada kimse yok" der. Yani sayaç bazen
-- gösterilmemeli. Bu karar SİTEDE verilseydi, birileri eşiği kaldırıp
-- ham sayıyı basardı; ya da site sayıyı alır, gizlemeye karar
-- veremezdi.
--
-- 🆕 SINIF: **"BİR SAYIYI GÖSTERİP GÖSTERMEME KARARI, SAYININ KENDİSİ
-- KADAR VERİDİR — KARARI DA VERİYİ VEREN YER VERSİN."**
-- Bu yüzden RPC ham sayıyı EŞİK ALTINDA HİÇ DÖNDÜRMEZ. Site
-- gizleyemez, çünkü eline hiç geçmez. Sızıntı imkânsız.
--
-- Eşik `beta_settings`'te; Gökberk BO'dan değiştirebilir, kod
-- değişmez.
-- ============================================================================

insert into beta_settings (key, value) values
  ('kurucu_kontenjan',      to_jsonb(100)),   -- çemberin büyüklüğü
  ('kurucu_gosterim_esigi', to_jsonb(10))     -- bu sayıya ulaşmadan sayaç GÖSTERİLMEZ
on conflict (key) do nothing;

-- ----------------------------------------------------------------------------
-- RPC — anon çağırır. Kişisel veri YOK, e-posta YOK, ham sayı eşik
-- altında YOK.
-- ----------------------------------------------------------------------------
drop function if exists public.kurucu_cember();
create or replace function public.kurucu_cember()
returns jsonb language plpgsql stable security definer set search_path = public as $kc$
declare
  v_kontenjan int := coalesce((select (value #>> '{}')::int from beta_settings where key='kurucu_kontenjan'), 100);
  v_esik      int := coalesce((select (value #>> '{}')::int from beta_settings where key='kurucu_gosterim_esigi'), 10);
  v_host      int;
begin
  select count(*)::int into v_host from waitlist where role = 'host';

  if v_host < v_esik then
    -- 🔴 SAYI DÖNMÜYOR. Eşik altındayken ham sayıyı döndürüp "sen
    -- gizle" demek, sızıntıyı zaman meselesi yapardı.
    return jsonb_build_object(
      'goster', false,
      'kontenjan', v_kontenjan,
      'neden', 'esik_alti'
    );
  end if;

  return jsonb_build_object(
    'goster', true,
    'kontenjan', v_kontenjan,
    -- Kontenjan dolduysa sayı kontenjanı AŞMIŞ gösterilmez: "100/100"
    -- doğrudur, "137/100" saçmadır.
    'dolan', least(v_host, v_kontenjan),
    'kalan', greatest(v_kontenjan - v_host, 0)
  );
end $kc$;
grant execute on function public.kurucu_cember() to anon, authenticated;

comment on function public.kurucu_cember() is
  'Site sayaci. Esik altinda HAM SAYI DONDURMEZ (goster=false) — 3 kisilik bir '
  'liste gostermek sosyal kanitin tersini yapar. Karar burada verilir ki sitede '
  'gevsetilemesin.';

-- ----------------------------------------------------------------------------
-- NÖBETÇİ — eşik davranışını GERÇEKTEN dener
-- ----------------------------------------------------------------------------
do $n231$
declare
  v_cevap jsonb;
  v_host  int;
  v_esik  int;
begin
  select count(*)::int into v_host from waitlist where role='host';
  select coalesce((value #>> '{}')::int, 10) into v_esik from beta_settings where key='kurucu_gosterim_esigi';

  v_cevap := public.kurucu_cember();

  if (v_cevap->>'goster')::boolean then
    if v_cevap ? 'dolan' = false then
      raise exception '231 NOBETCI: goster=true ama dolan alani yok.';
    end if;
    if (v_cevap->>'dolan')::int > (v_cevap->>'kontenjan')::int then
      raise exception '231 NOBETCI: dolan (%) kontenjani (%) asiyor.',
        v_cevap->>'dolan', v_cevap->>'kontenjan';
    end if;
  else
    -- 🔴 EN ÖNEMLİ SINAMA: eşik altındayken ham sayı SIZMAMALI.
    if v_cevap ? 'dolan' or v_cevap ? 'kalan' then
      raise exception '231 NOBETCI: esik altinda ham sayi sizdi: %', v_cevap::text;
    end if;
  end if;

  raise notice '231 OK · host kaydi: % · esik: % · sayac gosteriliyor mu: %',
    v_host, v_esik, (v_cevap->>'goster');
  raise notice '231 NOT: bugun sayac muhtemelen GIZLI (esik alti) ve bu DOGRU. '
               'Liste % kisiye ulasinca site kendiliginden gostermeye baslar — '
               'kod degistirmeye gerek yok.', v_esik;
end $n231$;

-- ----------------------------------------------------------------------------
-- RPC YÜZEYİ
-- ----------------------------------------------------------------------------
insert into rpc_client_surface (fn_name, client, note) values
  ('kurucu_cember','public_web','Site sayaci — esik altinda ham sayi DONDURMEZ (231)')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '231: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select 'KURUCU CEMBER SAYACI KURULDU' as sonuc,
       public.kurucu_cember() as su_anki_cevap;
