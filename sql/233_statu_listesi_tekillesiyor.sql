-- ============================================================================
-- LoungeLink · 233_statu_listesi_tekillesiyor.sql           (22 Ağustos 2026)
--
-- "STATÜN NE?" LİSTESİNDE AYNI STATÜ ÜÇ KEZ ÇIKIYOR (Gökberk, madde 8)
--
-- Ekran görüntüsünde: Corporate Club ×2, Elite ×3, Elite Plus ×2 —
-- hepsi "1 misafir" yazıyor, yani kullanıcı için AYIRT EDİLEMEZ üç
-- seçenek. Hangisine bassa aynı şeyi seçmiş oluyor.
--
-- ════════════════════════════════════════════════════════════════════════
-- KÖK SEBEP — veri değil, PROJEKSİYON
-- ════════════════════════════════════════════════════════════════════════
-- `lounge_guest_rules` bir KOŞUL→SONUÇ MATRİSİ; grain'i:
--     (program, salon, kapsam, havayolu, kart_tipi, kabin, yürürlük)
-- Yani bir statünün birden çok satırı OLMASI GEREKİR (198'in kendi notu:
-- "KURAL SALON DÜZEYİNDE YAZILIR, KAPSAM DÜZEYİNDE DEĞİL").
--
-- Hata `card_tier_options`'ın o matrisi düzleştirme biçiminde
-- (100_tier_fee_and_time.sql:155-178):
--
--     group by r.card_tier, r.guest_allowance, r.family_allowed, r.notes
--                                                        ↑↑↑↑↑
-- SERBEST METİN bir gruplama anahtarı. Notu bir karakter farklı olan her
-- kural satırı ayrı bir seçenek olarak ekrana düşüyor. Örnek:
--   146:59-62  carrier='TK'          · 1 misafir · aile var
--   146:94-95  carrier='STAR_ALLIANCE'· 1 misafir · aile yok
--   156:189    venue_scope='abroad'  · 1 misafir · "yurt dışında yalnız..."
--   168:145    salon bazlı istisna   · nota "(168: ...)" ekliyor
--
-- 🆕 SINIF: **"SERBEST METİN BİR GRUPLAMA ANAHTARI DEĞİLDİR."**
--
-- ════════════════════════════════════════════════════════════════════════
-- BUNUN İKİ SESSİZ SONUCU DAHA VARDI — Gökberk bunları GÖRMEDİ
-- ════════════════════════════════════════════════════════════════════════
-- (a) YAZDIĞI YER TEK SATIR. App yalnız `tier` kodunu saklıyor
--     (screens.js:6464 → save_host_card p_tier) ve depolama anahtarı
--     `uq_he (user_id, program_id, coalesce(tier,''))` (086:318).
--     Yani üç seçenek AYNI satıra yazıyor: fazladan seçenekler görsel
--     gürültü değil, ŞEMADA KARŞILIĞI OLMAYAN seçeneklerdi.
--
-- (b) SEÇTİĞİNİ DEĞİL, İLKİNİ GÖSTERİYORDU. screens.js:6457 ve 6477
--     `tiers.find(x => x.tier === tier)` yapıyor — kapalı buton etiketi
--     ve "misafir hakkın yok" uyarısı, kullanıcının bastığı satıra değil
--     LİSTEDE İLK GELENE bakıyordu. Kullanıcı "1 misafir veya aile"
--     yazan satırı seçip, altında "aile yok" uyarısı görebiliyordu.
--
-- ════════════════════════════════════════════════════════════════════════
-- ÜÇÜNCÜ KUSUR — ETİKET SÜRÜKLENMESİ
-- ════════════════════════════════════════════════════════════════════════
-- `card_tier_options` kendi CASE'ini yazıyordu. 184 merkezî
-- `card_tier_label()`'ı düzeltti (MS_EC → 'Elite Corporate',
-- MS_US_CC → 'Miles&Smiles Amex' — 184 eskisini "yanlış ad" diye
-- adlandırıyor) ama bu kopya güncellenmedi. Sonuç: kurulum ekranı ile
-- rehber ekranı AYNI statüye FARKLI ad veriyordu.
--
-- 🆕 SINIF: **"AYNI BİLGİNİN İKİNCİ BİR KOPYASI, BİRİNCİSİ DÜZELDİĞİNDE
-- YALAN SÖYLEMEYE BAŞLAR."** (site paletinde, hukuki metinde, marka
-- işaretinde aynı sınıf.)
--
-- ⚠️ `lounge_guest_rules` TEKİLLEŞTİRİLMİYOR — matris olduğu gibi kalıyor.
-- Düzelen tek şey, kullanıcıya sunulan projeksiyon.
-- ============================================================================

-- sqlcheck: allow-replace card_tier_options  (returns table AYNI: tier, label,
--            guest_allowance, family_allowed, note — 100 ile birebir 5 kolon)
create or replace function public.card_tier_options(p_program_code text)
returns table (tier text, label text, guest_allowance smallint,
               family_allowed boolean, note text)
language sql stable security definer set search_path = public as $cto$
  -- Statü başına TEK satır. Hangi satırın kazanacağı rastgele değil:
  --   1) en cömert misafir hakkı (kullanıcı kendi tavanını görsün)
  --   2) aile hakkı olan
  --   3) koşulsuz olan (carrier/venue/scope null = "her durumda")
  -- Böylece kurulum ekranı statünün EN GENİŞ hâlini gösterir; daralma
  -- kararını kural motoru uçuş/salon bilindiğinde zaten veriyor.
  select distinct on (r.card_tier)
         r.card_tier,
         public.card_tier_label(r.card_tier),   -- 184: TEK kaynak
         r.guest_allowance,
         r.family_allowed,
         -- Not artık gruplama anahtarı DEĞİL, yalnız gösterim.
         r.notes
    from lounge_guest_rules r
    join lounge_programs p on p.id = r.program_id
   where p.code = p_program_code
     and r.card_tier is not null
     and (r.effective_to is null or r.effective_to >= current_date)
   order by r.card_tier,
            r.guest_allowance desc nulls last,
            r.family_allowed desc nulls last,
            (r.carrier is null) desc,
            (r.venue_id is null) desc,
            (r.venue_scope is null) desc,
            r.notes nulls last;
$cto$;
grant execute on function public.card_tier_options(text) to authenticated;

comment on function public.card_tier_options(text) is
  'Kurulum ekranindaki statu listesi. STATU BASINA TEK SATIR: lounge_guest_rules '
  'bir kosul-sonuc matrisidir, statu katalogu degildir. Etiket card_tier_label() '
  'tek kaynagindan gelir (184).';

-- ----------------------------------------------------------------------------
-- NÖBETÇİ — "tekilleşti" bir iddiadır; ölçüyorum
-- ----------------------------------------------------------------------------
do $n233$
declare
  r        record;
  v_cift   int := 0;
  v_toplam int := 0;
  v_prog   int := 0;
  v_etiket int;
  v_ornek  text := '';
begin
  -- Her program için: dönen satır sayısı = farklı statü sayısı olmalı.
  for r in select code from lounge_programs where coalesce(active,true) loop
    v_prog := v_prog + 1;
    declare
      v_satir int; v_farkli int;
    begin
      select count(*), count(distinct tier) into v_satir, v_farkli
        from public.card_tier_options(r.code);
      v_toplam := v_toplam + v_satir;
      if v_satir <> v_farkli then
        v_cift := v_cift + (v_satir - v_farkli);
        v_ornek := v_ornek || r.code || '(' || v_satir || '/' || v_farkli || ') ';
      end if;
    end;
  end loop;

  if v_cift <> 0 then
    raise exception '233 NOBETCI: statu listesinde hala % fazla satir var — %', v_cift, v_ornek;
  end if;

  -- Etiket sürüklenmesi: hiçbir satır card_tier_label()'dan FARKLI ad taşımasın.
  select count(*) into v_etiket
    from lounge_programs p
    cross join lateral public.card_tier_options(p.code) o
   where coalesce(p.active,true)
     and o.label is distinct from public.card_tier_label(o.tier);
  if v_etiket <> 0 then
    raise exception '233 NOBETCI: % statu etiketi card_tier_label() ile uyusmuyor.', v_etiket;
  end if;

  raise notice '233 OK · % program · % statu satiri · cift: 0 · etiket sapmasi: 0',
    v_prog, v_toplam;
  raise notice '233 NOT: lounge_guest_rules TEKILLESTIRILMEDI — matris oldugu gibi duruyor. '
               'Duzelen tek sey kullaniciya sunulan projeksiyon.';
end $n233$;

select '233 STATU LISTESI TEKILLESTI' as sonuc,
       (select count(*) from public.card_tier_options('TK_MS'))    as tk_ms_secenek,
       (select count(distinct tier) from public.card_tier_options('TK_MS')) as tk_ms_farkli;
