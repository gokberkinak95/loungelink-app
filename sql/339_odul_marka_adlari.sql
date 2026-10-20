-- ============================================================================
-- 339 · ÖDÜL ADLARINDAN MARKA ÇIKAR (anlaşma imzalanana kadar)   (20 Ekim 2026)
--
-- Gökberk: "pasife almak yerine kategori adı yapalım". Neden: Apple 5.2 (fikri mülkiyet) —
-- uygulamada üçüncü taraf marka adı, o markayla iş birliği varmış izlenimi verir ve inceleme
-- bunu sorar; ayrıca mil programlarının koşulları mili ticari karşılıkla devretmeyi kısıtlar.
-- Ödülün KENDİSİ değişmez (aynı ürün, aynı tedarikçi, aynı puan); yalnız kullanıcının gördüğü
-- ad ve alt satır kategori olur. `supplier` iç bilgi olarak kalır (BO kuyruğu ona göre çalışır).
--
-- Ayrıca: ödül alınca giden bildirim "<tedarikçi> tarafından hazırlanıyor" diyordu ("Amazon
-- tarafından hazırlanıyor") — markanın ödülü bizimle birlikte verdiğini söylüyordu. Artık
-- "Hazırlanıyor".
--
-- Anlaşma imzalanınca adı BO › Ödüller'den geri yazmak yeterli.
-- Supabase SQL Editor'de tek parça koşar; tekrar koşulabilir. Doğrulama: beş satır tamam = true.
-- ============================================================================

-- §1 · adlar (etkin ve pasif; pasif olan sonradan açılırsa da markasız açılsın)
update rewards set title = '₺500 Alışveriş Hediye Kartı', subtitle = 'Dijital kod · e-postana'
 where title in ('Amazon Hediye Kartı ₺500');
update rewards set title = 'Yurt Dışı eSIM · 3 GB', subtitle = 'Küresel veri'
 where title in ('Airalo eSIM 3 GB', 'Airalo eSIM 3GB');
update rewards set title = 'Yurt Dışı eSIM · 10 GB', subtitle = 'Küresel veri · 30 gün'
 where title in ('Airalo eSIM 10 GB', 'Airalo eSIM 10GB');
update rewards set title = 'Otel Kredisi · 20 $', subtitle = 'Seçili otel zincirlerinde'
 where title in ('Marriott Bonvoy 20 $ Kredi', 'Marriott Bonvoy 20$ Kredi');
update rewards set title = 'Konaklama Kredisi · 25 $', subtitle = 'Rezervasyon sitesinde'
 where title in ('Booking.com 25 $ Kredi', 'Booking.com 25$ Kredi');
update rewards set title = 'Konaklama Kredisi · 50 $', subtitle = 'Rezervasyon sitesinde'
 where title in ('Booking.com 50$ Kredi', 'Booking.com 50 $ Kredi');
update rewards set title = '1000 Havayolu Mili', subtitle = 'Mil programı hesabına'
 where title in ('Türk Hava Yolları 1000 Mil');
update rewards set title = '500 Havayolu Mili', subtitle = 'Mil programı hesabına'
 where title in ('Türk Hava Yolları 500 Mil');
update rewards set title = '750 Havayolu Mili · uluslararası', subtitle = 'Mil programı hesabına'
 where title in ('Emirates Skywards 750 Mil');
update rewards set title = 'Seyahat Sağlık Sigortası · 1 ay', subtitle = 'Yurt dışı seyahatte'
 where title in ('SafetyWing 1 Ay');
-- Alt satırda marka kalanlar (ad değişmiş olsa bile)
update rewards set subtitle = 'Mil programı hesabına' where subtitle in ('Miles&Smiles', 'Skywards');
update rewards set subtitle = 'Seçili otel zincirlerinde' where subtitle in ('Bonvoy otelleri');

-- §2 · ödül bildirimi: tedarikçi adı kullanıcıya gitmez
do $rr339$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
   where p.proname = 'redeem_reward' and p.pronamespace = 'public'::regnamespace and p.pronargs = 2;
  if v_def is null then raise exception '339: redeem_reward(uuid,int) yok — once 338'; end if;
  if v_def not like '%tarafından hazırlanıyor%' then return; end if;   -- zaten yamalı
  v_yeni := replace(v_def, $s$|| v_r.supplier || ' tarafından hazırlanıyor. En geç '$s$, $s$|| 'Hazırlanıyor. En geç '$s$);
  if v_yeni = v_def then raise exception '339: bildirim metni beklenen bicimde degil'; end if;
  execute v_yeni;
end $rr339$;

-- §2b · Plan ekranı hediye cümlesi: eşik dolmuşken "1 ağırlama daha yaparsan" diyordu (ölçüldü: 3 ağırlama,
--       hediye henüz açılmamış). Hediye bir sonraki ONAYLANAN buluşmada değerlendirilir; cümle bunu söyler.
do $mp339$
declare v_def text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
   where p.proname = 'my_plan' and p.pronamespace = 'public'::regnamespace limit 1;
  if v_def is null then raise exception '339: my_plan yok'; end if;
  if v_def like '%339 · esik doldu%' then return; end if;
  v_yeni := replace(v_def,
    $s$when v_agir > 0 then format('Son 30 günde %s kişi ağırladın. %s ağırlama daha yaparsan %s 1 ay ücretsiz açılır.', v_agir, greatest(1, v_esik - v_agir), coalesce((select ad from plan_catalog where plan::text = v_plan_hediye), 'üst plan'))$s$,
    $s$when v_agir >= v_esik then format('Son 30 günde %s kişi ağırladın; %s hediyen bir sonraki onaylanan buluşmada açılır.', v_agir, coalesce((select ad from plan_catalog where plan::text = v_plan_hediye), 'üst plan')) -- 339 · esik doldu
      when v_agir > 0 then format('Son 30 günde %s kişi ağırladın. %s ağırlama daha yaparsan %s 1 ay ücretsiz açılır.', v_agir, v_esik - v_agir, coalesce((select ad from plan_catalog where plan::text = v_plan_hediye), 'üst plan'))$s$);
  if v_yeni = v_def then raise exception '339: my_plan metni beklenen bicimde degil (338 kosuldu mu?)'; end if;
  execute v_yeni;
end $mp339$;

-- §3 · doğrulama
select 'etkin odullerde marka adi yok' as kontrol,
       not exists (select 1 from rewards where active and (title ~* '(amazon|airalo|marriott|bonvoy|booking|türk hava|thy|emirates|skywards|safetywing|miles&smiles)'
                                                         or coalesce(subtitle,'') ~* '(amazon|airalo|marriott|bonvoy|booking|miles&smiles|skywards)')) as tamam
union all select 'havayolu mili 8000 puan', exists (select 1 from rewards where title = '1000 Havayolu Mili' and cost_points = 8000)
union all select 'hediye karti 2000 puan', exists (select 1 from rewards where title = '₺500 Alışveriş Hediye Kartı' and cost_points = 2000)
union all select 'bildirimde tedarikci yok', (select bool_and(prosrc not like '%tarafından hazırlanıyor%') from pg_proc where proname = 'redeem_reward')
union all select 'plan cumlesi esik dolunca dogru', (select bool_or(prosrc like '%339 · esik doldu%') from pg_proc where proname = 'my_plan');
-- Beklenen: beş satır tamam = true.
