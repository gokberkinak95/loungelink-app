-- ============================================================
-- LoungeLink · 183_lounges_rpc_and_grants.sql
-- SALON LİSTELERİNİN BOŞ GELMESİ — DOĞRUDAN TABLO SORGUSUNU BIRAKIYORUZ
--
-- ⚠️ Uygulamayı ETKİLER (yeni RPC + katalog grantları).
--
-- ------------------------------------------------------------
-- 🔴 TEŞHİS
-- ------------------------------------------------------------
-- Gökberk'in verisinde salonlar YERİNDE (AYT 7, SAW 7, IST 5, ESB 4…),
-- bende de liste dolu geliyor. Yani veri değil ERİŞİM YOLU sorunlu.
-- App şunu yapıyor:
--     from("lounges").select(...).eq("active",true).eq("airport_code", ap.key)
-- Bu doğrudan tablo sorgusu ÜÇ ayrı sebeple sessizce boş dönebilir:
--   1. RLS/GRANT — tablo görünmüyorsa PostgREST hata değil BOŞ döner
--      (bu projede tam olarak yaşandı: SQL 159, "politika var grant yok")
--   2. KOD EŞLEŞMESİ — ap.key ile airport_code büyük/küçük harf veya
--      boşluk farkı taşıyorsa eşleşme olmaz
--   3. Katalog satırı venue'ya bağlı değilse filtrelerden düşer
--
-- Üçünü de tek hamlede kapatmanın yolu: doğrudan tablo sorgusunu
-- bırakıp SECURITY DEFINER bir RPC kullanmak. RPC hem RLS'i aşar
-- (okuma için güvenli: yalnız aktif katalog döner), hem kodu
-- normalize eder, hem de katalog boşsa VENUE tablosundan yedekler.
-- ============================================================

-- ---- 1) EKSİK KATALOG GRANTLARI ----
-- Ölçüldü: authenticated rolünde lounge_venue_acceptance, lounge_guest_rules
-- ve carriers üzerinde SELECT YOK. Bugün app bunları doğrudan sorgulamıyor
-- ama rehber/kural ekranları büyüdükçe sorgulayacak ve aynı sessiz boşluk
-- sınıfı tekrar edecek. Okuma hakkı şimdi veriliyor (hepsi genel katalog
-- verisi; kişisel veri içermez).
grant select on lounge_venue_acceptance, lounge_guest_rules, carriers,
                lounge_programs, lounge_venues, lounges, airports
  to authenticated;
grant select on lounge_programs, lounge_venues, lounges, airports,
                lounge_venue_acceptance, lounge_guest_rules, carriers
  to anon;   -- rehber ekranı giriş yapmadan da çalışır (SEO + ilk izlenim)

-- ---- 2) SALON LİSTESİ RPC ----
-- ════════════════════════════════════════════════════════════════════
-- 🔴 21 AĞUSTOS — İKİ TUR ÖNCE SÖZ VERDİM, İKİ TUR GEÇTİ. ŞİMDİ KONDU.
--
-- 158'e koyduğum korumanın mutasyon testi BAŞKA bir gerçek örnek daha
-- buldu ve raporda aynen şöyle yazdı:
--
--     ✗ GERILEME — tekrar kurulum 1 fonksiyonu ESKI haline dusurdu:
--        lounges_for_airport() 10 -> 8 kolon
--
-- Yani bu dosya tek başına çalıştırılırsa 190'ın tanımını EZİYOR:
--   183 (bu dosya): 7 çıktı kolonu   → `section` ve `display_name` YOK
--   190           : 9 çıktı kolonu   → app'in modal sekmeleri bunlara bakıyor
-- Sonuç, `guest_policy` olayının aynısı olurdu: dosya BAŞARIYLA koşar,
-- hata vermez, uygulama sessizce eksik çalışır.
--
-- 🆕 KURAL (158 ile aynı): **ESKİ BİR MIGRATION, KENDİNDEN YENİ BİR
-- HÂLİ EZEMEZ.** Aşağıdaki blok canlıdaki tanımı ÖLÇÜYOR; sözleşme
-- zaten daha genişse (>= 9 toplam argüman = 1 girdi + 8+ çıktı)
-- DOKUNMUYOR ve bunu yazıyor. Boş veritabanına kurulumda eskisi gibi
-- kurar, sıra bozulmaz.
--
-- ⚠️ NEDEN `drop` HÂLÂ VAR: dönüş tipi değişmediğinde `create or
-- replace` yeterli olurdu ama bu dosya BOŞ veritabanında da koşuyor ve
-- oradaki tip farkı 42P13 verir. `drop` yalnızca korumanın içinde,
-- yani yalnızca gerçekten kurulacaksa çalışıyor.
-- ════════════════════════════════════════════════════════════════════
do $lfa183$
declare
  v_kolon int;
begin
  select coalesce(array_length(p.proallargtypes,1), 0) into v_kolon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='lounges_for_airport'
   limit 1;

  if coalesce(v_kolon,0) >= 9 then
    raise notice '183: lounges_for_airport zaten daha yeni bir surumde '
                 '(% toplam argüman) — DOKUNULMADI. 190 gecerli kalir.', v_kolon;
    return;
  end if;

  drop function if exists public.lounges_for_airport(text);
  execute $lfa_govde$
create or replace function public.lounges_for_airport(p_airport text)
returns table (
  id uuid, name text, terminal text, access_types text[],
  venue_scope text, accepts_guests boolean, note text
)
language plpgsql stable security definer set search_path = public as $lfa_inner$
declare v_ap text;
begin
  -- Kod normalize: 'ist', ' IST ', 'Ist' hepsi IST olur.
  v_ap := upper(btrim(coalesce(p_airport, '')));
  if v_ap = '' then return; end if;

  return query
  select l.id, l.name, l.terminal, l.access_types,
         v.scope,
         -- Bu salon HERHANGİ bir programda misafir kabul ediyor mu?
         -- Liste ekranında "misafirle girilebilir" ipucu için.
         exists (select 1 from lounge_venue_acceptance a
                  where a.venue_id = v.id and a.active and a.accepted
                    and coalesce(a.guest_policy,'') <> 'not_allowed'),
         null::text
    from lounges l
    left join lounge_venues v on v.id = l.venue_id and v.active
   where l.active and upper(btrim(l.airport_code)) = v_ap
   order by coalesce(v.scope = 'domestic', false) desc, l.name;  -- 187: NULL en basa cikmasin

  -- 🔴 YEDEK YOL: katalog o havalimanı için boşsa doğrudan VENUE
  -- tablosundan üret. Katalog uzlaştırması (158/160/161) bir ortamda
  -- eksik kalmışsa kullanıcı boş liste görmez; ürün çalışmaya devam eder.
  if not found then
    return query
    select v.id, v.name, null::text, null::text[],
           v.scope,
           exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.active and a.accepted
                      and coalesce(a.guest_policy,'') <> 'not_allowed'),
           null::text
      from lounge_venues v
     where v.active and upper(btrim(v.airport_code)) = v_ap
       and coalesce(v.venue_kind, 'lounge') = 'lounge'
     order by coalesce(v.scope = 'domestic', false) desc, v.name;  -- 187: NULL en basa cikmasin
  end if;
end $lfa_inner$;
  $lfa_govde$;
  raise notice '183: lounges_for_airport kuruldu (7 kolonlu ozgun hali)';
end $lfa183$;

grant execute on function public.lounges_for_airport(text) to authenticated, anon;

-- ---- 3) BEKÇİ: her aktif havalimanı salon döndürmeli ----
do $$
declare r record; v_bos int := 0; v_top int := 0;
begin
  for r in
    select distinct upper(btrim(l.airport_code)) as ap
      from lounges l where l.active
  loop
    v_top := v_top + 1;
    if (select count(*) from public.lounges_for_airport(r.ap)) = 0 then
      v_bos := v_bos + 1;
      raise notice '183: % için salon listesi BOŞ dönüyor', r.ap;
    end if;
  end loop;

  if v_top = 0 then
    raise exception '183: aktif salonu olan havalimanı yok — katalog boş';
  end if;
  if v_bos > 0 then
    raise exception '183: % havalimanında liste boş (toplam %)', v_bos, v_top;
  end if;
  raise notice '183: % havalimanının hepsi salon döndürüyor ✓', v_top;
end $$;

-- ---- 4) KANIT: normalize gerçekten çalışıyor ----
do $$
declare a int; b int; c int;
begin
  select count(*) into a from public.lounges_for_airport('IST');
  select count(*) into b from public.lounges_for_airport('ist');
  select count(*) into c from public.lounges_for_airport('  Ist ');
  if a = 0 then raise exception '183: IST boş döndü'; end if;
  if a <> b or a <> c then
    raise exception '183: kod normalize çalışmıyor (IST=% ist=% " Ist "=%)', a, b, c;
  end if;
  raise notice '183: IST % salon · büyük/küçük harf ve boşluk farkı sorun değil ✓', a;
end $$;

select '183 OK - salon listesi RPC + katalog grantlari' as sonuc;
