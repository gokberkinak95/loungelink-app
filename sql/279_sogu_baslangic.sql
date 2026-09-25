-- ============================================================
-- LoungeLink · sql/279_sogu_baslangic.sql
-- 31 Ağustos 2026
--
-- 🔴 SOĞUK BAŞLANGIÇ — ÜRÜNÜN EN PAHALI EKRANI
--
-- İki taraflı bir pazarın en pahalı anı, ilk misafirin Keşfet'i açıp
-- HİÇBİR ŞEY görmediği andır. Bugün o ekranda "Haber ver" var (247) —
-- yani TALEBİ yakalıyoruz. Ama ARZ tarafına dair tek kelime etmiyoruz.
--
-- ⚠️ EN KOLAY ÇÖZÜM YASAK. "Bu uçuşta 3 host var" gibi TAHMİNİ bir arzı
-- gerçek arz gibi göstermek, ürünün tek sermayesini — güveni — bir kerede
-- harcar. Kullanıcı gelir, kimseyi bulamaz, bir daha açmaz.
--
-- 🆕 SINIF: "BOŞ BİR PAZARI DOLU GÖSTERMEK, PAZARI DOLDURMAZ —
-- YALNIZCA İLK KULLANICIYI KAYBETTİRİR."
--
-- ── BUNUN YERİNE: SÖYLEYEBİLECEĞİMİZ DOĞRU ŞEY ──────────────────
--
-- Elimizde uydurmaya gerek bırakmayan bir şey var: KURAL MOTORU.
-- O havalimanındaki salonlar için "hangi kart programları misafir
-- hakkı veriyor" sorusunun cevabı veritabanımızda DURUYOR ve
-- doğrulanabilir.
--
-- Yani boş ekran şunu diyebilir:
--
--     "Burada henüz yayında host yok.
--      Ama bu havalimanının 6 salonunda, 4 kart programı
--      misafir hakkı veriyor — yanındaki kişi de olabilirsin."
--
-- Bu cümlenin her parçası ÖLÇÜLMÜŞ. Ve iki iş birden yapıyor:
--   1) misafire "bu ürün çalışıyor, arz henüz yok" diyor
--   2) ONA HOST OLMAYI öneriyor — çünkü belki kartı zaten uygundur
--
-- İkincisi asıl kazanç: soğuk başlangıcı çözecek kişi, ondan en çok
-- yakınan kişidir.
-- ============================================================

create or replace function public.sogu_baslangic_ozeti(p_airport text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_salon    int := 0;
  v_program  int := 0;
  v_hak      int := 0;
  v_benim    boolean := false;
  v_uid      uuid := auth.uid();
begin
  if p_airport is null or length(trim(p_airport)) = 0 then
    return jsonb_build_object('salon', 0, 'program', 0, 'hak', 0,
                              'kartin_uygun', false);
  end if;

  select count(distinct l.id) into v_salon
    from lounges l
   where upper(l.airport_code) = upper(trim(p_airport));

  -- Misafir hakkı VEREN program sayısı. `guest_allowance > 0` tek
  -- ölçüt: "aile serbest" ayrı bir kural ve misafir hakkı değil.
  -- 🔴 İLK YAZIMDA `lounge_guest_rules.venue_id` ÜZERİNDEN BAĞLADIM VE
  -- SONUÇ HER HAVALİMANINDA 0 ÇIKTI. Ölçtüm: 262 kuralın 141'i misafir
  -- hakkı veriyor ama hiçbiri bir SALONA bağlı değil — hepsi PROGRAM
  -- düzeyinde ("bu kart programı N misafir verir, nerede olursa olsun").
  -- Salona bağlanma yolu `lounge_venue_acceptance`: hangi mekân hangi
  -- programı kabul ediyor.
  --
  -- Nöbetçi bunu yakaladı çünkü GERÇEK BİR SAYI bekliyor; "0 döndü ama
  -- çalıştı" diye geçseydi ekran her havalimanında boş bir cümle
  -- kuracaktı.
  --
  -- 🆕 SINIF: "BİR JOIN'İN ÇALIŞMASI, DOĞRU TABLOYA BAĞLANDIĞI ANLAMINA
  -- GELMEZ — SIFIR SATIR DA GEÇERLİ BİR SONUÇTUR VE EN SESSİZ HATADIR."
  select count(distinct r.program_id), coalesce(max(r.guest_allowance), 0)
    into v_program, v_hak
    from lounges l
    join lounge_venue_acceptance a on a.venue_id = l.venue_id
    join lounge_guest_rules r on r.program_id = a.program_id
   where upper(l.airport_code) = upper(trim(p_airport))
     and coalesce(r.guest_allowance, 0) > 0;

  -- ── EN DEĞERLİ SATIR: KULLANICININ KENDİ KARTI UYGUN MU? ──────
  -- 🔴 Bu, boş ekranı bir davete çeviren şey. Kullanıcıya "birileri
  -- host olabilir" demek soyut; "SENİN kartın bu havalimanında
  -- misafir hakkı veriyor" demek somut ve eyleme çağırır.
  if v_uid is not null then
    select exists (
      select 1
        from user_cards uc
        join lounge_guest_rules r on r.program_id = uc.program_id
        join lounge_venue_acceptance a on a.program_id = uc.program_id
        join lounges l on l.venue_id = a.venue_id
       where uc.user_id = v_uid
         and upper(l.airport_code) = upper(trim(p_airport))
         and coalesce(r.guest_allowance, 0) > 0
    ) into v_benim;
  end if;

  return jsonb_build_object(
    'salon',        v_salon,
    'program',      v_program,
    'hak',          v_hak,
    'kartin_uygun', coalesce(v_benim, false));
end $$;

comment on function public.sogu_baslangic_ozeti(text) is
  'Boş Keşfet ekranı için ÖLÇÜLMÜŞ gerçekler: o havalimanındaki salon '
  'sayısı, misafir hakkı veren program sayısı ve kullanıcının KENDİ '
  'kartının uygun olup olmadığı. Tahmini arz DÖNDÜRMEZ — bkz. 279 başlığı.';

revoke all on function public.sogu_baslangic_ozeti(text) from public;
grant execute on function public.sogu_baslangic_ozeti(text) to authenticated;

-- ── NÖBETÇİ 1: UYDURMA ARZ SIZMIYOR ─────────────────────────────
-- 🔴 BU KAPININ TEK İŞİ: gelecekte biri bu fonksiyona "tahmini host
-- sayısı" eklemeye kalkarsa DURDURMAK. Dönen anahtar kümesi sabit.
do $$
declare v jsonb; v_anahtar text[];
begin
  select public.sogu_baslangic_ozeti('IST') into v;
  select array_agg(k order by k) into v_anahtar from jsonb_object_keys(v) k;
  if v_anahtar is distinct from array['hak','kartin_uygun','program','salon'] then
    raise exception '279: donen anahtarlar degisti (%) — tahmini arz eklenmis olabilir', v_anahtar;
  end if;
  -- ⚠️ SIFIR DA BİR CEVAPTIR AMA BURADA YANLIŞ CEVAPTIR: IST'te 37 salon
  -- ve misafir hakkı veren 3 program olduğunu ölçtük. 0 dönüyorsa join
  -- yanlış tabloya bağlanmış demektir (ilk yazımda tam bu oldu).
  if (v->>'salon')::int = 0 or (v->>'program')::int = 0 then
    raise exception '279: IST icin % salon / % program dondu — join yanlis tabloya bagli',
      v->>'salon', v->>'program';
  end if;
  raise notice '279 NOBETCI OK: yalniz olculmus gercekler donuyor (IST: % salon, % program)',
    v->>'salon', v->>'program';
end $$;

-- ── NÖBETÇİ 2: BOŞ GİRDİ ÇÖKMÜYOR ───────────────────────────────
do $$
declare v jsonb;
begin
  select public.sogu_baslangic_ozeti(null) into v;
  if (v->>'salon')::int <> 0 then
    raise exception '279: null havalimani icin sifir donmedi';
  end if;
  select public.sogu_baslangic_ozeti('') into v;
  raise notice '279 NOBETCI OK: bos/null girdi guvenli';
end $$;
