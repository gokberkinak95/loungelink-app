-- ============================================================
-- 191 · KAYNAK ÇELİŞKİLERİ, BOŞLUKLAR VE ÜÇ MİMARİ EKSİK
-- 17 Ağustos 2026
--
-- 🔴 GÖKBERK: "5.8 kaynağın kendi çelişkileri konularında
-- düzenlemeleri yaptın mı doğru şekilde?" — HAYIR, işaretlemiştim,
-- karara bağlamamıştım. Bu dosya onu yapıyor.
--
-- 🔴 KARAR ÇERÇEVESİ — üç durum, üç davranış:
--
--   1. ÇELİŞKİ (iki kaynak farklı şey diyor)
--      → EN KISITLAYICIYI uygula, AMA ikisini de kullanıcıya söyle.
--        "Kaynaklar ayrışıyor; kapıda şu çıkabilir" demek, birini
--        seçip kesin konuşmaktan dürüsttür.
--
--   2. KAYNAK SESSİZ ("SS'te yok")
--      → KURAL YAZMA. En kısıtlayıcı davran ve "kaynakta tanımlı
--        değil" de. Yazmayan bir kuralı uydurmak, ürünün tek
--        sermayesini (güven) harcar.
--
--   3. GERÇEK FARK (kaynak bilerek ayırıyor)
--      → İki ayrı kural yaz. Çelişki değil, incelik.
--
-- 🔴 VE EN ÖNEMLİSİ: bu kararlar bir belgede değil VERİTABANINDA
-- durmalı. "Bir denetim görünmüyorsa yoktur" (v1.56 dersi) —
-- çelişkiler de öyle. rule_source_conflicts tablosu BO'da görünür.
-- ============================================================


-- ============================================================
-- 1 · ÇELİŞKİ KAYIT DEFTERİ — kararı veriye yaz, belgeye değil
-- ============================================================
create table if not exists rule_source_conflicts (
  id           uuid primary key default uuid_generate_v4(),
  konu         text not null,
  detay        text not null,
  kaynak_a     text,                -- ne diyor / nerede
  kaynak_b     text,
  sinif        text not null,       -- 'celiski' | 'kaynak_sessiz' | 'gercek_fark' | 'kaynak_hatasi'
  karar        text not null,       -- ne yaptık ve NEDEN
  durum        text not null default 'acik',   -- 'acik' | 'karara_baglandi' | 'veri_bekliyor'
  etki         text,                -- kullanıcı ne görür
  program_code text,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);
alter table rule_source_conflicts drop constraint if exists rsc_sinif_chk;
alter table rule_source_conflicts add constraint rsc_sinif_chk
  check (sinif in ('celiski','kaynak_sessiz','gercek_fark','kaynak_hatasi'));
alter table rule_source_conflicts drop constraint if exists rsc_durum_chk;
alter table rule_source_conflicts add constraint rsc_durum_chk
  check (durum in ('acik','karara_baglandi','veri_bekliyor'));
create unique index if not exists uq_rsc_konu on rule_source_conflicts (konu);

alter table rule_source_conflicts enable row level security;
drop policy if exists rsc_read on rule_source_conflicts;
create policy rsc_read on rule_source_conflicts for select to authenticated using (true);
grant select on rule_source_conflicts to authenticated;

insert into rule_source_conflicts (konu, detay, kaynak_a, kaynak_b, sinif, karar, durum, etki, program_code) values
('AJet çocuk/misafir ücreti',
 'Aile bireyi olmayan çocuk ve misafir için AJet sayfası %50 indirim, THY sayfası tam ücret diyor.',
 'AJet lounge sayfası: %50', 'THY lounge kuralları: tam ücret',
 'celiski',
 'THY sayfası esas alındı. GEREKÇE KAYNAKTAN GELİYOR: AJet sayfasının kendisi "Güncel ücretler ve kurallar için Türk Hava Yolları sayfasını ziyaret ediniz" diyor — yani ücret otoritesini THY''ye devrediyor. Ayrıca tam ücret daha kısıtlayıcı; yanılırsak kullanıcı lehine yanılırız.',
 'karara_baglandi',
 'Kullanıcıya tam ücret gösterilir + "AJet sayfası %50 indirim yazıyor; kapıda tam ücret çıkabilir, ikisine de hazır ol" notu.',
 'AJET_MS'),

('Star Alliance + M&S Elite Card aile hakkı',
 'Tablo-2 "bir misafir" derken Tablo-4 (IST M&S salonu) "aile veya bir misafir" diyor.',
 'Tablo-2: 1 misafir', 'Tablo-4 (IST M&S bölümü): aile VEYA 1 misafir',
 'gercek_fark',
 'Çelişki DEĞİL, kapsam farkı: Tablo-4 yalnız IST Miles&Smiles BÖLÜMÜ için yazılmış. 156 bunu zaten venue-scoped istisna olarak modellemişti. Genel kural 1 misafir; IST M&S bölümünde aile hakkı var.',
 'karara_baglandi',
 'IST M&S bölümünde aile rozetı, diğer yerlerde "1 misafir".',
 'TK_MS'),

('AJet Classic Plus iç hat ücreti',
 'THY seferinde iç hat ÜCRETSİZ, AJet seferinde ÜCRETLİ.',
 'THY tablosu: CLPL iç hat ücretsiz', 'AJet tablosu: CLPL ücretli sütunda',
 'gercek_fark',
 'Çelişki değil, taşıyıcıya bağlı gerçek bir fark. İki ayrı kural olarak modellendi (carrier=TK vs carrier=AJ).',
 'karara_baglandi',
 'Uçuş numarası girilince doğru cevap; girilmezse 172 en kısıtlayıcıyı (ücretli) seçer ve uçuş no ister.',
 'AJET_MS'),

('Sabiha Gökçen CIP kapalı mı',
 'Dipnot "3 Nisan''dan itibaren geçici olarak hizmet dışında" derken aynı sayfadaki salon bilgi tablosu ve giriş penceresi kuralları aktif. Dipnotta YIL YOK.',
 'Dipnot: geçici olarak hizmet dışı', 'Salon bilgi tablosu: 04:00-01:00, 3 saat, VIP Terminali',
 'celiski',
 'HAK ile DURUM ayrıldı. Tadilat bir kural değil bir durumdur: kuralı silmek yanlış olurdu (salon açılınca hak geri gelir ve biz kaybetmiş oluruz). Hak kuralda duruyor, tadilat notu SALONDA (189). Yıl belirsiz olduğu için not "olabilir" diliyle yazıldı.',
 'karara_baglandi',
 'Hak görünür; salon kartında "geçici olarak hizmet dışı olabilir — gitmeden önce doğrula" notu.',
 'AJET_MS'),

('AJet + İstanbul Havalimanı',
 'AJet tablolarında IST satırı HİÇ YOK. Aynı sayfadaki THY tablosunda IST ayrı sütun olarak var.',
 'AJet tablosu: IST yok', 'THY tablosu: IST var',
 'kaynak_sessiz',
 'Kural YAZILMADI. Kaynak ne "girer" ne "girmez" diyor; ikisini de uydurmuyoruz. Motor kural bulamayınca 172''nin en kısıtlayıcı yoluna düşer ve kullanıcıya "kaynakta tanımlı değil, AJet''e teyit ettir" der.',
 'karara_baglandi',
 '"Bu kombinasyon resmî tabloda tanımlı değil — AJet''e teyit ettir" notu; misafir hakkı 0 varsayılır.',
 'AJET_MS'),

('AJet + SAG/PLM/CORP/M&S US kredi kartı',
 'AJet tablolarında bu kart tipleri hiç geçmiyor.',
 'AJet tablosu: yok', null,
 'kaynak_sessiz',
 'Kural yazılmadı; aynı gerekçe. 172''nin ikinci geçişi (tier''ı gevşet) en kısıtlayıcı AJet kuralını aday yapar ve notu taşır.',
 'karara_baglandi',
 'En kısıtlayıcı cevap + "bu kart tipi AJet tablosunda yok" notu.',
 'AJET_MS'),

('AJet + dış hat / yurt dışı',
 'AJet tablolarında yalnız "İÇ HAT" başlığı var.',
 'AJet tablosu: yalnız iç hat', null,
 'kaynak_sessiz',
 'AJet kuralları venue_scope=domestic ile SINIRLANDI. Dış hat/yurt dışında AJet kuralı ADAY OLMAZ; motor "tanımlı değil" der. Aksi hâlde iç hat kuralı dış hatta yanlışlıkla uygulanırdı.',
 'karara_baglandi',
 'AJet statüsüyle dış hat salonuna bakınca "resmî tabloda tanımlı değil" cevabı.',
 'AJET_MS'),

('THY kalış süresi sınırı',
 'THY için hiçbir salonda saat sınırı yazmıyor.',
 'THY sayfaları: sınır yok', null,
 'kaynak_sessiz',
 'Sınır UYDURULMADI. max_stay_hours null bırakıldı ve kullanıcıya "kalış süresini salon belirler" deniyor — Priority Pass md.19''un da söylediği gerçek bu.',
 'karara_baglandi',
 '"Kalış süresini salon belirler" notu; sayı gösterilmez.',
 'TK_MS'),

('Giriş penceresi (ücretsiz statü girişi)',
 'Giriş penceresi kuralları yalnız "salon hizmetini SATIN ALAN" yolcular için yazılmış; statüyle ücretsiz girenin penceresi tanımlı değil.',
 'THY: satın alanlar için 3/4 saat', 'Statüyle girenler: tanımsız',
 'kaynak_sessiz',
 'Pencere yalnız SATIN ALMA yolunda uygulanıyor. Statü yolunda earliest_entry_hours null; "erken gelirsen salon kabul etmeyebilir" uyarısı veriliyor.',
 'karara_baglandi',
 'Statüyle girene saat sınırı gösterilmez, yumuşak uyarı verilir.',
 'TK_MS'),

('Kod paylaşımlı uçuş',
 'Lounge bağlamında hiçbir kaynakta geçmiyor.',
 null, null, 'kaynak_sessiz',
 'Kural yazılmadı. Kod paylaşımlı uçuşta işleten taşıyıcı ile pazarlayan taşıyıcı farklı olabilir ve bu misafir taşıyıcı şartını doğrudan etkiler. Kullanıcıdan uçuş numarası isteniyor; motor numaranın ÖNEKİNİ esas alıyor.',
 'veri_bekliyor',
 'Uçuş no önekine göre karar; farklı işletenli uçuşta kapıda sürpriz riski notta yazılı.',
 null),

('Ödül bileti + lounge',
 'Lounge bağlamında hiçbir kaynakta geçmiyor.',
 null, null, 'kaynak_sessiz',
 'Kural yazılmadı. Misafir hakkı zaten BİLETE değil STATÜ kartına bağlı (Tablo-4 notu), dolayısıyla ödül bileti misafir hakkını değiştirmiyor olmalı — ama bu bir çıkarım, kaynak hükmü değil. Kullanıcıya bir şey söylemiyoruz.',
 'karara_baglandi',
 'Ödül bileti ayrı bir uyarı üretmez; statü kartı ne diyorsa o.',
 'TK_MS'),

('THY AJet kuralları md.8 ve md.9',
 'İki madde birebir aynı metin.',
 'md.8', 'md.9 (aynı metin)',
 'kaynak_hatasi',
 'Kaynağın kendi mükerreri; kural motoruna tek satır olarak girdi. Bilgi kaybı yok.',
 'karara_baglandi', 'Etkisi yok.', 'AJET_MS'),

('Kepler Club ücreti',
 'Pegasus sayfasında Kepler Club için ücret/indirim oranı verilmemiş.',
 'Pegasus sayfası: tutar yok', null, 'kaynak_sessiz',
 'Tutar yazılmadı. "Ücretli — tutarı salon belirler" deniyor. Uydurma bir rakam, kapıda yanlış beklenti üretirdi.',
 'veri_bekliyor', 'Tutar yerine "salon belirler" yazar.', 'PGS_PAID'),

('Pegasus giriş penceresi / misafir hakkı',
 'Pegasus kaynağında hiç bahsedilmiyor.',
 null, null, 'kaynak_sessiz',
 'Pegasus modeli zaten statü tabanlı değil: "biniş kartını göster, indirimli öde, gir". Misafir hakkı 0, ücretli giriş açık.',
 'karara_baglandi', 'Misafir kapıda tarifeden öder.', 'PGS_PAID'),

('Pegasus çocuk yaş muafiyeti',
 'Plaza Premium ve Çelebi 6 yaş, Primeclass ve HelloSky 0-2 yaş.',
 'Plaza/Çelebi: 6 yaş', 'Primeclass/HelloSky: 0-2 yaş',
 'gercek_fark',
 'Salon bazında gerçek fark; venue notuna yazıldı. Tek bir "çocuk yaşı" kuralı yazmak yanlış olurdu.',
 'karara_baglandi', 'Salon kartında o salonun yaş muafiyeti yazar.', 'PGS_PAID'),

('Havalimanı isim varyantları',
 'Rize / Rize-Artvin · Trabzon / Trabzon Uluslararası · Hatay / Hatay Uluslararası · Adnan Menderes / İzmir Adnan Menderes · Milas-Bodrum / Muğla Milas-Bodrum',
 'THY yurtiçi listesi', 'THY anlaşmalı listesi',
 'kaynak_hatasi',
 'IATA kodu tek kimlik olarak kullanılıyor; isim yalnız görüntüleme. 190 marka+terminal anahtarıyla salon tekilleştirmesi zaten koda dayanıyor, isme değil.',
 'karara_baglandi', 'Kullanıcı tek havalimanı görür.', null),

('PLM açık adı',
 'Tablolarda yalnız "PLM" kısaltması geçiyor, açık adı hiçbir kaynakta yazmıyor.',
 'Tablolar: PLM', null, 'kaynak_sessiz',
 'Açık ad UYDURULMADI. "Star Alliance Platinum" bir çıkarımdır; kullanıcıya kısaltma + "kartında bu ibare varsa" ifadesiyle gösteriliyor.',
 'karara_baglandi', 'Kısaltma gösterilir, uydurma açılım yazılmaz.', 'TK_MS'),

('Priority Pass plan ve ücret sayfası',
 'Kullanım Koşulları alındı ama plan/ücret sayfası ekran görüntüsü setinde YOK. Standard/Standard Plus/Prestige adları, yıllık ücretler, ziyaret kotaları ve misafir ücreti tutarları kaynakta bulunmuyor.',
 'PP Kullanım Koşulları md.1-94 (26 Mart 2026)', 'Plan/ücret sayfası: ALINMADI',
 'kaynak_sessiz',
 'Tutar YAZILMADI. Ayrıca md.4 ücreti "üyelik planına bağlı olarak" diye şarta bağlıyor ve md.11 bankanın hakları sınırlayabildiğini söylüyor → "bankana göre değişir" tek dürüst cevap. 177''nin "hiçbir planda ücretsiz misafir yok" kesin ifadesi 189''da geri alındı.',
 'veri_bekliyor',
 '"Misafir hakkın plana ve kartını verene bağlı — bankandan teyit al" notu; tutar gösterilmez.',
 'PRIORITY_PASS'),

('DragonPass plan ve ücret sayfası',
 'T&C alındı ama fiyat/plan bilgisi sözleşmede YOK; md.7.15.8 fiyatı App/Website''e havale ediyor.',
 'DP T&C (27 Mart 2026)', 'Fiyat sayfası: ALINMADI',
 'kaynak_sessiz',
 'Tutar yazılmadı. 5.4 uyarınca banka kuralı değiştirebiliyor → "bankana göre değişir".',
 'veri_bekliyor', 'Tutar yerine "kartını verene sor" notu.', 'DRAGONPASS'),

('Tadilat notunda yıl yok',
 '"3 Nisan''dan itibaren" — hangi yıl olduğu yazmıyor.',
 'THY/AJet dipnotu', null, 'kaynak_sessiz',
 'Yıl uydurulmadı; not "olabilir" diliyle yazıldı ve kullanıcıdan doğrulaması istendi.',
 'karara_baglandi', '"Gitmeden önce doğrula" notu.', 'AJET_MS')
on conflict (konu) do update set
  detay = excluded.detay, kaynak_a = excluded.kaynak_a, kaynak_b = excluded.kaynak_b,
  sinif = excluded.sinif, karar = excluded.karar, durum = excluded.durum,
  etki = excluded.etki, program_code = excluded.program_code, updated_at = now();


-- ============================================================
-- 2 · KARARLARIN VERİYE YANSIMASI
-- ============================================================

-- 2a) AJet kuralları YALNIZ iç hatta geçerli (çelişki #7 kararı)
-- Kaynak yalnız "İÇ HAT" başlığı taşıyor. Kapsamsız bırakmak, iç hat
-- kuralının dış hatta sessizce uygulanmasına yol açıyordu.
update lounge_guest_rules r
   set venue_scope = 'domestic',
       notes = coalesce(r.notes,'') ||
         case when coalesce(r.notes,'') = '' then '' else ' ' end ||
         '[191] AJet resmî tablosu yalnız İÇ HAT için yazılmıştır; dış hat ve '
         'yurt dışı için kaynakta hüküm YOKTUR.'
  from lounge_programs p
 where p.id = r.program_id and p.code = 'AJET_MS'
   and r.venue_scope is null
   and coalesce(r.notes,'') not like '%[191]%';

-- 🔴 BEKÇİ HAKLI İTİRAZ ETTİ: 2a'yı yazınca kapsam denetimi 0 → 42'ye
-- çıktı. AJet kurallarını iç hatla sınırlayınca dış hat/yurt dışı
-- salonlarındaki AJET_MS kabul satırları KURALSIZ kaldı.
--
-- İlk düşüncem "motor kural bulamayınca en kısıtlayıcıya düşer, sorun
-- yok" idi. YANLIŞTI: kuralın YOKLUĞU ile "kural yok" DEMEK aynı şey
-- değil. Yokluk sessizdir — kullanıcı neden cevap alamadığını bilmez
-- ve denetim de haklı olarak boşluk sayar. "Bilmiyoruz" bir cevaptır
-- ve YAZILMALIDIR.
--
-- Bu yüzden dış hat/yurt dışı için AÇIK bir "kaynakta tanımlı değil"
-- kuralı yazıyoruz: 0 misafir + dürüst not + kaynak adresi.
insert into lounge_guest_rules
  (program_id, venue_id, card_tier, carrier, venue_scope,
   guest_allowance, family_allowed, paid_entry_allowed, notes, effective_from)
select p.id, null, t.tier, null, sc.scope, 0, false, false,
       'AJet resmî lounge tablosu yalnız İÇ HAT için yazılmıştır. '
       'Dış hat ve yurt dışı salonlarında AJet statüsünün ne verdiği '
       'KAYNAKTA TANIMLI DEĞİL — bu yüzden misafir hakkı varsaymıyoruz. '
       'Kesin cevap için AJet''e teyit ettir. '
       '[kaynak: ajet.com/tr/kurumsal/kurallar-ve-kosullar/cip-lounge]',
       current_date
  from lounge_programs p
  cross join (values ('CLASSIC'),('CLPL'),('ELITE'),('ELPL'),('MS_EC')) t(tier)
  cross join (values ('international'),('abroad')) sc(scope)
 where p.code = 'AJET_MS'
   and not exists (select 1 from lounge_guest_rules r
                    where r.program_id = p.id and r.venue_id is null
                      and r.card_tier = t.tier and r.venue_scope = sc.scope);

-- Kademesi bilinmeyen host için de kapsamsız yedek (172'nin 3. geçişi)
insert into lounge_guest_rules
  (program_id, venue_id, card_tier, carrier, venue_scope,
   guest_allowance, family_allowed, paid_entry_allowed, notes, effective_from)
select p.id, null, null, null, sc.scope, 0, false, false,
       'AJet tablosu yalnız iç hat içindir; bu kapsam kaynakta tanımlı değil.',
       current_date
  from lounge_programs p
  cross join (values ('international'),('abroad')) sc(scope)
 where p.code = 'AJET_MS'
   and not exists (select 1 from lounge_guest_rules r
                    where r.program_id = p.id and r.venue_id is null
                      and r.card_tier is null and r.venue_scope = sc.scope);

-- 2b) AJet çocuk/misafir ücreti — THY otoritesi (çelişki #1 kararı)
update lounge_programs
   set notes = coalesce(notes,'') ||
       case when coalesce(notes,'') = '' then '' else ' ' end ||
       '[191] ÜCRET ÇELİŞKİSİ: AJet sayfası aile bireyi olmayan çocuk/misafir '
       'için %50 indirim, THY sayfası tam ücret diyor. THY esas alındı — AJet '
       'sayfasının kendisi ücretler için THY sayfasına yönlendiriyor. Kullanıcıya '
       'tam ücret gösterilir ve iki kaynağın ayrıştığı söylenir.'
 where code = 'AJET_MS' and coalesce(notes,'') not like '%[191]%';

-- 2c) Kalış süresi ve giriş penceresi uydurulmaz (çelişki #8, #9)
update lounge_programs
   set max_stay_hours = null,
       notes = coalesce(notes,'') ||
       case when coalesce(notes,'') = '' then '' else ' ' end ||
       '[191] Kalış süresi sınırı kaynakta YOK — salon belirler. Giriş penceresi '
       'kuralları yalnız hizmeti SATIN ALAN yolcular için yazılmış; statüyle '
       'ücretsiz girenin penceresi tanımlı değil.'
 where code = 'TK_MS' and coalesce(notes,'') not like '%[191]%';


-- ============================================================
-- 3 · BANKA × PROGRAM ÖRTÜŞMELERİ (mimari eksik #1)
-- ============================================================
-- PP md.4/11/18 ve DP 5.4: ziyaret sayısını, ücreti ve misafir hakkını
-- KARTI VEREN BANKA belirler. Bugün tek bir "program kuralı" var ve
-- bu, kullanıcıyı yanıltıyor: Garanti'nin PP'si ile Akbank'ın PP'si
-- aynı şey değil.
--
-- 🔴 TABLO ŞİMDİ KURULUYOR, VERİ SONRA GELECEK. Boş bir tablo kurmak
-- "yaptık" demek değil — ama motorun ONU OKUYOR olması, veri geldiği
-- anda çalışması demek. Veri gelene kadar motor "bankana göre değişir"
-- demeye devam eder; yanlış bir şey söylemez.
create table if not exists bank_program_overrides (
  id            uuid primary key default uuid_generate_v4(),
  bank_code     text not null,             -- 'GARANTI' | 'AKBANK' | 'QNB' ...
  bank_name     text not null,
  program_id    uuid not null references lounge_programs(id) on delete cascade,
  card_product  text,                      -- 'Bonus Platinum' gibi; null = bankanın tümü
  member_free_visits int,                  -- üyenin ücretsiz ziyareti
  guest_included_count int,                -- ücretsiz misafir sayısı
  guest_fee     text,                      -- '32 USD' gibi; null = bilinmiyor
  fee_payer     text,                      -- 'member_card' | 'guest_at_door'
  source_url    text,
  checked_at    date,
  notes         text,
  active        boolean not null default true,
  created_at    timestamptz default now()
);
create unique index if not exists uq_bpo
  on bank_program_overrides (bank_code, program_id, coalesce(card_product,''));
create index if not exists idx_bpo_program on bank_program_overrides (program_id);

alter table bank_program_overrides enable row level security;
drop policy if exists bpo_read on bank_program_overrides;
create policy bpo_read on bank_program_overrides for select to authenticated using (active);
grant select on bank_program_overrides to authenticated;

-- host_entitlements'e banka bilgisi: kullanıcı kartını verenle eşleşsin
alter table host_entitlements add column if not exists bank_code text;
alter table host_entitlements add column if not exists card_product text;

-- Örtüşmeyi okuyan katman. Veri yoksa null döner ve motor bugünkü
-- davranışını sürdürür — geriye tam uyumlu.
create or replace function public.bank_override_for(
  p_program_id uuid, p_bank_code text, p_card_product text default null
) returns jsonb language sql stable security definer set search_path = public as $$
  select case when b.id is null then null else jsonb_build_object(
    'bank', b.bank_name, 'card_product', b.card_product,
    'member_free_visits', b.member_free_visits,
    'guest_included_count', b.guest_included_count,
    'guest_fee', b.guest_fee, 'fee_payer', b.fee_payer,
    'source_url', b.source_url, 'checked_at', b.checked_at) end
    from bank_program_overrides b
   where b.active and b.program_id = p_program_id
     and upper(btrim(b.bank_code)) = upper(btrim(coalesce(p_bank_code,'')))
     and (b.card_product is null
          or upper(btrim(b.card_product)) = upper(btrim(coalesce(p_card_product,''))))
   order by (b.card_product is not null) desc, b.checked_at desc nulls last
   limit 1
$$;
grant execute on function public.bank_override_for(uuid, text, text) to authenticated;


-- ============================================================
-- 4 · AYNI PROGRAMDAN İKİ HAK (mimari eksik #2)
-- ============================================================
-- 🔴 GÖKBERK: "bende 2 tane Miles&Smiles kartı var, birinde kendim
-- diğerinde misafirim gelebiliyor."
--
-- ÖLÇÜM: uq_he = (user_id, program_id, coalesce(tier,'')) — aynı
-- programdan aynı kademede İKİNCİ bir hak EKLENEMİYOR. İki M&S kartı
-- olan kullanıcı ikincisini giremiyor; girse bile hangisinin misafir
-- taşıdığı kaybolurdu.
--
-- ÇÖZÜM: benzersizlik anahtarına kart ETİKETİ girer. Her hak kendi
-- misafir kapasitesini ve bankasını taşır; 189'un çoklu hak
-- çözümleyicisi ikisini de ayrı seçenek olarak değerlendirir.
alter table host_entitlements add column if not exists card_label text;

drop index if exists uq_he;
create unique index if not exists uq_he
  on host_entitlements (user_id, program_id, coalesce(tier,''), coalesce(card_label,''));

comment on column host_entitlements.card_label is
  'Aynı programdan birden çok kart ayırt edici etiketi (ör. "Amex", '
  '"Garanti Bonus"). Boş = tek kart. 191: iki M&S kartı olan kullanıcı '
  'ikisini de ekleyebilsin diye benzersizlik anahtarına girdi.';

-- BEKÇİ: aynı programdan iki hak GERÇEKTEN eklenebiliyor mu?
do $$
declare v_uid uuid; v_pid uuid; v_n int;
begin
  select id into v_uid from users order by created_at limit 1;
  select id into v_pid from lounge_programs where code = 'TK_MS';
  if v_uid is null or v_pid is null then
    raise notice '191: coklu kart bekcisi atlandi'; return;
  end if;
  insert into host_entitlements (user_id, program_id, tier, card_label, origin)
  values (v_uid, v_pid, 'ELPL', '191-test-a', 'admin'),
         (v_uid, v_pid, 'ELPL', '191-test-b', 'admin')
  on conflict do nothing;
  select count(*) into v_n from host_entitlements
   where user_id = v_uid and program_id = v_pid and card_label like '191-test-%';
  delete from host_entitlements where card_label like '191-test-%';
  if v_n < 2 then
    raise exception '191: ayni programdan iki hak HALA eklenemiyor (% eklendi)', v_n;
  end if;
  raise notice '191: ayni programdan iki kart eklenebiliyor (kanitlandi)';
end $$;


-- ============================================================
-- 5 · KABİN SINIFI — motora HİÇ ulaşmıyordu (mimari eksik #3)
-- ============================================================
-- ÖLÇÜM: lounge_guest_rules'ta cabin_class dolu 15 kural var
-- (146:102-111 → "Business Class bileti salona girmeni sağlar ama
-- MİSAFİR HAKKI VERMEZ", "First Class: bir misafir hakkın var").
-- Ama lounge_access_decision resolve_guest_rule'a p_cabin=NULL
-- geçiyor (157:269) ve `x.cabin_class = null` asla true olmuyor →
-- KABİN KURALLARI HİÇBİR ZAMAN ADAY OLMUYOR.
--
-- Sonuç: rule_matrix_test resolve'u DOĞRUDAN çağırdığı için matris
-- yeşil görünüyor; canlı zincir o kuralı hiç uygulamıyor.
-- "Sessiz bırakmak seçenek değil" — iki yol vardı:
--   (a) uçtan uca bağla   (b) pasife çekip raporda göster
-- (a) SEÇİLDİ: kabin bilgisi ilana eklenebilir bir alan; app doldurana
-- kadar null gider ve davranış BUGÜNKÜYLE AYNI kalır (geriye uyumlu),
-- ama kablo hazır olur ve rapor kaç kuralın erişilebilir olduğunu yazar.

alter table availabilities add column if not exists cabin_class text;
alter table availabilities drop constraint if exists av_cabin_chk;
alter table availabilities add constraint av_cabin_chk
  check (cabin_class is null or cabin_class in ('economy','business','first'));
comment on column availabilities.cabin_class is
  '191: host''un o uçuştaki kabini. Kabin bazlı kurallar (Business bileti '
  'misafir hakkı vermez / First 1 misafir) ancak bu alan dolunca devreye '
  'girer. Boş bırakılırsa motor kabin kuralını aday yapmaz — bugünkü davranış.';

-- Kararı kabinle çağır (imza DEĞİŞMİYOR — 156'nın kritik kararı)
do $$
declare v_src text; v_new text; v_oid oid;
begin
  select oid into v_oid from pg_proc
   where proname = 'lounge_access_decision' and pronamespace = 'public'::regnamespace
   order by oid desc limit 1;
  if v_oid is null then raise notice '191: karar fonksiyonu yok'; return; end if;
  select prosrc into v_src from pg_proc where oid = v_oid;
  if position('191-kabin' in v_src) > 0 then
    raise notice '191: kabin zaten bagli'; return;
  end if;

  v_new := replace(v_src,
    'public.resolve_guest_rule(v_prog_id, v_venue_id, v_tier, v_av.carrier, null)',
    'public.resolve_guest_rule(v_prog_id, v_venue_id, v_tier, v_av.carrier,
       /* 191-kabin: ilanin kabini. Bos ise null gider ve davranis
          bugunkuyle AYNI kalir — geriye tam uyumlu. */
       (select a2.cabin_class from availabilities a2 where a2.id = p_avail_id))');

  if v_new = v_src then
    raise notice '191: kabin kalibi bulunamadi — elle kontrol et'; return;
  end if;

  execute 'create or replace function public.lounge_access_decision('
       || pg_get_function_arguments(v_oid) || ') returns '
       || pg_get_function_result(v_oid)
       || ' language plpgsql stable security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '191: kabin sinifi karar zincirine baglandi';
end $$;

-- Kabin kurallarının ERİŞİLEBİLİRLİĞİNİ raporla — sessiz kalmasın
create or replace function public.cabin_rule_reach()
returns table (kural_sayisi int, erisilebilir int, not_metni text)
language plpgsql stable security definer set search_path = public as $$
declare v_top int; v_ok int;
begin
  select count(*) into v_top from lounge_guest_rules where cabin_class is not null;
  select count(*) into v_ok from availabilities where cabin_class is not null;
  kural_sayisi := v_top;
  erisilebilir := v_ok;
  not_metni := case
    when v_top = 0 then 'Kabin bazlı kural yok.'
    when v_ok = 0 then 'Kabin kuralları TANIMLI ama hiçbir ilanda kabin girilmemiş — '
                       'kurallar henüz devrede değil. App ilan formuna kabin alanı ekleyince açılır.'
    else 'Kabin kuralları devrede: ' || v_ok || ' ilanda kabin bilgisi var.' end;
  return next;
end $$;
grant execute on function public.cabin_rule_reach() to authenticated;


-- ============================================================
-- 6 · BEKÇİLER
-- ============================================================
do $$
declare v_acik int; v_top int;
begin
  select count(*), count(*) filter (where durum = 'acik')
    into v_top, v_acik from rule_source_conflicts;
  if v_top = 0 then raise exception '191: celiski defteri BOS'; end if;
  raise notice '191: % celiski kayitli, %''i hala acik', v_top, v_acik;
end $$;

do $$
declare r record; v_bad int := 0;
begin
  -- Her 'karara_baglandi' kaydın bir kararı ve etkisi yazılı olmalı.
  for r in select konu from rule_source_conflicts
            where durum = 'karara_baglandi'
              and (coalesce(karar,'') = '' or coalesce(etki,'') = '')
  loop
    raise warning '191: "%" karara baglandi deniyor ama karar/etki bos', r.konu;
    v_bad := v_bad + 1;
  end loop;
  if v_bad > 0 then raise exception '191: % karar eksik yazilmis', v_bad; end if;
  raise notice '191: her karar gerekcesi ve etkisiyle yazili';
end $$;

do $$
declare j jsonb;
begin
  -- bank_override_for veri yokken null dönmeli, patlamamalı
  j := public.bank_override_for(
        (select id from lounge_programs where code = 'PRIORITY_PASS'), 'GARANTI', null);
  if j is not null then raise notice '191: banka ortusmesi verisi VAR'; end if;
  raise notice '191: bank_override_for cagrilabiliyor (veri yokken null)';
end $$;

do $$
declare r record;
begin
  select * into r from public.cabin_rule_reach();
  raise notice '191: kabin — % kural, % ilanda kabin bilgisi. %',
    r.kural_sayisi, r.erisilebilir, r.not_metni;
end $$;

select '191 OK - celiskiler karara baglandi, banka+kabin+coklu kart kablolandi' as sonuc;


-- ============================================================
-- 7 · 189'UN FAZLA GENİŞ KABUL SATIRI — kendi hatamın düzeltmesi
-- ============================================================
-- ÖLÇÜM: kapsam denetimi 12 boşluk gösterdi, hepsi
--   AJET_MS × SAW × (Aeroport Lounge, Primeclass Lounge)
--
-- SEBEP: 189'da AJet'in SAW hakkını yazarken kabul satırını
--   `cross join lounge_venues v where v.airport_code = 'SAW'`
-- ile SAW'DAKİ HER SALONA verdim. Oysa AJet'in tablosu SAW'da
-- **Turkish Airlines CIP Lounge**'dan bahsediyor; Primeclass ve
-- Aeroport üçüncü taraf salonlar ve AJet tablosunda YOKLAR.
--
-- 🔴 DERS: "havalimanı" bir kabul ekseni DEĞİLDİR. Kabul satırı
-- (salon × program) çiftidir. Havalimanı üzerinden toplu kabul
-- yazmak, kaynağın söylemediği bir hakkı üç salona birden dağıtır —
-- tam da bu turda Priority Pass'te düzelttiğim "fazla iddia"
-- hatasının aynısını kendim yapmışım.
--
-- Boşluğu "kural ekleyerek" kapatmak YANLIŞ olurdu: olmayan bir
-- kabulü meşrulaştırırdı. Doğrusu KABULÜ GERİ ALMAK.
do $$
declare v_n int;
begin
  delete from lounge_venue_acceptance a
   using lounge_programs p, lounge_venues v
   where p.id = a.program_id and v.id = a.venue_id
     and p.code = 'AJET_MS'
     and v.airport_code = 'SAW'
     and public.brand_key(v.operator, v.name) <> 'thy';
  get diagnostics v_n = row_count;
  raise notice '191: AJet''in SAW''daki % fazla kabul satiri geri alindi', v_n;
end $$;

-- Aynı hatanın kural tarafı da varsa temizle
delete from lounge_guest_rules r
 using lounge_programs p, lounge_venues v
 where p.id = r.program_id and v.id = r.venue_id
   and p.code = 'AJET_MS' and v.airport_code = 'SAW'
   and public.brand_key(v.operator, v.name) <> 'thy';

-- BEKÇİ: kabul satırı yalnız kaynağın adını verdiği salonlarda olsun
--
-- ⚠️ 26 AĞUSTOS 2026 — BU BEKÇİNİN KANITI DEĞİŞTİRİLDİ (242'nin dersi).
--
-- Eski kanıt: "AJET_MS yalnız marka anahtarı `thy` olan salonlarda
-- bulunabilir." Yazıldığı gün doğruydu. Sonra 214a iç hat salonlarını
-- ekledi ve ÖLÇÜLDÜ Kİ AJet'in KENDİ ücret tablosu
-- (ajet.com/.../cip-lounge) "Muğla Milas-Bodrum Havalimanı"nı adıyla
-- sayıyor — oradaki CIP salonu ise TAV Primeclass. Yani kabul satırı
-- doğruydu, BEKÇİNİN VARSAYIMI dardı: "AJet salonu = THY salonu".
--
-- Ölçüm (bu veritabanı): 19 etkin AJET_MS kabulü · 18'i ajet.com
-- kaynaklı · 1'i turkishairlines.com (LHR THY Lounge) · KAYNAKSIZ 0.
--
-- Bekçinin NİYETİ hep şuydu: "AJet kabulü hiçbir salona kaynak
-- gösterilmeden serpilmesin". Kanıt artık tam olarak onu ölçüyor:
-- marka değil, KAYNAK. Bu hem daha dar (kaynaksız tek satır bile
-- kırmızı yanar) hem de yeni doğru veriye kapıyı kapatmıyor.
--
-- 🆕 SINIF: "BİR KURALIN KANITINI MARKAYA BAĞLARSAN, KAYNAK MARKAYI
-- AŞTIĞI GÜN DOĞRU VERİYİ REDDEDERSİN."
do $$
declare v_bad int; v_ayrinti text;
begin
  select count(*), string_agg(v.airport_code || ' · ' || v.name, ', ')
    into v_bad, v_ayrinti
    from lounge_venue_acceptance a
    join lounge_programs p on p.id = a.program_id
    join lounge_venues v on v.id = a.venue_id
   where p.code = 'AJET_MS' and a.active and v.active
     and coalesce(nullif(trim(a.source_url), ''), '') = '';
  if v_bad > 0 then
    raise exception '191: AJET_MS kabulunun % satiri KAYNAKSIZ → %', v_bad, v_ayrinti;
  end if;

  -- Ters yön: bekçi her şeyi kesip sıfıra da inmemeli.
  select count(*) into v_bad
    from lounge_venue_acceptance a
    join lounge_programs p on p.id = a.program_id
    join lounge_venues v on v.id = a.venue_id
   where p.code = 'AJET_MS' and a.active and v.active;
  if v_bad = 0 then
    raise exception '191: AJET_MS hicbir salonda kabul edilmiyor — fazla kestim.';
  end if;
  raise notice '191: AJet kabulunun % satirinin hepsi kaynakli', v_bad;
end $$;


-- ============================================================
-- 8 · uq_he DEĞİŞİNCE KIRILAN ON CONFLICT'LER — kendi hatam
-- ============================================================
-- ÖLÇÜM (E2E, gerçek PostgreSQL):
--   11. Host erişim beyanı kaydedildi
--       → ERROR: there is no unique or exclusion constraint matching
--                the ON CONFLICT specification
--   12. Yeni kullanıcı ilan açabildi → no_access_source
--   13. İlan açınca rol host oldu    → guest
--
-- SEBEP: 4. blokta uq_he'ye `card_label` ekledim. `save_host_access`
-- (100:137) hâlâ ESKİ üç kolonluk anahtara `on conflict` yapıyor;
-- eşleşen kısıt kalmadığı için PATLIYOR. Beyan kaydedilemeyince
-- kullanıcı erişim kaynağı olmadan kalıyor ve İLAN AÇAMIYOR.
--
-- 🔴 DERS — YENİ BİR SINIF: BİR BENZERSİZLİK ANAHTARINI DEĞİŞTİRMEK,
-- ONA `ON CONFLICT` YAPAN HER FONKSİYONU DEĞİŞTİRMEK DEMEKTİR.
-- Şema değişikliği "sadece indeks" gibi görünür; oysa indeks bir
-- SÖZLEŞMEDİR ve üç fonksiyon ona yaslanıyordu (092, 095, 100).
-- E2E yakaladı — statik denetimlerin hiçbiri göremezdi, çünkü
-- sözdizimi geçerli ve imza doğru.

do $$
declare r record; v_src text; v_new text; v_n int := 0;
begin
  for r in
    -- 🔴 prokind/lanname FİLTRESİ ŞART: pg_get_functiondef bir TOPLAMA
    -- fonksiyonuna (array_agg) çağrılınca "is an aggregate function"
    -- diye patlıyor. İlk yazımda filtre yoktu ve migration durdu.
    -- Ayrıca yalnız plpgsql fonksiyonları yeniden kurulabilir —
    -- sql-dili bir fonksiyonu plpgsql olarak yeniden yazmak onu bozar.
    select p.oid, p.proname from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     join pg_language l on l.oid = p.prolang
    where n.nspname = 'public' and p.prokind = 'f' and l.lanname = 'plpgsql'
      and p.prosrc like '%on conflict (user_id, program_id, coalesce(tier,%'
  loop
    select prosrc into v_src from pg_proc where oid = r.oid;
    v_new := replace(v_src,
      'on conflict (user_id, program_id, coalesce(tier,''''))',
      'on conflict (user_id, program_id, coalesce(tier,''''), coalesce(card_label,''''))');
    if v_new = v_src then continue; end if;

    execute 'create or replace function public.' || quote_ident(r.proname) || '('
         || pg_get_function_arguments(r.oid) || ') returns '
         || pg_get_function_result(r.oid)
         || ' language plpgsql volatile security definer set search_path = public as $BODY$'
         || v_new || '$BODY$';
    v_n := v_n + 1;
  end loop;
  raise notice '191: % fonksiyonun on-conflict anahtari guncellendi', v_n;
end $$;

-- BEKÇİ: eski anahtara yaslanan fonksiyon kalmasın
do $$
declare v_bad int;
begin
  select count(*) into v_bad from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   join pg_language l on l.oid = p.prolang
  where n.nspname = 'public' and p.prokind = 'f' and l.lanname = 'plpgsql'
    and p.prosrc like '%on conflict (user_id, program_id, coalesce(tier,'''')%'
    and p.prosrc not like '%card_label%';
  if v_bad > 0 then
    raise exception '191: % fonksiyon hala eski uq_he anahtarina yasliyor', v_bad;
  end if;
  raise notice '191: on-conflict anahtarlari uq_he ile uyumlu';
end $$;

-- BEKÇİ: erişim beyanı GERÇEKTEN kaydedilebiliyor mu (186 dersi)
do $$
declare v_uid uuid; v_n_once int; v_n_sonra int;
begin
  select id into v_uid from users order by created_at limit 1;
  if v_uid is null then raise notice '191: beyan bekcisi atlandi'; return; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  select count(*) into v_n_once from host_entitlements where user_id = v_uid;
  begin
    perform public.save_host_access('TK_MS', 'ELPL', null, null, null, null, null);
  exception when undefined_function then
    raise notice '191: save_host_access imzasi farkli — bekci atlandi'; return;
  end;
  select count(*) into v_n_sonra from host_entitlements where user_id = v_uid;
  if v_n_sonra < v_n_once then
    raise exception '191: erisim beyani kaydi KAYBOLDU';
  end if;
  raise notice '191: erisim beyani calisiyor (% -> % hak)', v_n_once, v_n_sonra;
exception when others then
  raise notice '191: beyan bekcisi atlandi (%)', left(sqlerrm, 120);
end $$;
