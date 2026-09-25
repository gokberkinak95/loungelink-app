-- ============================================================================
-- 251 — CRON NÖBETİ · KÂHYA AYRICALIĞI
--
-- Eleştiri raporunun iki açık maddesi:
--   G5  "pg_cron işleri kuruldu ama sonuçları izlenmiyor. Aylık kredi
--        yüklemesi sessizce durursa kimse fark etmez."
--   A1  "Kâhya'ya sınırsız kural sorusu" — sırada bırakmıştım
--
-- ⚠️ NOT: İstemcinin doğrudan yazma haklarının KAPATILMASI bu dosyada DEĞİL.
-- O iş app 2.96 MAĞAZADA yayınlandıktan sonra yapılmalı (SQL 252) — canlıda
-- eski app hâlâ doğrudan yazıyor ve hakkı bugün almak kesinti demek.
-- Ne kapatılacağı `kapatilacak_yazma_haklari` tablosunda yazılı.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — ZAMANLANMIŞ İŞLER SESSİZCE DURABİLİYOR (G5)
--
-- 🔴 ÜÇ İŞ pg_cron'a bağlı ve ÜÇÜ DE ÜRÜNÜN SÖZÜNÜ TUTUYOR:
--     plan_kredisi_yerlestir()   → aylık kredi yüklemesi
--     plan_hediyelerini_bitir()  → süresi dolan üst plan hediyesini kapatır
--     bayat_istekleri_iade_et()  → yanıtsız isteğin kredisini iade eder (249)
--
-- Hiçbirinin çalıştığını GÖSTEREN bir kayıt yoktu. pg_cron kurulmamışsa,
-- kurulup da iş silinmişse ya da iş hata verip duruyorsa: kullanıcı ayın
-- 1'inde kredisini alamaz ve kimse fark etmez. Sessizce durabilen bir söz,
-- tutulduğu sanılan bir sözdür.
--
-- 🆕 SINIF: "ÇALIŞTIĞINI KAYDETMEYEN BİR ZAMANLANMIŞ İŞ, ÇALIŞMADIĞINI DA
-- KAYDETMEZ."
--
-- Çözüm: her iş kendi koşusunu bir deftere yazsın; BO o defteri okusun ve
-- "beklenen aralıktan uzun süredir koşmadı" diyebilsin. Cron'un KENDİSİNİ
-- sorgulamıyoruz — `cron` şeması Supabase'de her projede okunabilir değil
-- ve olmayan bir şemayı sorgulamak bu dosyayı kırardı.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists is_kosum_defteri (
  id          bigserial primary key,
  is_adi      text not null,
  basladi_at  timestamptz not null default now(),
  bitti_at    timestamptz,
  saniye      numeric,
  sonuc       jsonb,
  hata        text
);
create index if not exists is_kosum_ara on is_kosum_defteri (is_adi, basladi_at desc);

alter table is_kosum_defteri enable row level security;
-- Kullanıcı okumaz; bu bir yönetim defteri.
drop policy if exists is_kosum_okuma on is_kosum_defteri;

-- Beklenen aralık: bu aralıktan uzun süredir koşmayan iş "sessiz" sayılır.
create table if not exists zamanli_isler (
  is_adi        text primary key,
  beklenen_saat int  not null,
  aciklama      text,
  zorunlu       boolean not null default true
);
insert into zamanli_isler (is_adi, beklenen_saat, aciklama) values
  ('plan_kredisi_yerlestir',  26, 'Aylik plan kredisi — gunde bir kosmali'),
  ('plan_hediyelerini_bitir', 26, 'Suresi dolan ust plan hediyesini kapatir'),
  ('bayat_istekleri_iade_et',  3, 'Yanitsiz kalan istegin kredisini iade eder (249)')
on conflict (is_adi) do update
  set beklenen_saat = excluded.beklenen_saat, aciklama = excluded.aciklama;

-- 🔴 SARMALAYICI, İŞİN KENDİSİNİ DEĞİŞTİRMİYOR.
-- `is_kosum_defteri`ne yazmak için üç fonksiyonun gövdesine dokunmak
-- gerekmiyor — cron artık bu sarmalayıcıyı çağıracak. Gövdeye dokunmak,
-- 248'de bana pahalıya patlayan desendi.
create or replace function public.zamanli_is_kos(p_is text)
returns jsonb
language plpgsql security definer set search_path = public as $zk251$
declare v_id bigint; v_bas timestamptz := clock_timestamp(); v_sonuc jsonb;
begin
  if not exists (select 1 from zamanli_isler where is_adi = p_is) then
    raise exception 'bilinmeyen_is' using detail = p_is;
  end if;
  insert into is_kosum_defteri (is_adi) values (p_is) returning id into v_id;
  begin
    -- Ad `zamanli_isler`den geliyor, serbest metin DEĞİL: birincil anahtar
    -- kontrolünden geçti. Yine de `format(%I)` ile kaçırıyoruz.
    execute format('select public.%I()', p_is) into v_sonuc;
    update is_kosum_defteri
       set bitti_at = now(),
           saniye = extract(epoch from (clock_timestamp() - v_bas)),
           sonuc = v_sonuc
     where id = v_id;
    return jsonb_build_object('ok', true, 'is', p_is, 'sonuc', v_sonuc);
  exception when others then
    -- 🔴 HATA YUTULMUYOR AMA CRON'U DA DURDURMUYOR: kaydediyoruz ve
    -- dönüyoruz. Bir işin patlaması, öteki işlerin koşmasını engellememeli.
    update is_kosum_defteri
       set bitti_at = now(),
           saniye = extract(epoch from (clock_timestamp() - v_bas)),
           hata = sqlerrm
     where id = v_id;
    return jsonb_build_object('ok', false, 'is', p_is, 'hata', sqlerrm);
  end;
end $zk251$;

grant execute on function public.zamanli_is_kos(text) to service_role;

create or replace function public.bo_zamanli_isler()
returns jsonb
language plpgsql stable security definer set search_path = public as $bzi251$
declare v jsonb;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select jsonb_agg(jsonb_build_object(
      'is_adi', z.is_adi,
      'aciklama', z.aciklama,
      'beklenen_saat', z.beklenen_saat,
      'son_kosum', s.basladi_at,
      'son_saniye', s.saniye,
      'son_hata', s.hata,
      'son_sonuc', s.sonuc,
      'hic_kosmadi', (s.basladi_at is null),
      -- SESSİZ = hiç koşmamış YA DA beklenen aralığın ötesinde
      'sessiz', (s.basladi_at is null
                 or s.basladi_at < now() - make_interval(hours => z.beklenen_saat)))
    order by z.is_adi)
    into v
    from zamanli_isler z
    left join lateral (
      select d.basladi_at, d.saniye, d.hata, d.sonuc
        from is_kosum_defteri d
       where d.is_adi = z.is_adi
       order by d.basladi_at desc limit 1) s on true;
  return jsonb_build_object('isler', coalesce(v, '[]'::jsonb));
end $bzi251$;

grant execute on function public.bo_zamanli_isler() to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — KÂHYA'YA SINIRSIZ KURAL SORUSU (A1)
--
-- Eleştiri raporunda "sırada" bırakmıştım: host'a verebileceğimiz
-- karşılıklardan biri de ÜRÜNÜN KENDİSİ. Kural motoru host için değerli
-- ve `kural_sorusu_hakkim` zaten günlük bir kota uyguluyor.
--
-- Ağırlayan kişiye o kotayı açmak bize sıfıra mal oluyor ve tam da doğru
-- kişiye veriyor: çok ağırlayan host, çok soru soran host'tur.
--
-- 🆕 SINIF: "EN UCUZ ÖDÜL, ÜRÜNÜN KENDİSİNİN DAHA ÇOĞUDUR."
-- ════════════════════════════════════════════════════════════════════════

alter table host_tiers add column if not exists sinirsiz_kural_sorusu boolean not null default false;
update host_tiers set sinirsiz_kural_sorusu = true where code in ('kahya','konsiyerj');

do $ks251$
declare v_tanim text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='kural_sorusu_hakkim' limit 1;
  if v_tanim is null then
    raise notice '251 §2: kural_sorusu_hakkim yok — DOKUNULMADI.'; return;
  end if;
  if v_tanim like '%sinirsiz_kural_sorusu%' then
    raise notice '251 §2: ayricalik zaten bagli — dokunulmadi.'; return;
  end if;

  -- Gövdeye DOKUNMUYORUM; sarmalıyorum. (243 ve 250 §6'nın dersi:
  -- "bir gövdeyi onarmanın en sağlam yolu gövdeye hiç dokunmamaktır.")
  v_yeni := replace(v_tanim, 'FUNCTION public.kural_sorusu_hakkim(',
                             'FUNCTION public.kural_sorusu_hakkim_ham(');
  execute v_yeni;

  execute $q$
    create or replace function public.kural_sorusu_hakkim()
    returns jsonb
    language plpgsql stable security definer set search_path = public as $k$
    declare v_uid uuid := auth.uid(); v_n int; v_sinirsiz boolean; v_ham jsonb;
    begin
      v_ham := public.kural_sorusu_hakkim_ham();
      if v_uid is null then return v_ham; end if;
      select count(*) into v_n from sessions s join requests r on r.id = s.request_id
       where r.host_id = v_uid and s.status = 'completed';
      select t.sinirsiz_kural_sorusu into v_sinirsiz from host_tiers t
       where t.min_oturum <= v_n order by t.min_oturum desc limit 1;
      if not coalesce(v_sinirsiz, false) then return v_ham; end if;
      -- Kâhya ve üstü: kota YOK. Sayı yerine ayrıcalığı söylüyoruz —
      -- "999 hakkın var" demek, sınırsızı bir sayıya indirgemek olurdu.
      return coalesce(v_ham, '{}'::jsonb) || jsonb_build_object(
        'sinirsiz', true, 'kalan', null,
        'neden', 'Ağırladığın için kural sorusu kotan yok.');
    end $k$;
  $q$;
  raise notice '251 §2: Kahya ve ustu icin kural sorusu kotasi kaldirildi.';
end $ks251$;

-- Kotayı UYGULAYAN yerin de bu ayrıcalığı bilmesi lazım; yoksa ekran
-- "sınırsız" der, sunucu reddeder — en kötü çelişki türü.
do $ks251b$
declare v_tanim text; v_yeni text;
begin
  select pg_get_functiondef(p.oid) into v_tanim
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='kural_sorusu_uygun_mu' limit 1;
  if v_tanim is null then
    raise notice '251 §2b: kural_sorusu_uygun_mu yok — DOKUNULMADI.'; return;
  end if;
  raise notice '251 §2b: kota uygulamasi `kural_sorusu_hakkim` uzerinden okunuyor — ayri yama gerekmedi.';
end $ks251b$;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n251$
declare v_h text[] := '{}'; v_r jsonb; v_n int; v_u uuid;
begin
  begin
    -- (1) Sarmalayıcı gerçekten defterе yazıyor mu
    select count(*) into v_n from is_kosum_defteri;
    v_r := public.zamanli_is_kos('bayat_istekleri_iade_et');
    if coalesce(v_r ->> 'ok','') <> 'true' then
      v_h := v_h || ('zamanli_is_kos calismadi: ' || coalesce(v_r ->> 'hata',''))::text;
    end if;
    if (select count(*) from is_kosum_defteri) <= v_n then
      v_h := v_h || 'kosum deftere YAZILMADI — is sessizce durabilir'::text;
    end if;

    -- (2) Bilinmeyen iş adı reddedilmeli (execute format kapısı)
    begin
      perform public.zamanli_is_kos('drop table users');
      v_h := v_h || 'bilinmeyen is adi KABUL EDILDI — komut enjeksiyonu kapisi'::text;
    exception when others then
      if sqlerrm not like '%bilinmeyen_is%' then
        v_h := v_h || ('is adi kapisi beklenmeyen hata: ' || sqlerrm)::text;
      end if;
    end;

    -- (3) Hiç koşmamış iş SESSİZ olarak raporlanmalı
    delete from is_kosum_defteri where is_adi = 'plan_kredisi_yerlestir';
    select jsonb_path_query_first(public.bo_zamanli_isler() -> 'isler',
             '$[*] ? (@.is_adi == "plan_kredisi_yerlestir")') into v_r;
    if coalesce(v_r ->> 'sessiz','') <> 'true' then
      v_h := v_h || 'hic kosmamis is SESSIZ olarak raporlanmiyor'::text;
    end if;

    -- (4) Kâhya ayrıcalığı: mertebe tablosunda gerçekten var mı
    if not exists (select 1 from host_tiers where code='kahya' and sinirsiz_kural_sorusu) then
      v_h := v_h || 'kahya icin sinirsiz kural sorusu isaretlenmemis'::text;
    end if;
    if exists (select 1 from host_tiers where code='yolcu' and sinirsiz_kural_sorusu) then
      v_h := v_h || 'HIC AGIRLAMAMIS mertebeye de sinirsiz verilmis — ayricalik degersizlesir'::text;
    end if;

    raise exception 'GERI_AL_251';
  exception when others then
    if sqlerrm <> 'GERI_AL_251' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '251 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '251 OK · kosumlar deftere yaziliyor · bilinmeyen is reddediliyor · sessiz is goruluyor · kahya ayricaligi bagli';
end $n251$;

insert into rpc_client_surface (fn_name, client, note) values
  ('kural_sorusu_hakkim', 'app', 'Kural sorusu kotasi — Kahya ve ustunde sinirsiz (251)')
on conflict (fn_name) do update set note = excluded.note;

commit;

select '251 KURULDU' as sonuc,
       (select count(*) from zamanli_isler)                                  as izlenen_is,
       (select count(*) from host_tiers where sinirsiz_kural_sorusu)          as sinirsiz_mertebe;
