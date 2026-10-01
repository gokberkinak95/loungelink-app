-- ============================================================================
-- 312 · SORU → İLAN BAĞI GERÇEKTEN KURULUR (239'un sessizce atladığı düzeltme)
--
-- ÖLÇÜLDÜ (1 Ekim, test verisi ekranında): "Sorduklarım" kartında
--   Merhaba! “bu” ilanına başvurmak istiyorum…
-- yazıyor. Salon adı yerine “bu”. Sebep zinciri:
--   · Soru metnini ve host bildirimini kuran tetikleyiciler (238/239) salonu
--     connection_requests.avail_id'den okuyor.
--   · 239, ilan_kurali_sor'un INSERT'ine avail_id eklemek için canlı gövdeyi
--     yamayacaktı. "Zaten yamalı mı?" koruması `like '%p_avail_id)%'` idi —
--     bu desen gövdedeki `kural_sorusu_uygun_mu(p_avail_id)` satırına da
--     uyuyor. 239 "ZATEN avail_id yaziyor — dokunulmadi" deyip ÇIKTI.
--     Sonraki denetimi (`not like '%avail_id%'`) de her zaman yanlıştı.
--   · Sonuç: 239'dan beri HİÇBİR soru ilanına bağlanmadı → metin “bu”,
--     host bildirimi “bu”, Sorduklarım'daki "İlana git" ilanı bulamıyor.
--
-- 312: koruma TAM INSERT satırına bakar; yamadan sonra canlı gövde yeniden
-- okunur ve bağ yoksa HATA verir (sessiz geçmez). Tekrar koşulabilir.
-- ============================================================================

do $ins$
declare v_govde text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_govde
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'ilan_kurali_sor' limit 1;
  if v_govde is null then raise exception '312: ilan_kurali_sor yok'; end if;

  if v_govde ~ 'insert into connection_requests \(from_id, to_id, intent, intro, status, avail_id\)' then
    raise notice '312: ilan_kurali_sor zaten avail_id yaziyor (INSERT satiri okundu) — dokunulmadi';
    return;
  end if;

  v_yeni := regexp_replace(
    v_govde,
    'insert into connection_requests \(from_id, to_id, intent, intro, status\)(\s*)values \(v_uid, v_av\.host_id, ''kural_sorusu'', v_intro, ''pending''\)',
    'insert into connection_requests (from_id, to_id, intent, intro, status, avail_id)\1values (v_uid, v_av.host_id, ''kural_sorusu'', v_intro, ''pending'', p_avail_id)');

  if v_yeni = v_govde then
    raise exception '312: beklenen INSERT satiri bulunamadi — ilan_kurali_sor degismis. Elle bakilmali.';
  end if;
  execute v_yeni;
end $ins$;

-- Sonuç denetimi: canlı gövdeyi YENİDEN oku.
do $$
declare v text;
begin
  select pg_get_functiondef('public.ilan_kurali_sor(uuid)'::regprocedure) into v;
  if position('''pending'', p_avail_id)' in v) = 0 then
    raise exception '312: yama uygulanmadi — ilan_kurali_sor hala avail_id yazmiyor';
  end if;
end $$;

-- ── GEÇMİŞ: yalnız EMİN olunan yerde doldur (239'un kuralı, genişletilmiş) ──
-- Host'un soru anında AÇIK olan tek bir ilanı varsa soru ona aittir.
-- (239 yalnız "şu an aktif" ilanlara bakıyordu; eski sorularda ilan çoktan bitmiş olur.)
update connection_requests cr
   set avail_id = (select a.id from availabilities a
                    where a.host_id = cr.to_id
                      and a.created_at <= cr.created_at
                      and a.avail_date >= (cr.created_at at time zone 'Europe/Istanbul')::date
                    limit 1)
 where cr.intent = 'kural_sorusu'
   and cr.avail_id is null
   and (select count(*) from availabilities a
         where a.host_id = cr.to_id
           and a.created_at <= cr.created_at
           and a.avail_date >= (cr.created_at at time zone 'Europe/Istanbul')::date) = 1;

-- Bağı artık bilinen eski sorularda “bu” yerine salonun adı.
update connection_requests cr
   set intro = replace(cr.intro, '“bu”', '“' || s.salon || '”')
  from (select a.id, coalesce(nullif(btrim(a.lounge_name), ''), l.name, a.airport_code::text) as salon
          from availabilities a left join lounges l on l.id = a.lounge_id) s
 where cr.intent = 'kural_sorusu' and cr.avail_id = s.id
   and position('“bu”' in coalesce(cr.intro, '')) > 0;

update notifications nt
   set body = replace(nt.body, '“bu”', '“' || s.salon || '”')
  from connection_requests cr
  join (select a.id, coalesce(nullif(btrim(a.lounge_name), ''), l.name, a.airport_code::text) as salon
          from availabilities a left join lounges l on l.id = a.lounge_id) s on s.id = cr.avail_id
 where cr.intent = 'kural_sorusu' and nt.ref_type = 'connection' and nt.ref_id = cr.id
   and position('“bu”' in coalesce(nt.body, '')) > 0;

do $$
declare v_bagsiz int; v_bu int;
begin
  select count(*) into v_bagsiz from connection_requests where intent = 'kural_sorusu' and avail_id is null;
  select count(*) into v_bu from connection_requests where intent = 'kural_sorusu' and position('“bu”' in coalesce(intro,'')) > 0;
  raise notice '312: ilan_kurali_sor avail_id yaziyor · ilansiz eski soru=% · “bu” metinli soru=% (ikisi de yalniz belirsiz eski kayitlar)', v_bagsiz, v_bu;
end $$;
