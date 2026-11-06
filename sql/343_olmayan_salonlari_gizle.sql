-- ============================================================================
-- LoungeLink · 343_olmayan_salonlari_gizle.sql                (6 Kasım 2026)
--
-- GÖKBERK: "Lounge seçicide SAW'da 'Aeroport Lounge' geliyor (Dom. Terminal ·
-- Priority Pass, Credit Card). Böyle bir lounge yok. Gerçekten olmayan
-- loungeları gösteremeyelim."
--
-- ÖLÇÜM (yerel replika, 6 Kasım 2026):
--   · Seçicide görünen salon (lounges.active + venue.active + tür lounge): 276
--   · Bunların 14'ü HİÇBİR KAYNAKTA YOK: hepsi 002_seed_reference.sql'in elle
--     yazılmış MVP demo satırları (002:23-51). 086 bunları "lounges tablosundan
--     otomatik aktarıldı" notuyla venue'ya, oradan salonlar.csv'ye taşıdı.
--     "Priority Pass, Credit Card" yazısı da 002'nin access_types sütunu —
--     o da kaynaksız.
--   · Kaynaklar: kural tabloları.xlsx (THY yurtiçi/yurtdışı/anlaşmalı, 42 ekran
--     görüntüsü → 188) + PP/LoungeKey/DragonPass Türkiye listeleri
--     (card_network_source, 66 satır, 9 havalimanı → 211).
--   · SAW için üç ağ da aynı şeyi söylüyor: Plaza Premium (iç hat),
--     Plaza Premium Bosphorus (dış), Plaza Premium Marmara (dış), Kepler
--     (uyku). THY tablosu: Turkish Airlines CIP (iç hat). "Aeroport" YOK.
--   · SAW sayım tutarsızlığı (İç Hat 3 · Dış Hat 2 · Tümü 4): Aeroport
--     scope='both' olduğu için iki sekmede birden sayılıyordu; üstelik
--     kaynaklı Marmara salonu, 211 venue'yu geri açtığı hâlde lounges
--     satırını pasif bıraktığı için seçicide HİÇ görünmüyordu.
--
-- NE YAPAR (silme YOK; her adım tekrar koşulabilir):
--   1) Gerçekte olmayan / mükerrer 4 kaydı PASİFE alır (lounges + venue +
--      kabul satırları). Bağlı AKTİF ilan: kardeş salona taşınır ya da
--      kapatılır ve host'a bildirim yazılır (214'teki kural). KABUL EDİLMİŞ
--      başvurusu olan ilana DOKUNULMAZ (trg_ilan_kapatma_kapisi zaten izin
--      vermez) — sayısı doğrulamada ayrıca yazılır.
--   2) Gerçek salona bağlı ama 002'nin eski adını taşıyan 2 satırın adını
--      venue'nunkiyle eşitler (ESB Primeclass CIP → Primeclass Lounge — Dış
--      Hat; AYT Antalya Airport CIP → Elite Lounge — Dış Hat (T1)) ve DXB
--      Marhaba'nın terminalini venue'yla eşitler.
--   3) Seçicide gösterilen kaynaksız access_types'ı boşaltır (15 satır, hepsi
--      002 kökenli; katalogun geri kalanı zaten boş).
--   4) Kart ağı kaynağı olan, venue'su aktif ama lounges satırı pasif kalmış
--      salonları seçiciye geri açar (SAW Marmara, IST iGA Pop-up).
--
-- Supabase SQL Editor: temp table yok, psql meta-komutu yok. Tek DO bloğu
-- (tek işlem) + sonda doğrulama select'i → "tamam = true".
-- ============================================================================

do $s343$
declare
  r record; a record;
  v_lids uuid[]; v_vids uuid[]; v_hedef_l uuid; v_hedef_v uuid;
  v_tasindi int := 0; v_kapandi int := 0; v_kilitli int := 0;
  v_l int := 0; v_v int := 0; v_k int := 0; v_n int := 0;
begin
  -- -------------------------------------------------------------- (1) GİZLE
  for r in
    select * from (values
      ('SAW', 'Aeroport Lounge', null::text,
       'Ne THY listesinde ne PP/LoungeKey/DragonPass SAW sayfasinda var; 002 demo satiri.'),
      ('ESB', 'Anatolia Lounge', null::text,
       'Ne THY listesinde ne PP/LoungeKey/DragonPass ESB sayfasinda var; 002 demo satiri.'),
      ('LHR', 'Turkish Airlines Lounge', null::text,
       'THY anlasmali listesi LHR''de yalniz ortak salonlari sayiyor (Air Canada, Lufthansa, Singapore, United); THY''nin kendi salonu yok. 002 demo satiri.'),
      ('DOH', 'Oryx Lounge', 'Oryx',
       'THY anlasmali listesindeki "Oryx" ile ayni salon; 002 demo satiri mukerrer.')
    ) t(ap, ad, tasi_ad, gerekce)
  loop
    select coalesce(array_agg(l.id), '{}') into v_lids
      from lounges l where l.airport_code = r.ap and l.name = r.ad;
    select coalesce(array_agg(distinct x), '{}') into v_vids from (
      select l.venue_id x from lounges l where l.id = any(v_lids) and l.venue_id is not null
      union
      select v.id from lounge_venues v where v.airport_code = r.ap and v.name = r.ad
    ) q;
    -- Ortak venue koruması: bu venue'ya BAŞKA adla bağlı aktif bir lounges
    -- satırı varsa venue gerçek bir salondur; venue'ya dokunma.
    select coalesce(array_agg(x), '{}') into v_vids
      from unnest(v_vids) x
     where not exists (select 1 from lounges l2
                        where l2.venue_id = x and l2.active and l2.name <> r.ad);

    -- Taşıma hedefi (yalnız mükerrer kayıtlarda)
    v_hedef_l := null; v_hedef_v := null;
    if r.tasi_ad is not null then
      select l.id, l.venue_id into v_hedef_l, v_hedef_v
        from lounges l join lounge_venues v on v.id = l.venue_id and v.active
       where l.active and l.airport_code = r.ap and l.name = r.tasi_ad
       order by l.id limit 1;
    end if;

    for a in
      select av.id, av.host_id, av.avail_date
        from availabilities av
       where av.active
         and (av.lounge_id = any(v_lids) or av.venue_id = any(v_vids))
    loop
      if exists (select 1 from requests q where q.avail_id = a.id and q.status = 'accepted') then
        v_kilitli := v_kilitli + 1;   -- kabul edilmiş misafir var: dokunma
        continue;
      end if;
      if v_hedef_l is not null then
        update availabilities set lounge_id = v_hedef_l, venue_id = v_hedef_v where id = a.id;
        if a.avail_date >= current_date then
          insert into notifications (user_id, category, title, body, ref_type, ref_id)
          values (a.host_id, 'system', 'İlanın aynı salonun doğru kaydına taşındı',
                  format('"%s" kaydı aynı salonun mükerrer kopyasıydı. İlanın "%s" kaydına taşındı; başka bir şey değişmedi.', r.ad, r.tasi_ad),
                  'availability', a.id);
        end if;
        v_tasindi := v_tasindi + 1;
      else
        update availabilities set active = false where id = a.id;
        if a.avail_date >= current_date then
          insert into notifications (user_id, category, title, body, ref_type, ref_id)
          values (a.host_id, 'system', 'İlanın kapatıldı: salon katalogdan kaldırıldı',
                  format('"%s" adlı bir salon %s havalimanında bulunmuyor; kayıt kataloğumuza yanlışlıkla girmişti. '
                      || 'Kimseyi olmayan bir salona göndermemek için ilanını kapattık. Aynı havalimanındaki başka bir salonda yeniden ilan açabilirsin.',
                         r.ad, r.ap),
                  'availability', a.id);
        end if;
        v_kapandi := v_kapandi + 1;
      end if;
    end loop;

    update lounges set active = false
     where id = any(v_lids) and active;
    get diagnostics v_n = row_count; v_l := v_l + v_n;

    update lounge_venue_acceptance
       set active = false, accepted = false,
           guest_fee_note = coalesce(guest_fee_note || ' · ', '') || '343: salon pasife alindi — ' || r.gerekce,
           updated_at = now()
     where venue_id = any(v_vids) and active;
    get diagnostics v_n = row_count; v_k := v_k + v_n;

    update lounge_venues
       set active = false,
           notes = coalesce(notes || ' · ', '') || '343: pasif — ' || r.gerekce
     where id = any(v_vids) and active;
    get diagnostics v_n = row_count; v_v := v_v + v_n;

    update venue_review_queue
       set durum = 'kapali', karar_at = now(),
           gerekce = gerekce || ' · 343 KARARI: salon gercekte yok, pasife alindi.'
     where venue_id = any(v_vids) and durum <> 'kapali';
  end loop;
  raise notice '343 (1): lounges % · venue % · kabul % pasif; ilan % tasindi, % kapatildi, % kilitli (kabul edilmis basvuru)',
    v_l, v_v, v_k, v_tasindi, v_kapandi, v_kilitli;

  -- ------------------------------------------- (2) ESKİ AD → VENUE ADI
  update lounges l
     set name = v.name, terminal = v.terminal
    from lounge_venues v
   where v.id = l.venue_id and v.active and l.active
     and (l.airport_code, l.name) in (('ESB', 'Primeclass CIP Lounge'),
                                      ('AYT', 'Antalya Airport CIP Lounge'))
     and l.name <> v.name;
  get diagnostics v_n = row_count;
  raise notice '343 (2): % eski adli satir venue adina esitlendi', v_n;

  update lounges l
     set terminal = v.terminal
    from lounge_venues v
   where v.id = l.venue_id and v.active and l.active
     and l.airport_code = 'DXB' and l.name = 'Marhaba Lounge'
     and v.terminal is not null and l.terminal is distinct from v.terminal;

  -- --------------------------------- (3) KAYNAKSIZ ERİŞİM İDDİASI
  update lounges set access_types = '{}'
   where active and cardinality(access_types) > 0;
  get diagnostics v_n = row_count;
  raise notice '343 (3): % satirin kaynaksiz access_types''i bosaltildi', v_n;

  -- ------------------------------ (4) KAYNAKLI AMA GÖRÜNMEYEN SALON
  -- Venue aktif, tür lounge, şemsiye değil, kart ağı kaynağı VAR, ama
  -- hiçbir aktif lounges satırı yok → seçicide görünmüyor. Venue başına
  -- tek satır açılır (venue adını taşıyan tercih edilir).
  with aday as (
    select distinct on (v.id) l.id lid, v.name vname, v.terminal vterm
      from lounge_venues v
      join lounges l on l.venue_id = v.id and not l.active
     where v.active and coalesce(v.venue_kind, 'lounge') = 'lounge' and not v.is_umbrella
       and exists (select 1 from card_network_source c where c.venue_id = v.id)
       and not exists (select 1 from lounges l2 where l2.venue_id = v.id and l2.active)
     order by v.id, (l.name = v.name) desc, l.id
  )
  update lounges l set active = true, name = aday.vname, terminal = aday.vterm
    from aday where l.id = aday.lid;
  get diagnostics v_n = row_count;
  raise notice '343 (4): % kaynakli salon secicide yeniden acildi', v_n;
end $s343$;


-- ============================================================================
-- DOĞRULAMA — "tamam = true" olmalı
-- ============================================================================
with gorunen as (
  select l.id, l.airport_code ap, l.name, l.access_types, v.scope
    from lounges l
    join lounge_venues v on v.id = l.venue_id and v.active
                        and coalesce(v.venue_kind, 'lounge') = 'lounge'
   where l.active
), saw as (
  select * from public.lounges_for_airport('SAW')
), o as (
  select
    (select count(*) from gorunen) as gorunen_salon,
    (select count(*) from gorunen
      where (ap, name) in (('SAW','Aeroport Lounge'),('ESB','Anatolia Lounge'),
                           ('LHR','Turkish Airlines Lounge'),('DOH','Oryx Lounge'))) as olmayan_gorunen,
    (select count(*) from gorunen
      where (ap, name) in (('ESB','Primeclass CIP Lounge'),('AYT','Antalya Airport CIP Lounge'))) as eski_ad_gorunen,
    (select count(*) from gorunen where cardinality(access_types) > 0) as kaynaksiz_erisim,
    (select count(*) from saw) as saw_tumu,
    (select count(*) from saw where scope in ('domestic','both')) as saw_ic,
    (select count(*) from saw where scope in ('international','both')) as saw_dis,
    (select count(*) from saw where name ilike '%Marmara%') as saw_marmara,
    (select count(*) from lounge_venues v
      where v.active and coalesce(v.venue_kind,'lounge') = 'lounge' and not v.is_umbrella
        and exists (select 1 from card_network_source c where c.venue_id = v.id)
        and not exists (select 1 from lounges l where l.venue_id = v.id and l.active)) as kaynakli_gizli,
    (select count(*) from (select distinct ap from gorunen) h
      where not exists (select 1 from public.lounges_for_airport(h.ap))) as bos_havalimani,
    -- Bilgi: kabul edilmiş başvurusu olduğu için dokunulmayan ilan
    (select count(*) from availabilities av
       join lounges l on l.id = av.lounge_id
      where av.active and not l.active
        and (l.airport_code, l.name) in (('SAW','Aeroport Lounge'),('ESB','Anatolia Lounge'),
                                         ('LHR','Turkish Airlines Lounge'),('DOH','Oryx Lounge'))) as elle_bakilacak_ilan
)
select o.*,
       (olmayan_gorunen = 0 and eski_ad_gorunen = 0 and kaynaksiz_erisim = 0
        and saw_ic + saw_dis = saw_tumu          -- 'both' kalmadı: sekmeler toplamı tutuyor
        and saw_marmara = 1 and kaynakli_gizli = 0 and bos_havalimani = 0) as tamam
  from o;
