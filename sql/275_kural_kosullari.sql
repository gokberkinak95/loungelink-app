-- ============================================================================
-- 275 · KURAL KOŞULLARI — KARARIN İÇİNİ AÇAN TEK FONKSİYON
-- ============================================================================
--
-- 🔴 NEDEN VAR
--
-- Gökberk'in onayladığı Gece tasarımının 03 numaralı ekranı şu:
--
--     KURAL MOTORU
--     Bu eşleşme neden %84?
--     ┌ KART · ELITE PLUS ─────────────────────────┐
--     │ ✓ Misafir hakkı var · 2 kişilik            │
--     │ ✓ Aynı havayolu · TK                       │
--     │ ✓ Birlikte varış şartı sağlanıyor          │
--     │ ✓ Kabin sınıfı şartı yok                   │
--     │ ✗ Uçuş numarası doğrulanmadı               │
--     └────────────────────────────────────────────┘
--
-- Yani kararı BİR PARAGRAF olarak değil, KOŞUL KOŞUL veriyor. Bu ürünün
-- tek gerçek farkı kural motoru; onu bir paragrafın içine gömmek, farkı
-- görünmez kılmak demek.
--
-- Uygulamada bugün elimizde olan tek yüzey `discovery_rule_badges`:
--   (avail_id, severity, label, info, detail, same_flight_match,
--    blocks_request, sort_boost)
-- `info` tek bir cümle, `detail` ise cümlelerin BOŞLUKLA BİRLEŞTİRİLMİŞ
-- hâli (bkz. 086, `array_to_string(v_notes,' ')`). Yani liste zaten
-- vardı ve tam da dışa verilirken düz metne eziliyordu.
--
-- 🆕 SINIF: **"YAPILI BİR VERİYİ SUNUMDAN ÖNCE METNE ÇEVİRİRSEN, O
-- YAPIYI BİR DAHA GERİ ALAMAZSIN — BİRLEŞTİRME KAYIPLI BİR İŞLEMDİR."**
--
-- Bu fonksiyon hiçbir yeni kural İCAT ETMİYOR. Kararın kendi alanlarını
-- okuyup her birini bir satıra çeviriyor:
--
--   guest_policy + guest_included_count → misafir hakkı
--   carrier_ok / carrier_known          → havayolu şartı
--   flight_coupling                     → birlikte varış / aynı uçuş
--   availabilities.cabin_class          → kabin şartı
--   ziyaretin flight_number'ı           → uçuş numarası doğrulaması
--   member_must_be_present              → host'un yanında olması
--   guest_needs_boarding_pass           → biniş kartı
--
-- ⚠️ ÜÇÜNCÜ BİR DURUM VAR VE ATLANMAMALI: `bilinmiyor`. Bir koşulu
-- bilmiyorsak onu ✓ ya da ✗ diye göstermek YALAN olur. Tasarımda iki
-- işaret çizilmişti (✓ ve ✗) çünkü örnek ilanda üçüncü durum yoktu.
-- Ürün, tasarımın çizmediği durumu da yaşamak zorunda.
--
-- 🆕 SINIF: **"BİR TASARIM ÖRNEĞİ ÜRÜNÜN DURUM UZAYINI DEĞİL, BİR
-- KESİTİNİ GÖSTERİR — ÇİZİLMEYEN DURUMU UYDURMAK DEĞİL, KENDİ KURALINLA
-- DOLDURMAK GEREKİR."**
-- ============================================================================

-- Tablo döndüren bir tanımın dönüş tipi `create or replace` ile
-- değiştirilemez; canlıda "cannot change return type" ile patlar.
drop function if exists public.kural_kosullari(uuid);
create or replace function public.kural_kosullari(p_avail_id uuid)
returns table (
  sira      int,
  kod       text,
  metin     text,
  durum     text,     -- 'ok' | 'yok' | 'bilinmiyor'
  agirlik   text      -- 'kapi' (girişi engeller) | 'not' (bilgi)
)
language plpgsql stable security definer set search_path = public as $$
declare
  d jsonb;
  v_av availabilities%rowtype;
  v_prog lounge_programs%rowtype;
  v_flight text;
  v_uyum boolean;
  v_n int;
begin
  select * into v_av from availabilities where id = p_avail_id;
  if not found then
    return;                       -- ilan yoksa koşul da yok; uydurmuyoruz
  end if;

  -- Misafirin kendi uçuşu: aynı havalimanı + aynı gün.
  select v.flight_number into v_flight
    from visits v
   where v.user_id = auth.uid()
     and v.airport_code = v_av.airport_code
     and v.visit_date = v_av.avail_date
     and coalesce(v.flight_number, '') <> ''
   order by v.created_at desc
   limit 1;

  d := public.lounge_access_decision_v5(p_avail_id, v_flight,
                                        public.guest_carrier_for(p_avail_id));
  select * into v_prog from lounge_programs
   where id = nullif(d ->> 'program_id', '')::uuid;

  -- ── 1 · MİSAFİR HAKKI ────────────────────────────────────────────────
  v_n := nullif(d ->> 'guest_included_count', '')::int;
  sira := 1; kod := 'misafir_hakki'; agirlik := 'kapi';
  if (d ->> 'guest_policy') = 'included' then
    durum := 'ok';
    metin := case when coalesce(v_n, 0) > 0
                  then format('Misafir hakkı var · %s kişilik', v_n)
                  else 'Misafir hakkı var' end;
  elsif (d ->> 'guest_policy') = 'paid' then
    -- Ücretli giriş bir ENGEL değil; kapı açık, bedeli var. `not`.
    durum := 'ok'; agirlik := 'not';
    metin := coalesce(nullif(d ->> 'guest_fee_note', ''), 'Misafir ücretli girer');
  elsif (d ->> 'guest_policy') = 'not_allowed' then
    durum := 'yok';
    metin := 'Bu kart misafir almıyor';
  else
    durum := 'bilinmiyor';
    metin := 'Misafir hakkı doğrulanmadı';
  end if;
  return next;

  -- ── 2 · HAVAYOLU ŞARTI ───────────────────────────────────────────────
  sira := 2; kod := 'havayolu'; agirlik := 'kapi';
  if (d ->> 'carrier_known') is null or (d ->> 'carrier_known') = 'false' then
    durum := 'bilinmiyor'; metin := 'Havayolu şartı bilinmiyor';
  elsif (d ->> 'carrier_ok') = 'true' then
    durum := 'ok';
    metin := case when coalesce(d ->> 'host_carrier', '') <> ''
                  then format('Aynı havayolu · %s', upper(d ->> 'host_carrier'))
                  else 'Havayolu şartı sağlanıyor' end;
  else
    durum := 'yok';
    metin := format('Havayolu şartı tutmuyor · %s ↔ %s',
                    upper(coalesce(d ->> 'host_carrier', '?')),
                    upper(coalesce(d ->> 'guest_carrier', '?')));
  end if;
  return next;

  -- ── 3 · UÇUŞ BAĞI (birlikte varış / aynı uçuş) ───────────────────────
  sira := 3; kod := 'ucus_bagi'; agirlik := 'kapi';
  if coalesce(d ->> 'flight_coupling', 'none') = 'none' then
    durum := 'ok'; agirlik := 'not';
    metin := 'Uçuş birlikteliği şartı yok';
  else
    v_uyum := coalesce(v_flight, '') <> ''
              and coalesce(v_av.flight_number, '') <> ''
              and upper(replace(v_flight, ' ', '')) = upper(replace(v_av.flight_number, ' ', ''));
    if (d ->> 'flight_coupling') = 'same_flight' then
      durum := case when v_uyum then 'ok'
                    when coalesce(v_flight, '') = '' then 'bilinmiyor'
                    else 'yok' end;
      metin := case when v_uyum then 'Aynı uçuş şartı sağlanıyor'
                    when coalesce(v_flight, '') = '' then 'Aynı uçuş şartı var · uçuşunu gir'
                    else 'Aynı uçuş şartı sağlanmıyor' end;
    else
      durum := 'ok';
      metin := 'Birlikte varış şartı sağlanıyor';
    end if;
  end if;
  return next;

  -- ── 4 · KABİN SINIFI ─────────────────────────────────────────────────
  sira := 4; kod := 'kabin'; agirlik := 'not';
  if coalesce(v_av.cabin_class, '') = '' then
    durum := 'ok'; metin := 'Kabin sınıfı şartı yok';
  else
    durum := 'ok'; metin := format('Kabin sınıfı · %s', upper(v_av.cabin_class));
  end if;
  return next;

  -- ── 5 · UÇUŞ NUMARASI DOĞRULAMASI ────────────────────────────────────
  -- Bu bir KAPI değil bir NOT: uçuşunu doğrulamamak girişi engellemiyor,
  -- yalnız eşleşmenin güvenini düşürüyor. Tasarımda ✗ ile çizilmişti ve
  -- doğrusu da bu — ama kırmızı değil AMBER, çünkü kapıyı kapatmıyor.
  sira := 5; kod := 'ucus_dogrulama'; agirlik := 'not';
  if coalesce(v_flight, '') = '' then
    durum := 'yok'; metin := 'Uçuş numarası doğrulanmadı';
  else
    durum := 'ok'; metin := format('Uçuşun kayıtlı · %s', upper(v_flight));
  end if;
  return next;

  -- ── 6/7 · PROGRAMIN KENDİ ŞARTLARI ───────────────────────────────────
  if v_prog.id is not null and coalesce(v_prog.member_must_be_present, false) then
    sira := 6; kod := 'host_yaninda'; agirlik := 'kapi'; durum := 'ok';
    metin := 'Host giriş anında yanında olmalı';
    return next;
  end if;
  if v_prog.id is not null and coalesce(v_prog.guest_needs_boarding_pass, false) then
    sira := 7; kod := 'binis_karti'; agirlik := 'not'; durum := 'ok';
    metin := 'Kendi biniş kartın ve kimliğin gerekir';
    return next;
  end if;
end $$;

revoke all on function public.kural_kosullari(uuid) from public, anon;
grant execute on function public.kural_kosullari(uuid) to authenticated;

-- ── BAŞLIK: KARTIN ADI ──────────────────────────────────────────────────
-- Tasarımdaki kutu başlığı "KART · ELITE PLUS". Program adı zaten
-- karardan geliyor; ayrı bir fonksiyon yazmıyorum — `kural_kosullari`
-- ile aynı çağrıda gelsin diye küçük bir yardımcı.
create or replace function public.kural_kart_adi(p_avail_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(p.name, p.code, 'Kart')
    from availabilities a
    left join lounge_programs p on p.id = a.program_id
   where a.id = p_avail_id;
$$;
revoke all on function public.kural_kart_adi(uuid) from public, anon;
grant execute on function public.kural_kart_adi(uuid) to authenticated;

-- ============================================================================
-- DOĞRULAMA — koşul listesi kararla ÇELİŞİYOR MU?
-- ============================================================================
-- Bir listeyi göstermenin bedeli şu: kullanıcı beş satırın hepsi ✓ iken
-- "başvuramazsın" görürse ürüne bir daha inanmaz. O yüzden nöbetçi
-- listeyi kararın kendisiyle karşılaştırıyor.
--
-- 🆕 SINIF: "BİR KARARI PARÇALARINA AYIRIP GÖSTERİYORSAN, PARÇALARIN
-- TOPLAMI KARARIN KENDİSİYLE AYNI ŞEYİ SÖYLEMEK ZORUNDADIR — YOKSA
-- AÇIKLAMA DEĞİL ÇELİŞKİ ÜRETİRSİN."
do $$
declare
  r record; v_bak int := 0; v_celiski int := 0; v_ornek text := '';
  v_kapi_yok boolean; v_engel boolean;
begin
  for r in select id from availabilities where active limit 200 loop
    v_bak := v_bak + 1;
    select bool_or(durum = 'yok' and agirlik = 'kapi') into v_kapi_yok
      from public.kural_kosullari(r.id);
    select coalesce((public.lounge_access_decision_v5(
             r.id, null, public.guest_carrier_for(r.id)) ->> 'severity') = 'block', false)
      into v_engel;
    -- Liste "kapı kapalı" diyorsa karar da engellemeli.
    if coalesce(v_kapi_yok, false) and not v_engel then
      v_celiski := v_celiski + 1;
      if v_ornek = '' then v_ornek := r.id::text; end if;
    end if;
  end loop;
  raise notice '275: bakılan ilan %, çelişki % (örnek: %)', v_bak, v_celiski,
               coalesce(nullif(v_ornek, ''), 'yok');
end $$;

select 'kural_kosullari' as fonksiyon,
       'hazır — 5..7 koşul, üç durum (ok/yok/bilinmiyor)' as durum;
