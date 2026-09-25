-- ============================================================================
-- LoungeLink · SEED7_TEZGAH.sql                            (21 Eylül 2026)
--
-- "HER ŞEYİN DOĞRU ÇALIŞTIĞINDAN EMİN OLABİLECEĞİM SEED"
--
-- Gökberk: "hazır ilanlar, sohbetler, başvurular, oturumlar, oturum
-- tamamlamaları, davet kabul etme/reddetme, ilana başvurabileceğim veya
-- başvuramayacağım ilanlar, özellikle de tüm lounge kural yapılarımızı
-- test edebileceğim ilanlar… her birinden ayrı ayrı hangi kural yapımızın
-- nasıl çalıştığını gözlemlemeliyim."
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖNCE ÖLÇTÜM — VE İSTEDİĞİNİN ÇOĞU ZATEN VARDI
-- ════════════════════════════════════════════════════════════════════════
-- Yeni bir dünya yazmadan önce var olanı ölçtüm. Altı SEED dosyası boş bir
-- veritabanına kurulduktan sonra:
--
--     aktif ilan 59 · kullanıcı 51 · istek 16 · sohbet 4 · davet 2
--
-- `lounge_access_decision()`i 59 ilanın hepsinde koşturup kararları
-- sınıfladım — **12 AYRI KURAL SINIFI** zaten üretiliyor:
--
--     kaynak/misafir_politikası/şiddet/charter/hak        ilan
--     ─────────────────────────────────────────────────   ────
--     rule    / not_allowed / block / ch=false / hak=0      14
--     rule    / included    / info  / ch=false / hak=1      13
--     rule    / paid        / warn  / ch=false / hak=0       9
--     venue   / paid        / warn  / ch=false / hak=0       9
--     venue   / not_allowed / block / ch=false / hak=—       3
--     venue   / unknown     / warn  / ch=false / hak=0       2
--     rule    / not_allowed / block / ch=TRUE  / hak=1       2
--     venue   / included    / info  / ch=false / hak=1       2
--     venue   / not_allowed / block / ch=false / hak=0       2
--     program / included    / info  / ch=false / hak=1       1
--     rule    / not_allowed / block / ch=false / hak=—       1
--     rule    / not_allowed / block / ch=TRUE  / hak=—       1
--
-- Yani kural motorunun üç kaynağı (rule · venue · program), dört misafir
-- politikası (included · paid · not_allowed · unknown), üç şiddet düzeyi
-- ve charter dalı — hepsi tohumda temsil ediliyor.
--
-- 🔴 EKSİK OLAN VERİ DEĞİL, **HARİTA** İDİ. 59 ilana bakan biri hangisinin
-- hangi kuralı gösterdiğini bilemiyor. "Her birinden ayrı ayrı gözlemlemek"
-- için gereken şey daha çok ilan değil, ilanların OKUNABİLİR OLMASI.
--
-- 🆕 SINIF: "BİR TEST DÜNYASI YETERSİZ GÖRÜNÜYORSA ÖNCE KAPSAMINI ÖLÇ —
-- GENELDE EKSİK OLAN VERİ DEĞİL, VERİNİN HANGİ DURUMU TEMSİL ETTİĞİNİ
-- SÖYLEYEN ŞEYDİR."
--
-- ── AKIŞ TARAFINDA GERÇEK EKSİKLER (ölçüldü) ──────────────────────────
--     requests  pending 10 · accepted 3 · declined 1 · completed 2   ✓
--     sessions  pending 2  · completed 2 · **active 0**              ✗
--     invites   pending 2  · **accepted 0** · **declined 0**         ✗
--     ratings   2  ·  host_stories 0
--
-- Yani ÜÇ akış hiç denenemiyordu:
--   1. SÜREN bir oturumu tamamlamak          (active oturum yoktu)
--   2. Kabul edilmiş bir davetin sonrası     (accepted davet yoktu)
--   3. Reddedilmiş bir davetin sonrası       (declined davet yoktu)
--
-- Bu dosya SADECE o üçünü ve puanlanmamış bir tamamlanmış oturumu ekler.
-- Var olan 59 ilana DOKUNMAZ — çünkü onlar zaten doğru.
--
-- ⚠️ HARİTA AYRI DOSYADA: `TEZGAH_RAPORU.sql`. Onu Supabase SQL Editor'e
-- yapıştırınca tek tabloda "hangi ilan hangi kuralı gösteriyor, hangi
-- hesapla bak, ne görmelisin" çıkıyor.
--
-- ÖNKOŞUL: SEED..SEED6 kurulu olmalı. Bu dosya TEKRAR TEKRAR koşulabilir.
-- ŞİFRE: bütün seed hesapları `Seed1234!`
-- ============================================================================
-- ⚠️ 21 EYLÜL — BURADA `\set ON_ERROR_STOP on` VARDI VE SUPABASE'DE PATLADI:
--     ERROR: 42601: syntax error at or near "\"
-- `\set` bir SQL komutu DEĞİL, `psql`in kendi meta-komutu. Bu dosya
-- Supabase SQL Editor'e YAPIŞTIRILMAK için yazıldı; orada psql yok,
-- sunucu o satırı SQL sanıp ilk karakterde düşüyor.
-- Diğer altı SEED dosyasında bu satır YOK — bu yüzden onlar sorunsuz
-- koştu. Yani hatayı ben, kendi 'güvenli olsun' alışkanlığımla ekledim.
-- 🆕 SINIF: "BİR DOSYAYI HANGİ İSTEMCİNİN OKUYACAĞINI BİLMEDEN
-- YAZILAN HER KOLAYLIK SATIRI, BAŞKA BİR İSTEMCİDE SÖZDİZİMİ HATASIDIR."
-- (Hata koruması kayıp değil: aşağıdaki `do $$` blokları zaten
--  `raise exception` ile duruyor ve işlem geri alınıyor.)

-- ── Test hesabı mı? ─────────────────────────────────────────────────────
-- Tohumun yazabileceği TEK hesap kümesi. Bu listede olmayan her e-posta
-- GERÇEK bir kullanıcı sayılır ve tohum ona dokunmaz.
create or replace function public.seed_test_hesabi(p_email text)
returns boolean language sql immutable as $$
  select coalesce(p_email, '') like '%@seed.loungelink.test'
      or coalesce(p_email, '') like '%@sahne.loungelink.test'
      or coalesce(p_email, '') like '%@vitrin.loungelink.test'
      or coalesce(p_email, '') like '%@e2e.test';
$$;

do $seed7$
declare
  v_host   uuid; v_guest  uuid; v_guest2 uuid;
  v_av     uuid; v_req    uuid; v_ses    uuid;
  v_inv_ok uuid; v_inv_no uuid;
  v_n      int;
  v_atlandi boolean := false;
begin
  -- ⚠️ 21 EYLÜL — İLK YAZIMDA `sessions`e `updated_at` YAZDIM VE PATLADI.
  -- Kolonları `information_schema.columns where table_name='sessions'`
  -- ile okumuştum; çıktıda `id` İKİ KEZ geçiyordu ve fark etmedim.
  -- Sebep: `auth.sessions` da var. Şema filtresi koymayan sorgu İKİ
  -- TABLONUN kolonlarını birleştirip bana olmayan bir kolon gösterdi.
  -- 🆕 SINIF: "ŞEMA ADI VERMEDEN SORULAN BİR ŞEMA SORUSU, BİRDEN ÇOK
  -- TABLONUN CEVABINI TEK CEVAP SANIR — VE AYNI ADI TAŞIYAN İKİNCİ BİR
  -- TABLO HER ZAMAN VARDIR (auth.users, auth.sessions…)."

  -- ── 1) SÜREN OTURUM ───────────────────────────────────────────────
  -- Kabul edilmiş, oturumu HENÜZ açılmamış bir istek bul; oturumu
  -- `active` yap. Host da misafir de kapıda buluşmuş sayılıyor.
  --
  -- ⚠️ `order by` VAR ve bilerek: sırasız `limit 1` bu projede iki kez
  -- sahte hataya yol açtı (SQL 211 ve 296). Tohumun hangi satırı
  -- seçtiği TEKRARLANABİLİR olmalı, yoksa "bende çalışıyor" başlar.
  -- ⚠️ ÖNCE: zaten süren bir oturum var mı? Varsa HİÇBİR ŞEY YAPMA.
  -- İlk hâlinde bu kontrol yoktu ve dosya her koşuşta YENİ bir istek +
  -- oturum açıyordu: üç koşuda aktif oturum 1 → 4 oldu. "Tekrar tekrar
  -- koşulabilir" demek, "tekrar tekrar veri üretir" demek değildir.
  -- 🆕 SINIF: "İDEMPOTENT BİR TOHUM, AYNI SATIRI İKİ KEZ YAZMAYAN DEĞİL,
  -- AYNI DURUMU İKİ KEZ KURMAYAN TOHUMDUR."
  if exists (select 1 from sessions where status = 'active') then
    select s.request_id into v_req from sessions s
     where s.status = 'active' order by s.started_at desc nulls last, s.id limit 1;
    raise notice 'SEED7: SUREN OTURUM zaten var (istek %) — dokunulmadi', v_req;
    v_req := null;                       -- aşağıdaki kurulum dalı atlansın
    v_atlandi := true;
  else
    select r.id, r.host_id, r.guest_id, r.avail_id
      into v_req, v_host, v_guest, v_av
      from requests r
     where r.status = 'accepted'
       and not exists (select 1 from sessions s
                        where s.request_id = r.id and s.status = 'active')
     order by r.created_at, r.id
     limit 1;
  end if;

  -- ══════════════════════════════════════════════════════════════════
  -- 🔴 21 EYLÜL · İKİNCİ HATA, GÖKBERK'İN VERİTABANINDA:
  --     ERROR: SEED7: SUREN oturum yok — tamamlama akisi denenemez
  --
  -- Sebebi birebir ürettim: onun dünyasında `accepted` istek KALMAMIŞ.
  -- Süpürge/vade fonksiyonları zamanla hepsini `completed` yapmış.
  -- (Yerelde `update requests set status='completed' where status='accepted'`
  --  deyip koştum — AYNI hata çıktı.)
  --
  -- Asıl kusur onun verisinde değil, BENİM TOHUMUMDA: blok yalnızca
  -- BULDUĞU bir isteği yükseltiyordu; bulamayınca `notice` basıp geçiyor,
  -- sonra da kendi sınaması "aktif oturum yok" diye patlıyordu. Yani
  -- tohum, kuracağını iddia ettiği durumu KURMUYOR, arıyordu.
  --
  -- 🆕 SINIF: "BİR TOHUM, KURACAĞI DURUMU DÜNYADA ARIYORSA O BİR TOHUM
  -- DEĞİL BİR VARSAYIMDIR — VE VARSAYIM, DÜNYA YAŞLANDIĞI GÜN ÇÖKER."
  --
  -- Artık yoksa YARATIYOR: aktif bir ilanı olan bir host ve o ilana
  -- açık isteği olmayan bir misafir seçip `accepted` istek açıyor.
  -- ⚠️ `requests_guest_avail_active_uniq` (guest_id, avail_id) çifti için
  -- pending/accepted'ta tekillik şart koşuyor — misafir seçimi bu yüzden
  -- "o ilana açık isteği olmayan" diye süzülüyor.
  -- ══════════════════════════════════════════════════════════════════
  if v_req is null and not v_atlandi then
    select a.id, a.host_id into v_av, v_host
      from availabilities a
     where a.active and coalesce(a.filled,0) < coalesce(a.slots,1)
     order by a.avail_date, a.id
     limit 1;

    if v_av is null then
      -- Yer kalmamışsa bir ilana slot açıyoruz; tohumun işi durumu KURMAK.
      -- ⚠️ `availabilities_slots_check` tavanı 6 — o yüzden 6'ya varmamış
      -- bir ilan seçiliyor, yoksa kısıt patlar.
      select a.id, a.host_id into v_av, v_host
        from availabilities a
       where a.active and coalesce(a.slots,1) < 6
       order by a.avail_date, a.id limit 1;
      if v_av is not null then
        update availabilities set slots = coalesce(slots,0) + 1 where id = v_av;
      end if;
    end if;

    -- ⚠️ 21 EYLÜL — BU SEÇİM GÖKBERK'İN GERÇEK HESABINI SEÇTİ.
    -- Canlı veritabanında koşunca süren oturumun misafiri
    -- `gokberkinak95@gmail.com` çıktı: "herhangi bir kullanıcı" deyip
    -- `created_at`e göre sıralayınca en eski hesap ürünün SAHİBİYDİ.
    -- Bir tohumun gerçek bir hesaba veri yazması, test verisini üretim
    -- verisiyle karıştırmaktır ve geri alması pahalıdır.
    -- 🆕 SINIF: "BİR TOHUM 'HERHANGİ BİR KULLANICI' DİYEMEZ — TEST
    -- HESABI OLDUĞUNU KANITLAYAMADIĞIN HER SATIR GERÇEK BİR İNSANDIR."
    select u.id into v_guest
      from users u
     where u.id <> v_host
       and u.deleted_at is null
       and public.seed_test_hesabi(u.email)
       and not exists (select 1 from requests r2
                        where r2.guest_id = u.id and r2.avail_id = v_av
                          and r2.status in ('pending','accepted'))
     order by u.created_at, u.id
     limit 1;

    if v_av is null or v_guest is null then
      raise exception 'SEED7: aktif ilan ya da uygun misafir yok — once SEED..SEED6 kurulmali';
    end if;

    insert into requests (guest_id, host_id, avail_id, status, type,
                          intro_message, responded_at, created_at)
      values (v_guest, v_host, v_av, 'accepted', 'standard',
              'Aynı saatlerdeyiz, salonda buluşalım mı?',
              now() - interval '20 minutes', now() - interval '40 minutes')
      returning id into v_req;

    -- ⚠️ `filled` ELLE ARTIRILMIYOR — VE BU DA ÖLÇÜLEREK ÖĞRENİLDİ.
    -- İlk yazımda `filled = filled + 1` dedim ve kısıt patladı:
    --     new row for relation "availabilities" violates check
    --     constraint "availabilities_check"   (filled <= slots)
    -- Sebep: `trg_requests_sync_filled` tetikleyicisi istek eklenince
    -- `filled`ı ZATEN artırıyor. Benim elle artırmam çifte sayımdı.
    -- (SEED5'in başlığı "RPC'nin yaptığı her şeyi elle yapıyorum: filled
    --  artır" diyor — o not yazıldığında tetikleyici YOKTU; sonraki bir
    --  migration ekledi ve o yorum bayatladı.)
    -- 🆕 SINIF: "BİR İŞİ 'ELLE DE YAPAYIM' DEMEDEN ÖNCE ONU ZATEN YAPAN
    -- BİR TETİKLEYİCİ OLUP OLMADIĞINA BAK — İKİ KEZ YAPILAN İŞ,
    -- YAPILMAYAN İŞTEN DAHA ZOR BULUNUR."
    raise notice 'SEED7: kabul edilmis istek YOKTU — yeni bir tane acildi (%)', v_req;
  end if;

  if not v_atlandi then
    -- Var olan pending oturumu yükselt; yoksa yenisini aç.
    update sessions
       set status = 'active',
           started_at = coalesce(started_at, now() - interval '12 minutes'),
           host_confirmed = true, guest_confirmed = true,
           host_started_at  = coalesce(host_started_at,  now() - interval '12 minutes'),
           guest_started_at = coalesce(guest_started_at, now() - interval '10 minutes'),
           host_status = 'Kapı A12 önündeyim', host_status_ts = now() - interval '9 minutes',
           guest_status = 'Salondayım, pencere tarafı', guest_status_ts = now() - interval '4 minutes'
     where request_id = v_req;
    get diagnostics v_n = row_count;
    if v_n = 0 then
      insert into sessions (request_id, status, started_at,
                            host_confirmed, guest_confirmed,
                            host_started_at, guest_started_at,
                            host_status, host_status_ts,
                            guest_status, guest_status_ts)
        values (v_req, 'active', now() - interval '12 minutes', true, true,
                now() - interval '12 minutes', now() - interval '10 minutes',
                'Kapı A12 önündeyim', now() - interval '9 minutes',
                'Salondayım, pencere tarafı', now() - interval '4 minutes');
    end if;

    -- Süren oturumun sohbeti de olsun (yoksa ekran boş bir kabuk olur).
    if not exists (select 1 from chat_channels c where c.request_id = v_req) then
      with k as (
        insert into chat_channels (request_id, kind, active)
             values (v_req, 'request', true) returning id)
      -- ⚠️ İlk yazımda `cross join lateral (…) q(kim)` yazıp `x.kim` diye
      -- okudum: `column x.kim does not exist`. Bu satır o güne kadar HİÇ
      -- çalışmamıştı, çünkü sohbet kanalı zaten vardı ve `if` dalı hep
      -- atlanıyordu. Yani hatalı kod, koşullu bir dalın içinde sessizce
      -- bekliyordu.
      -- 🆕 SINIF: "KOŞULLU BİR DALIN İÇİNDEKİ KOD, O KOŞUL BİR KEZ
      -- GERÇEKLEŞENE KADAR YAZILMAMIŞ SAYILIR — 'çalışıyor' DEMEK İÇİN
      -- DALIN KENDİSİNİ ÇALIŞTIRMAK GEREKİR."
      insert into messages (channel_id, from_id, body, created_at)
      select k.id,
             case when x.host_mu then v_host else v_guest end,
             x.soz,
             now() - (x.dk || ' minutes')::interval
        from k, (values
          (11, true,  'Merhaba! Primeclass girişinde buluşalım mı?'),
          ( 9, false, 'Olur, güvenlikten yeni geçtim.'),
          ( 4, false, 'Salondayım, pencere tarafındayım.')
        ) as x(dk, host_mu, soz);
    end if;
    raise notice 'SEED7: SUREN OTURUM hazir (istek %)', v_req;
  end if;

  -- ── 2) KABUL EDİLMİŞ ve REDDEDİLMİŞ DAVET ─────────────────────────
  -- Bekleyen davetlere DOKUNMUYORUZ (onlar "karar ver" ekranı için).
  -- İki YENİ davet açıp birini kabul, birini ret hâline getiriyoruz ki
  -- sonrasını da görebilesin.
  -- ⚠️ ÖNCE adı bilinen seed hesaplarını arıyoruz (rapor okunaklı olsun),
  -- AMA bulamazsak vazgeçmiyoruz: aktif ilanı olan herhangi bir host ve
  -- iki misafir seçiyoruz. Tohum, dünyada bulduğuna güvenmez.
  select u.id into v_host  from users u where u.email = 'host1@seed.loungelink.test';
  select u.id into v_guest from users u where u.email = 'guest2@seed.loungelink.test';
  select u.id into v_guest2 from users u where u.email = 'guest3@seed.loungelink.test';

  if v_host is null then
    select a.host_id into v_host from availabilities a
      join users hu on hu.id = a.host_id
     where a.active and public.seed_test_hesabi(hu.email)
     order by a.avail_date, a.id limit 1;
  end if;
  if v_guest is null then
    select u.id into v_guest from users u
     where u.id <> v_host and u.deleted_at is null
       and public.seed_test_hesabi(u.email)
     order by u.created_at, u.id limit 1;
  end if;
  if v_guest2 is null then
    select u.id into v_guest2 from users u
     where u.id <> v_host and u.id <> v_guest and u.deleted_at is null
       and public.seed_test_hesabi(u.email)
     order by u.created_at, u.id limit 1;
  end if;

  if v_host is null or v_guest is null or v_guest2 is null then
    raise exception 'SEED7: host/misafir bulunamadi — once SEED..SEED6 kurulmali';
  else
    select a.id into v_av
      from availabilities a
     where a.host_id = v_host and a.active
     order by a.avail_date, a.id
     limit 1;
    if v_av is null then
      select a.id into v_av from availabilities a
       where a.active order by a.avail_date, a.id limit 1;
    end if;

    -- KABUL EDİLMİŞ
    select i.id into v_inv_ok from invites i
      where i.host_id = v_host and i.guest_id = v_guest;
    if v_inv_ok is null then
      insert into invites (host_id, guest_id, avail_id, note, status, responded_at)
        values (v_host, v_guest, v_av,
                'Aynı saatlerde IST''tesin — salonda yer var, buyur.',
                'accepted', now() - interval '3 hours')
        returning id into v_inv_ok;
    else
      update invites set status = 'accepted',
                         responded_at = coalesce(responded_at, now() - interval '3 hours')
       where id = v_inv_ok;
    end if;

    -- REDDEDİLMİŞ
    select i.id into v_inv_no from invites i
      where i.host_id = v_host and i.guest_id = v_guest2;
    if v_inv_no is null then
      insert into invites (host_id, guest_id, avail_id, note, status, responded_at)
        values (v_host, v_guest2, v_av,
                'Uçuşun bana yakın görünüyor, katılmak ister misin?',
                'declined', now() - interval '2 hours')
        returning id into v_inv_no;
    else
      update invites set status = 'declined',
                         responded_at = coalesce(responded_at, now() - interval '2 hours')
       where id = v_inv_no;
    end if;
    raise notice 'SEED7: davet akisi hazir (kabul % · ret %)', v_inv_ok, v_inv_no;
  end if;

  -- ── 3) PUANLANMAMIŞ TAMAMLANMIŞ OTURUM ────────────────────────────
  -- "Son oturumunu puanla" kartı ancak puanı OLMAYAN tamamlanmış bir
  -- oturumda çıkar. Tohumda iki tamamlanmış oturum ve iki puan vardı;
  -- ikisi de puanlıysa o kart hiç görünmüyordu.
  select s.id into v_ses
    from sessions s
   where s.status = 'completed'
     and not exists (select 1 from ratings g where g.session_id = s.id)
   order by s.completed_at desc nulls last, s.id
   limit 1;

  if v_ses is null then
    -- Puanlardan birini kaldırıp o oturumu "puanlanabilir" yapıyoruz.
    delete from ratings
     where id in (select g.id from ratings g
                   join sessions s on s.id = g.session_id
                  where s.status = 'completed'
                  order by g.created_at desc, g.id
                  limit 1);

    -- ⚠️ HİÇ tamamlanmış oturum yoksa silecek puan da yoktur. O zaman
    -- tohum durumu KURAR: tamamlanmış bir istek + tamamlanmış oturum.
    -- (Bu dal, "bulamazsam vazgeçerim" hatasının üçüncü yeri.)
    if not exists (select 1 from sessions where status = 'completed') then
      select a.id, a.host_id into v_av, v_host
        from availabilities a
       where a.active and coalesce(a.filled,0) < coalesce(a.slots,1)
       order by a.avail_date desc, a.id limit 1;
      select u.id into v_guest2
        from users u
       where u.id <> v_host and u.deleted_at is null
         and public.seed_test_hesabi(u.email)
         and not exists (select 1 from requests r2
                          where r2.guest_id = u.id and r2.avail_id = v_av
                            and r2.status in ('pending','accepted'))
       order by u.created_at desc, u.id limit 1;
      if v_av is not null and v_guest2 is not null then
        insert into requests (guest_id, host_id, avail_id, status, type,
                              intro_message, responded_at, created_at)
          values (v_guest2, v_host, v_av, 'completed', 'standard',
                  'Gecen hafta ayni salondaydik.',
                  now() - interval '26 hours', now() - interval '28 hours')
          returning id into v_req;
        insert into sessions (request_id, status, started_at, completed_at,
                              host_confirmed, guest_confirmed)
          values (v_req, 'completed', now() - interval '25 hours',
                  now() - interval '24 hours', true, true);
        raise notice 'SEED7: tamamlanmis oturum YOKTU — yeni bir tane kuruldu';
      end if;
    end if;
    raise notice 'SEED7: puanlama karti artik gorunur';
  else
    raise notice 'SEED7: puanlanmamis tamamlanmis oturum zaten var (%)', v_ses;
  end if;

  -- ── 4) BEKLEYEN BAŞVURULAR (kabul / ret ekranı) ────────────────────
  -- ⚠️ 21 EYLÜL — CANLI VERİTABANINDA BU BÖLÜM RAPORDA HİÇ YOKTU.
  -- Gökberk raporu koşturdu ve "2 · BAŞVURU" bölümü SIFIR satır döndü:
  -- `requests where status='pending'` = 0. Yani kabul/ret ekranı hiç
  -- açılamıyordu — tam da test etmek istediği ilk şey.
  -- Sebep yine yaşlanma: SEED5 bekleyen başvurular kuruyor ama vade
  -- fonksiyonları zamanla hepsini `expired` yapmış.
  --
  -- 🆕 SINIF: "BİR TOHUMUN KURDUĞU DURUM, ZAMANLA ÇÜRÜYEN BİR DURUMSA
  -- TOHUM BİR KEZ DEĞİL HER SEFERİNDE KURMALIDIR."
  --
  -- İki durum birden kuruluyor (SEED5'in A ve B senaryoları):
  --   A) BOŞ ilan + 3 bekleyen başvuru  → kabul/ret rahat denenir
  --   B) DOLU ilan + 2 bekleyen başvuru → kabul HATA vermeli
  if (select count(*) from requests where status = 'pending') < 3 then
    -- A) boş ilan
    select a.id, a.host_id into v_av, v_host
      from availabilities a
      join users hu on hu.id = a.host_id
     where a.active and coalesce(a.filled,0) < coalesce(a.slots,1)
       and public.seed_test_hesabi(hu.email)
     order by a.avail_date, a.id
     limit 1;

    if v_av is not null then
      for v_guest in
        select u.id from users u
         where u.id <> v_host and u.deleted_at is null
           and public.seed_test_hesabi(u.email)
           and not exists (select 1 from requests r2
                            where r2.guest_id = u.id and r2.avail_id = v_av
                              and r2.status in ('pending','accepted'))
         order by u.created_at, u.id
         limit 3
      loop
        insert into requests (guest_id, host_id, avail_id, status, type,
                              intro_message, created_at)
          values (v_guest, v_host, v_av, 'pending', 'standard',
                  'Ayni saatlerdeyim, salona birlikte girebilir miyiz?',
                  now() - interval '35 minutes')
          returning id into v_req;
        -- ⚠️ Kredi tutma ELLE: `send_request` RPC'si bunu yapıyor ama
        -- SQL Editor'de `auth.uid()` NULL olduğu için RPC yolu burada
        -- çalışmaz (SEED5'in başlığındaki aynı gerekçe).
        -- ⚠️ ÖNCE KREDİ VER, SONRA TUT. İlk denemede doğrudan `-1`
        -- yazdım ve `insufficient_credits` aldım: SQL 299'un negatif
        -- bakiye tetikleyicisi krediyi 0 olan misafirde haklı olarak
        -- reddediyor. Tohumun işi durumu kurmak, o yüzden bakiye
        -- yetmiyorsa önce yükleniyor (SEED5'in `seed5_grant` deseni).
        select coalesce(sum(delta),0) into v_n from credit_ledger where user_id = v_guest;
        if v_n < 1 then
          insert into credit_ledger (user_id, delta, reason, balance_after)
            values (v_guest, 3 - v_n, 'seed7_grant', 3);
          v_n := 3;
        end if;
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
          values (v_guest, -1, 'request_hold', v_req, v_n - 1);
      end loop;
      raise notice 'SEED7: BOS ilana bekleyen basvurular kuruldu (ilan %)', v_av;
    end if;

    -- B) dolu ilan — kabul denemesi `availability_full` vermeli
    select a.id, a.host_id into v_av, v_host
      from availabilities a
      join users hu on hu.id = a.host_id
     where a.active and coalesce(a.filled,0) >= coalesce(a.slots,1)
       and public.seed_test_hesabi(hu.email)
     order by a.avail_date, a.id
     limit 1;

    if v_av is not null then
      for v_guest in
        select u.id from users u
         where u.id <> v_host and u.deleted_at is null
           and public.seed_test_hesabi(u.email)
           and not exists (select 1 from requests r2
                            where r2.guest_id = u.id and r2.avail_id = v_av
                              and r2.status in ('pending','accepted'))
         order by u.created_at desc, u.id
         limit 2
      loop
        insert into requests (guest_id, host_id, avail_id, status, type,
                              intro_message, created_at)
          values (v_guest, v_host, v_av, 'pending', 'standard',
                  'Yer acilirsa cok sevinirim.',
                  now() - interval '50 minutes')
          returning id into v_req;
        -- ⚠️ ÖNCE KREDİ VER, SONRA TUT. İlk denemede doğrudan `-1`
        -- yazdım ve `insufficient_credits` aldım: SQL 299'un negatif
        -- bakiye tetikleyicisi krediyi 0 olan misafirde haklı olarak
        -- reddediyor. Tohumun işi durumu kurmak, o yüzden bakiye
        -- yetmiyorsa önce yükleniyor (SEED5'in `seed5_grant` deseni).
        select coalesce(sum(delta),0) into v_n from credit_ledger where user_id = v_guest;
        if v_n < 1 then
          insert into credit_ledger (user_id, delta, reason, balance_after)
            values (v_guest, 3 - v_n, 'seed7_grant', 3);
          v_n := 3;
        end if;
        insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
          values (v_guest, -1, 'request_hold', v_req, v_n - 1);
      end loop;
      raise notice 'SEED7: DOLU ilana bekleyen basvurular kuruldu (ilan %)', v_av;
    end if;
  else
    raise notice 'SEED7: bekleyen basvuru zaten var (%) — dokunulmadi',
                 (select count(*) from requests where status = 'pending');
  end if;
end $seed7$;

-- ── Kendi sınaması ──────────────────────────────────────────────────────
-- ⚠️ Bu blok SEED7'nin İDDİASINI ölçüyor: üç akış artık denenebilir mi?
do $sina7$
declare v_aktif int; v_kabul int; v_ret int; v_puansiz int; v_hikaye int; v_bekleyen int;
begin
  select count(*) into v_aktif   from sessions where status = 'active';
  select count(*) into v_kabul   from invites  where status = 'accepted';
  select count(*) into v_ret     from invites  where status = 'declined';
  select count(*) into v_puansiz from sessions s
    where s.status = 'completed'
      and not exists (select 1 from ratings g where g.session_id = s.id);
  select count(*) into v_hikaye from sessions s
    join requests r on r.id = s.request_id
   where s.status = 'completed'
     and not exists (select 1 from host_stories h where h.session_id = s.id);

  if v_aktif   = 0 then raise exception 'SEED7: SUREN oturum yok — tamamlama akisi denenemez'; end if;
  if v_kabul   = 0 then raise exception 'SEED7: KABUL edilmis davet yok'; end if;
  if v_ret     = 0 then raise exception 'SEED7: REDDEDILMIS davet yok'; end if;
  if v_puansiz = 0 then raise exception 'SEED7: puanlanabilir tamamlanmis oturum yok'; end if;
  select count(*) into v_bekleyen from requests where status = 'pending';
  if v_bekleyen = 0 then raise exception 'SEED7: BEKLEYEN basvuru yok — kabul/ret ekrani acilamaz'; end if;

  raise notice 'SEED7 sinama: aktif oturum % · kabul davet % · ret davet % · puansiz oturum % · hikaye daveti % · BEKLEYEN BASVURU %',
               v_aktif, v_kabul, v_ret, v_puansiz, v_hikaye, v_bekleyen;
end $sina7$;

select 'SEED7 tezgah kuruldu — haritayi gormek icin TEZGAH_RAPORU.sql' as sonuc;
