-- ============================================================================
-- LoungeLink · 192a_PRE_charter_tabanda.sql            (18 Ağustos 2026)
--
-- 🔴 192'NİN BEKÇİSİ HAKLI. KUSUR VERİDE DEĞİL, MOTORDA.
--
-- 192 şunu diyor:
--     ERROR: 192: 1 ilanda on kontrol ile karar AYRISIYOR
-- Bekçi hangi ilan olduğunu `raise warning` ile yazıyor ama Supabase SQL
-- Editor uyarıları göstermiyor; o yüzden sebep görünmüyordu. Ölçtüm.
--
-- ── ÖLÇÜM ───────────────────────────────────────────────────────────
-- Ayrışan ilan: IST · Turkish Airlines Lounge — Dış Hat (Miles&Smiles)
-- host kartı ELPL (Elite Plus), host'un seferi CHARTER.
--
--   request_precheck(ilan)          → guest_policy = not_allowed
--       "Elite Plus kartında misafir hakkı yok
--        Host'un seferi CHARTER. Havayolu salonlarında charter seferde
--        bilet sınıfı ya da statü kartı geçmez."
--
--   lounge_access_decision(ilan,null) → guest_policy = included
--       "Misafir hakkı var (1 kişi), ek ücret yok."
--
-- İkisi AYNI ilan için birbirinin tam tersini söylüyor.
--
-- ── SEBEP: ZİNCİRİN İKİ UCU ─────────────────────────────────────────
-- Karar motoru katmanlı:
--     v5 → v4 → v3 → v2 → lounge_access_decision   (taban)
-- Charter kuralını **v4** uyguluyor (`charter_note()` ile). Taban
-- bilmiyor. `request_precheck` v5'i çağırdığı için doğru cevabı alıyor.
--
-- Ama tabanı ÇAĞIRAN KULLANICI YÜZEYLERİ VAR — ölçtüm:
--     discover_availabilities_prerank   ← KEŞİF LİSTESİ
--     my_sent_requests                  ← GÖNDERDİĞİM TALEPLER
--     availability_rule_snapshot · paid_guest_credit · ...
--
-- Yani keşif kartında **"Misafir hakkı var (1 kişi), ek ücret yok"**
-- yazıyor; misafir o ilana girince **"Charter seferde salon hakkı yok"**
-- görüyor. Ürünün tek cümlesi "kapıda ne olacağını biliyoruz" iken
-- listede bir şey, bir tık ötede tersi yazıyor.
--
-- ── BENİM HARNESS'IM BUNU NEDEN GÖRMEDİ ─────────────────────────────
-- 192'nin bekçisi `... from availabilities where active limit 25` diyor.
-- Bende 27 aktif ilan var ve ayrışan ilan sıralamada 25'ten sonraya
-- düşüyordu. Yani bekçi doğru yazılmış ama KAPSAMI ŞANSA bağlıydı;
-- satır sırası değişse bende de patlardı. Gökberk'te patladı.
-- (Bu dosyayla birlikte 192'nin limiti de kaldırılıyor.)
--
-- ── DÜZELTME ────────────────────────────────────────────────────────
-- Charter kuralı TABANA iniyor. Sarmalayıcı deseniyle: taban
-- `_prebase` adına alınıyor, aynı imzalı yeni `lounge_access_decision`
-- onu çağırıp `charter_note()` sonucunu uyguluyor.
--
-- Neden v4'ü kopyalamıyorum da tabanı düzeltiyorum: kusur "v4 eksik"
-- değil, "tabanı çağıran yüzeyler charter'ı hiç görmüyor". Tek tek her
-- çağıranı v5'e çevirmek beş ayrı yerde beş ayrı fırsat demekti; kural
-- motorunun DOĞRUSU tek yerde durmalı. v4 charter'ı yine uygular —
-- aynı sonucu ikinci kez yazmak zararsız (ölçüldü).
--
-- İmza ve dönüş tipi `pg_get_function_arguments`/`_result` ile
-- KOPYALANIYOR, elle yazılmıyor: bu depoda sarmalayıcının imzayı elle
-- yazması daha önce 22P02'ye yol açtı (hata sınıfı 21).
--
-- KULLANIM: 192'den ÖNCE çalıştır.
-- ============================================================================

do $sarmala$
declare
  v_oid  oid;
  v_args text;
  v_res  text;
  v_cagri text;
begin
  select p.oid into v_oid
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'lounge_access_decision'
   limit 1;

  if v_oid is null then
    raise exception '192a: lounge_access_decision bulunamadi';
  end if;

  -- Zaten sarmalanmış mı? (dosyayı iki kez çalıştırmak zararsız olmalı)
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = 'lounge_access_decision_prebase') then
    raise notice '192a: taban zaten sarmalanmis — atlandi';
    return;
  end if;

  v_args := pg_get_function_arguments(v_oid);       -- DEFAULT'lari korur
  v_res  := pg_get_function_result(v_oid);
  -- Çağrı listesi: yalnız parametre ADLARI
  select string_agg(split_part(btrim(x), ' ', 1), ', ')
    into v_cagri
    from unnest(string_to_array(pg_get_function_identity_arguments(v_oid), ',')) x;

  execute format('alter function public.lounge_access_decision(%s) '
                 'rename to lounge_access_decision_prebase',
                 pg_get_function_identity_arguments(v_oid));

  execute format($f$
    create function public.lounge_access_decision(%s) returns %s
    language plpgsql stable security definer set search_path = public as $BODY$
    declare
      d  jsonb;
      ch jsonb;
    begin
      d  := public.lounge_access_decision_prebase(%s);
      ch := public.charter_note(p_avail_id);

      -- charter_note bilmiyorsa tabana DOKUNMA (yanlis engel uretme)
      if ch is null or not coalesce((ch ->> 'blocked')::boolean, false) then
        return coalesce(d, '{}'::jsonb) || jsonb_build_object('charter', false);
      end if;

      -- v4 ile AYNI cumleler: iki katman ayni seyi soylemeli, yoksa
      -- 192'nin bekcisi yine ayrisma gorur.
      return coalesce(d, '{}'::jsonb) || jsonb_build_object(
        'severity',     'block',
        'guest_policy', 'not_allowed',
        'charter',      true,
        'headline',     'Charter seferde salon hakkı yok',
        'detail',       trim(both ' ' from coalesce(d ->> 'detail','') || ' ' ||
                          coalesce(ch ->> 'note',
                            'Havayolu salonlarında charter seferde bilet sınıfı '
                            'ya da statü kartı geçmez.')));
    end $BODY$$f$, v_args, v_res, v_cagri);

  raise notice '192a: taban artik charter kuralini uyguluyor';
end
$sarmala$;

-- ── NÖBETÇİ 1 · SARMALAYICI SÖZLEŞMESİ ──────────────────────────────
-- İmza ve dönüş tipi delegeyle BİREBİR aynı olmalı. (Hata sınıfı 21:
-- bir sarmalayıcı `returns boolean` yazmıştı, delegesi uuid dönüyordu;
-- beş çağıran 22P02 aldı.)
do $n1$
declare a1 text; a2 text; r1 text; r2 text;
begin
  select pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid)
    into a1, r1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='lounge_access_decision';
  select pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid)
    into a2, r2 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='lounge_access_decision_prebase';
  if a1 is distinct from a2 or r1 is distinct from r2 then
    raise exception '192a: sarmalayici sozlesmesi BOZUK — arg(% vs %) donus(% vs %)',
      a1, a2, r1, r2;
  end if;
  raise notice '192a: sarmalayici imzasi delegeyle ayni ✓';
end $n1$;

-- ── NÖBETÇİ 2 KALDIRILDI — VE SEBEBİ ────────────────────────────────
--
-- 🔴 BU DOSYAYA "ayrışma bitti mi" nöbetçisi KOYMUŞTUM VE YANLIŞTI.
-- Gökberk'te şunu verdi:
--     192a: 5 / 31 ilanda AYRISMA SURUYOR:
--       || b239a673 ADB precheck=(YOK) karar=not_allowed
--       || 23fae8d6 IST precheck=(YOK) karar=unknown   ...
--
-- `precheck=(YOK)` = `request_precheck` payload'ında `guest_policy`
-- alanı HİÇ YOK. Sebep basit ve tamamen benim kurgu hatam:
--
--     `request_precheck`'i düzelten dosya **192**'nin kendisi.
--     Bu dosya 192'den ÖNCE çalışıyor.
--     Yani nöbetçim, HENÜZ YAMALANMAMIŞ bir fonksiyonu sınıyordu.
--
-- 192 precheck'e "seyahat kapısı" (trip_gate) dalını ekliyor ve kendi
-- bekçisi o dalı zaten atlıyor. Yamadan önce o ilanlar başka bir dala
-- düşüp `guest_policy` taşımıyor, nöbetçim de bunu ayrışma sanıyordu.
--
-- Bende yakalanmamasının sebebi yine kapsam: SEED verisi o dallara hiç
-- düşmüyor. Yani nöbetçi yanlış yerdeydi ve benim verimde yanlış
-- olduğunu gösterecek durum yoktu.
--
-- Ayrışma denetimi ASIL YERİNDE duruyor: 192'nin kendi bekçisinde,
-- precheck yamalandıktan SONRA, ve artık `limit 25` olmadan.
-- Burada yalnız sarmalayıcı sözleşmesi denetleniyor (yukarıdaki
-- Nöbetçi 1) — o, bu dosyanın kendi işiyle ilgili tek doğrulama.
