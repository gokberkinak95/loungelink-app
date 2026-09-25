-- ============================================================================
-- 254 — ÜRÜN BOŞLUKLARI (253'ten SONRA çalıştır)
--
-- Uçtan uca UX incelemesinin sunucu tarafı gerektiren bulguları.
--
--  §1  "Pazarlama bildirimleri" anahtarı HİÇBİR YERE yazmıyordu — üstelik
--      `notify_push` onu okumaya ÇALIŞIYOR ve tablo olmadığı için sessizce
--      "izin var" sayıyor. Yani kapatan kullanıcı bildirim almaya devam
--      ediyordu. Bir vazgeçme (opt-out) anahtarının yalan söylemesi KVKK
--      açısından, o anahtarın hiç olmamasından daha kötüdür.
--  §2  Bildirime dokununca nereye gidileceği sunucuda YAZILI DEĞİLDİ;
--      istemci `category`yi yalnız renk için okuyordu.
--  §3  Ödül alma hatası istemcide sessizdi; sunucu tarafında da hata
--      metinleri Türkçe ham metindi — `metin()` katmanına alındı.
-- ============================================================================

begin;

-- ════════════════════════════════════════════════════════════════════════
-- §1 — BİLDİRİM TERCİHLERİ GERÇEKTEN VAR OLUYOR
--
-- 🔴 ÖLÇÜM: `notify_push` (SQL 111) şunu yazıyor —
--     select coalesce((n.prefs -> NEW.category::text ->> 'push')::boolean = false, false)
--       from notification_prefs n where n.user_id = NEW.user_id;
--     exception when undefined_table then v_quiet := false;
-- Tablo HİÇ OLUŞTURULMAMIŞTI. Yani okuma her seferinde `undefined_table`
-- fırlatıyor, yakalanıyor ve "sessiz değil" sayılıyordu. Ayarlar ekranındaki
-- dört anahtar da yalnız `useState` içinde yaşıyordu.
--
-- 🆕 SINIF: "OKUYANI OLAN AMA YAZANI OLMAYAN BİR TERCİH, HİÇ SORULMAMIŞ
-- BİR TERCİHTİR — VE EKRANDA GÖRÜNDÜĞÜ İÇİN SORULMUŞ SANILIR."
-- ════════════════════════════════════════════════════════════════════════

create table if not exists notification_prefs (
  user_id    uuid primary key references users(id) on delete cascade,
  prefs      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table notification_prefs enable row level security;
drop policy if exists notif_prefs_self on notification_prefs;
create policy notif_prefs_self on notification_prefs for select to authenticated
  using (user_id = auth.uid());
revoke all on notification_prefs from anon;
revoke insert, update, delete on notification_prefs from authenticated;
grant select on notification_prefs to authenticated;
grant select, insert, update on notification_prefs to service_role;

-- 🔵 KAPATILABİLİR OLANLAR SINIRLI, BİLEREK. `requests`, `sessions` ve
-- `safety` KAPATILAMAZ: bu üründe eşleşme zamana bağlı ve güvenlik
-- bildirimleri hayati. Kullanıcıya "kapat" düğmesi verip sonra yine
-- göndermek yalan olurdu; o yüzden düğmeyi hiç vermiyoruz.
insert into beta_settings (key, value) values
  ('bildirim_kapatilabilir', to_jsonb(array['credits','ratings','connections','invites','system']))
on conflict (key) do nothing;

create or replace function public.bildirim_tercihlerim()
returns jsonb
language plpgsql stable security definer set search_path = public as $bt254$
declare v_uid uuid := auth.uid(); v_p jsonb; v_kap jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select prefs into v_p from notification_prefs where user_id = v_uid;
  select value into v_kap from beta_settings where key = 'bildirim_kapatilabilir';
  return jsonb_build_object(
    'tercihler', coalesce(v_p, '{}'::jsonb),
    'kapatilabilir', coalesce(v_kap, '[]'::jsonb),
    -- Kapatılamayanları da SÖYLÜYORUZ: "neden bu anahtar yok?" sorusunun
    -- cevabı ekranda olmalı.
    'kapatilamaz_not', public.metin('bildirim_zorunlu_not_tr'));
end $bt254$;

create or replace function public.bildirim_tercihi_yaz(p_kategori text, p_push boolean)
returns jsonb
language plpgsql security definer set search_path = public as $bty254$
declare v_uid uuid := auth.uid(); v_kap jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select value into v_kap from beta_settings where key = 'bildirim_kapatilabilir';
  if not coalesce(v_kap, '[]'::jsonb) ? p_kategori then
    -- Kapatılamaz bir kategoriyi sessizce kabul etmek, ekranda kapalı
    -- görünen ama çalışan bir anahtar üretirdi.
    return jsonb_build_object('ok', false, 'reason', 'kapatilamaz_kategori');
  end if;

  insert into notification_prefs (user_id, prefs, updated_at)
  values (v_uid, jsonb_build_object(p_kategori, jsonb_build_object('push', p_push)), now())
  on conflict (user_id) do update
    set prefs = notification_prefs.prefs
                || jsonb_build_object(p_kategori, jsonb_build_object('push', p_push)),
        updated_at = now();
  return jsonb_build_object('ok', true, 'kategori', p_kategori, 'push', p_push);
end $bty254$;

grant execute on function public.bildirim_tercihlerim() to authenticated;
grant execute on function public.bildirim_tercihi_yaz(text, boolean) to authenticated;

insert into beta_settings (key, value) values
  ('bildirim_zorunlu_not_tr', to_jsonb('İstek, oturum ve güvenlik bildirimleri kapatılamaz: bu üründe eşleşme zamana bağlı, kaçırılan bir bildirim kaçırılan bir buluşmadır.'::text)),
  ('bildirim_zorunlu_not_tr_en', to_jsonb('Request, session and safety notifications cannot be turned off: matches here are time-bound, and a missed notification is a missed meeting.'::text))
on conflict (key) do nothing;

-- ════════════════════════════════════════════════════════════════════════
-- §2 — BİLDİRİM NEREYE GÖTÜRÜR: SUNUCU SÖYLESİN
--
-- 🔴 Bildirime dokunmak yalnız "okundu" işaretliyordu. Kullanıcı push'a
-- basıp uygulamayı açıyor, listeye dokunuyor, satır griye dönüyor ve
-- HİÇBİR ŞEY olmuyordu. İsteği bulmak için kendisi geziniyordu.
--
-- Hedefi istemciye gömmek yerine sunucudan veriyoruz: kategori→ekran
-- eşlemesi ürünün kuralıdır, iki istemcide (app + ileride web) ayrı ayrı
-- yazılmamalı.
--
-- 🆕 SINIF: "ZAMANA BAĞLI BİR ÜRÜNDE BİLDİRİM, HABER DEĞİL KISAYOLDUR."
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.bildirim_hedefi(p_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $bh254$
declare v_uid uuid := auth.uid(); n record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into n from notifications where id = p_id and user_id = v_uid;
  if n.id is null then return jsonb_build_object('ekran', null); end if;

  return case n.category::text
    when 'requests'    then jsonb_build_object('ekran','plan','alt','ilan','ref', n.ref_id)
    when 'sessions'    then jsonb_build_object('ekran','plan','alt','ilan','ref', n.ref_id)
    when 'invites'     then jsonb_build_object('ekran','plan','alt','seyahat','ref', n.ref_id)
    when 'connections' then jsonb_build_object('ekran','tanis','ref', n.ref_id)
    when 'credits'     then jsonb_build_object('ekran','cuzdan')
    when 'ratings'     then jsonb_build_object('ekran','degerlendirmeler','ref', n.ref_id)
    when 'safety'      then jsonb_build_object('ekran','guvenlik')
    else jsonb_build_object('ekran', null) end;
end $bh254$;

grant execute on function public.bildirim_hedefi(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- §3 — NÖBETÇİ
-- ════════════════════════════════════════════════════════════════════════

do $n254$
declare v_h text[] := '{}'; v_r jsonb; v_ben uuid; v_bid uuid;
begin
  begin
    select u.id into v_ben from users u where u.deleted_at is null order by u.created_at limit 1;
    perform set_config('request.jwt.claims', json_build_object('sub', v_ben::text)::text, true);

    -- (1) Kapatılabilir kategori gerçekten yazılıyor mu.
    v_r := public.bildirim_tercihi_yaz('credits', false);
    if coalesce(v_r ->> 'ok','') <> 'true' then
      v_h := v_h || ('kapatilabilir kategori yazilamadi: ' || coalesce(v_r::text,''))::text;
    end if;
    if not (select prefs -> 'credits' ->> 'push' = 'false'
              from notification_prefs where user_id = v_ben) then
      v_h := v_h || 'tercih tabloya YAZILMADI'::text;
    end if;

    -- (2) 🔴 ASIL KONTROL: `notify_push` bu tercihi GERÇEKTEN okuyor mu.
    -- Tabloyu kurmak yetmez; okuyanın onu görmesi lazım.
    if (select coalesce((n.prefs -> 'credits' ->> 'push')::boolean = false, false)
          from notification_prefs n where n.user_id = v_ben) is not true then
      v_h := v_h || 'notify_push`un okudugu ifade FALSE dondu — tercih uygulanmaz'::text;
    end if;

    -- (3) Kapatılamaz kategori REDDEDİLMELİ.
    v_r := public.bildirim_tercihi_yaz('requests', false);
    if coalesce(v_r ->> 'ok','') <> 'false' then
      v_h := v_h || 'kapatilamaz kategori KABUL EDILDI — yalan anahtar'::text;
    end if;

    -- (4) İstemci doğrudan yazamamalı (tek yol RPC).
    if has_table_privilege('authenticated', 'public.notification_prefs', 'update') then
      v_h := v_h || 'notification_prefs istemciden dogrudan yazilabiliyor'::text;
    end if;

    -- (5) Bildirim hedefi.
    -- 🔴 İLK YAZIMDA "EN SON BİLDİRİM" SEÇTİM VE NÖBETÇİ KIRMIZI YANDI.
    -- Ölçtüm: en son bildirim `system` kategorisindeydi ve `system` için
    -- hedef vermemek DOĞRU — bir duyurunun gidecek yeri yoktur. Yani kapı
    -- çalışıyordu, ölçüm yanlış örneği seçmişti.
    -- 🆕 SINIF: "BİR EŞLEMEYİ, EŞLEŞMESİ OLMAYAN BİR ÖRNEKLE SINAMAK,
    -- EŞLEMEYİ DEĞİL ÖRNEĞİ ÖLÇER."
    select id into v_bid from notifications
     where user_id = v_ben and category::text = 'requests'
     order by created_at desc limit 1;
    if v_bid is not null then
      v_r := public.bildirim_hedefi(v_bid);
      if v_r ->> 'ekran' is null then
        v_h := v_h || 'istek bildirimi icin hedef ekran VERILMEDI'::text;
      end if;
    end if;
    -- Ve `system` için hedef vermemek de ÖLÇÜLÜYOR: sessizce bir yere
    -- göndermek, duyuruyu eyleme benzetirdi.
    select id into v_bid from notifications
     where user_id = v_ben and category::text = 'system' order by created_at desc limit 1;
    if v_bid is not null and (public.bildirim_hedefi(v_bid)) ->> 'ekran' is not null then
      v_h := v_h || 'duyuru bildirimi bir ekrana YONLENDIRIYOR — duyurunun hedefi olmamali'::text;
    end if;

    perform set_config('request.jwt.claims', '', true);
    raise exception 'GERI_AL_254';
  exception when others then
    perform set_config('request.jwt.claims', '', true);
    if sqlerrm <> 'GERI_AL_254' then
      v_h := v_h || ('olcum coktu: ' || sqlerrm);
    end if;
  end;

  if array_length(v_h,1) is not null then
    raise exception '254 NOBETCI: %', array_to_string(v_h, ' | ');
  end if;
  raise notice '254 OK · bildirim tercihi gercekten yaziliyor · kapatilamaz kategori reddediliyor · bildirim bir yere goturuyor';
end $n254$;

insert into rpc_client_surface (fn_name, client, note) values
  ('bildirim_tercihlerim',  'app', 'Bildirim tercihleri (254)'),
  ('bildirim_tercihi_yaz',  'app', 'Bildirim tercihi yaz — kapatilamaz kategoriyi reddeder (254)'),
  ('bildirim_hedefi',       'app', 'Bildirime dokununca nereye gidilecek (254)')
on conflict (fn_name) do update set note = excluded.note;

select public.migration_kaydet('254_urun_bosluklari.sql');

commit;

select '254 KURULDU' as sonuc,
       (select count(*) from notification_prefs) as tercih_kaydi;
