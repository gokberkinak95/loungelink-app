-- ============================================================================
-- 267 — İLAN TABLOSU GİRİŞ YAPMAMIŞ HERKESE AÇIKTI  (28 Ağustos 2026)
--
-- ⚠️ 265'ten SONRA çalıştır. Bu dosya CANLIDA DURAN BİR SIZINTIYI kapatıyor.
--
-- ----------------------------------------------------------------------------
-- 🔴 BULGU — ÖLÇÜLDÜ VE OKUNDU
-- ----------------------------------------------------------------------------
-- 265 fonksiyon yüzeyini kapattıktan sonra TABLO yüzeyine baktım. `anon`
-- neredeyse her tabloda `SELECT` hakkına sahip — ama RLS açık ve çoğu
-- politika `auth.uid()` ile kendi satırına bağlı, o yüzden anon sıfır satır
-- görüyor. Doğruladım: `credit_ledger` 0, `consents` 0, `audit_log` 0.
--
-- **Ama `availabilities` 3 satır döndü.**
--
--     begin; set role anon;
--     select host_id, airport_code, avail_date, time_from, flight_number
--       from public.availabilities limit 3;
--
--     a1b2c3d4-…-001017999488 | ADB | 2026-08-29 | 16:00 | PC2214
--     a1b2c3d4-…-000503666603 | ESB | 2026-08-29 | 07:30 | TK2103
--     a1b2c3d4-…-001300123478 | SAW | 2026-08-30 | 18:00 | PC1042
--
-- Yani **giriş yapmamış herkes**, uygulamanın içine gömülü publishable
-- anahtarla, yayındaki her ilanın **kim · hangi havalimanı · hangi gün ·
-- hangi saat · hangi uçuş** bilgisini çekebiliyordu.
--
-- İki yabancıyı buluşturan bir üründe bundan daha hassas bir veri kümesi
-- yok. Takip etmek isteyen birinin hesap açmasına bile gerek yoktu.
--
-- ----------------------------------------------------------------------------
-- 🔴 SEBEP: BİR AD ÇAKIŞMASI
-- ----------------------------------------------------------------------------
--     create policy avail_public_read on availabilities
--       for select to public
--       using (visibility = 'Public' and active = true);
--
-- Buradaki iki "public" AYNI ŞEY DEĞİL:
--   · `visibility = 'Public'` → ÜRÜNÜN kavramı: "gizli değil, listelensin"
--   · `to public`             → POSTGRES'in rolü: anon dahil HERKES
--
-- Niyet neredeyse kesinlikle "giriş yapmış kullanıcılar listede görsün"di.
-- Yazılan şey "internetteki herkes tabloyu okusun" oldu. Ve politika adı
-- (`avail_public_read`) okuyan herkese doğru göründüğü için, bu satır
-- bugüne kadar hiçbir incelemede takılmadı.
--
-- 🆕 SINIF: "BİR YETKİ KURALINDA ÜRÜNÜN KELİMESİYLE VERİTABANININ KELİMESİ
-- AYNIYSA, KURAL DOĞRU OKUNUR VE YANLIŞ ÇALIŞIR."
--
-- ----------------------------------------------------------------------------
-- ⚠️ REHBER EKRANI BOZULMUYOR
-- ----------------------------------------------------------------------------
-- Giriş yapmadan çalışan Salon Rehberi ilanları TABLODAN değil
-- `guide_hosts_today()` RPC'sinden okuyor. O `security definer` — RLS'i
-- kendi yetkisiyle aşar ve **seçilmiş bir alt küme** döndürür (kimlik
-- taşımaz). Yani anon keşif yolu açık kalıyor; kapanan şey HAM TABLO.
--
-- 🆕 SINIF: "ANONİM BİR YÜZEYE VERİ AÇACAKSAN TABLOYU DEĞİL BİR
-- FONKSİYONU AÇ — TABLO HER KOLONU VERİR, FONKSİYON YALNIZ VERMEK
-- İSTEDİĞİNİ."
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — İLAN TABLOSU: LİSTELEME ARTIK GİRİŞ İSTİYOR
-- ════════════════════════════════════════════════════════════════════════
drop policy if exists avail_public_read on availabilities;
create policy avail_public_read on availabilities
  for select to authenticated
  using (visibility = 'Public'::availability_visibility and active = true);

-- Sahibin kendi ilanına tam erişimi de rolü ADLANDIRILARAK yeniden kuruluyor.
-- (`to public` + `auth.uid()` zaten anon'a satır vermiyordu; yine de kuralın
--  kime ait olduğu okunabilir olmalı.)
drop policy if exists avail_host_write on availabilities;
create policy avail_host_write on availabilities
  for all to authenticated
  using (auth.uid() = host_id)
  with check (auth.uid() = host_id);

-- ════════════════════════════════════════════════════════════════════════
-- §2 — KEŞİF YÜZEYİ TABLOLARI
--
-- Bunlar kişisel veri taşımıyor ama ÜRÜNÜN İÇ HARİTASINI veriyor:
--   `rpc_client_surface`     → istemcinin çağırabildiği RPC listesi
--   `client_write_allowlist` → istemcinin yazabildiği alanlar
--   `rule_test_cases`        → kural motorunun test matrisi
--   `rule_venue_cases`       → salon bazlı kural senaryoları
--
-- İlk ikisi bir saldırgana "nereden başlayacağını" söyleyen bir haritadır;
-- son ikisi ürünün en pahalı fikri. Hiçbirinin giriş yapmamış birine
-- gösterilmesi için sebep yok.
-- ════════════════════════════════════════════════════════════════════════
-- ⚠️ v2 — ADA GÖRE DEĞİL SINIFA GÖRE.
--
-- İlk yazışımda burada DÖRT TABLO ADI vardı. Nöbetçi (§4) canlıya benzer
-- bir veritabanında çalıştırılınca İKİ TABLO DAHA buldu ve dosyayı
-- reddetti: `zamanli_isler`, `kapatilacak_yazma_haklari`.
--
-- Kök nedene bakınca liste tutmanın neden yanlış olduğu görüldü. SQL 241
-- RLS'i TOPLUCA açarken "okumayı aynen koru" diye her tabloya şunu kurdu:
--
--     create policy <tablo>_okuma_korundu on <tablo> for select using (true)
--
-- `to <rol>` YAZILMADIĞI için Postgres bunu `to public` sayar — yani anon
-- dahil herkes. 241'in amacı "hiçbir şeyi bozmadan RLS aç"tı; yaptığı şey
-- "her tabloyu anon'a aç" oldu. 267'nin ilan tablosunda bulduğu sızıntının
-- TOPLU HÂLİ buymuş.
--
-- Ve 241'den SONRA eklenen her yeni tablo aynı deseni miras alıyor. Yani
-- dört ad yazmak, bugünü düzeltip yarını açık bırakmaktı.
--
-- 🆕 SINIF: "TOPLU ÜRETİLMİŞ BİR AÇIKLIĞI TEK TEK ADLARLA KAPATMAK,
-- ÜRETİCİYİ ÇALIŞIR BIRAKMAKTIR — SINIFI KAPAT, ÖRNEKLERİ DEĞİL."
do $k267$
declare
  r record;
  v_sayi int := 0;
  -- Anon'un GÖRMESİ GEREKENLER (§3'te gerekçeleri yazılı). Bu liste
  -- kısa ve gerekçeli; geri kalan HER ŞEY giriş ister.
  v_izinli text[] := array['country_aliases','host_tiers','rozet_katalogu',
                           'card_network_source','kredi_paketleri',
                           'airports','amenity_keys','carriers','host_stories',
                           'waitlist'];
begin
  for r in
    select tablename, policyname
      from pg_policies
     where schemaname = 'public'
       and 'public' = any(roles)
       and cmd in ('SELECT', 'ALL')
       -- `auth.uid()` geçen politika zaten kendi satırına bağlı: anon'a
       -- satır vermez. Onlara dokunmak gereksiz risk.
       and coalesce(qual, '') not like '%auth.uid()%'
       and not (tablename = any(v_izinli))
     order by 1, 2
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
    execute format(
      'create policy %I on public.%I for select to authenticated using (true)',
      r.policyname, r.tablename);
    raise notice '267: %.% → yalniz authenticated', r.tablename, r.policyname;
    v_sayi := v_sayi + 1;
  end loop;
  raise notice '267 §2: % politika anon''dan alindi.', v_sayi;
end $k267$;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — BİLEREK AÇIK KALANLAR
--
-- Bunlar giriş yapmadan da okunabilir ve bu bir TERCİH:
--   `country_aliases` · `host_tiers` · `rozet_katalogu` ·
--   `card_network_source` · `kredi_paketleri`
--
-- Hiçbiri kişi taşımıyor; ilk dördü sözlük, sonuncusu ilan edilmiş fiyat.
-- Fiyatı gizlemek, fiyatı olan bir ürün için anlamsız olurdu.
--
-- ⚠️ Gerekçesi buraya YAZILDI ki bir dahaki denetimde "bu neden açık"
-- sorusu yeniden araştırılmasın — ve gerekçesi olmayan yeni bir satır
-- eklenirse fark edilsin.
-- ════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════
-- §4 — NÖBETÇİ: SIZINTI GERÇEKTEN KAPANDI MI
--
-- 🔴 Politika yazmak yetmez; ROLÜ ÜSTLENİP OKUMAYI DENİYORUZ.
-- Ve ters yönü de: giriş yapmış kullanıcı ilanları HÂLÂ görebilmeli,
-- yoksa Keşfet ekranı boşalır.
-- ════════════════════════════════════════════════════════════════════════
do $nb267$
declare
  v_anon int; v_auth int; r record; v_kalan int := 0;
  v_izinli text[] := array['country_aliases','host_tiers','rozet_katalogu',
                           'card_network_source','kredi_paketleri',
                           'airports','amenity_keys','carriers','host_stories',
                           'waitlist'];
begin
  -- (a) anon artık ilan göremiyor
  set local role anon;
  select count(*) into v_anon from public.availabilities;
  reset role;
  if v_anon > 0 then
    raise exception '267 NOBETCI: anon HALA % ilan okuyabiliyor.', v_anon;
  end if;
  raise notice '267 NOBETCI: anon ilan tablosundan 0 satir okuyor. ✓';

  -- (b) gerekçesiz kalan her `public` politikası bildiriliyor
  for r in
    select tablename, policyname
      from pg_policies
     where schemaname='public' and 'public' = any(roles) and cmd in ('SELECT','ALL')
       and coalesce(qual,'') not like '%auth.uid()%'
       and not (tablename = any(v_izinli))
     order by 1
  loop
    raise warning '267: gerekcesiz anon okuma → %.%', r.tablename, r.policyname;
    v_kalan := v_kalan + 1;
  end loop;
  if v_kalan > 0 then
    raise exception '267 NOBETCI: % adet gerekcesiz anon okuma politikasi kaldi.', v_kalan;
  end if;

  -- (c) TERS YÖN: giriş yapmış kullanıcı ilanları görebiliyor mu
  -- (RLS `authenticated` rolünde `auth.uid()` null olsa da
  --  `visibility='Public' and active` koşulu sağlanır.)
  set local role authenticated;
  select count(*) into v_auth from public.availabilities;
  reset role;
  if v_auth = 0 and exists (select 1 from availabilities
                             where visibility = 'Public' and active) then
    raise exception '267 NOBETCI: giris yapmis kullanici ilan GOREMIYOR — Kesfet bosalir.';
  end if;
  raise notice '267 NOBETCI OK: anon 0 · authenticated % ilan · gerekcesiz politika yok.', v_auth;
end $nb267$;

commit;
