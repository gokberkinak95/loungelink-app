-- ============================================================================
-- 252 — ULAŞILABİLİRLİK · PUSH İZNİ BİR AYAR DEĞİL, ARZIN ŞARTIDIR (G7)
--
-- Eleştiri raporunun kapanmamış maddesi:
--   G7  "Push izni akışı yok. Bu üründe eşleşme ZAMANA BAĞLI; push yoksa
--        ürün yok."
--
-- ⚠️ NOT: İstemcinin doğrudan yazma haklarının kapatılması bu dosyada DEĞİL.
-- O iş app 2.96+ MAĞAZADA yayınlandıktan sonra yapılacak ve numarası 253
-- olacak. Ne kapatılacağı `kapatilacak_yazma_haklari` tablosunda yazılı.
--
-- ----------------------------------------------------------------------------
-- 🔴 ÖNCE ÖLÇTÜM — TEŞHİS BUNDAN SONRA
-- ----------------------------------------------------------------------------
-- (1) `registerPush()` ÜÇ yerden çağrılıyor (App.js:100, App.js:144,
--     App.js:564) ve üçü de işletim sisteminin izin penceresini AÇIYOR.
--     İlki kayıttan hemen sonra: kullanıcı daha tek bir salon görmeden
--     "LoungeLink bildirim göndermek istiyor" penceresiyle karşılaşıyor.
--
-- (2) `src/push.js` içindeki HER çıkış yolu çıplak `return`, hepsi tek bir
--     `try { } catch (e) { }` içinde. Dört sonucun — verildi · reddedildi ·
--     cihaz desteklemiyor · token alınamadı — HİÇBİRİ hiçbir yere yazılmıyor.
--
-- (3) `canAskAgain` hiç okunmuyor. iOS'ta bir kez "İzin Verme" denince
--     `requestPermissionsAsync` ömür boyu anında reddedilmiş dönüyor. App
--     bunu her girişte tekrar çağırıyor — hiçbir şey olmuyor, kimse Ayarlar'a
--     yönlendirilmiyor.
--
-- (4) Sunucu tarafında `notify_push` doğru olanı yapıyor: "Token yoksa
--     SESSİZCE geç." Ama bunun bedeli şu: ULAŞILAMAYAN BİR KULLANICI, ÜRÜNÜN
--     GERİ KALANINDA ULAŞILABİLİR BİR KULLANICIDAN AYIRT EDİLEMİYOR.
--
-- Yani "kaç host'a ulaşabiliyoruz?" sorusunun cevabı bilinmiyor — ve
-- bilinmemesinin sebebi kullanıcı değil, ÖLÇÜM NOKTASININ OLMAMASI.
--
-- ----------------------------------------------------------------------------
-- BU ÜRÜNDE BUNUN BEDELİ NE
-- ----------------------------------------------------------------------------
-- Misafir kapıda ve 40 dakikası var. Bildirimi kapalı bir host:
--   · keşifte görünmeye devam eder,
--   · istek almaya devam eder,
--   · misafirin KREDİSİNİ harcatır (249 §4 soğuk ağ indirimi dışında),
--   · isteği görmez,
--   · 72 saat sonra `bayat_istekleri_iade_et()` krediyi iade eder.
--
-- İade DEFTERİ onarır, ÜRÜNÜ onarmaz. Uçak çoktan kalktı.
--
-- 🆕 SINIF: "ULAŞILAMAYAN BİR ARZ ARZ DEĞİLDİR; İADE EDİLEN BİR KREDİ
-- KAÇIRILAN UÇUŞU GERİ GETİRMEZ."
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — İZNİN DURUMU BİR KAYITTIR
--
-- Token'ın VARLIĞI izin verildiğinin kanıtıdır (izin olmadan Expo token
-- alınamaz). Ama token'ın YOKLUĞU hiçbir şeyin kanıtı değildir: hiç mi
-- sorduk, sorduk da mı reddedildi, cihaz mı desteklemiyor? Üçü çok farklı
-- şeyler ve üçünün ÇARESİ de farklı.
--
-- Bu yüzden izin durumu her açılışta bildiriliyor — yalnız pencere
-- gösterildiğinde değil. `sorulmadi` DA bir ölçümdür: o satır bizim
-- akışımızı ölçer, kullanıcının tercihini değil.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists push_izinleri (
  user_id            uuid primary key references users(id) on delete cascade,
  durum              text not null default 'sorulmadi',
  tekrar_sorulabilir boolean not null default true,
  platform           text,
  ilk_sorulma        timestamptz,
  son_bildirim       timestamptz not null default now(),
  soruldu_sayi       int not null default 0
);

alter table push_izinleri drop constraint if exists push_izin_durum_kapisi;
alter table push_izinleri add constraint push_izin_durum_kapisi check (
  durum in ('verildi','reddedildi','sorulmadi','desteklenmiyor'));

create index if not exists push_izin_durum on push_izinleri (durum, son_bildirim desc);

alter table push_izinleri enable row level security;
drop policy if exists push_izin_kendi on push_izinleri;
create policy push_izin_kendi on push_izinleri for select using (user_id = auth.uid());

-- 🔴 YAZMA HAKKI VERİLMİYOR — bilerek. Tek yazma yolu aşağıdaki RPC.
-- İstemcinin doğrudan yazabildiği bir ölçüm, ölçüm değil beyandır.

create or replace function public.push_izni_bildir(
  p_durum text,
  p_tekrar_sorulabilir boolean default true,
  p_platform text default null,
  p_soruldu boolean default false)
returns jsonb
language plpgsql security definer set search_path = public as $pib252$
declare v_uid uuid := auth.uid(); v_durum text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  v_durum := lower(btrim(coalesce(p_durum,'')));
  if v_durum not in ('verildi','reddedildi','sorulmadi','desteklenmiyor') then
    -- Bilinmeyen bir durumu 'sorulmadi' saymak, reddi gizlerdi.
    return jsonb_build_object('ok', false, 'reason', 'bilinmeyen_durum');
  end if;

  insert into push_izinleri (user_id, durum, tekrar_sorulabilir, platform,
                             ilk_sorulma, son_bildirim, soruldu_sayi)
  values (v_uid, v_durum, coalesce(p_tekrar_sorulabilir, true), p_platform,
          case when p_soruldu then now() end, now(),
          case when p_soruldu then 1 else 0 end)
  on conflict (user_id) do update set
    durum              = excluded.durum,
    tekrar_sorulabilir = excluded.tekrar_sorulabilir,
    platform           = coalesce(excluded.platform, push_izinleri.platform),
    ilk_sorulma        = coalesce(push_izinleri.ilk_sorulma, excluded.ilk_sorulma),
    son_bildirim       = now(),
    soruldu_sayi       = push_izinleri.soruldu_sayi + case when p_soruldu then 1 else 0 end;

  -- 🔴 KAPANAN DELİK: kullanıcı izni SONRADAN Ayarlar'dan kapatabilir.
  -- O anda bize hiçbir şey gelmez; token veritabanında sağlam durur ve
  -- gönderdiğimiz her bildirim Expo'da "DeviceNotRegistered" olur — biz
  -- ise ulaşabildiğimizi sanırız. Expo makbuzlarını okumuyoruz (ayrı bir
  -- iş), ama uygulamanın HER AÇILIŞTA durum bildirmesi aynı deliği kapatır:
  -- izin artık yoksa token'ı BİZ pasife alırız.
  if v_durum <> 'verildi' then
    update push_tokens set active = false, updated_at = now()
     where user_id = v_uid and coalesce(active, true);
  end if;

  return jsonb_build_object('ok', true, 'durum', v_durum);
end $pib252$;

grant execute on function public.push_izni_bildir(text, boolean, text, boolean) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — "ULAŞILABİLİR Mİ" TEK BİR YERDE TANIMLANIR
--
-- Aynı sorunun iki farklı yerde iki farklı cevabı olmasın diye tek
-- fonksiyon. Tanım: AKTİF bir Expo token'ı VAR ve izin durumu bunu
-- yalanlamıyor.
--
-- 🔒 GİZLİLİK KARARI: bu fonksiyon `authenticated`e AÇILMIYOR. Kullanıcı
-- kimliği alan bir "ulaşılabilir mi" ucu, herkesin herkesin bildirim
-- durumunu yoklamasına izin verirdi. Misafirin ihtiyacı olan şey zaten
-- kişi değil İLAN: aşağıdaki ilan kapsamlı sarmalayıcı o ihtiyacı görür.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.ulasilabilir_mi(p_user uuid)
returns boolean
language sql stable security definer set search_path = public as $um252$
  select exists (
           select 1 from push_tokens t
            where t.user_id = p_user
              and coalesce(t.active, true)
              and coalesce(t.token,'') like 'ExponentPushToken%')
     and not exists (
           select 1 from push_izinleri i
            where i.user_id = p_user
              and i.durum in ('reddedildi','desteklenmiyor'));
$um252$;

-- 🔴 `from public` YETMEDİ — nöbetçi yakaladı. Projede şemaya toplu
-- `grant execute ... to authenticated` uygulanmış; PUBLIC'ten almak o
-- doğrudan hakkı kaldırmıyor. Rolü ADIYLA geri almak gerekiyor.
-- 🆕 SINIF: "BİR HAKKI HERKESTEN ALMAK, ONU ADIYLA ALMIŞ BİRİNDEN ALMAZ."
revoke all on function public.ulasilabilir_mi(uuid) from public;
revoke all on function public.ulasilabilir_mi(uuid) from authenticated;
revoke all on function public.ulasilabilir_mi(uuid) from anon;
grant execute on function public.ulasilabilir_mi(uuid) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §2b — "ULAŞAMIYORUZ" İLE "ULAŞTIĞIMIZI BİLMİYORUZ" AYNI ŞEY DEĞİL
--
-- 🔴 BU BÖLÜM BİR HATAMIN ÜZERİNE YAZILDI VE HATAYI E2E NÖBETÇİSİ BULDU.
--
-- §4'ü ilk yazdığımda bedeli `ulasilabilir_mi()`ye bağlamıştım: token yoksa
-- ulaşılamaz, ulaşılamıyorsa istek bedava. Sonra ölçtüm:
--
--     aktif token : 0
--     izin kaydı  : 0
--     ilanlı host : 29
--
-- Yani kural, KURULDUĞU GÜN 29 host'un HEPSİNİ ulaşılamaz ilan edip
-- BÜTÜN İSTEKLERİ BEDAVAYA çevirecekti. App 2.98 mağazaya düşene kadar da
-- öyle kalacaktı: kredi geliri sıfır, sebebi görünmez.
--
-- Üstelik bu dosyanın §1'inde doğru cümleyi ZATEN yazmıştım:
--     "Token'ın YOKLUĞU hiçbir şeyin kanıtı değildir."
-- ve on satır sonra kendi cümlemi çiğnedim.
--
-- 🆕 SINIF: "KANITIN YOKLUĞUNU KANIT SAYAN BİR KURAL, KURULDUĞU GÜN
-- HERKESİ SUÇLU BULUR."
--
-- Bu yüzden İKİ ayrı yüklem var ve ikisi ayrı işler için:
--   `ulasilabilir_mi`   → ÖLÇÜM. "Şu an ulaşabiliyor muyuz?" BO bunu okur.
--   `kesin_ulasilamaz`  → PARA. Yalnız kullanıcının KENDİ cihazı bize
--                          "bildirim kapalı" dediyse doğrudur.
-- Para kararı, ölçüm kararından DAHA YÜKSEK kanıt ister.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.kesin_ulasilamaz(p_user uuid)
returns boolean
language sql stable security definer set search_path = public as $ku252$
  select exists (
    select 1 from push_izinleri i
     where i.user_id = p_user
       and i.durum in ('reddedildi','desteklenmiyor'));
$ku252$;

revoke all on function public.kesin_ulasilamaz(uuid) from public;
revoke all on function public.kesin_ulasilamaz(uuid) from authenticated;
revoke all on function public.kesin_ulasilamaz(uuid) from anon;
grant execute on function public.kesin_ulasilamaz(uuid) to service_role;

create or replace function public.ilan_ulasilabilir_mi(p_avail_id uuid)
returns boolean
language sql stable security definer set search_path = public as $ium252$
  select public.ulasilabilir_mi(a.host_id)
    from availabilities a
   where a.id = p_avail_id
     and a.active
     and a.visibility <> 'Hidden';
$ium252$;

-- 🔴 NÖBETÇİ HAKLI ÇIKTI: bunu `authenticated`e açmış ve yüzeye yazmıştım
-- ama app onu HİÇ çağırmıyor — yalnız cümleyi (`..._notu`) okuyor.
-- Kullanılmayan bir hak yalnız yüzey büyütür. İç yapı taşı olarak kalıyor.
revoke all on function public.ilan_ulasilabilir_mi(uuid) from public;
revoke all on function public.ilan_ulasilabilir_mi(uuid) from authenticated;
revoke all on function public.ilan_ulasilabilir_mi(uuid) from anon;
grant execute on function public.ilan_ulasilabilir_mi(uuid) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — HOST'A NE SÖYLENECEK: SOYUT DEĞİL, SAYIYLA
--
-- "Bildirimlerin kapalı" bir ayar cümlesidir; kimse umursamaz.
-- "3 aktif ilanın ve 1 bekleyen isteğin var, ve bunu göremeyeceksin"
-- bir KAYIP cümlesidir. Uyarının şiddeti kullanıcının o an KAYBEDECEĞİ
-- şeye göre belirlenir — bizim ne kadar istediğimize göre değil.
-- ════════════════════════════════════════════════════════════════════════

insert into beta_settings (key, value) values
  ('push_uyari_kritik_tr', to_jsonb('Bekleyen bir isteğin var ve bildirimlerin kapalı. Misafir kapıda bekliyor; sen göremiyorsun.'::text)),
  ('push_uyari_kritik_en', to_jsonb('You have a pending request and notifications are off. Your guest is waiting at the gate — you cannot see it.'::text)),
  ('push_uyari_ilan_tr',   to_jsonb('İlanların yayında ama bildirimlerin kapalı. İstek anlık gelir; açık değilse kaçırırsın.'::text)),
  ('push_uyari_ilan_en',   to_jsonb('Your listings are live but notifications are off. Requests arrive in the moment — you will miss them.'::text)),
  ('push_uyari_genel_tr',  to_jsonb('Bildirimler kapalı. Eşleşmeler zamana bağlı olduğu için bu, kaçırılan buluşma demek.'::text)),
  ('push_uyari_genel_en',  to_jsonb('Notifications are off. Matches are time-bound, so this means missed meetings.'::text)),
  ('push_hazirlik_tr',     to_jsonb('Bir misafir isteği geldiğinde saniyeler önemli. Telefonunun haber vermesine izin ver.'::text)),
  ('push_hazirlik_en',     to_jsonb('When a guest request arrives, seconds matter. Let your phone tell you.'::text)),
  ('push_ayarlar_tr',      to_jsonb('İzin bir kez reddedildiği için uygulama tekrar soramaz. Telefon ayarlarından açman gerekiyor.'::text)),
  ('push_ayarlar_en',      to_jsonb('Permission was denied once, so the app cannot ask again. You need to enable it in phone settings.'::text)),
  ('push_ilan_uyarisi_tr', to_jsonb('Bu host şu an anlık bildirim almıyor; yanıt gecikebilir. Bu yüzden bu istek kredi harcamıyor.'::text)),
  ('push_ilan_uyarisi_en', to_jsonb('This host is not receiving instant notifications; a reply may be delayed. That is why this request costs no credit.'::text))
on conflict (key) do nothing;

create or replace function public.ulasilabilirlik_uyarim()
returns jsonb
language plpgsql stable security definer set search_path = public as $uu252$
declare
  v_uid uuid := auth.uid();
  v_ulas boolean; v_durum text; v_tekrar boolean;
  v_ilan int; v_istek int;
  v_siddet text; v_anahtar text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  v_ulas := public.ulasilabilir_mi(v_uid);
  select i.durum, i.tekrar_sorulabilir into v_durum, v_tekrar
    from push_izinleri i where i.user_id = v_uid;
  v_durum  := coalesce(v_durum, 'sorulmadi');
  v_tekrar := coalesce(v_tekrar, true);

  select count(*) into v_ilan
    from availabilities a
   where a.host_id = v_uid and a.active
     and a.avail_date >= current_date and a.visibility <> 'Hidden';

  select count(*) into v_istek
    from requests r
   where r.host_id = v_uid and r.status = 'pending';

  if v_ulas then
    v_siddet := 'yok'; v_anahtar := null;
  elsif v_istek > 0 then
    v_siddet := 'kritik'; v_anahtar := 'push_uyari_kritik_tr';
  elsif v_ilan > 0 then
    v_siddet := 'uyari';  v_anahtar := 'push_uyari_ilan_tr';
  else
    v_siddet := 'bilgi';  v_anahtar := 'push_uyari_genel_tr';
  end if;

  return jsonb_build_object(
    'ulasilabilir', v_ulas,
    'durum', v_durum,
    'tekrar_sorulabilir', v_tekrar,
    'aktif_ilan', coalesce(v_ilan,0),
    'bekleyen_istek', coalesce(v_istek,0),
    'siddet', v_siddet,
    'mesaj', case when v_anahtar is null then null else public.metin(v_anahtar) end,
    -- İzin bir daha sorulamıyorsa tek çıkış yolu Ayarlar. Bunu kullanıcıya
    -- SÖYLEMEZSEK, "bildirimleri aç" düğmesi hiçbir şey yapmayan bir düğme olur.
    'ayarlar_gerekli', (not v_ulas and not v_tekrar),
    'ayarlar_mesaji', case when (not v_ulas and not v_tekrar)
                           then public.metin('push_ayarlar_tr') else null end,
    'hazirlik_mesaji', public.metin('push_hazirlik_tr'));
end $uu252$;

grant execute on function public.ulasilabilirlik_uyarim() to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — KURAL MOTORU: ULAŞILAMAYAN HOST'A GİDEN İSTEK KREDİ HARCAMAZ
--
-- Üç seçenek vardı:
--   (a) İlanı keşiften GİZLE — arzı yok eder. Bildirimi kapalı bir host
--       yine de uygulamayı açıp isteği görebilir; onu görünmez yapmak
--       ürünün elindeki tek arzı cezalandırmak olurdu. HAYIR.
--   (b) İsteği ENGELLE — aynı sebeple hayır, üstelik misafiri de cezalandırır.
--   (c) SÖYLE ve ÜCRETLENDİRME — tutamayacağımız bir sözü satmayı bırak.
--
-- (c) seçildi. Yan etkisi kasıtlı ve iyi: ulaşılamayan arz bize GELİR
-- kaybettirir, yani onu düzeltmek için baskı ÜRETİR. Ölçüm kendi kendini
-- düzelten bir yere bağlanmadıkça yalnız bir tablodur.
--
-- 🔴 SARMALAYARAK, GÖVDESİNİ YENİDEN YAZARAK DEĞİL. (Bu turda öğrenilen
-- ders: bir fonksiyonu gövdesinden yeniden yazarken imzasını ezberden
-- yazmak, onu güncellemek değil YENİSİNİ yaratmaktır.)
-- ════════════════════════════════════════════════════════════════════════

-- 🔴 "_ham VAR MI" DİYE SORMAK YETMEZ. Tüm dosyalar bir kez daha koşarsa
-- 249 kendi gövdesini `request_credit_cost` adına geri yazar ve eskiden
-- kalan `_ham` BAYAT bir kopya olarak orada durur. O yüzden soru şu:
-- şu anki gövde SARMALAYICI mı, yoksa 249'un ham gövdesi mi?
do $rcw252$
declare v_tanim text;
begin
  -- 🔴 BURADA İKİ KEZ YANILDIM, İKİSİNİ DE ÖLÇEREK BULDUM:
  --   (1) `pg_get_function_identity_arguments` bu sürümde parametre ADLARINI
  --       da veriyor ('p_user uuid, p_avail uuid') — metinle imza aramak
  --       fonksiyonu "YOK" gösterdi.
  --   (2) `proargtypes::oid[]` SIFIR tabanlı bir dizi ([0:1]={2950,2950});
  --       `array[...]` ise BİR tabanlı. İçerikleri aynı, dizi eşitliği FALSE.
  --       🆕 SINIF: "İKİ DİZİYİ EŞİTLEMEK İÇERİĞİ DEĞİL SINIRLARI DA
  --       KARŞILAŞTIRIR."
  -- Doğru soru bir metin ya da dizi karşılaştırması değil, PostgreSQL'in
  -- kendi imza çözümleyicisi:
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p
   where p.oid = to_regprocedure('public.request_credit_cost(uuid,uuid)');

  if v_tanim is null then
    raise exception '252 §4: request_credit_cost(uuid,uuid) YOK — 249 kurulmamis. DURDURULDU.';
  elsif v_tanim like '%request_credit_cost_ham%' then
    raise notice '252 §4: gövde zaten sarmalayici — ham kopya korundu.';
  else
    drop function if exists public.request_credit_cost_ham(uuid, uuid);
    alter function public.request_credit_cost(uuid, uuid) rename to request_credit_cost_ham;
    raise notice '252 §4: 249 bedeli `request_credit_cost_ham` olarak korundu.';
  end if;
end $rcw252$;

-- Ham gövde artık YALNIZ sarmalayıcının içinden çağrılsın: istemciye açık
-- kalırsa 252'nin kuralı tek bir RPC çağrısıyla atlanabilirdi.
revoke all on function public.request_credit_cost_ham(uuid, uuid) from public;
revoke all on function public.request_credit_cost_ham(uuid, uuid) from authenticated;

create or replace function public.request_credit_cost(p_user uuid, p_avail uuid default null)
returns int
language plpgsql stable security definer set search_path = public as $rcc252$
declare v_ham int;
begin
  -- Önce eski kural aynen çalışır: Konsiyerj ayrıcalığı + soğuk ağ indirimi.
  v_ham := public.request_credit_cost_ham(p_user, p_avail);
  if coalesce(v_ham, 1) = 0 then return 0; end if;

  -- Sonra 252: ilan belliyse ve o ilanın sahibine ANLIK ulaşamıyorsak,
  -- zamana bağlı bir eşleşmeyi satmıyoruz — bedel almıyoruz.
  -- 🔴 `ilan_ulasilabilir_mi` DEĞİL. Para kararı kanıt ister: yalnız host'un
  -- kendi cihazı bize "bildirim kapalı" dediyse bedeli düşürüyoruz.
  -- (Gerekçesi §2b'de; hatayı e2e nöbetçisi buldu.)
  if p_avail is not null and exists (
       select 1 from availabilities a
        where a.id = p_avail and public.kesin_ulasilamaz(a.host_id)) then
    return 0;
  end if;
  return v_ham;
end $rcc252$;

-- 🔴 249 bunu `authenticated`e AÇMIŞTI ve nöbetçi "yüzeyde yok ama istemciye
-- açık" diye uyarıyordu. Ölçtüm: ne app ne BO bu fonksiyonu çağırıyor
-- (grep: 0 sonuç). Tüm çağıranlar sunucu tarafında SECURITY DEFINER
-- fonksiyonlar — yani hak kapanınca hiçbir akış bozulmuyor.
-- Kimsenin kullanmadığı bir hak, güvenlik yüzeyi olmaktan başka iş görmez.
revoke all on function public.request_credit_cost(uuid, uuid) from public;
revoke all on function public.request_credit_cost(uuid, uuid) from authenticated;
revoke all on function public.request_credit_cost(uuid, uuid) from anon;
grant execute on function public.request_credit_cost(uuid, uuid) to service_role;

-- Misafire NEDEN bedava olduğunu söyleyen cümle, isteği göndermeden önce
-- okunabilsin. `ilan_ozeti` zaten ilan başına çağrılıyor (248 §4).
create or replace function public.ilan_ulasilabilirlik_notu(p_avail_id uuid)
returns text
language plpgsql stable security definer set search_path = public as $iun252$
begin
  -- Misafire "bu host ulaşılamaz olabilir" demek de bir İDDİADIR; onu da
  -- ancak host'un cihazı söylediyse söylüyoruz.
  if not exists (select 1 from availabilities a
                  where a.id = p_avail_id and a.active and a.visibility <> 'Hidden'
                    and public.kesin_ulasilamaz(a.host_id)) then
    return null;
  end if;
  return public.metin('push_ilan_uyarisi_tr');
end $iun252$;

grant execute on function public.ilan_ulasilabilirlik_notu(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §4b — GÖSTERİLEN SAYI İLE ALINAN SAYI AYNI DEĞİLDİ (252'yi yazarken bulundu)
--
-- 🔴 BU MADDE PLANDA YOKTU. §4'ü yazarken "peki misafir göndermeden önce
-- kaç kredi tutulacağını nereden okuyor?" diye baktım ve ÖLÇTÜM:
--
--     request_precheck_pregate → 'credit_hold', 1        ← SABİT
--     create_request_impl_preflag → request_credit_cost(...)  ← DEĞİŞKEN
--
-- Yani 249 soğuk ağda isteği BEDAVA yaptığından beri, ekran misafire
-- "1 kredi tutulacak" diyor, sunucu 0 alıyor. Kimse şikâyet etmez — lehine
-- bir fark — ama bu, ekranın sunucuyu bilmediğinin kanıtı. 252 ulaşılamayan
-- host'u da bedava yapınca aynı yalan çoğalacaktı.
--
-- 🆕 SINIF: "KULLANICIYA GÖSTERİLEN BEDEL, ONU HESAPLAYAN FONKSİYONDAN
-- OKUNMUYORSA, O BİR FİYAT DEĞİL BİR TAHMİNDİR."
--
-- Gövdeyi elle yeniden yazmıyorum: mevcut tanımı okuyup BEKLEDİĞİM METNİ
-- bulamazsam DOKUNMUYORUM ve bunu söylüyorum.
-- ════════════════════════════════════════════════════════════════════════

do $pc252$
declare v_tanim text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p where p.oid = to_regprocedure('public.request_precheck_pregate(uuid)');
  if v_tanim is null then
    raise notice '252 §4b: request_precheck_pregate YOK — DOKUNULMADI.'; return;
  end if;
  if v_tanim like '%request_credit_cost(auth.uid(), p_avail_id)%' then
    raise notice '252 §4b: bedel zaten hesaplayan fonksiyondan okunuyor — dokunulmadi.'; return;
  end if;
  if v_tanim not like '%''credit_hold'', 1,%'
     or v_tanim not like '%''credit_total'', 1 + coalesce(v_credit, 0)%'
     or v_tanim not like '%v_credit := public.paid_guest_credit(p_avail_id);%' then
    raise notice '252 §4b: beklenen metin bulunamadi — DOKUNULMADI (elle bakilmali).'; return;
  end if;

  v_yeni := v_tanim;
  v_yeni := replace(v_yeni, 'v_credit int; v_bal int;',
                            'v_credit int; v_tut int := 1; v_bal int;');
  v_yeni := replace(v_yeni, 'v_credit := public.paid_guest_credit(p_avail_id);',
                            'v_credit := public.paid_guest_credit(p_avail_id);'
                         || E'\n  v_tut := coalesce(public.request_credit_cost(auth.uid(), p_avail_id), 1);');
  v_yeni := replace(v_yeni, '''credit_hold'', 1,', '''credit_hold'', v_tut,');
  v_yeni := replace(v_yeni, '''credit_total'', 1 + coalesce(v_credit, 0)',
                            '''credit_total'', v_tut + coalesce(v_credit, 0)');
  execute v_yeni;
  raise notice '252 §4b: gosterilen bedel artik request_credit_cost''tan okunuyor.';
end $pc252$;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — HUNİYE YENİ OLAY EKLENMEDİ (bilerek)
--
-- 250 §2 huni olay adlarını BEŞ tanede kilitledi ve bunun bir nöbetçisi var
-- ('uydurma_olay' reddedilmeli). "push_izni_soruldu" eklemek kolaydı; ama
-- huni ÜRÜNÜN yolunu ölçer, izin akışı ise BİZİM akışımızı. İkisini aynı
-- tabloya koymak huniyi seyreltir ve dönüşüm oranlarını kirletir.
-- İzin ölçümü kendi tablosunda duruyor; §6 onu okuyor.
-- ════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════
-- §6 — BO: "KAÇ HOST'A ULAŞABİLİYORUZ?"
--
-- En önemli sayı red oranı DEĞİL. En önemli sayı:
--   AKTİF İLANI OLAN kaç host'a ulaşamıyoruz — çünkü satılan arz o.
-- İkincisi: ulaşılamayan host'a giden isteklerin AKIBETİ. Kabul oranı
-- ulaşılabilir host'lara göre belirgin düşükse, teşhis kanıtlanmış olur.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.bo_push_ulasilabilirlik(p_gun int default 30)
returns jsonb
language plpgsql stable security definer set search_path = public as $bpu252$
declare
  v_bas timestamptz := now() - make_interval(days => greatest(coalesce(p_gun,30), 1));
  v_durum jsonb; v_host jsonb; v_istek jsonb;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;

  -- (1) İzin durumunun dağılımı. Satırı OLMAYAN kullanıcı da bir ölçümdür:
  -- ona hiç sormadık ya da eski sürümü kullanıyor.
  select jsonb_build_object(
      'verildi',        count(*) filter (where i.durum = 'verildi'),
      'reddedildi',     count(*) filter (where i.durum = 'reddedildi'),
      'sorulmadi',      count(*) filter (where i.durum = 'sorulmadi'),
      'desteklenmiyor', count(*) filter (where i.durum = 'desteklenmiyor'),
      'bildirim_yok',   count(*) filter (where i.durum is null),
      -- 🔴 AYRI BİR ARIZA SINIFI: izin VERİLDİ ama token yok. Bu kullanıcı
      -- "izin verenler" içinde sayılırsa ulaşabildiğimizi sanırız; oysa
      -- Expo token'ı hiç alınamamış demektir.
      'verildi_tokensiz', count(*) filter (where i.durum = 'verildi'
        and not exists (select 1 from push_tokens t
                         where t.user_id = u.id and coalesce(t.active, true))),
      'toplam',         count(*))
    into v_durum
    from users u
    left join push_izinleri i on i.user_id = u.id
   where u.deleted_at is null;

  -- (2) ASIL SAYI: aktif ilanı olan host'ların ulaşılabilirliği.
  select jsonb_build_object(
      'ilanli_host',      count(*),
      'ulasilabilir',     count(*) filter (where h.ulas),
      'ulasilamaz',       count(*) filter (where not h.ulas),
      'ulasilamaz_ilan',  coalesce(sum(h.ilan) filter (where not h.ulas), 0),
      -- 🔴 İKİ AYRI SAYI, İKİ AYRI ANLAM (§2b):
      --   kesin_ulasilamaz → cihazı bize "bildirim kapalı" DEDİ. Para kararı
      --                       bu sayıya bağlı; bu istekler kredi harcamıyor.
      --   bilinmiyor       → token yok ama sebebini BİLMİYORUZ (çoğunlukla
      --                       eski sürüm). Ürün bunları hâlâ ücretlendiriyor.
      'kesin_ulasilamaz', count(*) filter (where h.kesin),
      'bilinmiyor',       count(*) filter (where not h.ulas and not h.kesin))
    into v_host
    from (
      select a.host_id, count(*) as ilan,
             public.ulasilabilir_mi(a.host_id)  as ulas,
             public.kesin_ulasilamaz(a.host_id) as kesin
        from availabilities a
       where a.active and a.avail_date >= current_date and a.visibility <> 'Hidden'
       group by a.host_id) h;

  -- (3) KANIT: ulaşılamayan host'a giden isteğin akıbeti.
  select jsonb_build_object(
      'ulasilabilir_host_istek', count(*) filter (where x.ulas),
      'ulasilabilir_kabul',      count(*) filter (where x.ulas and x.status = 'accepted'),
      'ulasilamaz_host_istek',   count(*) filter (where not x.ulas),
      'ulasilamaz_kabul',        count(*) filter (where not x.ulas and x.status = 'accepted'),
      'ulasilamaz_yanitsiz',     count(*) filter (where not x.ulas and x.status = 'pending'))
    into v_istek
    from (select r.status::text as status, public.ulasilabilir_mi(r.host_id) as ulas
            from requests r where r.created_at >= v_bas) x;

  return jsonb_build_object(
    'gun', greatest(coalesce(p_gun,30), 1),
    'izin', coalesce(v_durum, '{}'::jsonb),
    'host', coalesce(v_host, '{}'::jsonb),
    'istek', coalesce(v_istek, '{}'::jsonb));
end $bpu252$;

grant execute on function public.bo_push_ulasilabilirlik(int) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §7 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n252$
declare
  v_h text[] := '{}';
  v_host uuid; v_guest uuid; v_av uuid; v_ap char(3); v_dolgu uuid; v_i int;
  v_ham int; v_yeni int; v_r jsonb; v_tanim text;
begin
  begin
    -- ---- Kendi verimizi üretiyoruz: SEED'ler bu dosyadan SONRA koşuyor.
    insert into users (email, password_hash, role)
    values ('n252_host@ll.test', 'x', 'host') returning id into v_host;
    insert into users (email, password_hash, role)
    values ('n252_guest@ll.test', 'x', 'guest') returning id into v_guest;
    insert into profiles (user_id, name) values (v_host, 'N252 Host'), (v_guest, 'N252 Guest');

    select code into v_ap from airports limit 1;
    if v_ap is null then
      v_h := v_h || 'airports BOS — olcum yapilamadi (sessiz gecmiyor)'::text;
    else
      insert into availabilities (host_id, airport_code, avail_date, time_from, time_to, slots, active)
      values (v_host, v_ap, current_date + 1, '10:00', '14:00', 1, true)
      returning id into v_av;

      -- 🔴 SOĞUK AĞ TUZAĞI: 249 bu havalimanında 3'ten az host varsa bedeli
      -- ZATEN 0 yapıyor. Tek host'la ölçseydim "0 çıktı" derdim ve testim
      -- HİÇBİR ŞEY kanıtlamamış olurdu — çünkü 252 hiç çalışmadan da 0'dı.
      -- Bu yüzden eşiğin üstüne çıkacak kadar host üretiyorum.
      for v_i in 1..3 loop
        insert into users (email, password_hash, role)
        values (format('n252_dolgu%s@ll.test', v_i), 'x', 'host') returning id into v_dolgu;
        insert into profiles (user_id, name) values (v_dolgu, format('N252 Dolgu %s', v_i));
        insert into availabilities (host_id, airport_code, avail_date, time_from, time_to, slots, active)
        values (v_dolgu, v_ap, current_date + 2, '10:00', '14:00', 1, true);
      end loop;

      -- (1) Token YOK → ulaşılamaz.
      if public.ulasilabilir_mi(v_host) then
        v_h := v_h || 'token yokken ULASILABILIR dendi'::text;
      end if;

      -- (2) Token VAR → ulaşılabilir.
      insert into push_tokens (user_id, token, platform, active)
      values (v_host, 'ExponentPushToken[n252]', 'android', true);
      if not public.ulasilabilir_mi(v_host) then
        v_h := v_h || 'aktif token varken ULASILAMAZ dendi'::text;
      end if;

      -- (3) 🔴 ASIL DELİK: token duruyor ama kullanıcı izni Ayarlar'dan
      -- kapatmış. Bunu ulaşılabilir saymak, ulaşamadığımız birine
      -- ulaştığımızı sanmaktır.
      insert into push_izinleri (user_id, durum, tekrar_sorulabilir)
      values (v_host, 'reddedildi', false);
      if public.ulasilabilir_mi(v_host) then
        v_h := v_h || 'izin REDDEDILMISKEN token yuzunden ulasilabilir sayildi'::text;
      end if;

      -- (3b) 🔴 KURULUŞ GÜNÜ TESTİ — bu nöbetçi bir hatanın üzerine yazıldı.
      -- Kanıt YOKKEN (token yok, izin kaydı yok) bedel DÜŞMEMELİ. Aksi
      -- hâlde 252 kurulduğu gün bütün istekler bedavaya döner.
      delete from push_izinleri where user_id = v_host;
      delete from push_tokens   where user_id = v_host;
      if public.request_credit_cost(v_guest, v_av)
         <> public.request_credit_cost_ham(v_guest, v_av) then
        v_h := v_h || 'KANIT YOKKEN bedel dustu — 252 kuruldugu gun tum istekler bedava olurdu'::text;
      end if;
      -- Kanıtı geri koy: bundan sonrası "biliyoruz ki ulaşamıyoruz" hâli.
      insert into push_izinleri (user_id, durum, tekrar_sorulabilir)
      values (v_host, 'reddedildi', false);

      -- (4) Bedel: ulaşılamayan host → 0, ve bu YALNIZCA eksiltme olmalı.
      -- Önce ölçümün kendisi geçerli mi: ham bedel 1 olmalı ki 0'ı 252
      -- üretmiş olsun.
      v_ham  := public.request_credit_cost_ham(v_guest, v_av);
      if coalesce(v_ham,0) <> 1 then
        v_h := v_h || format('OLCUM GECERSIZ: ham bedel %s (1 olmaliydi) — 0 sonucu 252 yuzunden degil', v_ham)::text;
      end if;
      v_yeni := public.request_credit_cost(v_guest, v_av);
      if v_yeni <> 0 then
        v_h := v_h || format('ulasilamayan hostta bedel %s (0 olmaliydi)', v_yeni)::text;
      end if;
      if v_yeni > v_ham then
        v_h := v_h || 'sarmalayici bedeli ARTIRDI — yalniz eksiltmeliydi'::text;
      end if;

      -- (5) Kanıt kalkınca sarmalayıcı ham değere DÖNMELİ.
      delete from push_izinleri where user_id = v_host;
      if public.request_credit_cost(v_guest, v_av)
         <> public.request_credit_cost_ham(v_guest, v_av) then
        v_h := v_h || 'ulasilabilir hostta sarmalayici ham degerden SAPTI (249 kurali bozuldu)'::text;
      end if;

      -- (6) Not da yalnız KANIT varken çıkmalı — token'ın olmaması yetmez.
      if public.ilan_ulasilabilirlik_notu(v_av) is not null then
        v_h := v_h || 'kanit yokken misafire `ulasilamaz` denildi'::text;
      end if;
      insert into push_izinleri (user_id, durum, tekrar_sorulabilir)
      values (v_host, 'reddedildi', false)
      on conflict (user_id) do update set durum = 'reddedildi';
      if public.ilan_ulasilabilirlik_notu(v_av) is null then
        v_h := v_h || 'kanit VARKEN misafire uyari notu CIKMADI'::text;
      end if;
    end if;

    -- (6b) §4b: ekrandaki bedel artık hesaplayan fonksiyondan okunuyor mu.
    -- Metni değil DAVRANIŞI ölçemiyorum (auth.uid() burada NULL), o yüzden
    -- kanıtı tanımın kendisinden alıyorum — ama "sabit 1" kalıntısının
    -- GİTTİĞİNİ de arıyorum: yalnız yeni metni aramak, ikisinin bir arada
    -- durduğu yarım bir yamayı yeşil gösterirdi.
    select pg_get_functiondef(p.oid) into v_tanim
      from pg_proc p where p.oid = to_regprocedure('public.request_precheck_pregate(uuid)');
    if v_tanim is null then
      v_h := v_h || 'request_precheck_pregate YOK'::text;
    else
      if v_tanim not like '%request_credit_cost(auth.uid(), p_avail_id)%' then
        v_h := v_h || 'ekrandaki bedel hala hesaplayan fonksiyondan OKUNMUYOR'::text;
      end if;
      if v_tanim like '%''credit_hold'', 1,%' then
        v_h := v_h || 'sabit `credit_hold, 1` hala duruyor — yama YARIM'::text;
      end if;
    end if;

    -- (7) Bilinmeyen durum reddedilmeli (ölçümün kapısı).
    -- Kendi bloğunda: harness'ta `auth.uid()` NULL olduğu için fonksiyon
    -- `not_authenticated` fırlatır ve bu, dıştaki tüm ölçümü düşürürdü.
    -- Kabul edilen tek sonuç: hata YA DA ok:false. `ok:true` ASLA.
    begin
      if coalesce((public.push_izni_bildir('belki'))->>'ok','') = 'true' then
        v_h := v_h || 'bilinmeyen izin durumu KABUL EDILDI'::text;
      end if;
    exception when others then
      if sqlerrm not like '%not_authenticated%' then
        v_h := v_h || ('izin kapisi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;

    -- (8) Gizlilik: kişi kapsamlı uç `authenticated`e AÇILMAMALI.
    if has_function_privilege('authenticated', 'public.ulasilabilir_mi(uuid)', 'execute') then
      v_h := v_h || 'ulasilabilir_mi(uuid) authenticated`e ACIK — herkes herkesi yoklayabilir'::text;
    end if;
    if has_function_privilege('authenticated', 'public.ilan_ulasilabilir_mi(uuid)', 'execute') then
      v_h := v_h || 'ilan boolean`i authenticated`e ACIK — app onu cagirmiyor, yuzey bosuna buyuyor'::text;
    end if;
    -- Misafirin GERCEKTEN okudugu uc CUMLEDIR; o acik olmali.
    if not has_function_privilege('authenticated', 'public.ilan_ulasilabilirlik_notu(uuid)', 'execute') then
      v_h := v_h || 'uyari cumlesi authenticated`e KAPALI — misafir okuyamaz (42501)'::text;
    end if;

    -- (9) BO okunabiliyor mu.
    v_r := public.bo_push_ulasilabilirlik(30);
    if v_r -> 'host' is null or v_r -> 'istek' is null then
      v_h := v_h || 'bo_push_ulasilabilirlik eksik dondu'::text;
    end if;

    -- (10) Huni kapısı hâlâ kilitli mi (252 bilerek olay eklemedi).
    if exists (select 1 from pg_constraint
                where conname = 'huni_olay_kapisi'
                  and pg_get_constraintdef(oid) like '%push%') then
      v_h := v_h || 'huniye push olayi eklenmis — 252 bunu bilerek YAPMIYOR'::text;
    end if;

    raise exception 'GERI_AL_252';
  exception when others then
    if sqlerrm <> 'GERI_AL_252' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '252 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '252 OK · izin durumu kayitli · ayarlardan kapatma yakalaniyor · ulasilamayan host bedelsiz · kisi kapsamli uc kapali';
end $n252$;

insert into rpc_client_surface (fn_name, client, note) values
  ('push_izni_bildir',          'app', 'Push izin durumunu her acilista bildirir (252)'),
  ('ulasilabilirlik_uyarim',    'app', 'Bildirim kapaliysa kullaniciya ne kaybettigini soyler (252)'),
  ('ilan_ulasilabilirlik_notu', 'app', 'Istegin neden bedelsiz oldugunu anlatan cumle (252)')
on conflict (fn_name) do update set note = excluded.note;

commit;

select '252 KURULDU' as sonuc,
       (select count(*) from push_izinleri)                                       as izin_kaydi,
       (select count(*) from beta_settings where key like 'push_%')               as push_metni;
