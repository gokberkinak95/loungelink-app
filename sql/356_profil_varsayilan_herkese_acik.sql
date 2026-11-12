-- ============================================================================
-- 356 · YENİ ÜYE TANIŞ'I BOŞ GÖRMESİN: PROFİL VARSAYILANI "HERKES"  (13 Kasım 2026)
--
-- ÖLÇÜM (355 sonucu, canlı): 14 gerçek kullanıcının 12'si puanı 24'ün altında (telefon
-- doğrulanmamış). Eşik 24'e inse de Tanış 12 kişide BOŞ (ortalama 2 kişi). Sebep eşik değil,
-- VARSAYILAN: profiles.profile_visibility default 'Trusted+' (001 ilk şemadan kalma; bilinçli
-- bir ürün kararı değil). 253 bu ayarı profile, 327 Tanış listesine uyguladı → ayarı hiç
-- değiştirmemiş herkes, telefonu doğrulanmamış herkese görünmez oldu. Yeni üye boş Tanış ve
-- adsız profil görüyor.
--
-- DÜZELTME (APP SÜRÜMÜ GEREKMEZ):
--   §1 varsayılan 'Everyone' (yeni üyeler herkese açık başlar)
--   §2 mevcut gerçek kullanıcılardaki 'Trusted+' → 'Everyone' (eski değer tezgah.gorunurluk_356'da)
--      Ayarlar'daki seçenekler aynen duruyor: isteyen "Güvenilir üyeler" ya da "Bağlantılarım"ı
--      seçer, seçimi Tanış'ta ve profilde uygulanır (253/327/355 değişmedi).
--   Dokunulmayanlar: test hesapları, inceleme@loungelink.co (355'te 'Connections'), 'Connections' seçenler.
--   Kadın güvenlik modu, engelleme, gölge kısıt ayrı kurallar — değişmedi.
--
-- KOŞMA: SQL Editor → tamamı → Run. Tekrar koşulabilir. ÖNKOŞUL: 355. Son tablo sonuçtur.
-- ============================================================================

-- §0 · önce (355'in ölçüm fonksiyonu)
select tezgah.olc_355('3_356_once') as olculen_kullanici;

-- §1 · yeni üyeler herkese açık başlar
alter table profiles alter column profile_visibility set default 'Everyone';

-- §2 · mevcut gerçek kullanıcılar (eski değer saklanır, geri alınabilir)
create table if not exists tezgah.gorunurluk_356 (
  user_id uuid primary key, eski text, kayit_at timestamptz default now()
);

insert into tezgah.gorunurluk_356 (user_id, eski)
select p.user_id, p.profile_visibility::text
  from profiles p join users u on u.id = p.user_id
 where p.profile_visibility::text = 'Trusted+'
   and not public.seed_test_hesabi(u.email)
   and lower(coalesce(u.email, '')) <> 'inceleme@loungelink.co'
on conflict (user_id) do nothing;

update profiles p set profile_visibility = 'Everyone', updated_at = now()
  from tezgah.gorunurluk_356 g
 where g.user_id = p.user_id and p.profile_visibility::text = 'Trusted+';

-- §3 · sonra
select tezgah.olc_355('4_356_sonra') as olculen_kullanici;

-- §4 · SONUÇ (beklenen: 'gercek' satırlarında herhangi_test_hesabi_goren 0 ve inceleme_hesabini_goren 0;
--      tanis_bos_kullanici 4_356_sonra'da belirgin düşer; olcum_hatasi 0)
select asama, tur,
       count(*)                                         as kullanici,
       sum(greatest(test_kesfet, 0) + greatest(test_tanis, 0) + test_profil + greatest(test_radar, 0)) as herhangi_test_hesabi_goren,
       sum(greatest(inceleme_goren, 0))                 as inceleme_hesabini_goren,
       count(*) filter (where tanis_kisi = 0)           as tanis_bos_kullanici,
       round(avg(nullif(tanis_kisi, -1)), 1)            as tanis_ort_kisi,
       count(*) filter (where vitrin_kesfet = -1 or tanis_kisi = -1 or test_radar = -1 or inceleme_goren = -1) as olcum_hatasi,
       (select count(*) from tezgah.gorunurluk_356)     as herkese_acilan_profil
  from tezgah.olcum_355
 where asama like '%356%'
 group by asama, tur
 order by tur, asama;

-- GERİ ALMA (gerekirse):
--   alter table profiles alter column profile_visibility set default 'Trusted+';
--   update profiles p set profile_visibility = g.eski::profile_visibility
--     from tezgah.gorunurluk_356 g where g.user_id = p.user_id and p.profile_visibility::text = 'Everyone';
