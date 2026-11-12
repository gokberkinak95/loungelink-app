-- ============================================================================
-- 353 · AKTİF ÖDÜLLERİN HEPSİNE STOK 10   (12 Kasım 2026, lansman günü)
--
-- Gökberk (12 Kasım): "sınırsız" stoklu büyük ödüller, bir güvenlik açığı ya da
-- kötüye kullanımda sınırsız zarar demek. Kullanıcı az; aktif ödüllerin hepsi
-- 10 adetle başlasın, kullanım geldikçe stok elle artırılsın.
--
-- Stok = KALAN adet. redeem_reward satırı kilitleyip (for update) o anki değeri
-- okur ve 1 düşürür; iptal 1 geri ekler. Yani stoğu 10'dan 50'ye çekmek ANINDA
-- geçerli olur, 11. alımda hata yoktur. Dikkat: 3 alım sonrası kalan 7 iken 50
-- yazarsan kalan 50 olur (47 değil).
-- Kullanıcı stoğu görmez: uygulama ve site stok sayısını hiçbir ekranda göstermiyor.
--
-- Önceki değerler tezgah.odul_stok_353'te. GERİ ALMAK (tek ifade):
--   update rewards r set stock = t.eski_stok from tezgah.odul_stok_353 t where t.id = r.id;
-- Tekrar koşulabilir (ilk saklanan değer korunur). Doğrulama: tamam = true.
-- ============================================================================
create schema if not exists tezgah;
create table if not exists tezgah.odul_stok_353 (
  id uuid primary key, title text, eski_stok int, kayit_at timestamptz default now()
);

insert into tezgah.odul_stok_353 (id, title, eski_stok)
select r.id, r.title, r.stock
  from rewards r
 where r.active
on conflict (id) do nothing;

update rewards r
   set stock = 10
 where r.active
returning r.title, r.maliyet_turu, r.stock;

select count(*) as aktif_odul,
       count(*) filter (where stock = 10) = count(*) as tamam
  from rewards
 where active;
