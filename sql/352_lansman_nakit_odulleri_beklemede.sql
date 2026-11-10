-- ============================================================================
-- 352 · LANSMAN: NAKİT MALİYETLİ ÖDÜLLER GEÇİCİ OLARAK ALINAMAZ   (10 Kasım 2026)
--
-- Gökberk (10 Kasım): ilk haftalarda yalnız kendi ürünümüz olan ödüller (ilan öne
-- çıkarma, istek kredisi, plan ayı, rozet) alınabilsin; gerçek para maliyeti olanlar
-- (kahve, eSIM, hediye kartı, otel/konaklama kredisi, mil) görünür kalsın ama alınamasın.
-- Sebep: kötüye kullanım (karşılıklı sahte buluşma ile puan biriktirme) ve elle teslim yükü,
-- gerçek kullanım ve ilk gelir ölçülmeden açılmasın.
--
-- Yapılan: maliyet_turu = 'nakit' olan aktif ödüllerin stoğu 0 olur. Ödül SİLİNMEZ,
-- listede görünür; almaya çalışan "Stokta yok." görür (redeem_reward: out_of_stock),
-- puanı düşmez. Önceki stok değeri tezgah.odul_stok_352'de saklanır.
-- GERİ AÇMAK (tek ifade, SQL Editor):
--   update rewards r set stock = t.eski_stok from tezgah.odul_stok_352 t where t.id = r.id;
-- Tekrar koşulabilir (ilk saklanan değer korunur). Doğrulama: 2 satır, tamam = true.
-- ============================================================================
create schema if not exists tezgah;
create table if not exists tezgah.odul_stok_352 (
  id uuid primary key, title text, eski_stok int, kayit_at timestamptz default now()
);

insert into tezgah.odul_stok_352 (id, title, eski_stok)
select r.id, r.title, r.stock
  from rewards r
 where r.active and r.maliyet_turu = 'nakit'
on conflict (id) do nothing;

update rewards r
   set stock = 0
 where r.active and r.maliyet_turu = 'nakit'
   and coalesce(r.stock, 1) <> 0;

-- DOĞRULAMA
select 'nakit maliyetli aktif odullerin hepsi alinamaz (stok 0)' as kontrol,
       not exists (select 1 from rewards where active and maliyet_turu = 'nakit'
                    and (stock is null or stock > 0)) as tamam
union all
select 'kendi urunumuz olan oduller acik: ' ||
       coalesce((select string_agg(title, ', ' order by cost_points) from rewards
                  where active and coalesce(maliyet_turu, 'kendi') <> 'nakit'
                    and (stock is null or stock > 0)), 'YOK'),
       exists (select 1 from rewards where active and coalesce(maliyet_turu, 'kendi') <> 'nakit'
                and (stock is null or stock > 0));
