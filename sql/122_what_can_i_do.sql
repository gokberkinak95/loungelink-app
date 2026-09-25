-- ============================================================
-- LoungeLink · 122_what_can_i_do.sql
-- "YAPAMAZSIN" DEMEK YETMEZ, "NE YAPABILIRSIN" DE SOYLEMELI
--
-- ⚠️ Uygulamayi ETKILER (yeni RPC + karar ciktisi).
--
-- ------------------------------------------------------------
-- URUN GOZLEMI (kimse istemedi, ama eksik)
-- ------------------------------------------------------------
-- Kural motoru artik dogru calisiyor: engelliyor, uyariyor, sebebini
-- yaziyor. Ama HER MESAJ BIR CIKMAZ SOKAK. Kullanici "bu ilana
-- basvuramazsin" okuyor ve orada kaliyor.
--
-- Oysa cogu engelin bir CIKISI var:
--   · Farkli havayolu     -> ayni havayolundaki host'lar var mi?
--   · Charter             -> kart agi kaynakli ilanlar charter'i
--                            umursamiyor; onlari goster
--   · Kart tipinde hak yok-> ucretli girise izin veren ilanlar
--   · Salon kurali bilinmiyor -> ayni havalimaninda DOGRULANMIS ilan
--
-- Reddedilen bir kullaniciya alternatif sunmak, urunun ise yarar
-- kalmasini saglar. Aksi halde ilk redde "burada bana gore bir sey
-- yok" der ve bir daha acmaz.
--
-- 🔴 ALTERNATIF UYDURULMAZ: yalnizca GERCEKTEN basvurabilecegi
-- ilanlar sayilir. "Belki vardir" demek, ikinci bir hayal kirikligi
-- uretmekten baska ise yaramaz.
-- ============================================================

create or replace function public.alternatives_for(p_avail_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); a availabilities%rowtype;
  v_n int := 0; v_reason text; d jsonb; v_ids uuid[];
begin
  select * into a from availabilities where id = p_avail_id;
  if not found then return jsonb_build_object('count', 0); end if;

  d := public.lounge_access_decision_v5(p_avail_id, null, null);

  -- Ayni havalimani + ayni tarih + acik slot + KENDISI DEGIL
  select array_agg(x.id) into v_ids from (
    select av.id from availabilities av
     where av.airport_code = a.airport_code
       and av.avail_date = a.avail_date
       and av.id <> p_avail_id
       and av.host_id <> v_uid
       and coalesce(av.filled,0) < coalesce(av.slots,1)
       and not public.is_blocked_pair(av.host_id, v_uid)
     limit 40
  ) x;

  if v_ids is null then return jsonb_build_object('count', 0); end if;

  -- 🔴 GERCEKTEN basvurabilecegi olanlari say. Rozet fonksiyonu
  -- precheck ile ayni mantigi kullaniyor; burada da onu cagirarak
  -- UC YERDE AYNI cevabi garanti ediyoruz.
  select count(*) into v_n
    from public.discovery_rule_badges(v_ids) b
   where not b.blocks_request;

  v_reason := case
    when (d ->> 'carrier_ok') = 'false'
      then 'Bu salon misafirin aynı havayolunda uçmasını istiyor.'
    when coalesce((d ->> 'charter'),'false') = 'true'
      then 'Havayolu salonları charter seferde hak vermiyor — ama kart ağı '
        || '(Priority Pass / LoungeKey / DragonPass) kaynaklı ilanlar charter''ı umursamaz.'
    when (d ->> 'guest_policy') = 'not_allowed'
      then 'Bu ilandaki hak misafir götürmeye izin vermiyor.'
    else null end;

  return jsonb_build_object(
    'count', v_n,
    'reason', v_reason,
    'airport', a.airport_code,
    'date', a.avail_date);
end $$;
grant execute on function public.alternatives_for(uuid) to authenticated;

insert into beta_settings (key, value) values
 ('alt_note_some', to_jsonb(
   'Aynı havalimanında ve aynı gün başvurabileceğin {n} ilan daha var.'::text)),
 ('alt_note_none', to_jsonb(
   'Bugün bu havalimanında başvurabileceğin başka ilan yok. Seyahatini kaydettiğin '
|| 'için yeni ilan açıldığında haberin olacak.'::text))
on conflict (key) do update set value = excluded.value;

select '122 OK - reddedilen kullaniciya cikis yolu gosteriliyor' as sonuc;
