-- ============================================================================
-- LoungeLink · TEZGAH_RAPORU.sql                            (21 Eylül 2026)
--
-- "HANGİ İLAN HANGİ KURALI GÖSTERİYOR, HANGİ HESAPLA BAKAYIM?"
--
-- Gökberk: "her birinden ayrı ayrı hangi kural yapımızın nasıl çalıştığını
-- gözlemlemeliyim bence. Tabii buna uygun userlar da."
--
-- Tohumda 59 aktif ilan var ve kural motorunun 12 ayrı sınıfını üretiyorlar.
-- Sorun veri eksikliği değildi: 59 ilana bakan biri hangisinin hangi kuralı
-- gösterdiğini BİLEMİYORDU. Bu dosya o haritayı çıkarır.
--
-- ⚠️ TEK SORGU. Supabase SQL Editor yalnız SON sonuç kümesini gösteriyor
-- (20 Ağustos dersi: iki `select` yazınca ilki hiç görünmedi). Bu yüzden
-- bütün bölümler tek tablonun içinde satır olarak duruyor.
--
-- ⚠️ BU DOSYA HİÇBİR ŞEYİ DEĞİŞTİRMEZ — yalnız okur. İstediğin kadar koş.
--
-- ⚠️ BEKLENEN/GERÇEK diye iki sütun YOK ve bu bilinçli. "Beklenen"i aynı
-- fonksiyondan türetseydim, kendi çıktısını kendisiyle kıyaslayan ve her
-- zaman ✅ diyen sahte bir sınama olurdu. Buradaki sütun GERÇEKtir:
-- motorun O İLAN için ŞU AN ne dediği. Doğrusu ne olmalıydı sorusunun
-- cevabı `kural_kosullari()` ve kaynak belgelerdedir — ekranla bu satırı
-- karşılaştıran SENSİN.
-- 🆕 SINIF: "BİR RAPORUN İKİ SÜTUNU DA AYNI KAYNAKTAN GELİYORSA, O RAPOR
-- DOĞRULAMA YAPMAZ — YALNIZ KENDİNİ ONAYLAR."
--
-- ÖNKOŞUL: SEED..SEED6 + SEED7_TEZGAH.sql kurulu.
-- ŞİFRE: bütün seed hesapları  Seed1234!
-- ============================================================================

with karar as (
  select a.id,
         a.airport_code,
         coalesce(a.lounge_name, '—')          as salon,
         a.avail_date,
         a.slots, a.filled,
         hu.email                               as host_mail,
         public.lounge_access_decision(a.id, null) as d
    from availabilities a
    join users hu on hu.id = a.host_id
   where a.active
),
sinif as (
  select coalesce(d->>'source','-')        as kaynak,
         coalesce(d->>'guest_policy','-')  as misafir,
         coalesce(d->>'severity','-')      as siddet,
         coalesce(d->>'charter','false')   as charter,
         coalesce(d->>'guest_included_count','-') as hak,
         coalesce(d->>'headline','—')      as baslik,
         *
    from karar
),
temsilci as (
  -- Her kural sınıfından BİR temsilci ilan. Sıra sabit: aynı veritabanında
  -- aynı satır seçilir (sırasız `limit 1` bu projede iki kez sahte hataya
  -- yol açtı — SQL 211 ve 296).
  select distinct on (kaynak, misafir, siddet, charter, hak)
         kaynak, misafir, siddet, charter, hak, baslik,
         airport_code, salon, avail_date, slots, filled, host_mail,
         count(*) over (partition by kaynak, misafir, siddet, charter, hak) as ayni_sinifta
    from sinif
   order by kaynak, misafir, siddet, charter, hak, avail_date, id
)

-- ══ BÖLÜM 1 · KURAL SINIFLARI ═══════════════════════════════════════════
select 1 as sira, '1 · KURAL' as bolum,
       kaynak || ' / ' || misafir || ' / ' || siddet
         || case when charter = 'true' then ' / CHARTER' else '' end
         || ' / hak=' || hak                                as ne,
       airport_code || ' · ' || salon || ' · ' || avail_date::text as nerede,
       host_mail                                            as hesap,
       baslik                                               as motor_ne_diyor,
       'bu sınıfta ' || ayni_sinifta || ' ilan var'          as not
  from temsilci

union all

-- ══ BÖLÜM 2 · BAŞVURU AKIŞI ═════════════════════════════════════════════
select 2, '2 · BAŞVURU',
       'Bekleyen başvuru — KABUL/RET düğmeleri burada',
       coalesce(a.airport_code,'—') || ' · ' || coalesce(a.lounge_name,'—')
         || '  (' || coalesce(a.filled,0) || '/' || coalesce(a.slots,0) || ' dolu)',
       hu.email,
       'misafir: ' || gu.email,
       case when coalesce(a.filled,0) >= coalesce(a.slots,0)
            then 'İLAN DOLU — kabul denemesi HATA vermeli (availability_full)'
            else 'ilan boş — kabul/ret rahat denenir' end
  from requests r
  join users hu on hu.id = r.host_id
  join users gu on gu.id = r.guest_id
  left join availabilities a on a.id = r.avail_id
 where r.status = 'pending'

union all

-- ══ BÖLÜM 3 · OTURUM AKIŞI ══════════════════════════════════════════════
select 3, '3 · OTURUM',
       case s.status::text
         when 'active'    then 'SÜREN oturum — "Oturumu tamamla" burada denenir'
         when 'pending'   then 'Oturum açılmamış — kapıda buluşma onayı burada'
         when 'completed' then case
              when exists (select 1 from ratings g where g.session_id = s.id)
              then 'Tamamlanmış + puanlanmış'
              else 'Tamamlanmış, PUANLANMAMIŞ — "Son oturumunu puanla" burada' end
         else 'oturum: ' || s.status::text end,
       coalesce(a.airport_code,'—') || ' · ' || coalesce(a.lounge_name,'—'),
       hu.email,
       'misafir: ' || gu.email,
       coalesce('host: ' || s.host_status, '') ||
       coalesce(' · misafir: ' || s.guest_status, '')
  from sessions s
  join requests r on r.id = s.request_id
  join users hu on hu.id = r.host_id
  join users gu on gu.id = r.guest_id
  left join availabilities a on a.id = r.avail_id

union all

-- ══ BÖLÜM 4 · DAVET AKIŞI ═══════════════════════════════════════════════
select 4, '4 · DAVET',
       case i.status::text
         when 'pending'  then 'BEKLEYEN davet — kabul/ret burada denenir'
         when 'accepted' then 'KABUL EDİLMİŞ davet — sonrası (sohbet/bağlantı) burada'
         when 'declined' then 'REDDEDİLMİŞ davet — ret sonrası davranış burada'
         else 'davet: ' || i.status::text end,
       coalesce(a.airport_code,'—') || ' · ' || coalesce(a.lounge_name,'—'),
       hu.email,
       'davet edilen: ' || gu.email,
       coalesce(i.note,'—')
  from invites i
  join users hu on hu.id = i.host_id
  join users gu on gu.id = i.guest_id
  left join availabilities a on a.id = i.avail_id

union all

-- ══ BÖLÜM 5 · HOST HİKÂYESİ (SQL 296) ═══════════════════════════════════
select 5, '5 · HİKÂYE',
       'Hikâye daveti bekliyor — "Şimdi değil" (erteleme) burada denenir',
       coalesce(a.airport_code,'—') || ' · ' || coalesce(a.lounge_name,'—'),
       hu.email,
       'misafir: ' || gu.email,
       'ertelersen 30 gün sorulmaz; tek daveti erteler, hepsini susturmaz'
  from sessions s
  join requests r on r.id = s.request_id
  join users hu on hu.id = r.host_id
  join users gu on gu.id = r.guest_id
  left join availabilities a on a.id = r.avail_id
 where s.status = 'completed'
   and not exists (select 1 from host_stories h where h.session_id = s.id)

union all

-- ══ BÖLÜM 6 · SOHBETLER ═════════════════════════════════════════════════
select 6, '6 · SOHBET',
       case c.kind::text
         when 'request'    then 'İstek sohbeti (' || (select count(*) from messages m where m.channel_id = c.id) || ' mesaj)'
         when 'connection' then 'Bağlantı sohbeti (' || (select count(*) from messages m where m.channel_id = c.id) || ' mesaj)'
         else c.kind::text end,
       '—', '—', '—',
       case when c.active then 'aktif' else 'kapalı' end
  from chat_channels c

union all

-- ══ BÖLÜM 7 · HESAPLAR ══════════════════════════════════════════════════
select 7, '7 · HESAP',
       u.email,
       coalesce(p.name, '—'),
       'Seed1234!',
       'kredi ' || coalesce((select sum(delta)::text from credit_ledger l where l.user_id = u.id), '0')
         || ' · güven ' || coalesce(t.score::text, '—')
         || ' · rol ' || coalesce(u.role::text, '—'),
       -- ⚠️ Kart bilgisi `host_entitlements`te (profillerde DEĞİL).
       -- İlk yazımda `profiles.trust_score` ve `profile_cards` diye iki
       -- şey uydurmuştum; ikisi de yok. Şemayı okumadan yazılan her
       -- sütun, çalışmayan bir rapordur.
       coalesce((select string_agg(distinct coalesce(e.card_label, e.tier, '—'), ' + ')
                   from host_entitlements e where e.user_id = u.id), 'kart yok')
  from users u
  left join profiles p on p.user_id = u.id
  left join trust_scores t on t.user_id = u.id
 where u.email like '%seed.loungelink.test'
    or u.email like '%sahne.loungelink.test'

order by 1, 3, 4;
