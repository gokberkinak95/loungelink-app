-- ============================================================================
-- LoungeLink · 245_vitrin_gokberkin_listesi.sql           (23 Ağustos 2026)
--
-- SENİN LİSTEN + ARİTMETİĞİN GÖRÜNÜR HÂLİ
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖNCE HESAP — ÇÜNKÜ YORUM İSTEDİN
-- ════════════════════════════════════════════════════════════════════════
-- Bir ağırlama 700 puan basıyor (host 500 + misafir 200).
-- Senin listenin her satırının bize maliyeti (kur 41 ₺/$ ile):
--
--   Ödül                        Puan   Maliyet   kuruş/puan   ağırlama
--   ─────────────────────────  ─────  ────────  ──────────  ────────
--   Havalimanı kahvesi           500      ₺60        12,0       0,7
--   Amazon hediye kartı ₺500    1000     ₺500        50,0       1,4
--   Airalo eSIM 3 GB            1500     ₺349        23,3       2,1
--   Marriott Bonvoy 20 $        2500     ₺820        32,8       3,6
--   Booking.com 25 $            3000    ₺1025        34,2       4,3
--   THY 1000 mil                5000    ₺1230        24,6       7,1
--
-- 🔴 SENİN ELEŞTİRDİĞİN ŞEY BU LİSTEDE DE VAR — DAHA BÜYÜĞÜ.
-- "Emirates 750 mil / 1200 puan" için "3 uçuşa 30 dolarlık hediye
-- verirsek batarız" dedin; o satır 18 kuruş/puandı. Yeni listedeki
-- **Amazon ₺500 / 1000 puan = 50 kuruş/puan**, yani eleştirdiğin
-- satırın ~3 katı. 1,4 ağırlamaya ₺500.
--
-- ⚠️ VE ŞU ÇOK ÖNEMLİ: **PUAN SAYILARI KOZMETİK.**
-- Bir ağırlamayı 700 yerine 70 puan yapıp Amazon'u 100 puana koysaydık
-- ekonomi ZERRE değişmezdi. Değişen tek şey rakamın görüntüsü olurdu.
--
-- 🆕 SINIF: **"BİR SADAKAT PROGRAMINDA PUAN SAYISI BİR TASARIM
-- TERCİHİDİR; TEK GERÇEK SAYI, BİR İŞLEMİN SANA KAÇ LİRAYA MAL
-- OLDUĞUDUR."**
--
-- Senin listende o sayı: **ağırlama başına ₺180–350.**
-- Bugünkü gelir: ₺0/ağırlama (gelir yalnız abonelikten, ağırlamadan
-- komisyon YOK).
--
-- ════════════════════════════════════════════════════════════════════════
-- O HÂLDE NE YAPIYORUM
-- ════════════════════════════════════════════════════════════════════════
-- Listeyi AYNEN kuruyorum — çünkü bunlar vitrin örneği ve kararı senin.
-- Ama zararı GİZLEMİYORUM: her satır `bilerek_zararina = true` ve
-- `zarar_gerekce` taşıyor, BO'da kırmızı görünüyor ve aylık yanma
-- hesabı ekranda yazıyor.
--
-- Ve üçüncü bir ödül türü ekliyorum — **`kendi`**: bize maliyeti SIFIR
-- olan, kendi ürünümüzden verdiğimiz ödüller. Asıl cevap bence burada;
-- gerekçesini teslim notunda yazdım.
--
-- ⚠️ ROZET VİTRİNDEN ÇIKTI. Haklısın: rozet puanla satın alınmaz,
-- kullanımla hak edilir. `hak_edilen_rozet` katalogu bu dosyada.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) ÜÇÜNCÜ TÜR: `kendi` · VE BİLEREK ZARAR ETME HAKKI
-- ----------------------------------------------------------------------------
alter table rewards add column if not exists bilerek_zararina boolean not null default false;
alter table rewards add column if not exists zarar_gerekce    text;

alter table rewards drop constraint if exists rewards_maliyet_turu_chk;
alter table rewards add constraint rewards_maliyet_turu_chk
  check (maliyet_turu in ('nakit','ortaklik','kendi'));

-- Bilerek zarar SEBEPSİZ olamaz. Bir kararın bedeli yazılıyorsa, sebebi
-- de yazılmalı — yoksa altı ay sonra kimse neden böyle olduğunu bilemez.
alter table rewards drop constraint if exists rewards_zarar_gerekce_chk;
alter table rewards add constraint rewards_zarar_gerekce_chk
  check (not bilerek_zararina or (zarar_gerekce is not null and length(btrim(zarar_gerekce)) >= 10));

create or replace function public.trg_odul_ekonomi_kapisi()
returns trigger language plpgsql security definer set search_path = public as $f$
declare v_asgari int;
begin
  if not coalesce(new.active, false) then return new; end if;
  if coalesce(new.maliyet_turu,'nakit') in ('ortaklik','kendi') then return new; end if;

  if new.supplier_cost_try is null then
    raise exception 'odul_maliyeti_yazilmamis'
      using detail = format('"%s" nakit odulu, maliyeti bilinmeden yayinlanamaz', new.title),
            hint   = 'BO > Odul Ekonomisi ekranindan maliyeti gir.';
  end if;

  v_asgari := public.odul_puan_onerisi(new.supplier_cost_try, 'nakit');
  if new.cost_points < v_asgari and not coalesce(new.bilerek_zararina, false) then
    raise exception 'odul_fiyati_maliyetin_altinda'
      using detail = format('"%s": %s puan, maliyet ₺%s → asgari %s puan',
                            new.title, new.cost_points, new.supplier_cost_try, v_asgari),
            hint   = 'Fiyati yukselt, ya da BILEREK zararina isaretleyip gerekce yaz.';
  end if;
  return new;
end $f$;

-- ----------------------------------------------------------------------------
-- 2) VİTRİN — GÖKBERK'İN LİSTESİ + İKİ EKLEME
-- ----------------------------------------------------------------------------
-- Rozet vitrinden çıkıyor: puanla satın alınan bir rozet, rozet değil
-- etikettir. Rozetler kullanımla hak edilir (aşağıda 4. bölüm).
update rewards set active = false;

do $vitrin$
declare
  v_kur numeric := coalesce((select (value #>> '{}')::numeric from beta_settings
                              where key='odul_kur_usd_try'), 41);
  r record;
begin
  for r in select * from (values
    -- baslik, altbaslik, kategori, puan, sira, saglayici, tur, maliyet_try, gerekce
    ('Havalimanı Kahvesi',        'Ortak kafelerde',    'yeme',    500,  1, 'Ortak kafe',
     'nakit',    60.0,  'Ilk odul bir PAZARLAMA GIDERI: kullanici sistemin gercekten odedigini gorsun diye. Kullanici basina bir kez.'),
    ('+2 Misafir İsteği Kredisi', 'Hemen hesabına',     'kendi',   500,  2, 'LoungeLink',
     'kendi',     0.0,  null),
    ('Amazon Hediye Kartı ₺500',  'Dijital kod',        'hediye', 1000,  3, 'Amazon',
     'nakit',   500.0,  'Vitrin ornegi — bilerek zararina. Gercek maliyet 50 kurus/puan; surdurulebilir degil, lansman kararidir.'),
    ('İlan Öne Çıkarma · 3 gün',  'Keşifte en üstte',   'kendi',   750,  4, 'LoungeLink',
     'kendi',     0.0,  null),
    ('Airalo eSIM 3 GB',          'Küresel veri',       'esim',   1500,  5, 'Airalo',
     'nakit',   349.0,  'Vitrin ornegi — bilerek zararina (23 kurus/puan).'),
    ('Sık Uçan Planı · 1 ay',     'Aylık 6 kredi',      'kendi',  2000,  6, 'LoungeLink',
     'kendi',     0.0,  null),
    ('Marriott Bonvoy 20 $ Kredi','Bonvoy otelleri',    'hotel',  2500,  7, 'Marriott Bonvoy',
     'nakit',   820.0,  'Vitrin ornegi — bilerek zararina (33 kurus/puan).'),
    ('Booking.com 25 $ Kredi',    'Her konaklama',      'hotel',  3000,  8, 'Booking.com',
     'nakit',  1025.0,  'Vitrin ornegi — bilerek zararina (34 kurus/puan).'),
    ('Türk Hava Yolları 1000 Mil','Miles&Smiles',       'miles',  5000,  9, 'Miles&Smiles',
     'nakit',  1230.0,  'Vitrin ornegi — bilerek zararina (25 kurus/puan). Hedef pazar Turkiye: vitrinin tepesi THY.')
  ) as t(baslik, alt, kat, puan, sira, saglayici, tur, maliyet, gerekce)
  loop
    update rewards
       set subtitle = r.alt, category = r.kat, cost_points = r.puan, sort_order = r.sira,
           supplier = r.saglayici, maliyet_turu = r.tur,
           supplier_cost_try = round(r.maliyet)::int,
           maliyet_kaynagi = 'tahmin', maliyet_guncel_at = now(),
           bilerek_zararina = (r.gerekce is not null),
           zarar_gerekce = r.gerekce,
           teslim_sekli = coalesce(teslim_sekli, 'manuel'),
           teslim_saat  = coalesce(teslim_saat, 48),
           active = true
     where title = r.baslik;

    if not found then
      insert into rewards (title, subtitle, category, cost_points, active, sort_order,
                           supplier, teslim_sekli, teslim_saat, maliyet_turu, maliyet_kaynagi,
                           supplier_cost_try, maliyet_guncel_at, bilerek_zararina, zarar_gerekce)
      values (r.baslik, r.alt, r.kat, r.puan, true, r.sira, r.saglayici,
              case when r.tur = 'kendi' then 'otomatik' else 'manuel' end,
              case when r.tur = 'kendi' then 1 else 48 end,
              r.tur, 'tahmin', round(r.maliyet)::int, now(),
              (r.gerekce is not null), r.gerekce);
    end if;
  end loop;
end $vitrin$;

-- Eski, artık vitrinde olmayanlar: silinmiyor, pasif duruyor.
-- (Emirates, SafetyWing, Airalo 10GB, Booking 50$, eski THY 500 mil,
--  LoungeLink rozeti, PP/DragonPass kartlari.)

-- ----------------------------------------------------------------------------
-- 3) SÜRDÜRÜLEBİLİRLİK — SAYIYI EKRANA YAZ
-- ----------------------------------------------------------------------------
-- Bir kararın bedelini görünmez kılmak, o kararı savunmak değil
-- ertelemektir. Bu fonksiyon "bu vitrin ayda ne yakar" sorusunu
-- cevaplıyor ve BO'da her açılışta görünüyor.
create or replace function public.odul_surdurulebilirlik(p_agirlama_ay int default 1)
returns jsonb language sql stable security definer set search_path = public as $f$
  with a as (
    select coalesce((select (value #>> '{}')::numeric from beta_settings where key='host_session_points'), 500)
         + coalesce((select (value #>> '{}')::numeric from beta_settings where key='guest_session_points'), 200) as puan_agirlama
  ),
  o as (
    select avg(r.supplier_cost_try::numeric * 100.0 / nullif(r.cost_points,0)) as ort_kurus
      from rewards r
     where r.active and coalesce(r.maliyet_turu,'nakit') = 'nakit' and r.supplier_cost_try is not null
  )
  select jsonb_build_object(
    'puan_agirlama',        (select puan_agirlama from a),
    'ortalama_kurus_puan',  round(coalesce((select ort_kurus from o), 0), 1),
    'odul_maliyeti_agirlama_try',
        round(coalesce((select ort_kurus from o), 0) * (select puan_agirlama from a) / 100.0, 2),
    'aylik_maliyet_try',
        round(coalesce((select ort_kurus from o), 0) * (select puan_agirlama from a) / 100.0 * p_agirlama_ay, 2),
    'sik_ucan_ayligi_try',  (select price_try from plan_catalog where plan='sik_ucan'),
    'yorum', case
      when coalesce((select ort_kurus from o), 0) = 0 then 'Aktif nakit odul yok — odul maliyeti sifir.'
      else format('Ayda %s agirlayan bir host icin odul maliyeti ~₺%s. Sik Ucan abonelik geliri ₺%s. %s',
                  p_agirlama_ay,
                  round(coalesce((select ort_kurus from o),0) * (select puan_agirlama from a) / 100.0 * p_agirlama_ay, 0),
                  coalesce((select price_try from plan_catalog where plan='sik_ucan'), 0),
                  case when coalesce((select ort_kurus from o),0) * (select puan_agirlama from a) / 100.0 * p_agirlama_ay
                            > coalesce((select price_try from plan_catalog where plan='sik_ucan'), 0)
                       then 'ODUL MALIYETI ABONELIK GELIRINI ASIYOR.'
                       else 'Abonelik geliri odul maliyetini karsiliyor.' end)
    end);
$f$;
revoke execute on function public.odul_surdurulebilirlik(int) from public, anon, authenticated;
grant execute on function public.odul_surdurulebilirlik(int) to service_role;

-- ----------------------------------------------------------------------------
-- 4) ROZETLER PUANLA SATILMAZ — HAK EDİLİR
-- ----------------------------------------------------------------------------
-- "Rozetleri kullanım karşılığı biz tanımlamalıyız zaten." Katılıyorum.
-- Bir rozet SATIN ALINABİLİYORSA, taşıdığı bilgi "bu kişi bunu yaptı"
-- değil "bu kişi bunu aldı" olur — yani rozetin bütün anlamı gider.
create table if not exists rozet_katalogu (
  kod        text primary key,
  ad         text not null,
  aciklama   text not null,
  kosul_tur  text not null check (kosul_tur in ('agirlama','misafirlik','dogrulama','kidem')),
  esik       int  not null check (esik >= 1),
  sira       int  not null default 0
);
revoke all on public.rozet_katalogu from anon, authenticated;
grant select on public.rozet_katalogu to authenticated;
alter table public.rozet_katalogu enable row level security;
drop policy if exists rozet_okuma on public.rozet_katalogu;
create policy rozet_okuma on public.rozet_katalogu for select using (true);

insert into rozet_katalogu (kod, ad, aciklama, kosul_tur, esik, sira) values
  ('ilk_kapi',    'İlk Kapı',      'İlk misafirini ağırladın',                  'agirlama',   1, 1),
  ('kapi_acan',   'Kapı Açan',     '5 kez ağırladın',                           'agirlama',   5, 2),
  ('ev_sahibi',   'Ev Sahibi',     '15 kez ağırladın',                          'agirlama',  15, 3),
  ('ilk_misafir', 'İlk Misafir',   'İlk kez birinin misafiri oldun',            'misafirlik', 1, 4),
  ('kimlik',      'Doğrulanmış',   'Kimliğini doğruladın',                      'dogrulama',  1, 5),
  ('kurucu',      'Kurucu Çember', 'İlk 100 host arasındasın',                  'kidem',    100, 6)
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama;

-- ----------------------------------------------------------------------------
-- 5) NÖBETÇİ
-- ----------------------------------------------------------------------------
do $n245$
declare
  v_h text[] := '{}';
  v_aktif int; v_ucuz int; v_kendi int; v_gecti boolean; v_id uuid;
begin
  select count(*) into v_aktif from rewards where active;
  select min(cost_points) into v_ucuz from rewards where active;
  select count(*) into v_kendi from rewards where active and maliyet_turu='kendi';

  if v_aktif < 6 then v_h := v_h || format('vitrinde yalniz %s odul var', v_aktif); end if;
  if v_ucuz > 500 then v_h := v_h || format('en ucuz odul %s puan — ilk basamak cok yuksek', v_ucuz); end if;
  if v_kendi = 0 then v_h := v_h || 'kendi urunumuzden HIC odul yok — vitrin tamamen disariya bagimli'::text; end if;

  -- Rozet vitrinden gercekten cikti mi
  if exists (select 1 from rewards where active and category = 'rozet') then
    v_h := v_h || 'rozet HALA puanla satiliyor'::text;
  end if;
  if (select count(*) from rozet_katalogu) < 4 then
    v_h := v_h || 'rozet katalogu bos — rozetler hicbir sekilde hak edilemiyor'::text;
  end if;

  -- Kapi hala calisiyor mu: gerekcesiz zararina odul GECMEMELI
  begin
    select id into v_id from rewards where active and maliyet_turu='nakit' limit 1;
    if v_id is not null then
      v_gecti := false;
      begin
        update rewards set bilerek_zararina = false, zarar_gerekce = null, cost_points = 1
         where id = v_id;
        v_gecti := true;
      exception when others then
        if sqlerrm not like '%odul_fiyati_maliyetin_altinda%'
           and sqlerrm not like '%rewards_zarar_gerekce_chk%' then
          v_h := v_h || ('beklenmeyen hata: ' || sqlerrm);
        end if;
      end;
      if v_gecti then
        v_h := v_h || 'GEREKCESIZ zararina odul gecti — kapi calismiyor'::text;
      end if;
    end if;
    raise exception 'GERI_AL_245';
  exception when others then
    if sqlerrm <> 'GERI_AL_245' then v_h := v_h || ('olcum coktu: ' || sqlerrm); end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '245 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '245 OK · % odul (% tanesi kendi urunumuz) · en ucuz % puan · rozetler hak edilir',
    v_aktif, v_kendi, v_ucuz;
  raise notice '245 SURDURULEBILIRLIK · %',
    (public.odul_surdurulebilirlik(1) ->> 'yorum');
end $n245$;

select '245 VITRIN KURULDU' as sonuc,
       (select count(*) from rewards where active)                              as aktif_odul,
       (select count(*) from rewards where active and maliyet_turu='kendi')     as kendi_urun_odulu,
       (select count(*) from rewards where active and bilerek_zararina)         as bilerek_zararina,
       (public.odul_surdurulebilirlik(1) ->> 'odul_maliyeti_agirlama_try')      as agirlama_basina_odul_try,
       (select count(*) from rozet_katalogu)                                    as hak_edilen_rozet;
