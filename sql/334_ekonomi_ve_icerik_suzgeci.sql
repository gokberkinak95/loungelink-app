-- ============================================================================
-- 334 · ÜYELİK MODELİ + BAĞLANTI SINIRI + KULLANICI İÇERİĞİ SÜZGECİ (16 Ekim 2026)
--
-- Gökberk ile kararlaştırılan model (16 Ekim, mağaza öncesi):
--   KREDİ = YALNIZ GERÇEKLEŞEN LOUNGE GİRİŞİ (red, yanıtsız, kapıda ret → iade).
--   Bu yüzden kredi değerli bir birim; eski sayılar (Yolcu ayda 1, Sık Uçan 6, Kâhya 12,
--   kayıtta 5) kimseyi ücretli plana geçirmeyecek kadar cömertti.
--
--   Yolcu (ücretsiz) : kayıtta 1 kredi (ilk giriş bizden) · aylık kredi YOK · 1 açık istek
--                      · haftada 3 bağlantı isteği · ağırlayarak kredi kazanır
--   Sık Uçan ₺99,99  : her ay 3 kredi (≈ ₺33/giriş) · 3 açık istek · haftada 15 bağlantı
--   Kâhya   ₺199,99  : her ay 7 kredi (≈ ₺28,6/giriş) · 6 açık istek · sınırsız bağlantı
--   Paket (tek sefer): 1 kredi ₺79,99 · 3 kredi ₺199,99 · 5 kredi ₺299,99
--
--   PLAN KREDİSİ DEVRETMEZ: ay dönünce önceki ayın KULLANILMAYAN plan kredisi düşülür, yeni
--   ayın payı yüklenir. Önce plan kredisi harcanmış sayılır. Satın alınan PAKET kredisi ve
--   AĞIRLAYARAK kazanılan kredi süresizdir (parayla alınan hakkı süreyle yakmak tüketici
--   şikâyeti ve mağaza iadesi doğurur; host'u ödüllendiren tek somut şey ağırlama kredisi).
--
--   BAĞLANTI SINIRI: Tanış'tan toplu bağlantı açıp krediyi atlatmayı zorlaştırır ve ücretli
--   planın ikinci somut gerekçesidir. Soru akışının (kural_sorusu) açtığı bağlantılar SAYILMAZ.
-- Tekrar koşulabilir.
-- ============================================================================

-- ── §1 · Plan kataloğu ─────────────────────────────────────────────────────
alter table plan_catalog add column if not exists baglanti_haftalik int;   -- null = sınırsız

update plan_catalog set monthly_credits = 0, acik_istek_tavani = 1, baglanti_haftalik = 3,
       perks = '["Kayıtta 1 kredi: ilk lounge girişin bizden", "Ağırlayarak kredi kazan", "Aynı anda 1 açık istek", "Haftada 3 bağlantı isteği", "Kural motoru, sohbet ve güvenlik araçları"]'::jsonb,
       perks_en = '["1 credit on sign-up: your first lounge visit is on us", "Earn credits by hosting", "1 open request at a time", "3 connection requests a week", "Rule engine, chat and safety tools"]'::jsonb
 where plan = 'yolcu';

update plan_catalog set monthly_credits = 3, price_try = 99, yillik_try = 899, acik_istek_tavani = 3, baglanti_haftalik = 15,
       perks = '["Her ay 3 lounge girişi (aylık kredi devretmez)", "Aynı anda 3 host''a istek: kabul şansın katlanır", "Haftada 15 bağlantı isteği", "Haftalık kaçırılan fırsat bildirimi", "Kart hakkı dolma uyarısı: 90 · 30 · 7 gün önce", "Ayda 3 ilan öne çıkarma"]'::jsonb,
       perks_en = '["3 lounge visits every month (monthly credits do not roll over)", "Request 3 hosts at once: multiply your chance", "15 connection requests a week", "Weekly missed-opportunity alerts", "Card benefit expiry alerts: 90 · 30 · 7 days ahead", "Feature a listing 3× a month"]'::jsonb
 where plan = 'sik_ucan';

update plan_catalog set monthly_credits = 7, price_try = 199, yillik_try = 1799, acik_istek_tavani = 6, baglanti_haftalik = null,
       perks = '["Her ay 7 lounge girişi (aylık kredi devretmez)", "Aynı anda 6 host''a istek", "Sınırsız bağlantı isteği", "Anlık kaçırılan fırsat bildirimi", "Kart hakkı dolma uyarısı: 90 · 30 · 7 gün önce", "Ayda 8 ilan öne çıkarma", "Öncelikli destek"]'::jsonb,
       perks_en = '["7 lounge visits every month (monthly credits do not roll over)", "Request 6 hosts at once", "Unlimited connection requests", "Instant missed-opportunity alerts", "Card benefit expiry alerts: 90 · 30 · 7 days ahead", "Feature a listing 8× a month", "Priority support"]'::jsonb
 where plan = 'kahya';

-- ── §2 · Kredi paketleri: 1 · 3 · 5 ────────────────────────────────────────
-- "altili" (6) yerini "besli" (5) alır; eski kayıt silinmez, pasifleşir (geçmiş satışlar ona bağlı).
update kredi_paketleri set aktif = false where kod = 'altili';
insert into kredi_paketleri (kod, ad, kredi, fiyat_try, sira, aktif, one_cikan, aciklama) values
  ('besli', 'Beş hak', 5, 299, 3, true, false, 'Yoğun bir seyahat dönemi için.')
on conflict (kod) do update set ad = excluded.ad, kredi = excluded.kredi, fiyat_try = excluded.fiyat_try,
  sira = excluded.sira, aktif = true, guncellendi = now();
update kredi_paketleri set fiyat_try = 79,  guncellendi = now() where kod = 'tek';
update kredi_paketleri set fiyat_try = 199, guncellendi = now() where kod = 'uclu';

insert into iap_urunleri (urun_kodu, tur, paket_kod, plan, donem) values
  ('ll_kredi_5', 'kredi', 'besli', null, null)
on conflict (urun_kodu) do update set paket_kod = excluded.paket_kod, aktif = true;
update iap_urunleri set aktif = false where urun_kodu = 'll_kredi_6';

-- Cüzdan ipucu: abonelik önerisi GİRİŞ planı (en düşük fiyatlı ücretli plan) — kredi başına
-- en ucuz plan artık Kâhya; ilk adım olarak onu önermek yanlış basamağı gösterirdi.
do $kp334$
declare v text;
begin
  v := pg_get_functiondef('public.kredi_paketleri()'::regprocedure);
  if position('order by pc.price_try::numeric / pc.monthly_credits asc' in v) > 0 then
    execute replace(v, 'order by pc.price_try::numeric / pc.monthly_credits asc', 'order by pc.price_try asc');
  end if;
end $kp334$;

-- Plan ekranı açık istek ve bağlantı sınırını da gösterir.
create or replace function public.subscription_plans(p_lang text default 'tr')
returns jsonb language sql stable security definer set search_path = public as $sp334$
  select jsonb_agg(jsonb_build_object(
           'plan', p.plan, 'ad',
             case when lower(coalesce(p_lang,'tr')) = 'en'
                  then coalesce(nullif(p.ad_en,''), p.ad) else p.ad end,
           'aylik_kredi', p.monthly_credits,
           'aylik_fiyat', p.price_try, 'yillik_fiyat', p.yillik_try,
           'yillik_indirim_yuzde', case when p.price_try > 0 and p.yillik_try > 0
             then round(100 - (p.yillik_try::numeric / (p.price_try * 12) * 100)) end,
           'haklar',
             case when lower(coalesce(p_lang,'tr')) = 'en'
                       and jsonb_array_length(coalesce(p.perks_en,'[]'::jsonb)) > 0
                  then p.perks_en else p.perks end,
           'sira', p.sort_order,
           'kacirilan_sikligi', p.kacirilan_sikligi,
           'oncelikli_destek', p.oncelikli_destek,
           'acik_istek', p.acik_istek_tavani,
           'baglanti_haftalik', p.baglanti_haftalik)
         order by p.sort_order)
    from plan_catalog p where p.aktif;
$sp334$;

-- ── §3 · Kayıt hediyesi 1 ──────────────────────────────────────────────────
update beta_settings set value = jsonb_set(value, '{amount}', '1'::jsonb) where key = 'signup_credits';

-- ── §4 · Aylık plan kredisi: devretmez ─────────────────────────────────────
-- Önceki ayın plan kredisinden kullanılmayanı bul: o aydan beri yapılan NET istek harcaması
-- (tutma − iade) önce plan kredisinden düşülmüş sayılır. Gelir kalemleri (paket, ağırlama,
-- hediye, yönetici, plan payları) harcama değildir.
create or replace function public.plan_kredisi_kalan(p_user uuid)
returns int
language sql stable security definer set search_path = public as $pkk334$
  with son as (
    select substring(reason from '^plan_monthly:([0-9]{4}-[0-9]{2})') as ay, min(created_at) as bas, sum(delta) as pay
      from credit_ledger
     where user_id = p_user and reason ~ '^plan_monthly:[0-9]{4}-[0-9]{2}:' and delta > 0
     group by 1 order by 1 desc limit 1
  ), harcama as (
    select coalesce(-sum(c.delta), 0) as net
      from credit_ledger c, son
     where c.user_id = p_user and c.created_at >= son.bas
       and c.reason !~ '^(plan_monthly|plan_expire|kredi_satin_alma|kredi_magaza_iadesi|hosted_session|beta_signup|signup|admin|paid_guest|seed)'
  )
  select greatest(0, least(son.pay - greatest(harcama.net, 0),
                           (select coalesce(sum(delta), 0) from credit_ledger where user_id = p_user)))::int
    from son, harcama;
$pkk334$;

create or replace function public.plan_kredisi_yerlestir(p_user uuid default null::uuid)
returns jsonb
language plpgsql security definer set search_path to 'public' as $pk334$
declare
  v_uid uuid := public.kimlik(p_user);
  v_ay text; v_n int; v_reason text; v_bal int; v_plan plan_type;
  v_onceki int := 0; v_son_ay text; v_yanan int := 0;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'neden', 'oturum_yok'); end if;

  v_ay := to_char(timezone('Europe/Istanbul', now()), 'YYYY-MM');

  -- 1) Önceki ayın kullanılmayan plan kredisi düşer (ayda bir kez).
  select max(substring(reason from '^plan_monthly:([0-9]{4}-[0-9]{2})')) into v_son_ay
    from credit_ledger where user_id = v_uid and reason ~ '^plan_monthly:[0-9]{4}-[0-9]{2}:' and delta > 0;
  if v_son_ay is not null and v_son_ay < v_ay
     and not exists (select 1 from credit_ledger where user_id = v_uid and reason = 'plan_expire:' || v_son_ay) then
    v_yanan := coalesce(public.plan_kredisi_kalan(v_uid), 0);
    select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = v_uid;
    insert into credit_ledger (user_id, delta, reason, balance_after, note)
    values (v_uid, -v_yanan, 'plan_expire:' || v_son_ay, v_bal - v_yanan,
            format('%s ayının kullanılmayan %s plan kredisi devretmedi', v_son_ay, v_yanan));
  end if;

  -- 2) Bu ayın payı.
  v_plan := public.etkin_plan(v_uid);
  v_reason := 'plan_monthly:' || v_ay || ':' || v_plan::text;
  if exists (select 1 from credit_ledger where user_id = v_uid and reason = v_reason) then
    return jsonb_build_object('ok', true, 'durum', 'zaten_verildi', 'ay', v_ay, 'plan', v_plan, 'yanan', v_yanan);
  end if;

  select coalesce(p.monthly_credits, 0) into v_n from plan_catalog p where p.plan = v_plan and p.aktif;
  v_n := coalesce(v_n, 0);
  if v_n <= 0 then
    return jsonb_build_object('ok', true, 'durum', 'plan_kredisi_yok', 'ay', v_ay, 'yanan', v_yanan);
  end if;

  -- Ay içinde plan yükseldiyse yalnız FARK verilir.
  select coalesce(sum(delta), 0) into v_onceki from credit_ledger
   where user_id = v_uid and reason like 'plan_monthly:' || v_ay || ':%';
  if v_onceki >= v_n then
    return jsonb_build_object('ok', true, 'durum', 'zaten_yeterli', 'ay', v_ay, 'yanan', v_yanan);
  end if;
  v_n := v_n - v_onceki;

  select coalesce(sum(delta), 0) into v_bal from credit_ledger where user_id = v_uid;
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (v_uid, v_n, v_reason, v_bal + v_n);

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_uid, 'credits', 'Aylık kredin yüklendi ✓',
          v_n || ' kredi hesabına eklendi. Aylık plan kredisi bir sonraki aya devretmez.',
          'credits');

  return jsonb_build_object('ok', true, 'durum', 'verildi', 'adet', v_n, 'ay', v_ay, 'plan', v_plan, 'yanan', v_yanan);
exception when others then
  return jsonb_build_object('ok', false, 'neden', sqlerrm);
end $pk334$;

-- ── §5 · Haftalık bağlantı isteği sınırı ───────────────────────────────────
create or replace function public.baglanti_hakkim(p_user uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $bh334$
declare v_uid uuid := public.kimlik(p_user); v_tavan int; v_kul int; v_ilk timestamptz;
begin
  if v_uid is null then return jsonb_build_object('ok', false); end if;
  select p.baglanti_haftalik into v_tavan from plan_catalog p where p.plan = public.etkin_plan(v_uid);
  select count(*), min(created_at) into v_kul, v_ilk
    from connection_requests
   where from_id = v_uid and created_at > now() - interval '7 days'
     and coalesce(intent, '') <> 'kural_sorusu';
  return jsonb_build_object('ok', true, 'sinirsiz', v_tavan is null, 'tavan', v_tavan,
    'kullanilan', v_kul, 'kalan', case when v_tavan is null then null else greatest(0, v_tavan - v_kul) end,
    'yenilenme', case when v_ilk is null then null else v_ilk + interval '7 days' end);
end $bh334$;
revoke all on function public.baglanti_hakkim(uuid) from public, anon;
grant execute on function public.baglanti_hakkim(uuid) to authenticated, service_role;

do $sc334$
declare v text;
begin
  v := pg_get_functiondef('public.send_connection(uuid, text, text)'::regprocedure);
  if position('baglanti_haftalik_sinir' in v) = 0 then
    v := replace(v,
      '  if public.is_blocked_pair(v_uid, p_to) then raise exception ''blocked_pair''; end if;',
      '  if public.is_blocked_pair(v_uid, p_to) then raise exception ''blocked_pair''; end if;
  -- 334 · haftalık bağlantı isteği sınırı (Yolcu 3 · Sık Uçan 15 · Kâhya sınırsız)
  if coalesce((public.baglanti_hakkim(v_uid) ->> ''kalan'')::int, 1) <= 0 then
    raise exception ''baglanti_haftalik_sinir'';
  end if;');
    if position('baglanti_haftalik_sinir' in v) = 0 then
      raise exception '334: send_connection icinde ekleme noktasi bulunamadi';
    end if;
    execute v;
  end if;
end $sc334$;

-- ── §5b · BO: kaçak göstergesi ─────────────────────────────────────────────
-- Tanış sohbetinde lounge'a birlikte girmeyi konuşan çiftlerden kaçı aynı dönemde RESMİ bir
-- oturuma döndü? Dönmeyenlerin oranı yüksekse uygulamadaki yönlendirme ve bağlantı sınırı
-- sıkılaştırılır; düşükse kullanıcı boşuna yorulmaz. Yalnız sayı döner, mesaj içeriği dönmez.
create or replace function public.bo_kacak_gostergesi(p_gun int default 30)
returns jsonb
language plpgsql stable security definer set search_path = public as $kg334$
declare v_gun int := greatest(1, least(coalesce(p_gun, 30), 365)); v jsonb;
begin
  if auth.uid() is not null and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  with konusan as (
    select distinct c.id as kanal, least(cr.from_id, cr.to_id) as a, greatest(cr.from_id, cr.to_id) as b
      from chat_channels c
      join connection_requests cr on cr.id = c.connection_id
      join messages m on m.channel_id = c.id
     where c.kind = 'companion' and m.created_at > now() - make_interval(days => v_gun)
       and lower(m.body) ~ '(lounge|salona|salonda|misafir olarak|misafirin olay|kartımla|kartinla|kartınla|yanına al|yanina al|birlikte gir|beraber gir|take me in|as your guest|guest pass)'
  ), sonuc as (
    select k.*, exists (
      select 1 from sessions s join requests r on r.id = s.request_id
       where r.created_at > now() - make_interval(days => v_gun)
         and least(r.guest_id, r.host_id) = k.a and greatest(r.guest_id, r.host_id) = k.b) as resmi
      from konusan k
  )
  select jsonb_build_object('gun', v_gun,
           'lounge_konusan_cift', count(*),
           'resmi_oturuma_donen', count(*) filter (where resmi),
           'donmeyen', count(*) filter (where not resmi),
           'donmeyen_orani', case when count(*) > 0 then round(100.0 * count(*) filter (where not resmi) / count(*)) end)
    into v from sonuc;
  return v;
end $kg334$;
revoke all on function public.bo_kacak_gostergesi(int) from public, anon;
grant execute on function public.bo_kacak_gostergesi(int) to authenticated, service_role;

-- ── §6 · Uygunsuz içerik süzgeci (Apple 1.2) ───────────────────────────────────────────
create or replace function public.uygunsuz_maskele(p text)
returns text
language plpgsql immutable set search_path = public as $um334$
declare
  r record; v_out text := ''; v_norm text; v_bas text;
  -- Normalize sözcükle TAM eşleşir (önek kökler `.*` ile). Liste bilerek dar.
  v_desen constant text :=
    '^(siktir.*|sikeyim|sikerim|sikiyim|sikik.*|sikiş.*|sikis.*|yarrak.*|yarak|amk|amq|amına.*|amina.*|amını|amini|'
    'amcık.*|amcik.*|orospu.*|oç|piç|piçler|göt|götveren|gotveren|ibne.*|pezevenk.*|kahpe.*|şerefsiz.*|serefsiz.*|'
    'gavat.*|yavşak.*|yavsak.*|puşt.*|pust|kaltak.*|sürtük.*|surtuk.*|ananı|anani|'
    'fuck.*|motherfuck.*|shit|shitty|bitch.*|cunt.*|nigg.*|faggot.*|asshole.*|whore.*|slut.*|dick|pussy)$';
begin
  if p is null or p = '' then return p; end if;
  v_bas := substring(p from '^\s*');
  v_out := coalesce(v_bas, '');
  for r in select m[1] as tok, m[2] as sp from regexp_matches(p, '(\S+)(\s*)', 'g') as m loop
    v_norm := lower(translate(r.tok, 'ÇĞİIÖŞÜÂÎÛ', 'çğiıöşüâîû'));
    v_norm := regexp_replace(v_norm, '[^a-zçğıöşüâîû0-9]', '', 'g');
    if v_norm <> '' and v_norm ~ v_desen then
      v_out := v_out || '•••' || r.sp;
    else
      v_out := v_out || r.tok || r.sp;
    end if;
  end loop;
  return v_out;
end $um334$;
grant execute on function public.uygunsuz_maskele(text) to authenticated, service_role;

-- Sohbet: mevcut süzgece (255) uygunsuz sözcük maskesi + işaret eklenir.
create or replace function public.trg_sohbet_suzgeci() returns trigger
language plpgsql security definer set search_path = public as $tss334$
declare v jsonb; v_temiz text;
begin
  v := public.sohbet_temizle(new.body);
  new.body := v ->> 'body';
  v_temiz := public.uygunsuz_maskele(new.body);
  if v_temiz is distinct from new.body then
    new.body := v_temiz;
    v := jsonb_set(v, '{sebep}', coalesce(v -> 'sebep', '[]'::jsonb) || '"uygunsuz"'::jsonb);
  end if;
  if jsonb_array_length(coalesce(v -> 'sebep', '[]'::jsonb)) > 0 then
    new.flagged := true;
    new.flag_reason := array_to_string(array(select jsonb_array_elements_text(v -> 'sebep')), ',');
  end if;
  return new;
exception when others then
  return new;
end $tss334$;

-- Diğer görünür metinler: tetikleyiciye kolon adları argüman olarak verilir.
create or replace function public.trg_uygunsuz_suz() returns trigger
language plpgsql security definer set search_path = public as $tus334$
declare c text; v text; m text; j jsonb := to_jsonb(new); degisti boolean := false;
begin
  foreach c in array tg_argv loop
    v := j ->> c;
    if v is not null then
      m := public.uygunsuz_maskele(v);
      if m is distinct from v then
        j := jsonb_set(j, array[c], to_jsonb(m));
        degisti := true;
      end if;
    end if;
  end loop;
  if degisti then new := jsonb_populate_record(new, j); end if;
  return new;
exception when others then
  return new;
end $tus334$;

drop trigger if exists trg_uygunsuz_profil on profiles;
create trigger trg_uygunsuz_profil before insert or update of name, bio, profession on profiles
  for each row execute function public.trg_uygunsuz_suz('name', 'bio', 'profession');
drop trigger if exists trg_uygunsuz_baglanti on connection_requests;
create trigger trg_uygunsuz_baglanti before insert or update of intro, cevap, cevap_notu on connection_requests
  for each row execute function public.trg_uygunsuz_suz('intro', 'cevap', 'cevap_notu');
drop trigger if exists trg_uygunsuz_soru on kural_sorulari;
create trigger trg_uygunsuz_soru before insert or update of soru, cevap, cevap_notu on kural_sorulari
  for each row execute function public.trg_uygunsuz_suz('soru', 'cevap', 'cevap_notu');
drop trigger if exists trg_uygunsuz_puan on ratings;
create trigger trg_uygunsuz_puan before insert or update of comment on ratings
  for each row execute function public.trg_uygunsuz_suz('comment');
drop trigger if exists trg_uygunsuz_istek on requests;
create trigger trg_uygunsuz_istek before insert or update of intro_message, decision_note on requests
  for each row execute function public.trg_uygunsuz_suz('intro_message', 'decision_note');
drop trigger if exists trg_uygunsuz_davet on invites;
create trigger trg_uygunsuz_davet before insert or update of note on invites
  for each row execute function public.trg_uygunsuz_suz('note');
drop trigger if exists trg_uygunsuz_ilan on availabilities;
create trigger trg_uygunsuz_ilan before insert or update of rule_note on availabilities
  for each row execute function public.trg_uygunsuz_suz('rule_note');

-- ── DOĞRULAMA ──────────────────────────────────────────────────────────────
select 'kahya kredi basi en ucuz' as kontrol,
       (select price_try::numeric / monthly_credits from plan_catalog where plan = 'kahya')
     < (select price_try::numeric / monthly_credits from plan_catalog where plan = 'sik_ucan') as tamam
union all
select 'yolcu aylik kredi yok, kayit hediyesi 1',
       (select monthly_credits from plan_catalog where plan = 'yolcu') = 0
   and (select (value ->> 'amount')::int from beta_settings where key = 'signup_credits') = 1
union all
select 'paketler 1-3-5, abonelikten pahali',
       (select array_agg(kredi order by sira) from kredi_paketleri where aktif) = array[1,3,5]
   and (select min(fiyat_try::numeric / kredi) from kredi_paketleri where aktif)
     > (select max(price_try::numeric / monthly_credits) from plan_catalog where aktif and monthly_credits > 0)
union all
select 'haftalik baglanti siniri',
       position('baglanti_haftalik_sinir' in pg_get_functiondef('public.send_connection(uuid, text, text)'::regprocedure)) > 0
union all
select 'suzgec maskeler, masumu birakir',
       public.uygunsuz_maskele('Selam orospu çocuğu, Sık Uçan planı güzel') = 'Selam ••• çocuğu, Sık Uçan planı güzel'
   and public.uygunsuz_maskele('I got the pic, sik ucan') = 'I got the pic, sik ucan';
-- Beklenen: beş satır tamam = true.
