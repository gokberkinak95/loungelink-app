-- ════════════════════════════════════════════════════════════════════════
-- 299 · SÜPÜRGENİN SAHİBİ · KREDİ YARIŞI · İADENİN DOĞRU TUTARI
--
-- 🔴 NEDEN VAR — 19 Eylül derin denetiminin açık kalan üç maddesi, artı
--    bu dosyayı yazarken ölçerek bulduğum İKİ YENİ KUSUR.
--
-- ── BÖLÜM A · SÜPÜRGE ARTIK SAHİPSİZ DEĞİL ────────────────────────────
-- 298 süpürgeye bir FREN taktı (5 dakikada bir koşar). Fren doğruydu ama
-- eksikti: süpürgenin hâlâ bir SAHİBİ yoktu. Tek tetikleyicisi
-- `App.js`in açılışı. Yani "bugün kimse uygulamayı açmadıysa hiç kimsenin
-- bayat isteği iptal edilmez, hiç kimseye kredi iadesi yazılmaz" —
-- ve bunu FARK EDEN DE OLMAZ, çünkü ölçen bir şey yok.
--
-- Bu dosya üç şey yapıyor:
--   1) Süpürgeye bir KİMLİK defteri: her koşum kimin çağırdığını, ne
--      yaptığını, hata aldıysa neyi yazıyor.
--   2) pg_cron VARSA işi ona devrediyor (5 dakikada bir). Yoksa
--      uygulama tetiği yedek olarak kalıyor — ikisi aynı freni paylaşır,
--      yani ikisi birden koşsa bile gövde 5 dakikada bir çalışır.
--   3) `bo_supurge_sagligi()` — "süpürge en son ne zaman koştu, kim
--      koşturdu, ŞU AN kaç satır birikmiş?" sorusunun tek cevabı.
--      Birikmiş satır sayısı asıl ölçüdür: süpürge hiç koşmazsa o sayı
--      büyür ve panelde kırmızı yanar.
--
-- 🆕 SINIF: "BİR BAKIM İŞİNİ FRENLEMEK YETMEZ — ONA BİR SAHİP VE BİR
-- SAĞLIK GÖSTERGESİ VERMEZSEN, 'HİÇ KOŞMUYOR' HALİ 'SORUNSUZ' HALİNDEN
-- AYIRT EDİLEMEZ."
--
-- ── BÖLÜM B · KREDİ YARIŞI ────────────────────────────────────────────
-- `create_request_impl_preflag` bakiyeyi şöyle okuyordu:
--     select sum(delta) into v_bal ...      -- kilitsiz
--     if v_bal < v_cost then raise ...      -- karar
--     insert into credit_ledger (... -v_cost ...)
--
-- Yukarıda `availabilities` satırı `for update` ile kilitleniyor; o kilit
-- AYNI İLANA giden iki isteği sıraya sokar. Ama bakiye ilana değil
-- KULLANICIYA aittir: FARKLI iki ilana aynı anda giden iki istek farklı
-- satırları kilitler, ikisi de aynı `v_bal`ı okur, ikisi de geçer.
-- 1 kredisi olan kullanıcı 2 istek açar, bakiye −1'e düşer ve sonraki
-- her işlem 'insufficient_credits' ile kilitlenir.
--
-- AYNI KUSUR ÜÇ YERDE DAHA VAR (ölçtüm):
--   · `respond_invite`  → credit_ledger, -1 'invite_hold'
--   · `redeem_reward`   → points_ledger, -cost_points
--   · `set_featured`    → points_ledger, -200
--
-- Ve iki defterin hiçbirinde bakiyeyi negatife karşı koruyan bir kısıt
-- yoktu (kısıtlar: yalnız PK + FK). Yani yarış hem geçiyor hem iz
-- bırakmıyordu. Bu dosya iki katman koyuyor: kullanıcı başına danışma
-- kilidi + defter üstünde tetikleyici.
--
-- 🆕 SINIF: "BİR KİLİT, KORUDUĞU DEĞERİN SAHİBİNE KONUR — İŞLEMİN
-- ÖZNESİNE DEĞİL. BAKİYE KULLANICININDIR, İLANIN DEĞİL."
--
-- ── BÖLÜM C · İADENİN DOĞRU TUTARI ────────────────────────────────────
-- 🔴 YENİ KUSUR 1 — DAVETLE AÇILAN İSTEK KAPIDA İADE ALAMIYOR.
-- `respond_invite` tutma satırını `'invite_hold'` adıyla yazıyor. Ama
-- iadeyi yapan üç yer de yalnız `'request_hold'` arıyor:
--     · `istek_kredisi_iade`        → bulamayınca "1 varsay" dalına düşer
--     · `trg_iade_tutulani_asamaz`  → bulamayınca "1 varsay" dalına düşer
--     · `kapida_giremedim`          → bulamayınca HİÇ İADE YAPMAZ  ← ❌
--
-- Yani: bir misafir daveti kabul etti, 1 kredi yandı, host kapıda
-- almadı → misafir "kapıda giremedim" dedi → kredisi İADE EDİLMEDİ ve
-- ekranda da hata çıkmadı. Sessiz kayıp.
--
-- 🔴 YENİ KUSUR 2 — İADE TUTARI SABİT `1` YAZILMIŞ.
-- `kapida_giremedim` ve `bayat_istekleri_iade_et` iade satırını `1` ile
-- yazıyor. Bedel 207'den beri MERTEBEDEN okunuyor
-- (`request_credit_cost`) ve 1'den büyük olabiliyor. 2 kredi tutulup
-- 1 kredi iade edilirse fark sessizce kullanıcının cebinden gider.
--
-- ⚪ ÜÇÜNCÜSÜ — "TUTMA KAYDI YOKSA 1 VARSAY" DALI ZAMANLA SINIRLANIYOR.
-- Bu dal geçmiş veri için doğruydu (seed/erken kayıtların defter satırı
-- yok — yerelde ölçtüm: 6 isteğin 6'sında da hiç defter satırı yok).
-- Ama bugünden sonra AÇILAN her istek mutlaka bir tutma satırı yazıyor
-- (`request_hold` / `request_free_tier` / `invite_hold`). Dolayısıyla
-- BUGÜNDEN SONRA tutma kaydı bulunamıyorsa bu "eski kayıt" değil,
-- "defter satırı silinmiş" demektir ve 1 kredi UYDURMAK yanlış cevaptır.
-- Eşik: isteğin `created_at`i. Eşikten eski → 1 varsay (eski davranış
-- aynen korunur). Eşikten yeni → 0 iade + `bo_defter_yetimleri()`ne düşer.
--
-- 🆕 SINIF: "BİR VARSAYILAN DEĞER GEÇMİŞ VERİYİ KURTARMAK İÇİN
-- KONULDUYSA, ONA BİR SON TARİH KOY — YOKSA GELECEKTEKİ HER BOZULMAYI
-- DA SESSİZCE 'DÜZELTİR'."
--
-- ── DÜRÜST DÜZELTME ───────────────────────────────────────────────────
-- Önceki teslimde "2 adet `no_show_refund` satırı yoktan basılmış kredi"
-- demiştim. Yeniden ölçtüm ve BU İFADE YANLIŞTI. `istek_kredisi_iade`
-- şöyle başlıyor:
--     select * into v_r from requests where id = p_req;
--     if not found then return 0;
-- Yani o satırlar yazıldıkları anda isteği VARDI ve meşrudurlar. Şu an
-- yetim görünmelerinin sebebi, işaret ettikleri isteğin SONRADAN
-- silinmiş olması (büyük olasılıkla 297'nin kapattığı `flow_test_cleanup`
-- ya da yerel seed tazelemesi). Dolayısıyla o 2 krediyi GERİ ALMIYORUM —
-- geri almak, meşru bir iadeyi cezaya çevirmek olurdu.
-- Onun yerine bu dosya yetimi GÖRÜNÜR yapıyor: `bo_defter_yetimleri()`.
--
-- 🆕 SINIF: "BİR SAYININ AÇIKLANAMAMASI, ONUN HAKSIZ OLDUĞUNU
-- KANITLAMAZ. ÖNCE YAZILDIĞI ANI YENİDEN KUR — SONRA KARAR VER."
--
-- Tekrar koşulabilir. 298'den sonra koşulmalı.
-- ════════════════════════════════════════════════════════════════════════

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ BÖLÜM 0 · TUTULAN KREDİNİN TEK KAYNAĞI                              ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Bu üç fonksiyon dosyanın EN BAŞINDA duruyor çünkü A, B ve C bölümleri
-- de bunları çağırıyor. "Ne kadar tutuldu?" sorusunun BEŞ ayrı yerde
-- BEŞ ayrı cevabı vardı ve biri (`invite_hold`) hiçbirinde yoktu.

-- Tutma adlarının TEK KAYNAĞI.
create or replace function public.tutma_sebepleri()
returns text[]
language sql
immutable
as $function$
  select array['request_hold', 'invite_hold', 'request_free_tier']::text[]
$function$;

-- Eşik: bu tarihten SONRA açılan istekte tutma kaydı yoksa "1 varsay"
-- dalı KAPALIDIR. Eşikten eski istekler eski davranışı aynen korur.
create or replace function public.tutma_varsayim_esigi()
returns timestamptz
language sql
immutable
as $function$
  select timestamptz '2026-09-19 00:00:00+03'
$function$;

-- BİR İSTEK İÇİN GERÇEKTEN TUTULAN KREDİ.
--
-- 🔴 NEDEN FONKSİYON — beş yerde beş ayrı kopya vardı:
--   `istek_kredisi_iade`, `trg_iade_tutulani_asamaz`, `kapida_giremedim`,
--   `bayat_istekleri_iade_et`, `expire_stale_sessions`. İkisi sabit `1`
--   yazıyordu, üçü `request_hold` arıyordu, hiçbiri `invite_hold`u
--   tanımıyordu. Bir kuralın beş kopyası, beş farklı kuraldır.
--
-- ⚠️ `request_free_tier` (delta 0) BİLEREK listede: bedelsiz istekte
-- tutulan 0'dır ve iade de 0 olmalıdır — kayıt YOK sayılırsa "varsay"
-- dalına düşer ve olmayan bir kredi iade edilir (bu hata bir kez yaşandı).
create or replace function public.tutulan_kredi(p_req uuid)
returns int
language plpgsql
stable
set search_path to 'public'
as $function$
declare v_tut int; v_olusum timestamptz;
begin
  select -min(delta) into v_tut
    from credit_ledger
   where ref_id = p_req and reason = any (public.tutma_sebepleri());
  if v_tut is not null then return greatest(0, v_tut); end if;

  -- Tutma kaydı yok. Eşikten ESKİ istek → geçmiş veri, 1 varsayılır
  -- (eski davranış aynen korunur). Eşikten YENİ istek → her istek
  -- mutlaka tutma satırı yazıyor; yoksa defter satırı SİLİNMİŞ demektir
  -- ve 1 kredi UYDURMAK yanlış cevaptır.
  select created_at into v_olusum from requests where id = p_req;
  if v_olusum is null or v_olusum < public.tutma_varsayim_esigi() then
    return 1;
  end if;
  return 0;
end $function$;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ BÖLÜM A · SÜPÜRGENİN SAHİBİ                                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- A1 · Damga defteri genişliyor: artık yalnız "ne zaman" değil
--      "kim / ne oldu / hata aldı mı" da yazılıyor.
alter table public.supurge_damgasi add column if not exists kaynak       text;
alter table public.supurge_damgasi add column if not exists son_sonuc    jsonb;
alter table public.supurge_damgasi add column if not exists ardisik_hata int not null default 0;
alter table public.supurge_damgasi add column if not exists son_hata     text;
alter table public.supurge_damgasi add column if not exists son_hata_an  timestamptz;

-- A2 · Süpürge: imzaya `p_kaynak` geliyor.
--
-- ⚠️ ÖNCE DROP: `create or replace` yeni parametreli bir AŞIRI YÜK
-- yaratır, eskisini SİLMEZ. İki tanım yan yana kalırsa hangisinin
-- koştuğu çağrının şekline bağlı olur — bu, sessiz sapmanın tarifidir.
-- Varsayılan değer sayesinde `rpc('expire_stale_sessions')` (argümansız)
-- İSTEMCİDE AYNEN ÇALIŞMAYA DEVAM EDER; App.js'te değişiklik gerekmez.
drop function if exists public.expire_stale_sessions();

create or replace function public.expire_stale_sessions(p_kaynak text default 'uygulama')
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_req int := 0; v_sess int := 0;
  v_son timestamptz;
  v_sonuc jsonb;
begin
  -- ── FREN (298) ────────────────────────────────────────────────────
  -- `for update` ile alıyoruz: iki istemci aynı anda çağırırsa ikincisi
  -- birincinin damgasını bekler ve "atlandi" döner. pg_cron ile uygulama
  -- tetiği AYNI FRENİ paylaşır — ikisi birden açık olsa bile gövde
  -- 5 dakikada bir koşar.
  select son_kosum into v_son from public.supurge_damgasi
   where ad = 'expire_stale_sessions' for update;

  if v_son is not null and v_son > now() - interval '5 minutes' then
    return jsonb_build_object('ok', true, 'durum', 'atlandi',
                              'kaynak', p_kaynak,
                              'sonraki', v_son + interval '5 minutes');
  end if;

  insert into public.supurge_damgasi (ad, son_kosum, kaynak)
  values ('expire_stale_sessions', now(), p_kaynak)
  on conflict (ad) do update set son_kosum = now(), kaynak = excluded.kaynak;

  -- ── GÖVDE ─────────────────────────────────────────────────────────
  --
  -- 🔴🔴 299/A2 — 298'DE KENDİ DÜŞÜRDÜĞÜM DÖRT ADIM GERİ KONULDU.
  --
  -- 298'de bu fonksiyonun başına freni takarken gövdeyi de yeniden
  -- yazdım ve 292'nin gövdesindeki DÖRT ADIMI düşürdüm. `drift_check.py`
  -- ikisini gösterdi (`perform public…`), kalan ikisini ben okuyarak
  -- buldum. Düşenler:
  --
  --   1) (b) bloğundaki `r.status = 'accepted'` KAPISI.
  --      280/K2'nin koyduğu kapı: iptal edilmiş isteğin yetim oturumu
  --      no_show DEĞİLDİR. Düşünce, iptal edilmiş bir isteğin arkasında
  --      kalan oturum yüzünden masum bir tarafa no_show yazılıyordu.
  --
  --   2) `perform public.recompute_trust(u) …`
  --      no_show işaretlenen tarafın güven puanı tazelenmiyordu. Yani
  --      ceza yazılıyor ama puana yansımıyordu.
  --
  --   3) (c) BLOĞUNUN TAMAMI — 187-noshow'un kapattığı hata.
  --      (b) oturumu 'expired' yapıyor ama isteği 'accepted' BIRAKIYOR.
  --      Bloksuz hali: misafirin kredisi sonsuza kilitli, host'un slotu
  --      sonsuza dolu (`sync_availability_filled` filled'ı accepted
  --      sayısından türetiyor). TEK BİR NO-SHOW İLANI KALICI OLARAK
  --      ÖLDÜRÜYORDU. 298 bunu geri getirmişti.
  --
  --   4) `perform public.tek_tarafli_oturumlari_kapat();`
  --
  -- 🆕 SINIF: "BİR FONKSİYONUN BAŞINA KAPI TAKARKEN GÖVDESİNİ YENİDEN
  -- YAZMA — ELDEKİ TANIMIN ÜSTÜNE EKLE. YENİDEN YAZMAK, GÖRMEDİĞİN HER
  -- ESKİ DÜZELTMEYİ SESSİZCE GERİ ALIR."
  --
  -- (a) Hiç başlatılmamış kabuller: kimse gelmedi ya da unutuldu →
  --     cezasız kapanış + kredi iadesi.
  --     🔴 İade tutarı artık sabit 1 değil: GERÇEKTEN TUTULAN kadar.
  with stale as (
    select r.id, r.guest_id
      from requests r
      join availabilities a on a.id = r.avail_id
      left join sessions s on s.request_id = r.id
     where r.status = 'accepted' and s.id is null
       and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours'
  ), upd as (
    update requests set status = 'cancelled' where id in (select id from stale) returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select u.guest_id, public.tutulan_kredi(u.id), 'expired_refund', u.id,
         coalesce((select sum(delta) from credit_ledger c where c.user_id = u.guest_id), 0)
           + public.tutulan_kredi(u.id)
    from upd u;
  get diagnostics v_req = row_count;

  -- (b) Tek taraf başlatmış ama diğeri hiç gelmemiş → 'expired'.
  --     `r.status = 'accepted'` KAPISI 280/K2'den; 299'da geri kondu.
  update sessions s
     set status = 'expired',
         completed_at = now(),
         cancel_reason = 'no_show',
         no_show_user_id = case when s.host_started_at is null then r.host_id else r.guest_id end
    from requests r, availabilities a
   where r.id = s.request_id and a.id = r.avail_id
     and s.status = 'pending'
     and r.status = 'accepted'
     and (s.host_started_at is null) <> (s.guest_started_at is null)
     and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours';
  get diagnostics v_sess = row_count;

  -- Etkilenenlerin güvenini tazele (292'den; 298'de düşmüştü).
  perform public.recompute_trust(u) from (
    select distinct no_show_user_id as u from sessions
     where cancel_reason = 'no_show' and no_show_user_id is not null
       and completed_at > now() - interval '1 day'
  ) x where u is not null;

  -- (c) 187-noshow · 298'de TAMAMEN DÜŞMÜŞTÜ, geri konuldu.
  --     (b) oturumu kapatır ama isteği 'accepted' bırakır; burada istek
  --     de kapanır ve kredi iade edilir. Yoksa kredi de slot da sonsuza
  --     kilitli kalır.
  with kapanan as (
    select r.id, r.guest_id
      from requests r
      join sessions s2 on s2.request_id = r.id
     where r.status = 'accepted'
       and s2.status = 'expired'
       and s2.cancel_reason = 'no_show'
  ), iade as (
    update requests set status = 'cancelled'
     where id in (select id from kapanan)
    returning id, guest_id
  )
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  select i.guest_id, public.tutulan_kredi(i.id), 'no_show_refund', i.id,
         coalesce((select sum(c.delta) from credit_ledger c
                    where c.user_id = i.guest_id), 0) + public.tutulan_kredi(i.id)
    from iade i
   where not exists (select 1 from credit_ledger c2
                      where c2.ref_id = i.id and c2.reason = 'no_show_refund');

  perform public.tek_tarafli_oturumlari_kapat();

  v_sonuc := jsonb_build_object('ok', true, 'durum', 'kosuldu',
                                'kaynak', p_kaynak,
                                'iptal_edilen', v_req, 'suresi_dolan', v_sess);

  -- Sonucu damgaya yaz: panelde "en son koşum NE YAPTI" görünsün.
  update public.supurge_damgasi
     set son_sonuc = v_sonuc, ardisik_hata = 0
   where ad = 'expire_stale_sessions';

  return v_sonuc;
exception
  when others then
    -- ⚠️ BURADA `update` DEĞİL `insert … on conflict` KULLANILIYOR VE
    -- BUNUN SEBEBİ ÖNEMLİ: plpgsql'de bir istisna, bloğun BAŞINDAN
    -- itibaren her şeyi geri alır — yukarıdaki damga `insert`i DAHİL.
    -- Yani handler'a girildiğinde satır ARTIK YOKTUR; `update` 0 satır
    -- günceller ve hata izi sessizce kaybolur. Tam da görünür kılmaya
    -- çalıştığımız şeyi kaybederdik.
    --
    -- 🆕 SINIF: "BİR HATA KAYDINI, HATANIN GERİ ALDIĞI SATIRIN ÜSTÜNE
    -- YAZAMAZSIN — HANDLER'DA HER ZAMAN YENİDEN OLUŞTURMAYA HAZIR OL."
    --
    -- Hatayı istisna olarak ATMIYORUZ, jsonb olarak DÖNÜYORUZ: çağıran
    -- `ok=false` görür, damga kalıcı olur ve `bo_supurge_sagligi()`
    -- onu gösterir. Yutmak değil — yerini değiştirmek.
    insert into public.supurge_damgasi (ad, son_kosum, kaynak, ardisik_hata, son_hata, son_hata_an)
    values ('expire_stale_sessions', coalesce(v_son, now() - interval '1 hour'),
            p_kaynak, 1, left(SQLERRM, 400), now())
    on conflict (ad) do update
      set ardisik_hata = public.supurge_damgasi.ardisik_hata + 1,
          kaynak       = excluded.kaynak,
          son_hata     = excluded.son_hata,
          son_hata_an  = excluded.son_hata_an;
    return jsonb_build_object('ok', false, 'durum', 'hata',
                              'kaynak', p_kaynak, 'hata', left(SQLERRM, 400));
end $function$;

revoke all on function public.expire_stale_sessions(text) from public;
revoke execute on function public.expire_stale_sessions(text) from anon;
grant  execute on function public.expire_stale_sessions(text) to authenticated, service_role;

-- A3 · pg_cron VARSA işi ona ver.
--
-- Yerelde ölçtüm: `pg_available_extensions` içinde `pg_cron` YOK (0 satır),
-- yani bu blok yerelde sessizce atlanır. Supabase'te vardır; orada
-- kurulur ve iş 5 dakikada bir koşar. Her iki halde de uygulama tetiği
-- yedek olarak durmaya devam eder — freni paylaştıkları için çifte
-- koşma riski yoktur.
-- ⚠️ ÖLÇÜM `pg_extension` ÜZERİNDEN — `to_regclass('cron.job')` ÜZERİNDEN
-- DEĞİL. Yerelde ölçtüm: bu replikada `cron` şeması ve `cron.job` tablosu
-- VAR ama `pg_cron` uzantısı KURULU DEĞİL (pg_available_extensions: 0).
-- Yani "tablo duruyor" ile "zamanlayıcı çalışıyor" AYNI ŞEY DEĞİL —
-- tabloya bakan bir gösterge bana yeşil yanardı ve yalan söylerdi.
--
-- 🆕 SINIF: "BİR YETENEĞİN VARLIĞINI, O YETENEĞİN BIRAKTIĞI İZDEN DEĞİL
-- KENDİ KAYDINDAN ÖLÇ — İZ, YETENEK GİTTİKTEN SONRA DA DURUR."
--
-- 226 aynı deseni zaten kurmuş (unschedule → schedule). Onu izliyoruz.
do $$
declare v_var boolean;
begin
  select exists (select 1 from pg_extension where extname = 'pg_cron') into v_var;
  if not v_var then
    select exists (select 1 from pg_available_extensions where name = 'pg_cron') into v_var;
    if v_var then
      begin
        execute 'create extension if not exists pg_cron';
        v_var := true;
      exception when others then
        raise notice '299/A3: pg_cron kurulamadi (%) — uygulama tetigi yedekte kaliyor.', SQLERRM;
        v_var := false;
      end;
    end if;
  end if;

  if not v_var then
    raise notice '299/A3: pg_cron bu sunucuda YOK — supurge uygulama tetigiyle kosmaya devam edecek.';
    return;
  end if;

  begin
    if exists (select 1 from cron.job where jobname = 'll-supurge') then
      perform cron.unschedule('ll-supurge');
    end if;
    perform cron.schedule('ll-supurge', '*/5 * * * *',
                          'select public.expire_stale_sessions(''pg_cron'')');
    raise notice '299/A3: pg_cron isi kuruldu — ll-supurge, 5 dakikada bir.';
  exception when others then
    raise notice '299/A3: pg_cron isi planlanamadi (%) — uygulama tetigi yedekte kaliyor.', SQLERRM;
  end;
end $$;

-- A4 · SAĞLIK GÖSTERGESİ.
--
-- Asıl ölçü "en son ne zaman koştu" değil, "ŞU AN kaç satır birikmiş".
-- Süpürge hiç koşmazsa o sayı büyür; koşuyorsa 0'a yakın durur.
-- Zaman bilgisi yalnız sebebi söyler, belirtiyi değil.
create or replace function public.bo_supurge_sagligi()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_d       record;
  v_bekleyen_istek int;
  v_bekleyen_otrm  int;
  v_cron_var boolean := false;
  v_cron_is  jsonb   := null;
  v_durum    text;
  v_gecen    interval;
begin
  select * into v_d from public.supurge_damgasi where ad = 'expire_stale_sessions';

  -- ŞU AN süpürülmeyi bekleyen satırlar (gövdenin iki dalıyla birebir
  -- aynı koşullar — biri değişirse buranın da değişmesi gerekir).
  select count(*) into v_bekleyen_istek
    from requests r
    join availabilities a on a.id = r.avail_id
    left join sessions s on s.request_id = r.id
   where r.status = 'accepted' and s.id is null
     and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours';

  select count(*) into v_bekleyen_otrm
    from sessions s
    join requests r on r.id = s.request_id
    join availabilities a on a.id = r.avail_id
   where s.status = 'pending'
     and (s.host_started_at is null) <> (s.guest_started_at is null)
     and public.yerel_an(a.avail_date, a.time_to, a.airport_code) < now() - interval '2 hours';

  -- pg_cron canlı ölçülüyor — saklanan bir bayrağa güvenmiyoruz.
  -- ⚠️ `to_regclass('cron.job')` DEĞİL `pg_extension`: yerel replikada
  -- `cron.job` tablosu duruyor ama uzantı kurulu değil. Tabloya bakan
  -- bir gösterge yeşil yanar ve yalan söyler.
  select exists (select 1 from pg_extension where extname = 'pg_cron') into v_cron_var;
  if v_cron_var and to_regclass('cron.job') is not null then
    begin
      execute $q$ select jsonb_agg(jsonb_build_object('ad', jobname, 'plan', schedule, 'aktif', active))
                    from cron.job where jobname = 'll-supurge' $q$ into v_cron_is;
    exception when others then v_cron_is := null;
    end;
  end if;

  v_gecen := case when v_d.son_kosum is null then null else now() - v_d.son_kosum end;

  v_durum := case
    when v_d.son_kosum is null                       then 'hic_kosmadi'
    when coalesce(v_d.ardisik_hata,0) > 0            then 'hata_aliyor'
    when v_gecen > interval '30 minutes'
         and (v_bekleyen_istek + v_bekleyen_otrm) > 0 then 'gecikmis_ve_birikmis'
    when v_gecen > interval '30 minutes'             then 'gecikmis'
    else 'saglikli'
  end;

  return jsonb_build_object(
    'durum',            v_durum,
    'son_kosum',        v_d.son_kosum,
    'gecen_saniye',     case when v_gecen is null then null else extract(epoch from v_gecen)::int end,
    'kaynak',           v_d.kaynak,
    'son_sonuc',        v_d.son_sonuc,
    'ardisik_hata',     coalesce(v_d.ardisik_hata, 0),
    'son_hata',         v_d.son_hata,
    'son_hata_an',      v_d.son_hata_an,
    'bekleyen_istek',   v_bekleyen_istek,
    'bekleyen_oturum',  v_bekleyen_otrm,
    'pg_cron_var',      v_cron_var,
    'pg_cron_isi',      v_cron_is,
    -- Süpürgeyi ŞU AN kim koşturuyor? Yanıt "hiç kimse" olamaz: pg_cron
    -- yoksa uygulama tetiği yedektedir ve panelde öyle yazar.
    'zamanlayici',      case when v_cron_is is not null then 'pg_cron'
                             else 'uygulama_tetigi' end
  );
end $function$;

revoke all    on function public.bo_supurge_sagligi() from public;
revoke execute on function public.bo_supurge_sagligi() from anon, authenticated;
grant  execute on function public.bo_supurge_sagligi() to service_role;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ BÖLÜM B · KREDİ YARIŞI — İKİ KATMAN                                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- B1 · KATMAN 2 ÖNCE KURULUYOR (defter tetikleyicisi).
--
-- Neden önce? Çünkü katman 1 (kilit) yalnız BİLDİĞİM yolları korur.
-- Tetikleyici HER yolu korur — bugün yazılmamış olanı da. Bir değişmezi
-- yalnız onu ihlal edebilecek koda emanet etmek, değişmez yazmamaktır.
--
-- ⚠️ MUAFİYETLER — ölçerek belirlendi, keyfi değil:
--   · `paid_guest_thanks_reversal:%` → K3 geri alması. Misafir teşekkür
--     kredisini ALDI ve HARCADI; oturum sonradan iptal olunca geri
--     alınır. Bu, bakiyeyi eksiye düşürebilir ve DÜŞÜRMELİDİR — aksi
--     halde harcanmış bir krediyi geri alamayız ve kayıp hosta kalır.
--   · `admin%` → yönetici düzeltmesi. Yanlışlıkla verilmiş krediyi geri
--     almak, harcanmış olsa bile mümkün olmalı.
-- Bunların dışındaki her negatif satır HARCAMADIR ve bakiyeyi
-- eksiye düşüremez.
create or replace function public.trg_bakiye_negatife_dusemez()
returns trigger
language plpgsql
as $function$
declare v_bal int;
begin
  if new.delta >= 0 then return new; end if;
  if new.reason like 'paid_guest_thanks_reversal:%' or new.reason like 'admin%' then
    return new;
  end if;

  select coalesce(sum(delta), 0) into v_bal
    from credit_ledger where user_id = new.user_id;

  if v_bal + new.delta < 0 then
    raise exception 'insufficient_credits'
      using detail = format('kullanici %s: bakiye %s, denenen %s (%s)',
                            new.user_id, v_bal, new.delta, new.reason),
            hint   = 'Bu satir bakiyeyi negatife dusururdu; 299/B1 reddetti.';
  end if;
  return new;
end $function$;

drop trigger if exists trg_bakiye_negatife_dusemez on public.credit_ledger;
create trigger trg_bakiye_negatife_dusemez
  before insert on public.credit_ledger
  for each row execute function public.trg_bakiye_negatife_dusemez();

-- Aynı değişmez PUAN defteri için de geçerli: `redeem_reward` ve
-- `set_featured` puanı da kilitsiz okuyup kilitsiz harcıyor.
create or replace function public.trg_puan_negatife_dusemez()
returns trigger
language plpgsql
as $function$
declare v_pts int;
begin
  if new.delta >= 0 then return new; end if;
  if new.reason like 'admin%' then return new; end if;

  select coalesce(sum(delta), 0) into v_pts
    from points_ledger where user_id = new.user_id;

  if v_pts + new.delta < 0 then
    raise exception 'insufficient_points'
      using detail = format('kullanici %s: puan %s, denenen %s (%s)',
                            new.user_id, v_pts, new.delta, new.reason);
  end if;
  return new;
end $function$;

drop trigger if exists trg_puan_negatife_dusemez on public.points_ledger;
create trigger trg_puan_negatife_dusemez
  before insert on public.points_ledger
  for each row execute function public.trg_puan_negatife_dusemez();

-- B2 · KATMAN 1 — kullanıcı başına danışma kilidi, DÖRT YOLA.
--
-- Tablo satırı kilitlemiyoruz çünkü kilitlenecek bir "bakiye satırı"
-- yok: bakiye bir TOPLAM. `pg_advisory_xact_lock` işlem bitince kendi
-- kendine bırakılır — `unlock` unutma riski yoktur.
--
-- ⚠️ KİLİT ANAHTARLARI AYRI: kredi için 'kredi:<uid>', puan için
-- 'puan:<uid>'. Aynı anahtarı paylaşsalardı puan harcayan bir işlem
-- kredi harcayan bir işlemi gereksiz yere bekletirdi.
--
-- Tanımı ELDEN yazmıyoruz: `pg_get_functiondef` ile MEVCUT gövdeyi alıp
-- tek bir çapa metnini değiştiriyoruz. Çapa bulunamazsa migration
-- PATLAR — sessizce "hiçbir şey yapmadım" demez.
do $$
declare
  v_def text; v_yeni text; v_capa text; v_ek text;
begin
  -- ── create_request_impl_preflag ─────────────────────────────────────
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_request_impl_preflag';
  if v_def is null then raise exception '299/B2: create_request_impl_preflag bulunamadi'; end if;

  v_capa := 'select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;';
  v_ek   := '-- 299/B2: bakiye ARTIK KILITLI okunuyor (kullanici basina).' || E'\n  '
         || 'perform pg_advisory_xact_lock(hashtextextended(''kredi:'' || v_uid::text, 0));' || E'\n  '
         || v_capa;

  if position(v_capa in v_def) = 0 then
    raise exception '299/B2: create_request_impl_preflag icinde bakiye okuma capasi bulunamadi';
  end if;
  if position('pg_advisory_xact_lock' in v_def) > 0 then
    raise notice '299/B2: create_request_impl_preflag zaten kilitli — atlandi.';
  else
    v_yeni := replace(v_def, v_capa, v_ek);
    execute v_yeni;
    raise notice '299/B2: create_request_impl_preflag kilitlendi.';
  end if;

  -- ── respond_invite ──────────────────────────────────────────────────
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'respond_invite';
  if v_def is null then raise exception '299/B2: respond_invite bulunamadi'; end if;

  v_capa := 'select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;';
  v_ek   := '-- 299/B2: davet kabulu de bakiye harciyor — ayni kilit.' || E'\n        '
         || 'perform pg_advisory_xact_lock(hashtextextended(''kredi:'' || v_uid::text, 0));' || E'\n        '
         || v_capa;

  if position(v_capa in v_def) = 0 then
    raise exception '299/B2: respond_invite icinde bakiye okuma capasi bulunamadi';
  end if;
  if position('pg_advisory_xact_lock' in v_def) > 0 then
    raise notice '299/B2: respond_invite zaten kilitli — atlandi.';
  else
    execute replace(v_def, v_capa, v_ek);
    raise notice '299/B2: respond_invite kilitlendi.';
  end if;

  -- ── redeem_reward (puan) ────────────────────────────────────────────
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'redeem_reward';
  if v_def is not null and position('pg_advisory_xact_lock' in v_def) = 0 then
    v_capa := 'from points_ledger where user_id = v_uid;';
    if position(v_capa in v_def) = 0 then
      raise exception '299/B2: redeem_reward icinde puan okuma capasi bulunamadi';
    end if;
    v_ek := v_capa || E'\n  '
         || '-- 299/B2: puan da kilitli okunuyor.' || E'\n  '
         || 'perform pg_advisory_xact_lock(hashtextextended(''puan:'' || v_uid::text, 0));';
    execute replace(v_def, v_capa, v_ek);
    raise notice '299/B2: redeem_reward kilitlendi.';
  end if;

  -- ── set_featured (puan) ─────────────────────────────────────────────
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'set_featured';
  if v_def is not null and position('pg_advisory_xact_lock' in v_def) = 0 then
    v_capa := 'from points_ledger where user_id = v_uid;';
    if position(v_capa in v_def) = 0 then
      raise exception '299/B2: set_featured icinde puan okuma capasi bulunamadi';
    end if;
    v_ek := v_capa || E'\n    '
         || '-- 299/B2: puan da kilitli okunuyor.' || E'\n    '
         || 'perform pg_advisory_xact_lock(hashtextextended(''puan:'' || v_uid::text, 0));';
    execute replace(v_def, v_capa, v_ek);
    raise notice '299/B2: set_featured kilitlendi.';
  end if;
end $$;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ BÖLÜM C · İADENİN DOĞRU TUTARI                                      ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- C1 · `istek_kredisi_iade` — invite_hold tanınıyor, varsayım zamana bağlandı.
create or replace function public.istek_kredisi_iade(p_req uuid, p_reason text, p_ref uuid default null::uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_r      requests%rowtype;
  v_tutulan int;
  v_bal    int;
  v_thanks record;
  v_iade   int := 0;
begin
  select * into v_r from requests where id = p_req;
  if not found then return 0; end if;

  -- İDEMPOTENT: bu istek için herhangi bir iade zaten yazılmışsa DUR.
  if exists (select 1 from credit_ledger
              where ref_id = p_req
                and reason in ('request_refund','request_cancel_refund',
                               'session_cancel_refund','expired_refund',
                               'no_show_refund','request_stale_refund',
                               'kapida_ret_iade','dispute_refund')) then
    return 0;
  end if;

  -- Ne tutulduysa o iade edilir — tek kaynaktan (Bölüm 0).
  -- Tutma kaydı ÜÇ ADLA yazılıyor: `request_hold` (bedel>0),
  -- `request_free_tier` (bedel 0) ve 🔴 `invite_hold` (davet kabulü) —
  -- sonuncusu 299'a kadar hiçbir iade yolunda tanınmıyordu.
  v_tutulan := public.tutulan_kredi(p_req);

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_r.guest_id;

  if v_tutulan > 0 then
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
    values (v_r.guest_id, v_tutulan, p_reason, coalesce(p_ref, p_req), v_bal + v_tutulan);
    v_iade := v_tutulan;
  else
    -- Bedel 0'dı (ya da tutma kaydı yok): iade YOK ama iz bırak —
    -- idempotency bu satıra bakıyor ve "0 iade edildi" de bir karardır.
    insert into credit_ledger (user_id, delta, reason, ref_id, balance_after, note)
    values (v_r.guest_id, 0, p_reason, coalesce(p_ref, p_req), v_bal,
            case when v_r.created_at >= public.tutma_varsayim_esigi()
                 then 'Tutma kaydi bulunamadi — iade 0 yazildi (299/C).' end);
  end if;

  -- K3 · ücretli misafir teşekkür kredisi geri alınır (varsa, bir kez)
  for v_thanks in
    select * from credit_ledger
     where reason = 'paid_guest_thanks:' || p_req::text
  loop
    if not exists (select 1 from credit_ledger
                    where reason = 'paid_guest_thanks_reversal:' || p_req::text
                      and user_id = v_thanks.user_id) then
      select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_thanks.user_id;
      insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
      values (v_thanks.user_id, -v_thanks.delta,
              'paid_guest_thanks_reversal:' || p_req::text, p_req, v_bal - v_thanks.delta);
    end if;
  end loop;

  return v_iade;
end $function$;

-- C2 · `trg_iade_tutulani_asamaz` — aynı iki düzeltme.
create or replace function public.trg_iade_tutulani_asamaz()
returns trigger
language plpgsql
as $function$
declare v_tutulan int; v_iade int; v_req uuid;
begin
  if new.delta <= 0 or new.ref_id is null then return new; end if;
  if new.reason not in ('request_refund','request_cancel_refund','session_cancel_refund',
                        'expired_refund','no_show_refund','request_stale_refund',
                        'kapida_ret_iade','dispute_refund') then
    return new;
  end if;

  -- ref_id istek mi oturum mu? Oturumsa isteğe çevir.
  v_req := coalesce((select request_id from sessions where id = new.ref_id), new.ref_id);

  -- Tek kaynak (Bölüm 0). `ref_id` oturum kimliği de olabildiği için
  -- önce isteğe çevirdik; tutma satırı HER ZAMAN isteğe yazılır.
  v_tutulan := public.tutulan_kredi(v_req);

  select coalesce(sum(delta),0) into v_iade
    from credit_ledger
   where delta > 0
     and reason in ('request_refund','request_cancel_refund','session_cancel_refund',
                    'expired_refund','no_show_refund','request_stale_refund',
                    'kapida_ret_iade','dispute_refund')
     and ref_id in (new.ref_id, v_req,
                    (select id from sessions where request_id = new.ref_id));

  if v_iade + new.delta > v_tutulan then
    raise exception 'refund_exceeds_hold'
      using detail = format('istek/oturum %s: tutulan %s, iade edilmis %s, denenen +%s',
                            new.ref_id, v_tutulan, v_iade, new.delta);
  end if;
  return new;
end $function$;

-- C3 · `kapida_giremedim` ve `bayat_istekleri_iade_et` — iki düzeltme:
--      (a) `invite_hold` da tutma sayılıyor,
--      (b) iade tutarı SABİT 1 değil, GERÇEKTEN TUTULAN kadar.
do $$
declare v_def text; v_yeni text; v_capa text; v_ek text; v_n int;
begin
  -- ── kapida_giremedim ────────────────────────────────────────────────
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'kapida_giremedim';
  if v_def is null then raise exception '299/C3: kapida_giremedim bulunamadi'; end if;
  v_yeni := v_def;

  -- Tekrar koşulabilirlik: zaten uygulanmışsa çapa yoktur ve bu bir HATA
  -- DEĞİLDİR. Ama "çapa yok" ile "zaten uygulanmış" ayrı ayrı ölçülmeli —
  -- ikisini aynı sessiz dala koymak, bozulmayı başarı gibi gösterir.
  if position('tutma_sebepleri' in v_def) > 0 then
    raise notice '299/C3: kapida_giremedim zaten duzeltilmis — atlandi.';
  else

  -- (a) tutma adı listesi
  v_capa := 'where cl.ref_id = v_req.id and cl.reason = ''request_hold'' and cl.delta < 0';
  if position(v_capa in v_yeni) = 0 then
    raise exception '299/C3: kapida_giremedim tutma capasi bulunamadi';
  end if;
  v_yeni := replace(v_yeni, v_capa,
    'where cl.ref_id = v_req.id and cl.reason = any (public.tutma_sebepleri()) and cl.delta < 0');

  -- (b) sabit 1 → gerçekten tutulan
  v_capa := 'values (v_req.guest_id, 1, ''kapida_ret_iade'', v_req.id, v_bal + 1,';
  if position(v_capa in v_yeni) = 0 then
    raise exception '299/C3: kapida_giremedim iade tutari capasi bulunamadi';
  end if;
  v_ek :=
    'values (v_req.guest_id, public.tutulan_kredi(v_req.id), ''kapida_ret_iade'', v_req.id,' || E'\n'
 || '            v_bal + public.tutulan_kredi(v_req.id),';
  v_yeni := replace(v_yeni, v_capa, v_ek);

  if v_yeni = v_def then raise exception '299/C3: kapida_giremedim degismedi'; end if;
  execute v_yeni;
  raise notice '299/C3: kapida_giremedim duzeltildi.';
  end if;

  -- ── bayat_istekleri_iade_et ─────────────────────────────────────────
  -- Bu yol yalnız `pending` istekleri kapatır; davetle açılan istek
  -- `accepted` doğar, yani (a) düzeltmesi burada DAVRANIŞ DEĞİŞTİRMEZ.
  -- Yine de listeyi tek kaynağa bağlıyoruz: iki liste = iki gerçek.
  -- (b) düzeltmesi burada GERÇEKTEN gerekli — bedel 2 olabiliyor.
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'bayat_istekleri_iade_et';
  if v_def is null then raise exception '299/C3: bayat_istekleri_iade_et bulunamadi'; end if;
  v_yeni := v_def;

  if position('invite_hold' in v_def) > 0 then
    raise notice '299/C3: bayat_istekleri_iade_et zaten duzeltilmis — atlandi.';
  else

  v_capa := 'where cl.ref_id = r.id and cl.reason = ''request_hold'' and cl.delta < 0';
  if position(v_capa in v_yeni) = 0 then
    raise exception '299/C3: bayat tutma capasi bulunamadi';
  end if;
  -- ⚠️ BURADA `request_free_tier` KASITLA DIŞARIDA: harcanmayan kredi
  -- iade edilmez. Bu yüzden `tutma_sebepleri()` DEĞİL, elle iki ad.
  v_yeni := replace(v_yeni, v_capa,
    'where cl.ref_id = r.id and cl.reason in (''request_hold'',''invite_hold'') and cl.delta < 0');

  v_capa := 'values (r.guest_id, 1, ''request_stale_refund'', r.id, v_bal + 1,';
  if position(v_capa in v_yeni) = 0 then
    raise exception '299/C3: bayat iade tutari capasi bulunamadi';
  end if;
  v_ek :=
    'values (r.guest_id, public.tutulan_kredi(r.id), ''request_stale_refund'', r.id,' || E'\n'
 || '                v_bal + public.tutulan_kredi(r.id),';
  v_yeni := replace(v_yeni, v_capa, v_ek);

  if v_yeni = v_def then raise exception '299/C3: bayat_istekleri_iade_et degismedi'; end if;
  execute v_yeni;
  raise notice '299/C3: bayat_istekleri_iade_et duzeltildi.';
  end if;

  select count(*) into v_n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname in ('kapida_giremedim','bayat_istekleri_iade_et')
     and p.prosrc like '%tutma_sebepleri%invite_hold%' escape '~';
end $$;

-- C4 · YETİM DEFTER SATIRLARI — görünür oluyor.
--
-- "Yoktan basılmış kredi" değil, "işaret ettiği satır sonradan silinmiş
-- kredi". Aradaki fark önemli: birincisi bir hata, ikincisi bir iz.
-- Panelde görünmesi gereken de bu iz.
create or replace function public.bo_defter_yetimleri()
returns table (
  defter     text,
  satir_id   uuid,
  user_id    uuid,
  delta      int,
  reason     text,
  ref_id     uuid,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select 'credit'::text, c.id, c.user_id, c.delta, c.reason, c.ref_id, c.created_at
    from credit_ledger c
   where c.ref_id is not null
     and not exists (select 1 from requests      r where r.id = c.ref_id)
     and not exists (select 1 from sessions      s where s.id = c.ref_id)
     and not exists (select 1 from availabilities a where a.id = c.ref_id)
     and not exists (select 1 from users         u where u.id = c.ref_id)
  union all
  select 'points'::text, p.id, p.user_id, p.delta, p.reason, p.ref_id, p.created_at
    from points_ledger p
   where p.ref_id is not null
     and not exists (select 1 from requests      r where r.id = p.ref_id)
     and not exists (select 1 from sessions      s where s.id = p.ref_id)
     and not exists (select 1 from availabilities a where a.id = p.ref_id)
     and not exists (select 1 from rewards       w where w.id = p.ref_id)
  order by 7 desc
$function$;

revoke all    on function public.bo_defter_yetimleri() from public;
revoke execute on function public.bo_defter_yetimleri() from anon, authenticated;
grant  execute on function public.bo_defter_yetimleri() to service_role;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ SINAMA                                                              ║
-- ╚══════════════════════════════════════════════════════════════════════╝
do $$
declare
  v_uid   uuid;
  v_sag   jsonb;
  v_r     jsonb;
  v_yetim int;
  v_bal   int;
  v_hata  text;
  v_req   uuid;
  v_av    uuid;
  v_host  uuid;
  v_iade  int;
  v_satir uuid;
begin
  -- ── T1 · Süpürge hâlâ frenli ve artık kaynağını yazıyor ────────────
  delete from public.supurge_damgasi where ad = 'expire_stale_sessions';
  v_r := public.expire_stale_sessions('sinama');
  if (v_r ->> 'durum') <> 'kosuldu' then
    raise exception '299/T1: ilk cagri kosmadi (%)', v_r;
  end if;
  if (v_r ->> 'kaynak') <> 'sinama' then
    raise exception '299/T1: kaynak yazilmadi (%)', v_r;
  end if;
  v_r := public.expire_stale_sessions('sinama');
  if (v_r ->> 'durum') <> 'atlandi' then
    raise exception '299/T1: fren calismadi (%)', v_r;
  end if;
  -- Argümansız çağrı (istemcinin yaptığı) hâlâ çalışmalı:
  v_r := public.expire_stale_sessions();
  if (v_r ->> 'ok')::boolean is not true then
    raise exception '299/T1: argumansiz cagri bozuldu (%)', v_r;
  end if;

  -- ── T2 · Sağlık göstergesi konuşuyor ───────────────────────────────
  v_sag := public.bo_supurge_sagligi();
  if v_sag ->> 'durum' is null then raise exception '299/T2: saglik durumu bos'; end if;
  if (v_sag ->> 'bekleyen_istek') is null or (v_sag ->> 'bekleyen_oturum') is null then
    raise exception '299/T2: birikim sayaclari bos (%)', v_sag;
  end if;
  if (v_sag ->> 'son_sonuc') is null then
    raise exception '299/T2: son kosum sonucu damgaya yazilmamis (%)', v_sag;
  end if;
  -- Damgayı 40 dakika geriye al: durum 'gecikmis' olmalı.
  update public.supurge_damgasi set son_kosum = now() - interval '40 minutes'
   where ad = 'expire_stale_sessions';
  v_sag := public.bo_supurge_sagligi();
  if (v_sag ->> 'durum') not in ('gecikmis','gecikmis_ve_birikmis') then
    raise exception '299/T2: 40 dk once kosmus supurge SAGLIKLI gorunuyor (%) — gosterge isirmiyor', v_sag;
  end if;

  -- ── T3 · Bakiye negatife düşemiyor ─────────────────────────────────
  select id into v_uid from users limit 1;
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  begin
    insert into credit_ledger (user_id, delta, reason, balance_after)
    values (v_uid, -(v_bal + 1), 'request_hold', -1);
    raise exception '299/T3: bakiyeyi negatife dusuren satir KABUL EDILDI — tetikleyici isirmiyor';
  exception when others then
    if SQLERRM not like '%insufficient_credits%' then raise; end if;
  end;
  -- Muafiyet çalışıyor mu: yönetici düzeltmesi eksiye düşebilmeli.
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (v_uid, -(v_bal + 5), 'admin_adjust', -5)
  returning id into v_satir;
  -- Sonraki sınamalar bu kullanıcının bakiyesini okuyabilir; izi hemen
  -- siliyoruz ki T5'in tutma satırı yanlışlıkla reddedilmesin.
  delete from credit_ledger where id = v_satir;

  -- ── T4 · Tutma adları tek kaynaktan ve invite_hold içeride ─────────
  if not ('invite_hold' = any (public.tutma_sebepleri())) then
    raise exception '299/T4: invite_hold tutma listesinde yok';
  end if;

  -- ── T5 · Davetle açılan istekte iade GERÇEKTEN yazılıyor ───────────
  -- Sahte bir davet isteği kur: tutma adı `invite_hold`, bedel 2.
  select a.id, a.host_id into v_av, v_host from availabilities a limit 1;
  select id into v_uid from users where id <> v_host limit 1;
  insert into requests (guest_id, host_id, avail_id, status, type, purpose, match_score, created_at)
  values (v_uid, v_host, v_av, 'accepted', 'direct_invite', 'lounge', 60, now())
  returning id into v_req;

  -- Bakiyeyi garantiye al: sınama, kullanıcının seed bakiyesine bağlı
  -- olmamalı (bağlı olsaydı sınamanın yeşil yanması veriye bağlı olurdu).
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (v_uid, 5, 'admin_adjust', v_bal + 5);

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -2, 'invite_hold', v_req, v_bal - 2);

  v_iade := public.istek_kredisi_iade(v_req, 'no_show_refund');
  if v_iade <> 2 then
    raise exception '299/T5: invite_hold ile tutulan 2 kredi icin iade % yazildi (2 olmaliydi)', v_iade;
  end if;
  -- `idx_requests_unique_active` (guest_id, avail_id) yalnız pending/accepted
  -- için geçerli — sıradaki sınama aynı ilana yazabilsin diye kapatıyoruz.
  update requests set status = 'cancelled' where id = v_req;

  -- ── T6 · Eşikten SONRA tutma kaydı yoksa 1 UYDURULMUYOR ────────────
  insert into requests (guest_id, host_id, avail_id, status, type, purpose, match_score, created_at)
  values (v_uid, v_host, v_av, 'accepted', 'standard', 'lounge', 40, now())
  returning id into v_req;
  v_iade := public.istek_kredisi_iade(v_req, 'no_show_refund');
  if v_iade <> 0 then
    raise exception '299/T6: tutma kaydi OLMAYAN yeni istege % kredi UYDURULDU (0 olmaliydi)', v_iade;
  end if;
  update requests set status = 'cancelled' where id = v_req;

  -- ── T7 · Eşikten ÖNCEKİ istekte eski davranış KORUNUYOR ────────────
  insert into requests (guest_id, host_id, avail_id, status, type, purpose, match_score, created_at)
  values (v_uid, v_host, v_av, 'accepted', 'standard', 'lounge', 40,
          public.tutma_varsayim_esigi() - interval '10 days')
  returning id into v_req;
  v_iade := public.istek_kredisi_iade(v_req, 'no_show_refund');
  if v_iade <> 1 then
    raise exception '299/T7: eski istekte varsayim BOZULDU — iade % (1 olmaliydi)', v_iade;
  end if;
  update requests set status = 'cancelled' where id = v_req;

  -- ── T8 · 298'de DÜŞEN (c) BLOĞU GERÇEKTEN GERİ GELDİ Mİ ───────────
  -- Kurulum: kabul edilmiş bir istek + no_show ile 'expired' kapanmış
  -- oturum. 298'in gövdesinde bu istek SONSUZA 'accepted' kalıyordu:
  -- misafirin kredisi kilitli, host'un slotu dolu.
  insert into requests (guest_id, host_id, avail_id, status, type, purpose, match_score, created_at)
  values (v_uid, v_host, v_av, 'accepted', 'standard', 'lounge', 40, now())
  returning id into v_req;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, 5, 'admin_adjust', v_req, v_bal + 5);
  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  insert into credit_ledger (user_id, delta, reason, ref_id, balance_after)
  values (v_uid, -2, 'request_hold', v_req, v_bal - 2);

  insert into sessions (request_id, status, cancel_reason, completed_at, no_show_user_id)
  values (v_req, 'expired', 'no_show', now(), v_host);

  -- Freni aç ve koştur.
  update public.supurge_damgasi set son_kosum = now() - interval '1 hour'
   where ad = 'expire_stale_sessions';
  v_r := public.expire_stale_sessions('sinama');
  if (v_r ->> 'ok')::boolean is not true then
    raise exception '299/T8: supurge hata dondu (%)', v_r;
  end if;

  if (select status from requests where id = v_req) <> 'cancelled' then
    raise exception '299/T8: no_show oturumun arkasindaki istek ACCEPTED kaldi — 187-noshow hatasi geri gelmis';
  end if;
  select coalesce(sum(delta),0) into v_iade
    from credit_ledger where ref_id = v_req and reason = 'no_show_refund';
  if v_iade <> 2 then
    raise exception '299/T8: no_show iadesi % yazildi (tutulan 2 idi)', v_iade;
  end if;

  -- ── T9 · Yetim tarayıcı çalışıyor ──────────────────────────────────
  select count(*) into v_yetim from public.bo_defter_yetimleri();
  raise notice '299 sinama OK · defter yetimi: % satir', v_yetim;

  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
end $$;

select '299 kuruldu' as sonuc;
