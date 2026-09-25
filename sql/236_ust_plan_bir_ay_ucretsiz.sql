-- ============================================================================
-- LoungeLink · 236_ust_plan_bir_ay_ucretsiz.sql             (22 Ağustos 2026)
--
-- "ÜST PLAN ÜCRETSİZ AÇILIR" → "1 AY ÜCRETSİZ" (Gökberk, madde 7)
--
-- Gökberk: "üst plan ücretsiz açılır yerine 1 aylığına ücretsiz olacağını
-- belirtsek daha iyi olur. Bununla ilgili BE ve BO yapılarını da kur.
-- O hakkı elde edince bir üst plan 1 aylığına ücretsiz olsun. 1 ayın
-- sonunda tekrar eski plana dönmeli."
--
-- ════════════════════════════════════════════════════════════════════════
-- ÖNCE: BUGÜN NE OLUYOR — VE NEDEN SÖZ ZATEN TUTULMUYORDU
-- ════════════════════════════════════════════════════════════════════════
-- `my_plan()` (210:136) hediyeyi HER ÇAĞRIDA YENİDEN HESAPLIYOR:
--     v_bu_ay := bu TAKVİM AYINDA tamamlanan oturum sayısı
--     if v_bu_ay >= 2 then etkin := üst plan
--
-- Üç sonucu var, üçü de kullanıcı aleyhine:
--
--   (a) SÜRE 1 AY DEĞİL, "AYIN KALANI". 28 Ağustos'ta hak eden kişi
--       3 gün sonra planını kaybediyor. Söz "1 ay" ise bu sözün
--       tutulmadığı en bariz hâli.
--   (b) HAK GERİYE DÖNÜK KAYBOLUYOR. Ayın 1'i geldiğinde sayaç sıfırlanıp
--       hediye SESSİZCE bitiyor. Ne bildirim var, ne kayıt — kullanıcı
--       neyi kaybettiğini bilmiyor.
--   (c) 🔴 HEDİYE ZATEN EKSİK VERİLİYORDU. `plan_kredisi_yerlestir`
--       (225:245) aylık krediyi `users.plan`'dan okuyor — yani SATIN
--       ALINAN plandan. Hediye alan kişi üst planın kredilerini HİÇ
--       almıyordu. Ekranda "üst plan ayrıcalıkları bu ay senin" yazarken
--       ayrıcalığın en somut olanı verilmiyordu.
--
-- 🆕 SINIF: **"HESAPLANAN BİR HAK, VERİLEN BİR HAK DEĞİLDİR."**
-- Hesap her çağrıda yeniden yapılır ve girdisi değişince hak sessizce
-- yok olur. Verilen hakkın başlangıcı, bitişi ve kaydı vardır.
--
-- ════════════════════════════════════════════════════════════════════════
-- YENİ YAPI
-- ════════════════════════════════════════════════════════════════════════
--   plan_grants          → hediyenin KAYDI (kime, hangi plan, ne zaman biter)
--   plan_hediyesi_degerlendir()  → hak edilince BİR KEZ verir (tetikleyici)
--   plan_hediyelerini_bitir()    → süresi dolanı kapatır + haber verir (cron)
--   my_plan()            → hesaplamaz, KAYDA bakar
--   plan_kredisi_yerlestir() → ETKİN plandan kredi verir (c maddesi)
--   BO: bo_plan_hediyeleri / bo_plan_hediyesi_ver / bo_plan_hediyesi_iptal
--
-- DÜŞÜNÜLEN VE KAPATILAN KENAR DURUMLAR (Gökberk bunları sormadı):
--   · Hediye sürerken üst planı SATIN ALIRSA → etkin plan yine en yüksek
--     olan; hediye bitince ALT plana DÜŞMEZ (satın aldığı kalır)
--   · Hediye sürerken tekrar hak ederse → ikinci hediye VERİLMEZ,
--     üst üste binmez (kısmi benzersiz indeks garanti ediyor)
--   · Hediye bitince tekrar hak ederse → yeniden verilir (bekleme süresi
--     ayarlanabilir, varsayılan 0)
--   · Hediye edilen plan katalogdan kalkarsa → etkin plan satın alınana
--     düşer, hata vermez
--   · Hediye edilen plan mevcut plandan DÜŞÜKSE → hiç verilmez
--   · Bitmeden 3 gün önce hatırlatma → sürpriz düşüş olmasın
--   · Kullanıcı silinirse → cascade
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) AYARLAR
-- ----------------------------------------------------------------------------
insert into beta_settings (key, value) values
  ('host_free_upgrade_days',         to_jsonb(30)),   -- "1 ay"ın tanımı
  ('host_free_upgrade_cooldown_days',to_jsonb(0)),    -- bitince tekrar hak edebilir
  ('host_free_upgrade_warn_days',    to_jsonb(3))     -- bitmeden kaç gün önce hatırlat
on conflict (key) do nothing;

-- ----------------------------------------------------------------------------
-- 1) KAYIT
-- ----------------------------------------------------------------------------
create table if not exists plan_grants (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references users(id) on delete cascade,
  plan        plan_type not null,
  kaynak      text not null default 'agirlama',   -- agirlama | admin | kampanya
  not_metni   text,
  basladi_at  timestamptz not null default now(),
  biter_at    timestamptz not null,
  bitti_at    timestamptz,                        -- süresi dolunca yazılır
  iptal_at    timestamptz,                        -- admin geri aldıysa
  iptal_notu  text,
  uyarildi_at timestamptz,                        -- "3 gün kaldı" gönderildi mi
  created_at  timestamptz not null default now(),
  check (biter_at > basladi_at)
);

alter table plan_grants enable row level security;
drop policy if exists "pg_own" on plan_grants;
create policy "pg_own" on plan_grants for select to authenticated
  using (user_id = auth.uid());

-- 🔴 AYNI ANDA TEK AKTİF HEDİYE. Kısmi benzersiz indeks; iki hediye
-- üst üste binerse hangisinin geçerli olduğu belirsizleşir ve bitiş
-- tarihi tartışmaya açılır. Belirsizlik, kullanıcı aleyhine çözülür.
drop index if exists uq_plan_grants_aktif;
create unique index uq_plan_grants_aktif on plan_grants (user_id)
  where bitti_at is null and iptal_at is null;

create index if not exists ix_plan_grants_biter on plan_grants (biter_at)
  where bitti_at is null and iptal_at is null;

comment on table plan_grants is
  'Ucretsiz ust plan hediyesinin KAYDI. 210 bunu her cagrida yeniden HESAPLIYORDU; '
  'hesaplanan hak, girdi degisince sessizce yok olur. Artik baslangici, bitisi ve '
  'kaydi var.';

-- ----------------------------------------------------------------------------
-- 2) ETKİN PLAN — tek kaynak
-- ----------------------------------------------------------------------------
-- Hem `my_plan` hem `plan_kredisi_yerlestir` buradan okur. İki yerde iki
-- kez hesaplarsam biri düzelince diğeri yalan söylemeye başlar (233'ün
-- dersi).
create or replace function public.etkin_plan(p_user uuid default null)
returns plan_type language plpgsql stable security definer set search_path = public as $ep$
declare
  v_uid   uuid := coalesce(p_user, auth.uid());
  v_satin text;
  v_hed   text;
begin
  if v_uid is null then return null; end if;

  select coalesce(u.plan::text,'yolcu') into v_satin from users u where u.id = v_uid;
  if not exists (select 1 from plan_catalog where plan::text = v_satin and aktif) then
    v_satin := 'yolcu';
  end if;

  select g.plan::text into v_hed
    from plan_grants g
    join plan_catalog c on c.plan = g.plan and c.aktif
   where g.user_id = v_uid
     and g.bitti_at is null and g.iptal_at is null
     and g.biter_at > now()
   limit 1;

  if v_hed is null then return v_satin::plan_type; end if;

  -- 🔴 EN YÜKSEK OLAN KAZANIR. Hediye sürerken üst planı satın alan
  -- kişiyi hediye ALTINA düşürmek, ödediği için cezalandırmak olurdu.
  if (select sort_order from plan_catalog where plan::text = v_hed)
     > (select sort_order from plan_catalog where plan::text = v_satin)
  then return v_hed::plan_type;
  else return v_satin::plan_type;
  end if;
end $ep$;
grant execute on function public.etkin_plan(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 3) HAK EDİŞ — bir kez, tetikleyiciyle
-- ----------------------------------------------------------------------------
create or replace function public.plan_hediyesi_degerlendir(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $phd$
declare
  v_esik    int  := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_sessions'), 2);
  v_plan    text := coalesce((select value #>> '{}' from beta_settings where key='host_free_upgrade_plan'), 'sik_ucan');
  v_gun     int  := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_days'), 30);
  v_bekle   int  := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_cooldown_days'), 0);
  v_agir    int;
  v_satin   text;
  v_son     timestamptz;
  v_biter   timestamptz;
  v_ad      text;
begin
  if p_user is null then return jsonb_build_object('ok', false, 'neden','kullanici_yok'); end if;

  -- Zaten aktif hediyesi varsa üstüne bir şey koyma.
  if exists (select 1 from plan_grants
              where user_id = p_user and bitti_at is null and iptal_at is null
                and biter_at > now()) then
    return jsonb_build_object('ok', true, 'durum', 'zaten_aktif');
  end if;

  -- Bekleme süresi (varsayılan 0 = hemen yeniden hak edebilir).
  if v_bekle > 0 then
    select max(coalesce(bitti_at, biter_at)) into v_son
      from plan_grants where user_id = p_user and kaynak = 'agirlama';
    if v_son is not null and v_son > now() - make_interval(days => v_bekle) then
      return jsonb_build_object('ok', true, 'durum', 'bekleme_suresi');
    end if;
  end if;

  -- 🔴 SAYAÇ ARTIK "BU TAKVİM AYI" DEĞİL: hediye penceresinden BU YANA
  -- tamamlanan oturumlar. Takvim ayı kullanmak, ayın 28'inde hak eden
  -- kişiye 3 gün vermek demekti.
  select coalesce(max(coalesce(bitti_at, biter_at)), '-infinity'::timestamptz)
    into v_son
    from plan_grants where user_id = p_user and kaynak = 'agirlama';

  select count(*) into v_agir
    from sessions s join requests r on r.id = s.request_id
   where r.host_id = p_user and s.status = 'completed'
     and s.completed_at > v_son;

  if v_agir < v_esik then
    return jsonb_build_object('ok', true, 'durum', 'yetersiz',
                              'agirlama', v_agir, 'esik', v_esik);
  end if;

  -- Hediye edilen plan gerçekten ÜST plan mı?
  select coalesce(u.plan::text,'yolcu') into v_satin from users u where u.id = p_user;
  if not exists (select 1 from plan_catalog where plan::text = v_plan and aktif) then
    return jsonb_build_object('ok', false, 'neden', 'hediye_plani_pasif');
  end if;
  if (select sort_order from plan_catalog where plan::text = v_plan)
     <= coalesce((select sort_order from plan_catalog where plan::text = v_satin), -1) then
    return jsonb_build_object('ok', true, 'durum', 'zaten_ust_planda');
  end if;

  v_biter := now() + make_interval(days => v_gun);
  select ad into v_ad from plan_catalog where plan::text = v_plan;

  insert into plan_grants (user_id, plan, kaynak, basladi_at, biter_at, not_metni)
  values (p_user, v_plan::plan_type, 'agirlama', now(), v_biter,
          format('%s ağırlama tamamlandı', v_agir));

  insert into notifications (user_id, category, title, body, ref_type)
  values (p_user, 'system',
          coalesce(v_ad,'Üst plan') || ' 1 ay boyunca senin 🎁',
          format('%s kişi ağırladın. %s planı %s gün boyunca ücretsiz açıldı — '
              || '%s tarihine kadar. Süre bitince eski planına dönersin, '
              || 'hiçbir ücret çıkmaz.',
              v_agir, coalesce(v_ad,'üst plan'), v_gun,
              to_char(timezone('Europe/Istanbul', v_biter), 'DD.MM.YYYY')),
          'plan');

  -- Üst planın aylık kredisi HEMEN yazılsın: hediyenin en somut kısmı bu
  -- ve 225 bugüne kadar satın alınan plandan okuduğu için hiç verilmiyordu.
  begin
    perform public.plan_kredisi_yerlestir(p_user);
  exception when others then null;   -- kredi yükleme hediyeyi engellemez
  end;

  return jsonb_build_object('ok', true, 'durum', 'verildi',
                            'plan', v_plan, 'biter', v_biter, 'gun', v_gun);
end $phd$;
grant execute on function public.plan_hediyesi_degerlendir(uuid) to service_role;

-- Oturum tamamlanınca değerlendir. 206'nın kalıbı: hediye ASLA oturumun
-- tamamlanmasını engellemez.
create or replace function public.trg_plan_hediyesi()
returns trigger language plpgsql security definer set search_path = public as $tph$
declare v_host uuid;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    begin
      select r.host_id into v_host from requests r where r.id = new.request_id;
      if v_host is not null then perform public.plan_hediyesi_degerlendir(v_host); end if;
    exception when others then
      insert into client_errors (source, message, context)
      values ('plan_hediyesi_degerlendir', sqlerrm,
              jsonb_build_object('session_id', new.id));
    end;
  end if;
  return new;
end $tph$;
drop trigger if exists trg_plan_hediyesi_on_complete on sessions;
create trigger trg_plan_hediyesi_on_complete after update on sessions
  for each row execute function public.trg_plan_hediyesi();

-- ----------------------------------------------------------------------------
-- 4) BİTİŞ — süresi dolanı kapat, HABER VER
-- ----------------------------------------------------------------------------
-- 🔴 Sessiz bitiş, hediyenin en kötü hâlidir: kullanıcı bir sabah
-- ayrıcalığını kaybetmiş olarak uyanır ve sebebini bilmez.
create or replace function public.plan_hediyelerini_bitir()
returns jsonb language plpgsql security definer set search_path = public as $phb$
declare
  r        record;
  v_bitti  int := 0;
  v_uyari  int := 0;
  v_warn   int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_warn_days'), 3);
begin
  -- (a) Süresi dolanlar
  for r in
    select g.*, c.ad
      from plan_grants g left join plan_catalog c on c.plan = g.plan
     where g.bitti_at is null and g.iptal_at is null and g.biter_at <= now()
  loop
    update plan_grants set bitti_at = now() where id = r.id;
    insert into notifications (user_id, category, title, body, ref_type)
    values (r.user_id, 'system',
            'Ücretsiz ayın doldu',
            coalesce(r.ad,'Üst plan') || ' hediyeni kullandın — planın eski hâline döndü. '
         || 'Yeniden açmak için birini daha ağırlaman yeterli; ücret çıkmadı, çıkmayacak.',
            'plan');
    v_bitti := v_bitti + 1;
  end loop;

  -- (b) Bitmeye yaklaşanlar — bir kez uyar
  for r in
    select g.*, c.ad
      from plan_grants g left join plan_catalog c on c.plan = g.plan
     where g.bitti_at is null and g.iptal_at is null
       and g.uyarildi_at is null
       and g.biter_at <= now() + make_interval(days => v_warn)
       and g.biter_at > now()
  loop
    update plan_grants set uyarildi_at = now() where id = r.id;
    insert into notifications (user_id, category, title, body, ref_type)
    values (r.user_id, 'system',
            coalesce(r.ad,'Üst plan') || ' hediyenin bitişine az kaldı',
            format('%s tarihinde eski planına döneceksin. Bir kişi daha ağırlarsan '
                || 'süre dolduğunda yeniden açılır.',
                to_char(timezone('Europe/Istanbul', r.biter_at), 'DD.MM.YYYY')),
            'plan');
    v_uyari := v_uyari + 1;
  end loop;

  return jsonb_build_object('ok', true, 'bitirilen', v_bitti, 'uyarilan', v_uyari);
end $phb$;
grant execute on function public.plan_hediyelerini_bitir() to service_role;

-- ----------------------------------------------------------------------------
-- 5) my_plan — HESAPLAMIYOR, KAYDA BAKIYOR
-- ----------------------------------------------------------------------------
-- sqlcheck: allow-replace my_plan  (returns jsonb — 210 ile AYNI tip)
-- 210'un döndürdüğü TÜM alanlar korunuyor; üçü ekleniyor
-- (hediye_biter, hediye_gun_kaldi, hediye_kaynak) — app eski alanları
-- okumaya devam edebilsin.
create or replace function public.my_plan(p_user uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $mp$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  -- 🔴 22 AGUSTOS: `text` idi, `etkin_plan()` `plan_type` donuyor.
  -- plpgsql atamada ortuk cevirdigi icin PATLAMIYORDU ama nobetci
  -- hakli: cagirici, cagirdigi seyin sozlesmesini yazmalidir —
  -- yoksa donus tipi degistigi gun sessizce yanlis calisir.
  v_satin text; v_etkin plan_type; v_p plan_catalog%rowtype;
  v_esik int; v_plan_hediye text; v_gun int;
  v_agir int; v_neden text;
  v_g plan_grants%rowtype;
  v_son timestamptz;
  v_kaldi int;
begin
  if v_uid is null then return jsonb_build_object('known', false); end if;

  select coalesce(u.plan::text,'yolcu') into v_satin from users u where u.id = v_uid;
  if not exists (select 1 from plan_catalog where plan::text = v_satin and aktif) then
    v_satin := 'yolcu';
  end if;

  v_esik := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_sessions'), 2);
  v_plan_hediye := coalesce((select value #>> '{}' from beta_settings where key='host_free_upgrade_plan'), 'sik_ucan');
  v_gun := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_days'), 30);

  v_etkin := public.etkin_plan(v_uid)::text;

  select * into v_g from plan_grants
   where user_id = v_uid and bitti_at is null and iptal_at is null and biter_at > now()
   limit 1;

  -- İlerleme sayacı: son hediyeden BU YANA (takvim ayı değil).
  select coalesce(max(coalesce(bitti_at, biter_at)), '-infinity'::timestamptz)
    into v_son from plan_grants where user_id = v_uid and kaynak='agirlama';
  select count(*) into v_agir
    from sessions s join requests r on r.id = s.request_id
   where r.host_id = v_uid and s.status='completed' and s.completed_at > v_son;

  if v_g.id is not null then
    v_kaldi := greatest(0, ceil(extract(epoch from (v_g.biter_at - now()))/86400)::int);
    v_neden := format('%s ayrıcalıkları %s gün daha senin — ücretsiz. %s tarihinde eski planına dönersin.',
                      (select ad from plan_catalog where plan::text = v_etkin),
                      v_kaldi,
                      to_char(timezone('Europe/Istanbul', v_g.biter_at), 'DD.MM.YYYY'));
  else
    v_kaldi := null;
    v_neden := case
      when v_agir > 0 then format('%s kişi ağırladın. %s ağırlamada üst plan 1 ay ücretsiz açılıyor.', v_agir, v_esik)
      else format('Birini ağırla — %s ağırlamada üst plan %s gün boyunca ücretsiz açılır.', v_esik, v_gun) end;
  end if;

  select * into v_p from plan_catalog where plan::text = v_etkin;

  return jsonb_build_object(
    'known', true,
    'satin_alinan', v_satin,
    'etkin', v_etkin,
    'ad', v_p.ad,
    'aylik_kredi', v_p.monthly_credits,
    'fiyat_try', v_p.price_try,
    'yillik_try', v_p.yillik_try,
    'haklar', v_p.perks,
    'kacirilan_sikligi', v_p.kacirilan_sikligi,
    'one_cikarma_ayda', v_p.one_cikarma_ayda,
    'yanma_uyarilari', to_jsonb(v_p.yanma_uyarilari),
    'ucus_dogrulama_ayda', v_p.ucus_dogrulama_ayda,
    'kart_siniri', v_p.kart_siniri,
    'oncelikli_destek', v_p.oncelikli_destek,
    'bu_ay_agirlama', v_agir,
    'esik', v_esik,
    'hediye_gun', v_gun,
    'ucretsiz_yukseltme', (v_g.id is not null and v_etkin <> v_satin),
    'hediye_biter', v_g.biter_at,
    'hediye_gun_kaldi', v_kaldi,
    'hediye_kaynak', v_g.kaynak,
    'neden', v_neden);
end $mp$;
grant execute on function public.my_plan(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 6) AYLIK KREDİ ARTIK ETKİN PLANDAN
-- ----------------------------------------------------------------------------
-- sqlcheck: allow-replace plan_kredisi_yerlestir  (returns jsonb — 225 ile AYNI)
-- 🔴 (c) MADDESİNİN DÜZELTMESİ. 225 `users.plan`'dan okuyordu; hediye
-- alan kişi üst planın kredisini HİÇ almıyordu. Hediyenin en somut
-- kısmı buydu ve verilmiyordu.
create or replace function public.plan_kredisi_yerlestir(p_user uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $pky$
declare
  v_uid uuid := coalesce(p_user, auth.uid());
  v_ay text; v_n int; v_reason text; v_bal int; v_plan plan_type;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'neden', 'oturum_yok'); end if;

  v_plan := public.etkin_plan(v_uid)::text;
  v_ay := to_char(timezone('Europe/Istanbul', now()), 'YYYY-MM');
  -- 🔴 Sebep artık PLANI da taşıyor: hediye ay ortasında açılırsa kişi o
  -- ayın üst-plan kredisini de alabilsin. Aksi hâlde "zaten_verildi"ye
  -- takılıp hediyenin kredisi hiç yazılmazdı.
  v_reason := 'plan_monthly:' || v_ay || ':' || v_plan;

  if exists (select 1 from credit_ledger where user_id = v_uid and reason = v_reason) then
    return jsonb_build_object('ok', true, 'durum', 'zaten_verildi', 'ay', v_ay, 'plan', v_plan);
  end if;

  select coalesce(p.monthly_credits, 0) into v_n
    from plan_catalog p where p.plan::text = v_plan and p.aktif;
  v_n := coalesce(v_n, 0);
  if v_n <= 0 then
    return jsonb_build_object('ok', true, 'durum', 'plan_kredisi_yok', 'ay', v_ay);
  end if;

  -- Aynı ay içinde alt plandan kredi aldıysa FARKI ver, tamamını değil.
  declare v_onceki int := 0;
  begin
    select coalesce(max(delta),0) into v_onceki from credit_ledger
     where user_id = v_uid and reason like 'plan_monthly:' || v_ay || '%';
    if v_onceki >= v_n then
      return jsonb_build_object('ok', true, 'durum', 'zaten_yeterli', 'ay', v_ay);
    end if;
    v_n := v_n - v_onceki;
  end;

  select coalesce(sum(delta),0) into v_bal from credit_ledger where user_id = v_uid;
  insert into credit_ledger (user_id, delta, reason, balance_after)
  values (v_uid, v_n, v_reason, v_bal + v_n);

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_uid, 'system', 'Aylık kredin yüklendi ✓',
          v_n || ' kredi hesabına eklendi. Planın her ay bu krediyi veriyor.',
          'credits');

  return jsonb_build_object('ok', true, 'durum', 'verildi', 'adet', v_n,
                            'ay', v_ay, 'plan', v_plan);
exception when others then
  return jsonb_build_object('ok', false, 'neden', sqlerrm);
end $pky$;
grant execute on function public.plan_kredisi_yerlestir(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 7) BACKOFFICE
-- ----------------------------------------------------------------------------
drop function if exists public.bo_plan_hediyeleri(text);
create or replace function public.bo_plan_hediyeleri(p_durum text default 'aktif')
returns table (
  id uuid, user_id uuid, eposta text, ad text,
  plan text, plan_adi text, kaynak text, not_metni text,
  basladi_at timestamptz, biter_at timestamptz,
  bitti_at timestamptz, iptal_at timestamptz, iptal_notu text,
  gun_kaldi int, satin_alinan text
)
language plpgsql stable security definer set search_path = public as $bph$
begin
  -- 🔴 248'DE DÜZELTİLDİ (42702). Burada `where user_id = auth.uid()`
  -- yazıyordu. Bu fonksiyon `returns table (... user_id uuid ...)` ilan
  -- ediyor ve plpgsql'de OUT parametreleri gövdede birer DEĞİŞKENDİR.
  -- Niteliksiz `user_id`, hem `admin_roles.user_id` kolonuna hem o
  -- değişkene işaret ediyordu: "column reference user_id is ambiguous".
  -- Bir PLANLAMA hatası olduğu için deyim her çalıştığında patlıyordu —
  -- yani auth.uid() dolu olan HER admin bu ekranı hiç açamadı.
  -- 🆕 SINIF: "returns table İLE İLAN EDİLEN HER KOLON ADI, GÖVDEDE BİR
  -- DEĞİŞKEN ADIDIR."
  if auth.uid() is not null
     and not exists (select 1 from admin_roles ar where ar.user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  return query
  select g.id, g.user_id, u.email, p.name,
         g.plan::text, c.ad, g.kaynak, g.not_metni,
         g.basladi_at, g.biter_at, g.bitti_at, g.iptal_at, g.iptal_notu,
         greatest(0, ceil(extract(epoch from (g.biter_at - now()))/86400)::int),
         u.plan::text
    from plan_grants g
    left join users u on u.id = g.user_id
    left join profiles p on p.user_id = g.user_id
    left join plan_catalog c on c.plan = g.plan
   where case coalesce(p_durum,'aktif')
           when 'aktif' then (g.bitti_at is null and g.iptal_at is null and g.biter_at > now())
           when 'gecmis' then (g.bitti_at is not null or g.iptal_at is not null or g.biter_at <= now())
           else true end
   order by g.biter_at desc
   limit 200;
end $bph$;
grant execute on function public.bo_plan_hediyeleri(text) to service_role;

drop function if exists public.bo_plan_hediyesi_ver(uuid, text, int, text);
create or replace function public.bo_plan_hediyesi_ver(
  p_user uuid, p_plan text, p_gun int default null, p_not text default null)
returns jsonb language plpgsql security definer set search_path = public as $bhv$
declare v_gun int; v_biter timestamptz; v_ad text;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  if p_user is null then raise exception 'kullanici_yok'; end if;
  if not exists (select 1 from plan_catalog where plan::text = p_plan and aktif) then
    raise exception 'plan_pasif_veya_yok';
  end if;
  if exists (select 1 from plan_grants
              where user_id = p_user and bitti_at is null and iptal_at is null
                and biter_at > now()) then
    raise exception 'zaten_aktif_hediye_var';
  end if;

  v_gun := coalesce(p_gun,
    (select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_days'), 30);
  if v_gun < 1 or v_gun > 365 then raise exception 'gecersiz_gun'; end if;
  v_biter := now() + make_interval(days => v_gun);
  select ad into v_ad from plan_catalog where plan::text = p_plan;

  insert into plan_grants (user_id, plan, kaynak, not_metni, biter_at)
  values (p_user, p_plan::plan_type, 'admin', left(coalesce(p_not,''),300), v_biter);

  insert into notifications (user_id, category, title, body, ref_type)
  values (p_user, 'system', coalesce(v_ad,'Üst plan') || ' senin oldu 🎁',
          format('%s planı %s gün boyunca ücretsiz açıldı — %s tarihine kadar.',
                 coalesce(v_ad,'Üst plan'), v_gun,
                 to_char(timezone('Europe/Istanbul', v_biter),'DD.MM.YYYY')),
          'plan');

  insert into audit_log (actor_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), 'plan.grant', 'users', p_user,
          jsonb_build_object('plan', p_plan, 'gun', v_gun, 'biter', v_biter));

  perform public.plan_kredisi_yerlestir(p_user);
  return jsonb_build_object('ok', true, 'biter', v_biter);
end $bhv$;
grant execute on function public.bo_plan_hediyesi_ver(uuid, text, int, text) to service_role;

drop function if exists public.bo_plan_hediyesi_iptal(uuid, text);
create or replace function public.bo_plan_hediyesi_iptal(p_id uuid, p_neden text)
returns jsonb language plpgsql security definer set search_path = public as $bhi$
declare v_g plan_grants%rowtype;
begin
  if auth.uid() is not null
     and not exists (select 1 from admin_roles where user_id = auth.uid()) then
    raise exception 'not_admin';
  end if;
  select * into v_g from plan_grants where id = p_id for update;
  if not found then raise exception 'hediye_yok'; end if;
  if v_g.bitti_at is not null or v_g.iptal_at is not null then
    raise exception 'zaten_kapali';
  end if;

  update plan_grants
     set iptal_at = now(), iptal_notu = left(coalesce(p_neden,''),300)
   where id = p_id;

  insert into notifications (user_id, category, title, body, ref_type)
  values (v_g.user_id, 'system', 'Plan hediyen kapatıldı',
          'Ücretsiz üst plan hediyen sona erdi. Planın eski hâline döndü; '
       || 'hiçbir ücret çıkmadı.', 'plan');

  insert into audit_log (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (auth.uid(), 'plan.grant_cancel', 'users', v_g.user_id,
          to_jsonb(v_g), jsonb_build_object('neden', p_neden));

  return jsonb_build_object('ok', true);
end $bhi$;
grant execute on function public.bo_plan_hediyesi_iptal(uuid, text) to service_role;

-- ----------------------------------------------------------------------------
-- 8) ZAMANLANMIŞ İŞ
-- ----------------------------------------------------------------------------
do $cron$
declare v_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice '236: pg_cron KURULU DEGIL — hediye bitisi zamanlanamadi.';
    raise notice '236: ⚠️ CRON YOKSA HEDIYE KENDILIGINDEN BITMEZ. `etkin_plan()` '
                 'biter_at kontrolu yaptigi icin kullanici ayricaligini KAYBEDER '
                 '(dogru davranis) ama BILDIRIM GITMEZ ve kayit `bitti_at` almaz. '
                 'Supabase''te pg_cron acildiginda 226 ve 236 tekrar calistirilmali.';
    return;
  end if;
  begin
    perform cron.unschedule('loungelink_plan_hediyesi');
  exception when others then null;
  end;
  select cron.schedule(
           'loungelink_plan_hediyesi',
           '0 5 * * *',                       -- her gün 05:00 UTC (TR 08:00)
           $$select public.plan_hediyelerini_bitir();$$)
    into v_id;
  raise notice '236: gunluk plan-hediyesi bitis isi kuruldu (job #%)', v_id;
end $cron$;

-- ----------------------------------------------------------------------------
-- 9) NÖBETÇİ — hediyeyi GERÇEKTEN verip GERÇEKTEN bitiriyor mu?
-- ----------------------------------------------------------------------------
do $n236$
declare
  v_uid uuid; v_id uuid; v_etkin text; v_satin text;
  v_esik int := coalesce((select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_sessions'), 2);
  v_plan text := coalesce((select value #>> '{}' from beta_settings where key='host_free_upgrade_plan'), 'sik_ucan');
  v_r jsonb;
  -- ⚠️ DIŞ blokta bildiriliyor: ilk yazımda iç `declare`de tanımlamıştım
  -- ve blok bitince kapsam da bitiyordu ("column v_hata does not exist").
  v_hata boolean := false;
begin
  if not exists (select 1 from plan_catalog where plan::text = v_plan and aktif) then
    raise exception '236 NOBETCI: hediye plani (%) katalogda aktif degil.', v_plan;
  end if;

  select id into v_uid from users where deleted_at is null order by created_at limit 1;
  if v_uid is null then
    raise notice '236 OLCULMEDI: hic kullanici yok — hediye dongusu sinanmadi.';
  else
    select coalesce(plan::text,'yolcu') into v_satin from users where id = v_uid;

    -- (a) Elle hediye ver → etkin plan yükseldi mi?
    insert into plan_grants (user_id, plan, kaynak, not_metni, biter_at)
    values (v_uid, v_plan::plan_type, 'admin', '236 nobetci', now() + interval '30 days')
    returning id into v_id;

    v_etkin := public.etkin_plan(v_uid)::text;
    if v_etkin <> v_plan
       and (select sort_order from plan_catalog where plan::text = v_plan)
         > coalesce((select sort_order from plan_catalog where plan::text = v_satin), -1) then
      delete from plan_grants where id = v_id;
      raise exception '236 NOBETCI: hediye verildi ama etkin plan degismedi (% kaldi).', v_etkin;
    end if;

    -- (b) Süreyi geçmişe çek → bitir → eski plana döndü mü?
    -- ⚠️ `basladi_at`i de geriye çekmek ZORUNDAYIM: `check (biter_at >
    -- basladi_at)` yalnız bitişi geriye çekince patlıyor. Nöbetçi ilk
    -- yazımda tam bunu yaptı ve kısıt onu yakaladı — kısıt çalışıyor.
    update plan_grants
       set basladi_at = now() - interval '31 days',
           biter_at   = now() - interval '1 minute'
     where id = v_id;
    v_r := public.plan_hediyelerini_bitir();
    if (v_r ->> 'bitirilen')::int < 1 then
      delete from plan_grants where id = v_id;
      raise exception '236 NOBETCI: suresi dolan hediye BITIRILMEDI (%).', v_r::text;
    end if;
    if public.etkin_plan(v_uid)::text <> v_satin then
      delete from plan_grants where id = v_id;
      raise exception '236 NOBETCI: hediye bitti ama etkin plan eski haline DONMEDI.';
    end if;

    -- (c) Üst üste binme: aynı anda iki aktif hediye kurulamamalı
    begin
      insert into plan_grants (user_id, plan, kaynak, biter_at)
      values (v_uid, v_plan::plan_type, 'admin', now() + interval '10 days');
      insert into plan_grants (user_id, plan, kaynak, biter_at)
      values (v_uid, v_plan::plan_type, 'admin', now() + interval '10 days');
      v_hata := true;   -- buraya düşmek indeksin çalışmadığı anlamına gelir
    exception when unique_violation then null;
    end;
    delete from plan_grants where user_id = v_uid and not_metni is distinct from null or id = v_id;
    delete from plan_grants where user_id = v_uid and kaynak = 'admin';
    delete from notifications where user_id = v_uid and ref_type = 'plan';
    if v_hata then
      raise exception '236 NOBETCI: ayni anda IKI aktif hediye kurulabildi — indeks calismiyor.';
    end if;

    raise notice '236 OK · hediye verildi → etkin plan yukseldi → bitirildi → eski plana dondu · ust uste binme engellendi';
  end if;

  raise notice '236 OLCULMEDI: gercek odeme entegrasyonu YOK. Hediye biterken kullaniciya '
               'otomatik satin alma teklif edilmiyor; Play Billing baglanana kadar bu '
               'bilincli bir bosluk.';
end $n236$;

-- ----------------------------------------------------------------------------
-- 10) RPC YÜZEYİ
-- ----------------------------------------------------------------------------
insert into rpc_client_surface (fn_name, client, note) values
  ('etkin_plan','app','Satin alinan ve hediye planin YUKSEK olani — tek kaynak (236)')
on conflict (fn_name) do update set note = excluded.note;

do $$
declare v jsonb;
begin
  v := public.apply_rpc_surface();
  raise notice '236: sinir uygulandi — % kapatildi', v ->> 'kilitlenen';
end $$;

select '236 UST PLAN 1 AY UCRETSIZ KURULDU' as sonuc,
       (select count(*) from plan_grants where bitti_at is null and iptal_at is null and biter_at > now()) as aktif_hediye,
       (select (value #>> '{}')::int from beta_settings where key='host_free_upgrade_days') as hediye_gun;
