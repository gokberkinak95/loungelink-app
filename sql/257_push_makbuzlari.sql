-- ============================================================================
-- 257 — PUSH MAKBUZLARI (256'dan SONRA çalıştır)
--
-- 🔴 KAPANMAMIŞ DELİK: gönderdiğimiz bildirimin AKIBETİNİ hiç okumuyoruz.
--
-- SQL 111 bildirimi Expo'ya gönderiyor ve orada bırakıyor. Expo yanıtında
-- her mesaj için bir "ticket" döner ve `DeviceNotRegistered` şunu söyler:
-- **bu cihaz artık yok** (uygulama silinmiş, token dönmüş, izin kalkmış).
-- O token veritabanımızda sağlam durduğu için biz ulaştığımızı sanıyoruz.
--
-- SQL 252 bu deliğin bir yarısını kapatmıştı: uygulama her açılışta izin
-- durumunu bildiriyor. Ama uygulamayı SİLEN kullanıcı bir daha hiç
-- açmayacağı için o yol asla tetiklenmez. Kalan yarısı burası.
--
-- 🆕 SINIF: "BİR MESAJI GÖNDERİP MAKBUZUNU OKUMAMAK, GÖNDERDİĞİNİ SANMAKTIR."
--
-- ----------------------------------------------------------------------------
-- TASARIM: AYRIŞTIRICI AYRI, GÖNDERİM AYRI
-- ----------------------------------------------------------------------------
-- Makbuz okumak `pg_net`e bağlı ve `pg_net` her kurulumda YOK. Eğer her şeyi
-- tek fonksiyona koysaydım, `pg_net` olmayan bir ortamda (ki test ortamı
-- öyle) mantık hiç ÖLÇÜLEMEZDİ ve "kurulur, çalışır umarız" derdim.
--
-- Onun için ikiye ayrıldı:
--   `push_makbuz_ayristir(jsonb)`  → SAF fonksiyon, ağ istemez, ÖLÇÜLEBİLİR
--   `push_makbuzlarini_isle()`     → G/Ç, `pg_net` yoksa nazikçe atlar
--
-- 🆕 SINIF: "AĞA BAĞLI BİR MANTIĞI SAF BİR AYRIŞTIRICIYA AYIRMAZSAN, O
-- MANTIK ANCAK ÜRETİMDE SINANIR."
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — GÖNDERİM DEFTERİ
-- ════════════════════════════════════════════════════════════════════════

create table if not exists push_gonderimleri (
  id              bigserial primary key,
  notification_id uuid,
  user_id         uuid references users(id) on delete cascade,
  net_request_id  bigint,
  token_sayisi    int,
  gonderildi_at   timestamptz not null default now(),
  islendi_at      timestamptz,
  sonuc           jsonb
);
create index if not exists push_gonderim_bekleyen
  on push_gonderimleri (gonderildi_at) where islendi_at is null;

alter table push_gonderimleri enable row level security;
revoke all on push_gonderimleri from anon;
revoke all on push_gonderimleri from authenticated;
grant select, insert, update on push_gonderimleri to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — SAF AYRIŞTIRICI (ağ istemez → ölçülebilir)
--
-- Expo'nun yanıt şekli:
--   {"data":[{"status":"error","message":"...","details":{"error":"DeviceNotRegistered"}},
--            {"status":"ok","id":"..."}]}
-- Sıra ÖNEMLİ: `data[i]` gönderdiğimiz `to[i]` ile eşleşir.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.push_makbuz_ayristir(p_yanit jsonb)
returns jsonb
language plpgsql immutable set search_path = public as $pma257$
declare v_d jsonb; i int; v_ok int := 0; v_hata int := 0; v_olu int[] := '{}';
begin
  v_d := p_yanit -> 'data';
  if v_d is null or jsonb_typeof(v_d) <> 'array' then
    -- Tanımadığımız bir yanıt: "hepsi başarılı" SAYMIYORUZ.
    return jsonb_build_object('taninmadi', true, 'ok', 0, 'hata', 0, 'olu_indeks', '[]'::jsonb);
  end if;
  for i in 0 .. jsonb_array_length(v_d) - 1 loop
    if (v_d -> i ->> 'status') = 'ok' then
      v_ok := v_ok + 1;
    else
      v_hata := v_hata + 1;
      -- YALNIZ `DeviceNotRegistered` token'ı öldürür. `MessageRateExceeded`
      -- ya da `MessageTooBig` geçici/bizim hatamızdır; onlar için token'ı
      -- pasife almak, ulaşabildiğimiz birini kaybetmek olurdu.
      if (v_d -> i -> 'details' ->> 'error') = 'DeviceNotRegistered' then
        v_olu := v_olu || i;
      end if;
    end if;
  end loop;
  return jsonb_build_object('taninmadi', false, 'ok', v_ok, 'hata', v_hata,
                            'olu_indeks', to_jsonb(v_olu));
end $pma257$;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — `notify_push` GÖNDERİM KİMLİĞİNİ KAYDETSİN
--
-- Gövdeyi elden yazmıyoruz: mevcut tanımı okuyup `perform net.http_post(`
-- çağrısını `select ... into` hâline getiriyoruz ve deftere yazıyoruz.
-- Beklediğimiz metni bulamazsak DOKUNMUYORUZ ve bunu SÖYLÜYORUZ.
-- ════════════════════════════════════════════════════════════════════════

do $np257$
declare v_tanim text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p where p.oid = to_regprocedure('public.notify_push()');
  if v_tanim is null then
    raise notice '257 §3: notify_push YOK — dokunulmadi.'; return;
  end if;
  if v_tanim like '%push_gonderimleri%' then
    raise notice '257 §3: gonderim defteri zaten bagli — dokunulmadi.'; return;
  end if;
  if v_tanim !~ 'perform\s+net\.http_post\(' then
    raise notice '257 §3: beklenen `perform net.http_post(` bulunamadi — DOKUNULMADI.'; return;
  end if;

  v_yeni := regexp_replace(v_tanim,
    'declare v_body jsonb;', 'declare v_body jsonb; v_req bigint; v_tok int;', 'g');
  v_yeni := regexp_replace(v_yeni,
    'perform\s+net\.http_post\(', 'select net.http_post(', 'g');
  -- `perform` → `select ... into v_req`: çağrının kapanışına `into` ekle.
  v_yeni := regexp_replace(v_yeni,
    '(body\s*:=\s*v_body\))\s*;', E'\\1 into v_req;\n    v_tok := jsonb_array_length(v_body);\n'
    || '    insert into push_gonderimleri (notification_id, user_id, net_request_id, token_sayisi)'
    || E'\n    values (NEW.id, NEW.user_id, v_req, v_tok);', 'g');

  if v_yeni not like '%push_gonderimleri%' then
    raise notice '257 §3: yama uygulanamadi — DOKUNULMADI (elle bakilmali).'; return;
  end if;
  execute v_yeni;
  raise notice '257 §3: notify_push artik gonderim kimligini deftere yaziyor.';
end $np257$;

-- ════════════════════════════════════════════════════════════════════════
-- §4 — MAKBUZ İŞLEYİCİ (pg_net yoksa NAZİKÇE ATLAR, sessizce DEĞİL)
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.push_makbuzlarini_isle()
returns jsonb
language plpgsql security definer set search_path = public as $pmi257$
declare
  r record; v_yanit jsonb; v_coz jsonb; v_olu int; v_tok text;
  v_islenen int := 0; v_kapatilan int := 0; v_bekleyen int := 0;
begin
  if to_regnamespace('net') is null then
    -- Sessiz geçmiyoruz: BO bunu görecek.
    return jsonb_build_object('ok', false, 'reason', 'pg_net_yok',
      'not', 'Expo makbuzlari okunamiyor; ulasilamayan cihazlar aktif gorunmeye devam eder.');
  end if;
  if to_regclass('net._http_response') is null then
    return jsonb_build_object('ok', false, 'reason', 'net_yanit_tablosu_yok');
  end if;

  for r in
    select g.* from push_gonderimleri g
     where g.islendi_at is null
       and g.net_request_id is not null
       -- Expo makbuzu hemen gelmez; çok yeni gönderimleri bekletiyoruz.
       and g.gonderildi_at < now() - interval '2 minutes'
     order by g.gonderildi_at limit 200
  loop
    begin
      execute format(
        'select (content)::jsonb from net._http_response where id = %s', r.net_request_id)
        into v_yanit;
    exception when others then v_yanit := null;
    end;
    if v_yanit is null then
      v_bekleyen := v_bekleyen + 1;
      continue;
    end if;

    v_coz := public.push_makbuz_ayristir(v_yanit);
    -- Ölü indeksleri kullanıcının token'larına eşle. Gönderim sırası
    -- `notify_push`taki `jsonb_agg` sırasıdır; onu birebir tekrarlıyoruz.
    for v_olu in select value::int from jsonb_array_elements_text(v_coz -> 'olu_indeks') loop
      select t.token into v_tok
        from (select token, row_number() over (order by updated_at desc) - 1 as ix
                from push_tokens
               where user_id = r.user_id and coalesce(active, true)) t
       where t.ix = v_olu;
      if v_tok is not null then
        update push_tokens set active = false, updated_at = now() where token = v_tok;
        v_kapatilan := v_kapatilan + 1;
      end if;
    end loop;

    update push_gonderimleri set islendi_at = now(), sonuc = v_coz where id = r.id;
    v_islenen := v_islenen + 1;
  end loop;

  return jsonb_build_object('ok', true, 'islenen', v_islenen,
                            'kapatilan_token', v_kapatilan, 'bekleyen', v_bekleyen);
end $pmi257$;

grant execute on function public.push_makbuzlarini_isle() to service_role;

-- Zamanlı işler defterine kaydet: çalışmadığında BO görsün (SQL 251).
insert into zamanli_isler (is_adi, aciklama, beklenen_saat) values
  ('push_makbuzlarini_isle',
   'Expo makbuzlarini okur; DeviceNotRegistered donen token''i pasife alir.', 6)
on conflict (is_adi) do update set aciklama = excluded.aciklama,
                                   beklenen_saat = excluded.beklenen_saat;

-- ════════════════════════════════════════════════════════════════════════
-- §5 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n257$
declare v_h text[] := '{}'; v jsonb;
begin
  begin
    -- (1) AYRIŞTIRICI — asıl mantık burada ve ağ olmadan ÖLÇÜLEBİLİR.
    v := public.push_makbuz_ayristir('{"data":[
          {"status":"error","details":{"error":"DeviceNotRegistered"}},
          {"status":"ok","id":"x"},
          {"status":"error","details":{"error":"MessageRateExceeded"}}]}'::jsonb);
    if (v ->> 'ok')::int <> 1 then
      v_h := v_h || format('basarili sayisi %s (1 olmaliydi)', v ->> 'ok')::text;
    end if;
    if (v -> 'olu_indeks')::text <> '[0]' then
      v_h := v_h || format('olu token indeksi %s ([0] olmaliydi)', v -> 'olu_indeks')::text;
    end if;

    -- (2) 🔴 EN ÖNEMLİ AYRIM: geçici hata token'ı ÖLDÜRMEMELİ.
    -- `MessageRateExceeded` bizim hatamız; o token'ı kapatmak
    -- ULAŞABİLDİĞİMİZ birini kaybetmek olurdu.
    v := public.push_makbuz_ayristir('{"data":[{"status":"error","details":{"error":"MessageRateExceeded"}}]}'::jsonb);
    if (v -> 'olu_indeks')::text <> '[]' then
      v_h := v_h || 'gecici hata token`i OLDURDU — ulasilabilir cihaz kaybedilir'::text;
    end if;

    -- (3) Tanımadığımız yanıt "hepsi başarılı" SAYILMAMALI.
    v := public.push_makbuz_ayristir('{"errors":[{"code":"X"}]}'::jsonb);
    if coalesce((v ->> 'taninmadi')::boolean, false) is not true then
      v_h := v_h || 'taninmayan yanit taninmis sayildi'::text;
    end if;

    -- (4) Altyapı eksikken NAZİKÇE ama SESLİCE atlamalı.
    --
    -- 🔴 İLK YAZIMDA "`net` şeması varsa `_http_response` de vardır"
    -- varsaydım ve nöbetçi kırmızı yandı: test veritabanında `net` şeması
    -- VAR (taklit) ama yanıt tablosu YOK. Yani iki ayrı eksiklik, iki ayrı
    -- sebep — ve ikisi de "sessizce başarılı" sayılmamalı.
    -- 🆕 SINIF: "BİR BAĞIMLILIĞIN VARLIĞI, ONUN PARÇALARININ DA VARLIĞI
    -- DEĞİLDİR."
    v := public.push_makbuzlarini_isle();
    if coalesce(v ->> 'ok','') = 'true' then
      null;   -- gerçekten çalıştı
    elsif coalesce(v ->> 'reason','') in ('pg_net_yok','net_yanit_tablosu_yok') then
      -- Kabul edilebilir atlama — AMA sebebi SÖYLEMEK zorunda.
      if coalesce(v ->> 'reason','') = '' then
        v_h := v_h || 'atlandi ama SEBEP bildirilmedi'::text;
      end if;
    else
      v_h := v_h || ('makbuz isleyici beklenmeyen sonuc: ' || coalesce(v::text,''))::text;
    end if;

    -- (5) İş, zamanlı işler defterinde olmalı (susarsa BO görsün).
    if not exists (select 1 from zamanli_isler where is_adi = 'push_makbuzlarini_isle') then
      v_h := v_h || 'is zamanli isler defterine YAZILMADI — sustugunda kimse gormez'::text;
    end if;

    raise exception 'GERI_AL_257';
  exception when others then
    if sqlerrm <> 'GERI_AL_257' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '257 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '257 OK · ayristirici olculdu · gecici hata token oldurmuyor · pg_net yoklugu sesli bildiriliyor';
end $n257$;

select public.migration_kaydet('257_push_makbuzlari.sql');

commit;

select '257 KURULDU' as sonuc,
       (select count(*) from zamanli_isler) as izlenen_is,
       (to_regnamespace('net') is not null)  as pg_net_var;
