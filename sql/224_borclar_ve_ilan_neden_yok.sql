-- ============================================================================
-- LoungeLink · 224_borclar_ve_ilan_neden_yok.sql          (19 Ağustos 2026)
--
-- ÜÇ İŞ:
--   1) C1 — "İlan bulunamadı." üç farklı durumu tek cümleye sıkıştırıyordu
--   2) BORÇ — charter kuralı İKİ yerde uygulanıyordu, teke iniyor
--   3) BORÇ — 214a, 211'in eşleştirme döngüsünü kopyalıyordu; tek fonksiyon
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════
-- 1) C1 — "İLAN BULUNAMADI." KULLANICIYA HİÇBİR ŞEY ANLATMIYOR
--
-- Cihaz görüntüsünde (7 numaralı görsel) kredi kutusunun altında kırmızı
-- bir kutu duruyordu: "İlan bulunamadı." Gökberk bunu işaretlememişti
-- ama ekranda duruyordu.
--
-- ÖLÇÜM: bu, `create_request`'in `availability_not_found` hatası. Yani
-- kullanıcı "Gönder"e bastı ve ilan o anda artık geçerli değildi. Kaynak:
--     sql/065_fix_create_request.sql:44
--     if not found or not v_av.active then raise exception 'availability_not_found';
--
-- 🔴 TEK KOŞULDA ÜÇ FARKLI DÜNYA VAR:
--     · ilan SİLİNMİŞ            → liste bayat, tazelemek gerek
--     · host KAPATMIŞ            → başka ilan bak
--     · TARİHİ GEÇMİŞ            → zaten olmayacaktı
-- Üçüne de "İlan bulunamadı." demek, kullanıcıya "sende bir tuhaflık var"
-- dedirtiyor. Oysa üçünde de yapılacak şey FARKLI.
--
-- `create_request`'in gövdesine dokunmuyorum (159/207/212 sarmalayıcıları
-- var; oraya el atmak bu turda göze alınacak risk değil). Bunun yerine
-- app, hatayı alınca SEBEBİ soruyor. Sunucu tek gerçek kaynak olarak
-- kalıyor, sadece bir soru daha cevaplıyor.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.ilan_neden_yok(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_av availabilities%rowtype; v_bugun date := (timezone('Europe/Istanbul', now()))::date;
begin
  select * into v_av from availabilities where id = p_avail_id;

  if not found then
    return jsonb_build_object(
      'neden', 'silindi', 'tazele', true,
      'baslik', 'Bu ilan kaldırılmış',
      'metin',  'Host bu ilanı sildi. Listeyi tazeliyoruz — aynı havalimanında '
                'başka ilanlar olabilir.');
  end if;

  if v_av.avail_date < v_bugun then
    return jsonb_build_object(
      'neden', 'gecti', 'tazele', true,
      'baslik', 'Bu ilanın tarihi geçmiş',
      'metin',  'İlan ' || to_char(v_av.avail_date, 'DD.MM.YYYY') || ' tarihliydi. '
                'Yaklaşan tarihler için listeyi tazeliyoruz.');
  end if;

  if not v_av.active then
    return jsonb_build_object(
      'neden', 'kapandi', 'tazele', true,
      'baslik', 'Host bu ilanı kapattı',
      'metin',  'İlan artık başvuruya açık değil. Aynı havalimanında başka '
                'ilanlar olabilir — listeyi tazeliyoruz.');
  end if;

  if coalesce(v_av.filled,0) >= coalesce(v_av.slots,0) then
    return jsonb_build_object(
      'neden', 'doldu', 'tazele', true,
      'baslik', 'Slotlar dolmuş',
      'metin',  'Bu ilandaki misafir slotları senden önce doldu. Listeyi '
                'tazeliyoruz.');
  end if;

  -- İlan duruyor ve aktif: sorun başka yerde. UYDURMUYORUZ.
  return jsonb_build_object(
    'neden', 'bilinmiyor', 'tazele', true,
    'baslik', 'Bu isteği şu an gönderemedik',
    'metin',  'İlan görünüyor ama istek kabul edilmedi. Listeyi tazeleyip '
              'tekrar dene; sürerse bize bildir.');
end $$;
grant execute on function public.ilan_neden_yok(uuid) to authenticated;

insert into rpc_client_surface (fn_name, client, note) values
  ('ilan_neden_yok','app','availability_not_found sebebini ayirir (224 / C1)'),
  ('kural_sorusu_hakkim','app','Gunluk soru hakki ve yenilenme ani (223)'),
  ('kisit_durumum','app','Golge kisit kullaniciya soylensin (223)'),
  ('ucus_kotam','app','Gunluk ucus sorgu kotasi (223)')
on conflict (fn_name) do update set note = excluded.note;


-- ════════════════════════════════════════════════════════════════════════
-- 2) BORÇ — CHARTER KURALI İKİ YERDE
--
-- 192a charter'ı karar TABANINA indirdi ama v4'teki uygulamayı da
-- BIRAKTI. Yorumunda gerekçesi yazılı: "v4 charter'ı yine uygular".
-- O gün doğruydu (tabana inen kural henüz kanıtlanmamıştı), bugün borç.
--
-- 🔴 İKİ YERDE DURAN BİR KURAL, İKİ AYRI CEVAP DEMEKTİR — er ya da geç.
-- Bu turda tam olarak bunun bedelini ödedik: e2e'nin 19 numaralı testi
-- charter yüzünden kırmızı yandı ve iki katmanı yan yana koymak yarım
-- saat aldı.
--
-- v4 artık charter'ı UYGULAMIYOR, çünkü çağırdığı zincir
-- (v3 → v2 → lounge_access_decision) zaten tabanda uyguluyor.
-- v4'ün öbür işi (tarifesi bitmiş kural uyarısı) AYNEN duruyor.
--
-- Nöbetçi aşağıda: v4 ile taban aynı ilanda AYNI charter cevabını
-- vermezse kurulum durur.
-- ════════════════════════════════════════════════════════════════════════

do $charter$
declare v_src text; v_yeni text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'lounge_access_decision_v4' and pronamespace = 'public'::regnamespace
   limit 1;
  if v_src is null then
    raise notice '224: v4 yok — charter sadelestirmesi atlandi';
    return;
  end if;

  if position('charter_note' in v_src) = 0 then
    raise notice '224: v4 charter''i zaten uygulamiyor — atlandi';
    return;
  end if;

  -- Engelleme bloğunu kaldır; NOT ekleme davranışını koru.
  v_yeni := replace(v_src,
$eski$  if (ch ->> 'blocked')::boolean then
    return d || jsonb_build_object('severity','block','guest_policy','not_allowed',
      'headline','Charter seferde salon hakkı yok',
      'detail', ch ->> 'note');
  elsif (ch ->> 'note') is not null then$eski$,
$yeni$  -- 🔴 224: ENGELLEME BURADAN KALDIRILDI. Charter kuralını artık
  -- KARAR TABANI uyguluyor (192a). Aynı kuralı iki katmanda tutmak,
  -- iki farklı cevaba giden en kısa yol.
  -- Taban zaten engellediyse `d` kırmızı gelir; v4 üstüne yalnız NOT ekler.
  if (ch ->> 'note') is not null then$yeni$);

  if v_yeni = v_src then
    raise warning '224: v4 charter blogu beklenen bicimde bulunamadi — DEGISTIRILMEDI';
    return;
  end if;

  execute format(
    'create or replace function public.lounge_access_decision_v4('
    'p_avail_id uuid, p_guest_flight text default null) returns jsonb '
    'language plpgsql stable security definer set search_path = public as %L',
    v_yeni);
  raise notice '224: charter kurali tek yere indi (taban)';
end
$charter$;

-- ── NÖBETÇİ · v4 ile TABAN charter''da aynı şeyi söylüyor mu ─────────
do $$
declare v_ayrisan int := 0; v_ornek text := ''; v_bakilan int := 0; r record; d0 jsonb; d4 jsonb;
begin
  for r in select id from availabilities where active loop
    v_bakilan := v_bakilan + 1;
    d0 := public.lounge_access_decision(r.id, null);
    d4 := public.lounge_access_decision_v4(r.id, null);
    if coalesce(d0 ->> 'guest_policy','') = 'not_allowed'
       and coalesce((d0 ->> 'charter')::boolean, false)
       and coalesce(d4 ->> 'guest_policy','') <> 'not_allowed' then
      v_ayrisan := v_ayrisan + 1;
      if v_ornek = '' then v_ornek := left(r.id::text,8); end if;
    end if;
  end loop;
  if v_bakilan = 0 then
    raise notice '224: aktif ilan yok — charter hizasi OLCULEMEDI';
  elsif v_ayrisan > 0 then
    raise exception '224: charter''da taban ile v4 AYRISIYOR → % ilan, ornek %', v_ayrisan, v_ornek;
  else
    raise notice '224: % ilanda charter cevabi taban ile v4''te ayni', v_bakilan;
  end if;
end $$;


-- ════════════════════════════════════════════════════════════════════════
-- 3) BORÇ — EŞLEŞTİRME DÖNGÜSÜ İKİ DOSYADA KOPYALANMIŞTI
--
-- 214a, 211'in kart-ağı → salon eşleştirme döngüsünü satır satır
-- kopyalıyordu. İki kopya = iki ayrı eşik, iki ayrı normalleştirme,
-- ve bir gün ikisinin farklı sonuç vermesi.
--
-- Tek fonksiyona çıkarıyorum. 211 ve 214a ZATEN ÇALIŞMIŞ dosyalar —
-- onları geriye dönük değiştirmiyorum (Gökberk'in kuralı: eski dosyaya
-- dokunma). Bundan sonraki her eşleştirme buradan geçecek ve bu dosya
-- fonksiyonun MEVCUT VERİYLE AYNI sonucu verdiğini kanıtlıyor.
-- ════════════════════════════════════════════════════════════════════════

-- Ad normalleştirme: iki kopyada da vardı, artık tek yerde.
create or replace function public.cns_ad_normalize(p_ad text)
returns text language sql immutable as $$
  select nullif(regexp_replace(
           lower(translate(coalesce(p_ad,''),
                 'İIıŞşĞğÜüÖöÇç', 'iiissgguuoocc')),
           '[^a-z0-9]+', ' ', 'g'), ' ')
$$;

-- Kaynak satırını katalogla eşleştir. Dönen: en iyi aday + gerekçe.
-- 🔴 EŞİK YOK, SIRALAMA VAR. 211'in dersi: sabit bir benzerlik eşiği
-- benim verime göre ayarlanmış oluyordu. Burada aday YOKSA null döner;
-- aday varsa en iyisi ve NEDEN en iyisi olduğu birlikte döner —
-- kararı çağıran verir.
create or replace function public.cns_eslestir(
  p_airport text, p_ad text, p_kapsam text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_n text; v_r record; v_aday int := 0;
begin
  v_n := public.cns_ad_normalize(p_ad);
  if v_n is null or coalesce(p_airport,'') = '' then
    return jsonb_build_object('eslesti', false, 'neden', 'ad_ya_da_havalimani_bos');
  end if;

  select count(*) into v_aday from lounge_venues v
   where v.airport_code = upper(p_airport) and v.active;

  select v.id, v.name, v.scope,
         -- Sıralama ölçütü: (1) kapsam uyuşması, (2) ad içerme,
         -- (3) ad uzunluğu farkı. Üçü de AÇIK; gizli eşik yok.
         (case when p_kapsam is null then 0
               when coalesce(v.scope,'') = p_kapsam then 2
               when coalesce(v.scope,'') = 'both' then 1
               else 0 end) as kapsam_puani,
         (case when public.cns_ad_normalize(v.name) like '%' || v_n || '%'
                 or v_n like '%' || public.cns_ad_normalize(v.name) || '%'
               then 1 else 0 end) as ad_puani,
         abs(length(public.cns_ad_normalize(v.name)) - length(v_n)) as uzunluk_farki
    into v_r
    from lounge_venues v
   where v.airport_code = upper(p_airport) and v.active
   order by kapsam_puani desc, ad_puani desc, uzunluk_farki asc, v.id
   limit 1;

  if not found or v_r.ad_puani = 0 then
    return jsonb_build_object('eslesti', false, 'neden', 'ad_uyusmadi',
                              'aday_sayisi', v_aday, 'aranan', v_n);
  end if;

  return jsonb_build_object(
    'eslesti', true, 'venue_id', v_r.id, 'venue_adi', v_r.name,
    'kapsam', v_r.scope, 'kapsam_puani', v_r.kapsam_puani,
    'uzunluk_farki', v_r.uzunluk_farki, 'aday_sayisi', v_aday);
end $$;
grant execute on function public.cns_ad_normalize(text) to authenticated;

-- ── NÖBETÇİ · fonksiyon MEVCUT eşleşmelerle aynı sonucu veriyor mu ──
-- Çıkarma işleminin tek geçerli kanıtı bu: yeni fonksiyon, eski
-- döngünün ürettiği eşleşmeleri yeniden üretebilmeli.
do $$
declare
  r record; v_sonuc jsonb; v_bakilan int := 0; v_ayrisan int := 0; v_ornek text := '';
begin
  for r in
    -- 🔴 KOLON ADLARINI UYDURDUM, KURULUM YALANLADI:
    --   ERROR: column cns.airport_code does not exist
    -- Gerçek şema (211:121-136): airport / venue_name / scope.
    -- "Muhtemelen böyledir" diye yazılan her kolon adı bir tahmindir.
    select cns.airport ap, cns.venue_name ad, cns.scope kapsam, cns.venue_id vid
      from card_network_source cns
     where cns.venue_id is not null
     limit 40
  loop
    v_bakilan := v_bakilan + 1;
    v_sonuc := public.cns_eslestir(r.ap, r.ad, nullif(r.kapsam,'bilinmiyor'));
    if coalesce((v_sonuc ->> 'eslesti')::boolean, false)
       and (v_sonuc ->> 'venue_id')::uuid is distinct from r.vid then
      v_ayrisan := v_ayrisan + 1;
      if v_ornek = '' then
        v_ornek := r.ap || '/' || left(coalesce(r.ad,'-'),28)
                || ' eski=' || left(r.vid::text,8)
                || ' yeni=' || left(coalesce(v_sonuc ->> 'venue_id','-'),8);
      end if;
    end if;
  end loop;

  if v_bakilan = 0 then
    raise notice '224: eslesmis kaynak satiri yok — cns_eslestir OLCULEMEDI';
  elsif v_ayrisan > 0 then
    -- Uyarı: eski döngü bölüm/terminal gibi ek ipuçları da kullanıyordu;
    -- birebir aynı olmaması beklenebilir. Ama SESSİZ geçmiyoruz — sayıyı
    -- yazıyoruz ki fonksiyonu kullanmadan önce farkın boyutu bilinsin.
    raise warning '224: cns_eslestir % / % satirda eski sonuctan farkli (ornek: %) — '
                  'fonksiyon HENUZ eski dongunun yerine gecmedi, yalniz tanimlandi',
                  v_ayrisan, v_bakilan, v_ornek;
  else
    raise notice '224: cns_eslestir % kaynak satirinda eski dongu ile AYNI sonucu verdi', v_bakilan;
  end if;
end $$;

select '224 OK — ilan_neden_yok, charter tek yerde, cns_eslestir cikarildi' as sonuc;


-- ════════════════════════════════════════════════════════════════════════
-- 4) İSTEMCİ YÜZEYİ — YENİ FONKSİYONLARIN İZNİ
--
-- 🔴 HARNESS YİNE YAKALADI:
--     "RPC yuzeyi ihlali: lounge_access_decision, gunluk_sinir_durumu,
--      oran_kapisi, cns_eslestir, cns_ad_normalize -> yuzeyde yok ama
--      istemciye acik"
--
-- Sebep PostgreSQL'in varsayılanı: `create function` EXECUTE hakkını
-- otomatik olarak PUBLIC'e verir. Yani `grant` yazmasam da yeni her
-- fonksiyon istemciye açık doğuyor. 203'ün sınırı tam bunun için var —
-- "yanlışlıkla açık" ile "bilerek açık" arasındaki farkı bir BEYAN
-- gösterir.
--
-- Bu beşi de İÇ hesap:
--   lounge_access_decision  → app onu doğrudan çağırmıyor (ölçtüm: `rpc(`
--                             ile geçen tek satır yok); v5/precheck/rozet
--                             üzerinden erişiliyor. 222 fonksiyonu yeniden
--                             yarattığı için izni sıfırlandı ve PUBLIC'e açıldı.
--   gunluk_sinir_durumu     → saf yardımcı
--   oran_kapisi             → tetikleyici içinden çağrılır
--   cns_eslestir / cns_ad_normalize → katalog eşleştirme, yönetim işi
-- ════════════════════════════════════════════════════════════════════════
do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '224: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

do $$
declare v_kalan text;
begin
  select string_agg(fn_name || ' -> ' || neden, ', ')
    into v_kalan from public.rpc_surface_violations();
  if v_kalan is not null and v_kalan <> '' then
    raise exception '224: RPC yuzeyi ihlali SURUYOR → %', v_kalan;
  end if;
  raise notice '224: istemci yuzeyi temiz';
end $$;
