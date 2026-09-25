-- ============================================================================
-- 263 - ANA SAYFA AKIS OZETI  (28 Agustos 2026)
--
-- 🔴 GOKBERK (28 Agustos)
-- "ana sayfaya gelen sohbetler, istekler, sorularim gibi alanlar (gerisini
--  sen biliyorsun hepsini yazmadim tek tek) sanki ana sayfaya yansimiyor gibi?"
--
-- OLCTUM VE HAKLIYDI - AMA SEBEP SANDIGIMIZ SEY DEGILDI.
--
-- Ana sayfadaki BUTUN bolumler "bos ise HIC CIZILME" kuralina gore yazilmis:
--   ActionNeeded          → if (!items.length) return null
--   RequestsPanel         → if (!inc.length && !sent.length) return null
--   HomeConnections       → if (!rows.length) return null
--   BaglantiIstekleri     → if (!gelen.length) return null
--   RateReminder          → if (!items.length) return null
--   LoungeRadarCard       → if (!r) return null
--
-- Tek tek bakinca hepsi dogru: bos bir bolum gurultudur. Ama ALTI TANESI
-- ayni anda yok oldugunda ana sayfa "bugun bir sey yok" demekle kalmiyor,
-- "bu ozellikler var mi acaba" dedirtiyor. Kullanici sistemin CALISIP
-- CALISMADIGINI anlayamiyor.
--
-- 🆕 SINIF: "HER BIRI TEK BASINA DOGRU OLAN 'BOSSA GIZLE' KURALLARI BIR
-- ARAYA GELDIGINDE, EKRAN BOS OLDUGUNU DEGIL VAR OLMADIGINI SOYLER."
--
-- VE BIR DE GERCEK BIR OLU KOD: `MyQuestions` bileseni yazilmis, `sorularim()`
-- RPC'si var, App.js onu IMPORT ediyor - ama HICBIR YERDE cizilmiyor.
-- Yani "sorularim" diye bir ekran gercekten YOK. Gokberk onu aramakta
-- hakliydi.
--
-- ============================================================================
-- ⚠️ NEDEN SAYILARI YENIDEN TURETMIYORUM
--
-- Ilk yazimda bes sayiyi bes ayri SELECT ile sifirdan kurdum ve
-- `lounge_questions` diye OLMAYAN bir tabloya dokundum. "Sorularim" bu
-- uruunde ayri bir tablo degil: `connection_requests` uzerinde `avail_id`
-- tasiyan bir kayit (bkz. `sorularim()`).
--
-- Ve asil mesele su: sayilari yeniden turetseydim, EKRANIN gosterdigi liste
-- ile ROZETIN gosterdigi sayi iki AYRI cumleden gelirdi. Ilk gun tutar,
-- ucuncu ay tutmaz — ve tutmadigi gun kullanici rozete inanmayi birakir.
--
-- 🆕 SINIF: "BIR ROZETIN SAYISI, O ROZETIN ACTIGI LISTEDEN GELMELI —
-- AYRI TURETILEN HER SAYI, ER YA DA GEC LISTEYE YALAN SOYLER."
--
-- Bu yuzden fonksiyon mevcut RPC'leri CAGIRIYOR ve sayiyor.
--
-- ⚠️ NEDEN TEK RPC: ayni turda "app bir tik yavas" maddesi de var. Bes ayri
-- cagri ana sayfaya BES tur eklerdi - bir sikayeti cozerken digerini
-- buyutmek olurdu.
--
-- 🆕 SINIF: "BIR EKSIGI KAPATIRKEN ODENEN BEDELI DE OLC — YOKSA HER
-- DUZELTME BASKA BIR SIKAYETIN TOHUMUDUR."
-- ============================================================================

create or replace function public.ana_sayfa_akisi()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $asa263$
declare
  v_uid uuid := auth.uid();
  v_sohbet int := 0;
  v_istek  int := 0;
  v_davet  int := 0;
  v_soru   int := 0;
  v_baglanti int := 0;
  v_ilan   int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('sohbet',0,'istek',0,'davet',0,'soru',0,'baglanti',0,'ilan',0);
  end if;

  -- SOHBETLER: ana sayfadaki "Baglantilarim" listesinin uzunlugu.
  -- `home_connections()` kendi 24 saat kuralini uyguluyor; rozet de AYNI
  -- kurali gorsun diye o fonksiyondan sayiliyor.
  select count(*)::int into v_sohbet from public.home_connections();

  -- ISTEKLER: bekleyen misafir istekleri — hem bana gelen hem gonderdigim.
  select count(*)::int into v_istek
    from requests r
   where r.status = 'pending'
     and (r.host_id = v_uid or r.guest_id = v_uid);

  -- DAVETLER ve SORULAR: ikisi de `pending_actions()`ten. O fonksiyon
  -- ana sayfadaki "AKSIYON GEREKLI" kartinin kaynagi; rozet onunla ayni
  -- cumleyi kuruyor.
  select count(*) filter (where pa.kind = 'invite')::int
    into v_davet
    from public.pending_actions() pa;

  -- SORULARIM: sordugum ve HENUZ YANITLANMAMIS sorular. `sorularim()`
  -- listesinin kendisinden sayiliyor — ekranla rozet ayrisamaz.
  select count(*)::int into v_soru
    from public.sorularim() s
   where coalesce(s.cevap_durumu, '') not in ('yanitlandi', 'acildi');

  -- ILANLAR: yayindaki aktif ilanlarim (bugun ve sonrasi).
  -- 🔴 Gokberk'in listesinde vardi, ilk surumde ATLAMISIM: "istek, sohbet,
  -- soru, davet, ILAN gibi alanlar". Sayi yalniz HOST icin anlamli; guest
  -- icin her zaman 0 doner ve arayuz o cipi hic cizmez.
  select count(*)::int into v_ilan
    from availabilities a
   where a.host_id = v_uid and a.active and a.avail_date >= current_date;

  -- BAGLANTI: bana gelen bekleyen baglanti istekleri.
  select count(*)::int into v_baglanti
    from connection_requests cr
   where cr.to_id = v_uid and cr.status = 'pending';

  return jsonb_build_object(
    'sohbet', coalesce(v_sohbet, 0),
    'istek',  coalesce(v_istek, 0),
    'davet',  coalesce(v_davet, 0),
    'soru',   coalesce(v_soru, 0),
    'baglanti', coalesce(v_baglanti, 0),
    'ilan', coalesce(v_ilan, 0)
  );
end $asa263$;

revoke all on function public.ana_sayfa_akisi() from public, anon;
grant execute on function public.ana_sayfa_akisi() to authenticated;

-- ── NOBETCI ────────────────────────────────────────────────────────────
-- 🔴 BU FONKSIYON UC RPC VE IKI TABLOYA DOKUNUYOR. Herhangi birinde
-- olmayan bir kolon, `create` sirasinda DEGIL CAGRI sirasinda patlar —
-- yani "kuruldu" demek "calisiyor" demek degildir. Nobetci CAGIRIYOR.
--
-- 🆕 SINIF: "COK KAYNAGA DOKUNAN BIR SORGUYU KURMAK ONU DOGRULAMAZ —
-- POSTGRES PLANI CAGRI ANINDA COZER, KURULUM ANINDA DEGIL."
do $nb263$
declare v jsonb;
begin
  select public.ana_sayfa_akisi() into v;
  if v is null then
    raise exception '263 NOBETCI: ana_sayfa_akisi null dondu.';
  end if;
  if not (v ? 'sohbet' and v ? 'istek' and v ? 'davet' and v ? 'soru'
          and v ? 'baglanti' and v ? 'ilan') then
    raise exception '263 NOBETCI: eksik anahtar. Donen: %', v;
  end if;
  raise notice '263 NOBETCI OK: ana_sayfa_akisi calisiyor → %', v;
end $nb263$;
