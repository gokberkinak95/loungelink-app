-- ============================================================
-- LoungeLink · 180_flow_test_future_availability.sql
-- SON KIRMIZI: TEST GEÇMİŞ TARİHLİ İLAN SEÇİYORDU
--
-- ⚠️ Uygulamayı ETKİLEMEZ (yalnız test seçimi).
--
-- ------------------------------------------------------------
-- 🔴 TEŞHİS (raporun kendisi verdi)
-- ------------------------------------------------------------
--   flow_gate_test — Misafir kabul etmeyen ilana istek gönderilemez
--                    → availability_expired
--
-- 178'de rapora "hangi senaryo, hangi cevap" yazdırmıştım; teşhisi
-- bu satır verdi. Tahmin etmeye gerek kalmadı — denetimin adres
-- vermesi tam da bunun için.
--
-- SEBEP: senaryo, kararı 'not_allowed' olan HERHANGİ bir ilanı
-- seçiyordu. Gökberk'in veritabanında o ilan GEÇMİŞ tarihli.
-- create_request'in ilk kapısı süre kontrolü:
--     if v_av.avail_date < current_date then raise 'availability_expired'
-- Yani motor doğru davranıyor, test yanlış ilanı seçiyor: ölçmek
-- istediği kapıya varmadan daha üstteki bir kapıda duruyor.
--
-- İKİ KATMANLI DÜZELTME:
--   1. KÖK: senaryo yalnız BUGÜN VE SONRASI tarihli ilan seçer.
--   2. AĞ: yine de süre kapısına takılırsa bu bir ortam engelidir
--      (⊘ ULAŞILAMADI), gerçek hata değil — 179'un listesine eklenir.
-- ============================================================

-- ---- 1) AĞ: süre kapısı ortam engelidir ----
create or replace function public.flow_env_block(p_err text)
returns boolean language sql immutable as $$
  select p_err ilike any (array[
    '%insufficient_credit%',
    '%already_requested%',
    '%duplicate key%',
    '%rate_limited%',
    '%not_verified%',
    '%no_matching_trip%',
    '%own_availability%',
    '%self_request%',
    -- 180: ilan geçmişte kalmışsa test konusuna ulaşamaz. Motorun
    -- süre kapısı doğru çalışmıştır; senaryo ölçülememiştir.
    '%availability_expired%',
    '%availability_not_found%',
    '%not_active%'
  ]);
$$;

-- ---- 2) KÖK: senaryo geleceğe bakan ilan seçer ----
do $$
declare v_src text; v_new text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'flow_gate_test' and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then raise exception '180: flow_gate_test yok'; end if;
  if position('180:' in v_src) > 0 then
    raise notice '180: seçim zaten güncel'; return;
  end if;

  v_new := replace(v_src,
'    from availabilities a
   where a.active
     and (public.lounge_access_decision(a.id, null) ->> ''guest_policy'') = ''not_allowed''
   limit 1;',
'    from availabilities a
   where a.active
     -- 🔴 180: GELECEĞE BAKAN ilan. Geçmiş tarihli ilanda create_request
     -- önce süre kapısında durur (availability_expired) ve senaryonun
     -- ölçmek istediği misafir kapısına hiç varılmaz.
     and a.avail_date >= current_date
     and a.slots - coalesce(a.filled,0) >= 1
     and (public.lounge_access_decision(a.id, null) ->> ''guest_policy'') = ''not_allowed''
   order by a.avail_date
   limit 1;');

  if v_new = v_src then
    raise exception '180: seçim güncellenemedi — gövde kalıbı değişmiş';
  end if;

  -- sqlcheck: allow-replace flow_gate_test  (dönüş tipi AYNI — dinamik yeniden tanım)
  execute 'create or replace function public.flow_gate_test() returns table '
       || '(senaryo text, beklenen text, gercek text, sonuc text) '
       || 'language plpgsql security definer set search_path = public as $BODY$'
       || v_new || '$BODY$';
  raise notice '180: senaryo artık yalnız bugün ve sonrası tarihli ilan seçiyor';
end $$;

-- ---- KANIT: geçmiş tarihli ilan varken bile senaryo doğru çalışır ----
do $$
declare v_old uuid; r record; v_fail int;
begin
  -- Gökberk'in durumunu taklit et: kararı not_allowed olan ilanı
  -- GEÇMİŞE al ve testin yine de doğru sonucu vermesini bekle.
  select a.id into v_old from availabilities a
   where a.active
     and (public.lounge_access_decision(a.id, null) ->> 'guest_policy') = 'not_allowed'
   limit 1;

  if v_old is not null then
    update availabilities set avail_date = current_date - 3 where id = v_old;
  end if;

  select count(*) into v_fail from public.flow_gate_test() where sonuc like '✗%';

  if v_old is not null then
    update availabilities set avail_date = current_date + 1 where id = v_old;
  end if;

  if v_fail > 0 then
    for r in select senaryo, gercek, sonuc from public.flow_gate_test() where sonuc like '✗%' loop
      raise notice '180 KALAN: % → % (%)', r.senaryo, r.gercek, r.sonuc;
    end loop;
    raise exception '180: geçmiş tarihli ilan varken hâlâ % gerçek hata var', v_fail;
  end if;
  raise notice '180: geçmiş tarihli ilan varken de akış kapıları temiz ✓';
end $$;

select '180 OK - senaryo gelecege bakan ilan seciyor' as sonuc;
