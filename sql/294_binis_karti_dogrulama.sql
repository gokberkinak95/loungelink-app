-- ════════════════════════════════════════════════════════════════════════
-- 294 · BİNİŞ KARTI DOĞRULAMA — KAYIT, ÇİFTE KULLANIM, ESNEK GÜVENCE
--
-- 🔴 NEDEN VAR — GÖKBERK, 13 EYLÜL (v5.9.0 biniş kartı briefi + onay)
--
-- ⚠️ EN ÖNEMLİ KARAR: HAM BCBP DİZESİ BURAYA YAZILMAZ.
-- Brief "görsel sunucuya gitmesin" diyordu; ölçtüm ve bir adım daha
-- gerekiyordu. Ham dize içinde *PNR + soyadı* birlikte duruyor ve bu
-- ikili birçok havayolu sitesinde REZERVASYONU GÖRÜNTÜLEME/DEĞİŞTİRME
-- anahtarıdır. Yani ham dizeyi veritabanımıza yazmak, biletin
-- fotoğrafını yüklemekten DAHA tehlikelidir.
--
-- Buraya yalnız TÜRETİLMİŞ, geri döndürülemez alanlar yazılır:
--   airport_code · flight_date · carrier_flight · cabin_code
--   bp_hash = sha256(PNR|soyad|tarih + SUNUCU TUZU)   ← çifte kullanım
-- YAZILMAYANLAR: ham dize, tam ad, koltuk, check-in sırası,
--                VARIŞ HAVALİMANI, görselin kendisi, dosya yolu.
--
-- 🆕 SINIF: "BİR VERİYİ YÜKLEMEMEK MAHREMİYET DEĞİLDİR — ONDAN
-- TÜRETTİĞİN ŞEYİN NEYİN ANAHTARI OLDUĞUNU BİLMEK MAHREMİYETTİR."
--
-- ⚠️ TUZ SUNUCUDA. Karma istemcide üretilseydi sözlük saldırısına
-- açık olurdu (PNR uzayı küçüktür). İstemci ham girdiyi gönderir,
-- karmayı `security definer` fonksiyon üretir, karma İSTEMCİYE DÖNMEZ.
--
-- ESNEK GÜVENCE: `bypass` bir HATA DEĞİL, kayıtlı bir DURUMDUR. Akış
-- asla kesilmez; karşı tarafa Gökberk'in yazdığı editoryal uyarı gider.
--
-- Tekrar koşulabilir. Kendi sınamasını taşır.
-- ════════════════════════════════════════════════════════════════════════

-- ── 1 · TUZ (yalnız sunucu okur) ───────────────────────────────────────
create table if not exists public.sunucu_sirlari (
  anahtar text primary key,
  deger   text not null,
  created_at timestamptz not null default now()
);
alter table public.sunucu_sirlari enable row level security;
-- RLS açık ve HİÇ POLİTİKA YOK: `security definer` fonksiyonlar dışında
-- kimse okuyamaz. Politika yazmamak burada bir eksiklik değil, kararın
-- kendisidir.
revoke all on public.sunucu_sirlari from anon, authenticated;

-- ⚠️ `gen_random_bytes`/`digest` PGCRYPTO'dan gelir ve Supabase'de
-- `extensions` şemasındadır; bu fonksiyonlar `set search_path = public`
-- ile çalıştığı için ONLARI GÖREMEZ (ölçtüm: "function digest(text,
-- unknown) does not exist"). Çekirdekte var olanı kullanıyorum:
-- `gen_random_uuid()` (PG13+) ve `sha256()` (PG11+). Eklenti bağımlılığı
-- olmayan bir şema, bir kurulum adımı eksik olmayan şemadır.
-- 🆕 SINIF: "BİR FONKSİYONA search_path VERDİĞİNDE ONA EKLENTİLERİ DE
-- KAPATMIŞ OLURSUN — ÇEKİRDEKTE KARŞILIĞI VARSA ONU KULLAN."
insert into public.sunucu_sirlari (anahtar, deger)
select 'bp_tuz', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
where not exists (select 1 from public.sunucu_sirlari where anahtar = 'bp_tuz');

-- ── 2 · DOĞRULAMA KAYDI ────────────────────────────────────────────────
do $$ begin
  if not exists (select 1 from pg_type where typname = 'bp_yontem') then
    create type public.bp_yontem as enum ('scan', 'gallery', 'file', 'bypass');
  end if;
end $$;

create table if not exists public.session_verifications (
  id            uuid primary key default gen_random_uuid(),
  request_id    uuid not null references requests(id) on delete cascade,
  user_id       uuid not null references users(id) on delete cascade,
  method        public.bp_yontem not null,
  passed        boolean not null,
  reason_code   text,                    -- basarisizsa NEDEN (odak_yok, parlama…)
  airport_code  char(3),
  flight_date   date,
  carrier_flight text,
  cabin_code    char(1),
  bp_hash       text,                    -- çifte kullanım tespiti (tuzlu)
  duration_ms   int,
  created_at    timestamptz not null default now()
);

create index if not exists idx_sv_request on public.session_verifications(request_id);
create index if not exists idx_sv_user    on public.session_verifications(user_id, created_at desc);
create unique index if not exists idx_sv_hash
  on public.session_verifications(bp_hash) where bp_hash is not null and passed;

alter table public.session_verifications enable row level security;

drop policy if exists sv_kendi_okur on public.session_verifications;
create policy sv_kendi_okur on public.session_verifications for select
  using (
    user_id = auth.uid()
    -- Karşı taraf da görebilmeli: uyarı onun ekranına düşüyor.
    or exists (select 1 from requests q where q.id = request_id
                 and (q.host_id = auth.uid() or q.guest_id = auth.uid()))
  );
-- Yazma YALNIZ fonksiyon üzerinden: istemci `passed: true` uyduramasın.
revoke insert, update, delete on public.session_verifications from anon, authenticated;

comment on table public.session_verifications is
  'Biniş kartı doğrulama kaydı. Ham BCBP dizesi ve görsel ASLA saklanmaz — yalnız türetilmiş alanlar + tuzlu karma.';

-- ── 3 · DOĞRULAMAYI KAYDET ─────────────────────────────────────────────
-- İstemci çözümlemeyi CİHAZDA yapar ve yalnız türetilmiş alanları yollar.
-- `p_pnr_girdi` karma için ham girdi; SAKLANMAZ, yalnız karmalanır.
create or replace function public.binis_karti_kaydet(
  p_request_id uuid,
  p_method text,
  p_passed boolean,
  p_reason_code text default null,
  -- ⚠️ `char(3)`/`char(1)` YAZMIŞTIM — İKİ SEBEPLE `text`E ÇEVİRDİM:
  -- (a) `char(n)` değeri SESSİZCE BOŞLUKLA DOLDURUR; 'IST ' ile 'IST'
  --     karşılaştırması ileride birini şaşırtır.
  -- (b) `contract_check.py` imza ayrıştırıcısı parantezli tipte
  --     parametreyi göremiyor ve çağrıyı "fazla parametre" sanıyor.
  --     Nöbetçiyi gevşetmek yerine imzayı sadeleştirmek doğru olan:
  --     kısıtı zaten gövde uyguluyor.
  -- 🆕 SINIF: "BİR PARAMETRE TİPİ HEM VERİYİ HEM DENETİMİ ŞAŞIRTIYORSA,
  -- SORUN DENETİMDE DEĞİL TİP SEÇİMİNDEDİR."
  p_airport text default null,
  p_flight_date date default null,
  p_carrier_flight text default null,
  p_cabin text default null,
  p_pnr_girdi text default null,
  p_duration_ms int default null
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid();
  v_tuz text; v_hash text; v_id uuid; v_diger uuid; v_ad text;
  v_q record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform public.hesap_kapisi(v_uid);

  select * into v_q from requests where id = p_request_id;
  if v_q.id is null then raise exception 'request_not_found'; end if;
  if v_uid not in (v_q.host_id, v_q.guest_id) then raise exception 'not_participant'; end if;

  if p_method not in ('scan', 'gallery', 'file', 'bypass') then
    raise exception 'gecersiz_yontem';
  end if;

  -- Karma: yalnız BAŞARILI ve ham girdisi olan doğrulamalarda
  if p_passed and coalesce(p_pnr_girdi, '') <> '' then
    select deger into v_tuz from sunucu_sirlari where anahtar = 'bp_tuz';
    v_hash := encode(sha256(convert_to(p_pnr_girdi || '|' || coalesce(v_tuz, ''), 'UTF8')), 'hex');
    -- Çifte kullanım: aynı biniş kartı başka bir hesapta doğrulanmışsa
    if exists (select 1 from session_verifications sv
                where sv.bp_hash = v_hash and sv.passed and sv.user_id <> v_uid) then
      raise exception 'zaten_dogrulandi';
    end if;
  end if;

  insert into session_verifications
    (request_id, user_id, method, passed, reason_code, airport_code,
     flight_date, carrier_flight, cabin_code, bp_hash, duration_ms)
  values (p_request_id, v_uid, p_method::public.bp_yontem, p_passed, p_reason_code,
          nullif(upper(trim(coalesce(p_airport, ''))), '')::char(3),
          p_flight_date, p_carrier_flight,
          nullif(upper(trim(coalesce(p_cabin, ''))), '')::char(1),
          v_hash, p_duration_ms)
  returning id into v_id;

  -- ── ESNEK GÜVENCE: karşı tarafa editoryal uyarı ───────────────────
  -- 🔴 METİN GÖKBERK'İN YAZDIĞI GİBİ, KELİMESİ KELİMESİNE.
  -- Akış KESİLMİYOR; yalnız karşı taraf bilgilendiriliyor.
  if p_method = 'bypass' or not p_passed then
    v_diger := case when v_uid = v_q.host_id then v_q.guest_id else v_q.host_id end;
    select coalesce(p.name, 'Yolcu') into v_ad from profiles p where p.user_id = v_uid;
    insert into notifications (user_id, category, title, body, ref_id, ref_type)
    values (v_diger, 'requests', 'Biniş kartı doğrulanamadı',
            'Dijital biniş kartı doğrulaması sistem şartlarından dolayı tamamlanamadı. '
            || 'Lütfen turnike geçişi esnasında salon kurallarına manuel olarak '
            || 'uyduğunuzdan emin olun.',
            p_request_id, 'request');
  end if;

  return jsonb_build_object('ok', true, 'id', v_id, 'method', p_method, 'passed', p_passed);
end $fn$;

drop function if exists public.binis_karti_kaydet(uuid, text, boolean, text, char, date, text, char, text, int);
grant execute on function public.binis_karti_kaydet(uuid, text, boolean, text, text, date, text, text, text, int)
  to authenticated;

-- ── 4 · BU İSTEKTE DOĞRULAMA DURUMU ────────────────────────────────────
-- Sohbet ekranı iki tarafın da durumunu gösterir: kim doğruladı, kim
-- atladı. "Karşı tarafın ekranına düşsün" tam olarak bu.
create or replace function public.binis_karti_durumu(p_request_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid(); v_q record; v_out jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_q from requests where id = p_request_id;
  if v_q.id is null then raise exception 'request_not_found'; end if;
  if v_uid not in (v_q.host_id, v_q.guest_id) then raise exception 'not_participant'; end if;

  select jsonb_object_agg(k, v) into v_out from (
    select case when sv.user_id = v_q.host_id then 'host' else 'guest' end as k,
           jsonb_build_object('method', sv.method, 'passed', sv.passed,
                              'reason', sv.reason_code, 'at', sv.created_at) as v
      from session_verifications sv
     where sv.request_id = p_request_id
       and sv.id = (select sv2.id from session_verifications sv2
                     where sv2.request_id = p_request_id and sv2.user_id = sv.user_id
                     order by sv2.created_at desc limit 1)
  ) x;
  return coalesce(v_out, '{}'::jsonb);
end $fn$;

grant execute on function public.binis_karti_durumu(uuid) to authenticated;

-- ── 5 · KENDİ SINAMASI ─────────────────────────────────────────────────
do $$
declare
  hd uuid; g uuid; lng uuid; av uuid; rq uuid; s jsonb; v_n int; v_ham text;
begin
  select id into hd from users where role = 'host' and deleted_at is null limit 1;
  select id into lng from lounges where airport_code = 'IST' limit 1;
  if hd is null or lng is null then raise notice '294 sinama: veri yok, atlandi'; return; end if;
  select id into g from users where id <> hd and deleted_at is null limit 1;

  insert into availabilities (host_id, airport_code, lounge_id, avail_date, time_from, time_to, slots, active)
    values (hd, 'IST', lng, public.yerel_gun('IST') + 7, time '10:00', time '13:00', 2, true)
    returning id into av;
  insert into requests (guest_id, host_id, avail_id, status) values (g, hd, av, 'accepted') returning id into rq;

  perform set_config('request.jwt.claims',
    json_build_object('sub', g::text, 'role', 'authenticated')::text, true);

  -- 1) Başarılı tarama kaydedilir, karma üretilir
  v_ham := 'ABC123|INAK|2026-09-20';
  s := public.binis_karti_kaydet(rq, 'scan', true, null, 'IST', date '2026-09-20', 'TK1979', 'Y', v_ham, 850);
  if (s ->> 'ok') is distinct from 'true' then raise exception '294: kayit dusru'; end if;
  if (select bp_hash from session_verifications where id = (s ->> 'id')::uuid) is null then
    raise exception '294: karma uretilmedi';
  end if;
  -- HAM DİZE HİÇBİR KOLONDA OLMAMALI
  if exists (select 1 from session_verifications sv where sv.id = (s ->> 'id')::uuid
               and (sv.bp_hash like '%ABC123%' or sv.carrier_flight like '%ABC123%')) then
    raise exception '294: HAM PNR sizdi';
  end if;
  raise notice '294 sinama 1 ✓ basarili tarama · karma uretildi · ham PNR sizmadi';

  -- 2) Aynı biniş kartı BAŞKA hesapta reddedilmeli
  perform set_config('request.jwt.claims',
    json_build_object('sub', hd::text, 'role', 'authenticated')::text, true);
  begin
    perform public.binis_karti_kaydet(rq, 'scan', true, null, 'IST', date '2026-09-20', 'TK1979', 'Y', v_ham, 700);
    raise exception '294: cifte kullanim engellenmedi';
  exception when others then
    if SQLERRM <> 'zaten_dogrulandi' then raise; end if;
    raise notice '294 sinama 2 ✓ ayni binis karti ikinci hesapta reddedildi';
  end;

  -- 3) Bypass akışı KESMEZ ve karşı tarafa uyarı düşer
  select count(*) into v_n from notifications where user_id = g;
  s := public.binis_karti_kaydet(rq, 'bypass', false, 'kullanici_atladi', null, null, null, null, null, null);
  if (s ->> 'ok') is distinct from 'true' then raise exception '294: bypass kaydi dusru'; end if;
  if (select count(*) from notifications where user_id = g) <= v_n then
    raise exception '294: bypassta karsi tarafa uyari gitmedi';
  end if;
  raise notice '294 sinama 3 ✓ bypass kaydedildi · karsi tarafa editoryal uyari gitti';

  -- 4) Durum sorgusu iki tarafı da gösterir
  s := public.binis_karti_durumu(rq);
  if not (s ? 'host' and s ? 'guest') then
    raise exception '294: durum sorgusu iki tarafi gostermiyor (%)', s;
  end if;
  raise notice '294 sinama 4 ✓ durum: %', s;

  -- 5) Katılımcı olmayan kaydedemez
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', (select id from users where id not in (hd, g) and deleted_at is null limit 1)::text,
                        'role', 'authenticated')::text, true);
    perform public.binis_karti_kaydet(rq, 'scan', true, null, 'IST', date '2026-09-20', 'TK1979', 'Y', 'XYZ|A|B', 100);
    raise exception '294: yabanci kullanici kaydedebildi';
  exception when others then
    if SQLERRM not in ('not_participant', 'hesap_kapali') then raise; end if;
    raise notice '294 sinama 5 ✓ katilimci olmayan kaydedemiyor (%)', SQLERRM;
  end;

  raise exception 'GERI_AL_SINAMA';
exception
  when others then
    if SQLERRM <> 'GERI_AL_SINAMA' then raise; end if;
    raise notice '294 sinama: tum veri geri alindi';
end $$;

select '294 kuruldu · binis karti dogrulama kaydi + cifte kullanim + esnek guvence' as sonuc;
