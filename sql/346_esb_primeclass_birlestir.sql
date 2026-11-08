-- ============================================================================
-- 346 · ESB "Primeclass CIP Lounge" KOPYASI DIŞ HAT KAYDINA BİRLEŞİR   (8 Kasım 2026)
--
-- Ölçüm (canlı, 343 sonrası): 343 doğrulaması tamam = false, eski_ad_gorunen = 1.
--   lounges dd5ccfaa… · ESB · "Primeclass CIP Lounge" · Int. Terminal · aktif ilan 1
--   bağlı venue 91b08abc… adı DA "Primeclass CIP Lounge" → 343'ün "ad = venue adı"
--   adımı hiçbir şey değiştirmedi. Yerelde bu venue yoktu: 211 onu dış hat kaydına
--   birleştirmişti; canlıda 211'in birleştirmesi çalışmamış (eski nesil kopya kalmış).
-- Kaynak (211): Priority Pass ve LoungeKey ESB'de iki Primeclass listeliyor (Dış + İç
-- Hat). "Primeclass CIP Lounge" (Int. Terminal) dış hat kaydının kopyası.
--
-- Yapılan: kopya venue "Primeclass Lounge — Dış Hat"a cns_merge_venue ile birleşir
-- (kabul listesi, kurallar, ilanlar, katalog kaydı taşınır). Hedefte tutulan katalog
-- kaydının adı/terminali venue'ya eşitlenir (birleştirme "en çok ilanı olan" kaydı
-- tutar; o eski adlı kayıt olabilir). Hedef venue canlıda YOKSA kopya yeniden adlandırılır.
-- İlan kapanmaz; doğru salona taşınır. Tekrar koşulabilir.
-- Doğrulama: tek satır, tamam = true. Ardından 343'ün doğrulaması da tamam = true döner.
-- ============================================================================
do $s346$
declare v_eski uuid; v_hedef uuid; v_n int;
begin
  select id into v_eski from lounge_venues
   where active and airport_code = 'ESB' and name = 'Primeclass CIP Lounge' limit 1;
  -- 8 Kasım (canlı ölçüm, 23505): hedef kayıt canlıda VAR ama PASİF. Önceki sürüm yalnız
  -- aktifi arıyor, bulamayınca kopyayı aynı ada çevirmeye kalkıp benzersizlik kuralına
  -- çarpıyordu. Şimdi pasif hedef de bulunur ve yeniden açılır (kaynak: PP + LoungeKey
  -- ESB'de iki Primeclass listeliyor; dış hat salonu gerçekte var).
  select id into v_hedef from lounge_venues
   where airport_code = 'ESB' and name = 'Primeclass Lounge — Dış Hat' and coalesce(section, '') = ''
   order by active desc limit 1;
  if v_hedef is not null then
    update lounge_venues set active = true where id = v_hedef and not active;
  end if;

  if v_eski is null then
    raise notice '346: kopya venue yok (zaten birlesmis).';
  elsif v_hedef is not null then
    perform public.cns_merge_venue(v_eski, v_hedef,
      '346: PP ve LoungeKey ESB''de iki Primeclass listeliyor; eski nesil kopya dis hat kaydina birlesti (canli).');
    raise notice '346: ESB kopya venue % → % birlestirildi.', v_eski, v_hedef;
  else
    update lounge_venues
       set name = 'Primeclass Lounge — Dış Hat', terminal = 'Dış Hat', scope = 'international'
     where id = v_eski;
    v_hedef := v_eski;
    raise notice '346: dis hat kaydi yoktu; kopya venue yeniden adlandirildi.';
  end if;

  -- Hedefte tutulan aktif katalog kaydı venue adını taşısın.
  if v_hedef is not null then
    update lounges l
       set name = v.name, terminal = v.terminal
      from lounge_venues v
     where v.id = v_hedef and l.venue_id = v.id and l.active
       and (l.name is distinct from v.name or l.terminal is distinct from v.terminal);
    get diagnostics v_n = row_count;
    raise notice '346: % katalog kaydi venue adina esitlendi.', v_n;

    -- Birleştirme ilanın venue_id'sini taşır, lounge_id'sini taşımaz: pasife düşen
    -- kopya katalog kaydına bağlı ilan, hedefteki aktif kayda bağlanır.
    update availabilities a
       set lounge_id = (select x.id from lounges x where x.venue_id = v_hedef and x.active order by x.id limit 1)
     where a.lounge_id in (select y.id from lounges y where y.venue_id = v_hedef and not y.active)
       and exists (select 1 from lounges x where x.venue_id = v_hedef and x.active);
    get diagnostics v_n = row_count;
    raise notice '346: % ilan aktif katalog kaydina baglandi.', v_n;
  end if;
end $s346$;

-- DOĞRULAMA
select 'ESB eski adli salon gorunmuyor, dis hat Primeclass tek' as kontrol,
       not exists (select 1 from lounges l join lounge_venues v on v.id = l.venue_id and v.active
                    where l.active and l.airport_code = 'ESB' and l.name = 'Primeclass CIP Lounge')
   and (select count(*) from lounges l join lounge_venues v on v.id = l.venue_id and v.active
         where l.active and l.airport_code = 'ESB' and l.name = 'Primeclass Lounge — Dış Hat') = 1
   and not exists (select 1 from availabilities a join lounges l on l.id = a.lounge_id
                    where a.active and not l.active and l.airport_code = 'ESB') as tamam;
