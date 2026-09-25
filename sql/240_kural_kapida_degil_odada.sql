-- ============================================================================
-- LoungeLink · 240_kural_kapida_degil_odada.sql          (22 Ağustos 2026)
--
-- KURALI KAPIYA KOYMAK, ODAYA BAŞKA KAPILAR VARKEN KURAL KOYMAK DEĞİLDİR
--
-- ════════════════════════════════════════════════════════════════════════
-- BU DOSYA BİR TALEBİN CEVABI DEĞİL. KENDİM ARAYIP BULDUM VE ÖLÇTÜM.
-- ════════════════════════════════════════════════════════════════════════
-- 237'de `update_availability()` ve `update_visit()` yazdım. İkisinin de
-- içine sözleşme kilidi koydum: kabul edilmiş misafiri olan bir ilanın
-- tarihi/saati/salonu değişemez; aktif başvurusu olan bir seyahatin
-- havalimanı/tarihi değişemez.
--
-- 🔴 AMA `authenticated` rolünün bu tablolar üzerinde TABLO DÜZEYİNDE
-- UPDATE/DELETE hakkı duruyordu. Yani kilidi koyduğum kapının yanında,
-- hiç kilitlenmemiş ikinci bir kapı vardı: PostgREST'in kendisi.
--
-- ÖLÇTÜM. Aynı host, aynı ilan, aynı değişiklik, iki ayrı yol:
--
--   1) update_availability(id, p_date := '2026-09-30')
--      → ERROR: kabul_edilmis_basvuru_var          ✅ kilit tuttu
--
--   2) update availabilities set avail_date='2026-09-30', slots=4,
--            filled=0, rule_severity='ok',
--            rule_headline='Kesinlikle girersin' where id=...
--      → UPDATE 1                                   ❌ HİÇBİR ŞEY DURDURMADI
--
--      avail_date | slots | filled | rule_severity |    rule_headline
--      -----------+-------+--------+---------------+---------------------
--      2026-09-30 |     4 |      0 | ok            | Kesinlikle girersin
--
-- Ve `delete from visits where id=...` → silinen satır: 1.
--
-- ════════════════════════════════════════════════════════════════════════
-- BUNUN ÜÇ AYRI BEDELİ VAR
-- ════════════════════════════════════════════════════════════════════════
-- 1. KABUL EDİLMİŞ MİSAFİR YANLIŞ GÜNE GİDER. Host tarihi kaydırır,
--    misafirin elinde eski tarih kalır. Sözleşme kilidi tam bunu
--    engellemek için vardı.
-- 2. KURAL MOTORUNUN AĞZINDAN KONUŞULABİLİR. `rule_severity` ve
--    `rule_headline` motorun ÇIKTISI — ilan sahibinin girdisi değil.
--    İstemci bunları yazabildiği sürece host, motorun vermediği bir
--    "kesin girersin" sözünü motorun ağzından verebilir. Bu üründeki en
--    pahalı yalan budur: farkımız motor, motorun sözü taklit edilebiliyorsa
--    fark yok demektir.
-- 3. DOLU İLAN BOŞ GÖSTERİLEBİLİR. `filled=0` yazmak yeter.
--
-- ════════════════════════════════════════════════════════════════════════
-- DERS
-- ════════════════════════════════════════════════════════════════════════
-- 🆕 SINIF: **"BİR KURAL, YALNIZCA ÇAĞRILDIĞI FONKSİYONUN İÇİNDEYSE KURAL
-- DEĞİL, RİCADIR. KURAL VERİNİN DEĞİŞTİĞİ YERDE DURUR."**
--
-- Bu yüzden aşağıdaki düzeltme iki katmanlı:
--   (a) İstemcinin doğrudan yazma hakkı KALKAR   → kapı kapanır
--   (b) Kural TETİKLEYİCİYE taşınır              → kapı yeniden açılsa
--                                                   bile kural yerinde
-- (b) olmadan (a) yeterli değil: gelecekte biri "app yazamıyor" diye
-- grant'ı geri verirse kural yine kaybolur. Tetikleyici, grant'tan
-- bağımsız olarak veriyi korur.
--
-- ⚠️ ADMIN İSTİSNASI BİLEREK YOK. `auth.uid() is null` (service_role /
-- BO) istisna DEĞİL — çünkü istisna koysaydım bu dosyanın nöbetçisi de
-- istisna kapsamına girer ve kuralı İSPAT EDEMEZDİM. Ölçülemeyen koruma,
-- koruma değildir. BO bugün yalnız `filled` yazıyor (ölçüldü:
-- app/requests/actions.js) ve bu tetikleyici `filled` yazmayı engellemiyor.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) İLAN SÖZLEŞME KAPISI — 237'nin kapatma kapısı GENİŞLETİLİYOR
-- ----------------------------------------------------------------------------
-- Tetikleyicinin ADI aynı kalıyor (237'nin nöbetçisi onu arıyor), gövdesi
-- artık yalnız "kapatma"yı değil sözleşmenin tamamını koruyor.
create or replace function public.trg_ilan_kapatma_kapisi()
returns trigger language plpgsql security definer set search_path = public as $f$
declare
  v_kabul  int;
  v_admin  boolean;
begin
  -- Gerçek admin (giriş yapmış ve admin_roles'ta) istisna. service_role
  -- ve harness (auth.uid() null) istisna DEĞİL — nöbetçi ölçebilsin diye.
  v_admin := auth.uid() is not null
             and exists (select 1 from admin_roles where user_id = auth.uid());

  select count(*) into v_kabul
    from requests where avail_id = new.id and status = 'accepted';

  -- (a) 237'DEN GELEN KURAL: kabul edilmiş misafir varken ilan kapatılamaz
  if coalesce(old.active,true) and not coalesce(new.active,true)
     and v_kabul > 0 and not v_admin then
    raise exception 'has_accepted_requests'
      using detail = format('%s kabul edilmis basvuru', v_kabul),
            hint   = 'Kabul ettigin misafir var. Ilani kaldirmadan once '
                  || 'sohbetten haber ver ve basvuruyu iptal et.';
  end if;

  -- (b) 🔴 YENİ: kabul edilmiş misafir varken TARİH / SAAT / SALON kilitli.
  -- update_availability() bunu zaten reddediyordu; artık doğrudan yazma
  -- yolu da reddediyor. Hata kodu BİLEREK aynı — app'in sözlüğünde
  -- karşılığı zaten var, yeni çeviri gerekmiyor.
  if v_kabul > 0 and not v_admin
     and (new.avail_date   is distinct from old.avail_date
       or new.time_from    is distinct from old.time_from
       or new.time_to      is distinct from old.time_to
       or new.lounge_id    is distinct from old.lounge_id
       or new.airport_code is distinct from old.airport_code) then
    raise exception 'kabul_edilmis_basvuru_var'
      using detail = format('%s kabul edilmis basvuru', v_kabul),
            hint   = 'Tarih, saat ve salon kilitli. Kontenjani artirabilir, '
                  || 'ucus numarasini duzeltebilirsin.';
  end if;

  -- (c) 🔴 YENİ: kontenjan, dolu koltuk sayısının altına inemez.
  -- Bu kural admin için de geçerli — çünkü bu bir yetki meselesi değil,
  -- ARİTMETİK. 3 kişi kabul edilmişken kontenjanı 2 yapmak, veriyi
  -- kendisiyle çelişkiye sokar.
  if new.slots is distinct from old.slots and new.slots < coalesce(new.filled,0) then
    raise exception 'kontenjan_dolulugun_altinda'
      using detail = format('kontenjan %s, dolu %s', new.slots, coalesce(new.filled,0));
  end if;

  -- (d) 🔴 YENİ: KURAL MOTORUNUN ÇIKTISI İSTEMCİNİN GİRDİSİ DEĞİLDİR.
  -- Bu kolonları motor ve onun tetikleyicileri yazar. Doğrudan yazma
  -- yolundan gelen bir değişiklik SESSİZCE GERİ ALINIR — hata vermiyoruz
  -- çünkü meşru bir istemci bunları zaten göndermiyor; gönderen için de
  -- ilan bozulmasın yeter.
  if not v_admin then
    new.rule_severity        := old.rule_severity;
    new.rule_headline        := old.rule_headline;
    new.rule_note            := old.rule_note;
    new.rule_entry_hours     := old.rule_entry_hours;
    new.rule_guest_policy    := old.rule_guest_policy;
    new.rule_flight_coupling := old.rule_flight_coupling;
    new.rule_checked_at      := old.rule_checked_at;
    new.min_trust            := old.min_trust;
    new.featured_until       := old.featured_until;
  end if;

  return new;
end $f$;

-- ----------------------------------------------------------------------------
-- 2) SEYAHAT SÖZLEŞME KAPISI — SİLME DAHİL
-- ----------------------------------------------------------------------------
-- 🔴 237'de `update_visit()` için kilit yazdım ama SİLME hiç konuşulmadı.
-- Seyahati silmek, taşımaktan daha yıkıcı: başvuru dayanağını kaybeder ve
-- geri dönüşü yok. App bugün `visits.delete()` çağırıyor (screens.js:644),
-- yani bu yol her gün kullanılıyor.
--
-- ⚠️ DÜRÜSTLÜK NOTU — BU KAPININ BİR KISMI ZATEN VARDI, AMA KONUŞMUYORDU.
-- Mutasyon testinde (kapıyı bilerek kaldırıp ölçerken) şunu gördüm:
--   ERROR: update or delete on table "visits" violates foreign key
--          constraint "requests_visit_id_fkey" on table "requests"
-- Yani `requests.visit_id` dolu olan bir seyahat FK yüzünden zaten
-- silinemiyordu. Ama kullanıcı bu cümleyi görüyordu — Türkçe değil,
-- anlaşılır değil, ne yapacağını söylemiyor. Ve `visit_id` boş kalmış
-- başvurular bu korumanın DIŞINDA kalıyordu.
--
-- Bu tetikleyici ikisini birden düzeltir: kapsamı genişletir (aynı kişi,
-- aynı havalimanı, aynı gün) ve hatayı app'in sözlüğündeki bir koda
-- çevirir. Bir korumanın var olması yetmez; kullanıcının onu ANLAMASI da
-- korumanın parçasıdır.
create or replace function public.trg_seyahat_sozlesme_kapisi()
returns trigger language plpgsql security definer set search_path = public as $f$
declare
  v_satir  visits%rowtype;
  v_bagli  int;
  v_admin  boolean;
begin
  v_satir := case when tg_op = 'DELETE' then old else new end;

  v_admin := auth.uid() is not null
             and exists (select 1 from admin_roles where user_id = auth.uid());
  if v_admin then
    return v_satir;
  end if;

  -- 🔴 BURAYI BİR KEZ YANLIŞ YAZDIM VE KENDİ HARNESS'İM YAKALADI.
  -- İlk sürümde bağı "aynı kişi + aynı havalimanı + aynı gün" diye
  -- TAHMİN ediyordum. SEED_KURAL_SENARYOLARI tekrar kurulumda patladı:
  --   ERROR: seyahat_silinemez_basvuru_var
  -- çünkü o seyahate bağlı OLMAYAN, sadece aynı gün/havalimanına denk
  -- gelen bir başvuru vardı.
  --
  -- Daha kötüsü: bu, 239'da tam olarak SÖKTÜĞÜM hatanın aynısıydı.
  -- Orada "sorunun hangi ilana ait olduğunu tahmin etme, KAYDET" dedim;
  -- burada seyahat bağını tahmin ediyordum. `requests.visit_id` zaten
  -- var ve app onu yazıyor (ölçüldü: 18 başvurunun 13'ünde dolu).
  --
  -- 🆕 SINIF: **"BİR BAĞI TAHMİN ETMEK, O BAĞ KAYITLIYKEN, KAYDI
  -- OKUMAMAYI SEÇMEKTİR."**
  select count(*) into v_bagli
    from requests r
   where r.visit_id = old.id
     and r.status in ('pending','accepted');

  if v_bagli = 0 then
    return v_satir;
  end if;

  if tg_op = 'DELETE' then
    raise exception 'seyahat_silinemez_basvuru_var'
      using detail = format('%s aktif basvuru', v_bagli),
            hint   = 'Bu seyahate dayanan basvurun var. Once basvuruyu iptal et.';
  end if;

  if new.airport_code is distinct from old.airport_code
     or new.visit_date is distinct from old.visit_date then
    -- Aynı bağ tanımı UPDATE için de geçerli: kayıtlı bağ, tahmin değil.
    raise exception 'seyahate_bagli_basvuru_var'
      using detail = format('%s aktif basvuru', v_bagli),
            hint   = 'Havalimani ve tarih kilitli. Saat ve ucus bilgisini '
                  || 'simdi de duzeltebilirsin.';
  end if;

  return v_satir;
end $f$;

-- ----------------------------------------------------------------------------
-- 1b) 🔴 GÖVDEYİ GENİŞLETMEK YETMEDİ — TETİKLEYİCİ SÜTUN KAPSAMLIYDI
-- ----------------------------------------------------------------------------
-- Yukarıdaki gövdeyi yazıp ölçtüm ve nöbetçi kırmızı yandı:
--   "kabul edilmis basvuru varken ilan TARIHI dogrudan degistirilebildi"
--
-- Sebep, gövde değil TANIMdı:
--   CREATE TRIGGER trg_avail_kapatma_kapisi
--     BEFORE UPDATE **OF active** ON availabilities
--
-- `UPDATE OF active` — yani tetikleyici yalnızca SET listesinde `active`
-- geçtiğinde çalışıyor. `set avail_date=...` yazan bir sorgu onu HİÇ
-- uyandırmıyor. Gövdesine ne yazarsam yazayım, o kod hiç koşmayacaktı.
--
-- 🆕 SINIF: **"BİR TETİKLEYİCİYİ GÖVDESİNDEN OKUMAK, NE ZAMAN
-- ÇALIŞTIĞINI OKUMAK DEĞİLDİR."** Gövde "if active değiştiyse" diyordu;
-- ben bunu "her güncellemede çalışır, içeride ayıklar" diye okudum.
-- Oysa ayıklama tanımın kendisindeydi.
drop trigger if exists trg_avail_kapatma_kapisi on public.availabilities;
create trigger trg_avail_kapatma_kapisi
  before update on public.availabilities
  for each row execute function public.trg_ilan_kapatma_kapisi();

drop trigger if exists trg_visit_sozlesme on public.visits;
create trigger trg_visit_sozlesme
  before update or delete on public.visits
  for each row execute function public.trg_seyahat_sozlesme_kapisi();

-- ----------------------------------------------------------------------------
-- 2b) TEK TANIM, İKİ KAPI — RPC VE TETİKLEYİCİ AYNI CÜMLEYİ OKUSUN
-- ----------------------------------------------------------------------------
-- 237'nin `update_visit()`'i bağı "aynı havalimanı + aynı gün" diye
-- TAHMİN ediyordu; yukarıdaki tetikleyici artık `requests.visit_id`'yi
-- OKUYOR. İkisi farklı cümle kurarsa, kullanıcı hangi kapıdan girdiğine
-- göre farklı cevap alır — bu dosyanın varlık sebebi tam olarak buydu.
--
-- Çözüm: tanım TEK bir fonksiyona taşınır, iki kapı da onu çağırır.
create or replace function public.seyahate_bagli_basvuru(p_visit_id uuid)
returns int language sql stable security definer set search_path = public as $f$
  select count(*)::int from requests
   where visit_id = p_visit_id and status in ('pending','accepted');
$f$;
revoke execute on function public.seyahate_bagli_basvuru(uuid) from public, anon, authenticated;

-- Önce KAYITSIZ bağları kapat: `visit_id` boş kalmış başvuruları, YALNIZ
-- tek bir seyahatle eşleşiyorsa doldur. 239'un kuralı: tahmini kalıcı
-- veri olarak yazma — iki aday varsa boş bırak.
with aday as (
  select r.id as req_id, (array_agg(v.id))[1] as visit_id, count(*) as kac
    from requests r
    join availabilities a on a.id = r.avail_id
    join visits v on v.user_id = r.guest_id
                 and v.airport_code = a.airport_code
                 and v.visit_date   = a.avail_date
   where r.visit_id is null
   group by r.id
  having count(*) = 1
)
update requests r set visit_id = aday.visit_id
  from aday where aday.req_id = r.id;

do $u$
declare v_def text; v_yeni text; v_kalan int;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='update_visit' limit 1;

  if v_def is null then
    raise notice '240: update_visit yok (237 kosulmamis) — atlaniyor.';
  else
    -- 🔴 METNİ EZBERDEN YAZMIYORUM (238'in dersi): canlı gövdeyi okuyup
    -- düzenli ifadeyle değiştiriyorum. Değişmediyse haber veriyorum.
    v_yeni := regexp_replace(
      v_def,
      'select count\(\*\) into v_bagli\s*from requests r join availabilities a on a\.id = r\.avail_id[\s\S]*?and a\.avail_date   = v_v\.visit_date;',
      'v_bagli := public.seyahate_bagli_basvuru(p_id);');
    if v_yeni = v_def then
      raise notice '240 OLCULMEDI: update_visit govdesinde beklenen kalip bulunamadi — '
                   'RPC hala kendi tanimini kullaniyor olabilir. 237 surumunu kontrol et.';
    else
      execute v_yeni;
      raise notice '240: update_visit artik ortak tanimi okuyor.';
    end if;
  end if;

  select count(*) into v_kalan from requests
   where visit_id is null and status in ('pending','accepted');
  if v_kalan > 0 then
    raise notice '240: % aktif basvurunun seyahat bagi HALA bos (birden fazla '
                 'aday seyahat var, tahmin yazmadim). Bunlar silme kapisinin '
                 'disinda kalir.', v_kalan;
  end if;
end $u$;

-- ----------------------------------------------------------------------------
-- 3) KAPILARI KAPAT — İSTEMCİNİN DOĞRUDAN YAZMA HAKKI
-- ----------------------------------------------------------------------------
-- Ölçüldü: app'te `from("availabilities").update/insert/delete` HİÇ YOK
-- (237 hepsini RPC'ye taşıdı) ve `from("visits").update` de yok.
-- Yani bu grant'lar bugün KİMSE tarafından kullanılmıyor — yalnız
-- kötüye kullanım için duruyorlar.
revoke update on public.availabilities from authenticated;
revoke update on public.availabilities from anon;
revoke insert, delete on public.availabilities from authenticated;
revoke insert, delete on public.availabilities from anon;

revoke update on public.visits from authenticated;
revoke update on public.visits from anon;
-- INSERT ve DELETE KALIYOR: app ikisini de kullanıyor. DELETE artık
-- yukarıdaki tetikleyiciyle korunuyor; INSERT'ün bozacağı bir sözleşme yok.

-- Bildirim: kullanıcı kendi bildirimini OKUNDU işaretleyebilmeli, ama
-- bildirimin METNİNİ değiştirebilmemeli. Bugün tablo düzeyinde UPDATE
-- vardı, yani başlık ve gövde de yazılabiliyordu.
revoke update on public.notifications from authenticated;
revoke update on public.notifications from anon;
grant update (read, read_at) on public.notifications to authenticated;

-- ----------------------------------------------------------------------------
-- 4) NÖBETÇİ — HER İKİ YOLU DA ÖLÇ, HİÇBİR VERİYİ BOZMADAN
-- ----------------------------------------------------------------------------
-- 🔴 İLK YAZDIĞIMDA BU NÖBETÇİ SENİN VERİNİ SİLİYORDU. "Bağsız bir seyahat
-- silinebiliyor mu?" diye ölçmek için gerçekten siliyordu — harness'te
-- zararsız, CANLIDA senin seyahatin. Bir ölçüm, ölçtüğü şeyi bozuyorsa
-- ölçüm değil, hasardır.
--
-- 🆕 SINIF: **"BİR NÖBETÇİ, NÖBET TUTTUĞU ŞEYE ZARAR VEREMEZ."**
--
-- Çözüm: bütün yazma denemeleri BİR ALT İŞLEMİN içinde yapılır ve o alt
-- işlem SONUNDA HER HÂLÜKÂRDA geri alınır. PL/pgSQL değişkenleri geri
-- alınmaz — bu yüzden ölçüm sonuçları hayatta kalır, veri değişikliği
-- kalmaz.
do $n240$
declare
  v_av      uuid;
  v_vis     uuid;
  v_bos     uuid;
  v_dolu    uuid;
  v_eski    date;
  v_hatalar text[] := '{}';
  v_notlar  text[] := '{}';
  v_gecti   boolean;
begin
  -- ═══ ÖLÇÜM ALT İŞLEMİ — sonunda geri alınır ═══
  begin
    ------------------------------------------------------------------ İLAN
    select a.id, a.avail_date into v_av, v_eski
      from availabilities a
     where exists (select 1 from requests r where r.avail_id=a.id and r.status='accepted')
     limit 1;

    if v_av is null then
      v_notlar := v_notlar || 'ilan yolu OLCULMEDI (kabul edilmis basvurusu olan ilan yok)'::text;
    else
      -- (A1) tarih doğrudan değiştirilememeli
      v_gecti := false;
      begin
        update availabilities set avail_date = v_eski + 30 where id = v_av;
        v_gecti := true;
      exception when others then
        if sqlerrm not like '%kabul_edilmis_basvuru_var%' then
          v_hatalar := v_hatalar || ('tarih kapisinda beklenmeyen hata: ' || sqlerrm);
        end if;
      end;
      if v_gecti then
        v_hatalar := v_hatalar || 'kabul edilmis basvuru varken ilan TARIHI dogrudan degistirilebildi'::text;
      end if;

      -- (A2) kural motorunun çıktısı yazılamamalı
      begin
        update availabilities set rule_severity='ok', rule_headline='Kesinlikle girersin'
         where id = v_av;
        if exists (select 1 from availabilities where id=v_av and rule_headline='Kesinlikle girersin') then
          v_hatalar := v_hatalar || 'KURAL MOTORUNUN CIKTISI istemci yolundan yazilabildi'::text;
        end if;
      exception when others then
        v_hatalar := v_hatalar || ('motor cikitisi kapisinda beklenmeyen hata: ' || sqlerrm);
      end;

      -- (A3) kontenjan, doluluğun altına inememeli.
      -- 🔴 İLK DENEMEMDE `slots = 0` yazdım; o `slots >= 1` CHECK kısıtına
      -- takıldı ve benim kapımı hiç sınamadı. Bir sınama, sınadığı kapıya
      -- VARMADAN başka bir duvara çarpıyorsa o kapıyı ölçmemiştir.
      -- Doğrusu: dolu koltuk 2+ olan bir ilanda `slots = filled - 1`.
      select a.id into v_dolu from availabilities a where coalesce(a.filled,0) >= 2 limit 1;
      if v_dolu is null then
        v_notlar := v_notlar || 'kontenjan kapisi OLCULMEDI (2+ dolu ilan yok)'::text;
      else
        v_gecti := false;
        begin
          update availabilities a set slots = (a.filled - 1)::smallint where a.id = v_dolu;
          v_gecti := true;
        exception when others then
          if sqlerrm not like '%kontenjan_dolulugun_altinda%' then
            v_hatalar := v_hatalar || ('kontenjan kapisinda beklenmeyen hata: ' || sqlerrm);
          end if;
        end;
        if v_gecti then
          v_hatalar := v_hatalar || 'kontenjan dolulugun ALTINA indirilebildi'::text;
        end if;
      end if;

      -- (A4) 🔴 TERSTEN ÖLÇÜM: meşru değişiklik HÂLÂ geçebilmeli.
      -- Yalnızca "engelledi mi" diye bakan bir nöbetçi, HER ŞEYİ engelleyen
      -- bir tetikleyiciyi de yeşil yakar. Uçuş numarası kilitli DEĞİL.
      begin
        update availabilities set flight_number = 'TK9999' where id = v_av;
        if not exists (select 1 from availabilities where id=v_av and flight_number='TK9999') then
          v_hatalar := v_hatalar || 'mesru degisiklik (ucus no) da engellendi — kapi fazla genis'::text;
        end if;
      exception when others then
        v_hatalar := v_hatalar || ('mesru degisiklik engellendi: ' || sqlerrm);
      end;

      -- (A5) BO'nun tek yazdığı kolon (`filled`) hâlâ yazılabilmeli
      begin
        update availabilities set filled = coalesce(filled,0) where id = v_av;
      exception when others then
        v_hatalar := v_hatalar || ('BO nun filled yazmasi engellendi: ' || sqlerrm);
      end;

      v_notlar := v_notlar || 'ilan yolu olculdu'::text;
    end if;

    --------------------------------------------------------------- SEYAHAT
    select v.id into v_vis from visits v
     where exists (select 1 from requests r
                    where r.visit_id = v.id and r.status in ('pending','accepted'))
     limit 1;

    if v_vis is null then
      v_notlar := v_notlar || 'seyahat yolu OLCULMEDI (bagli basvurusu olan seyahat yok)'::text;
    else
      v_gecti := false;
      begin
        delete from visits where id = v_vis;
        v_gecti := true;
      exception when others then
        if sqlerrm not like '%seyahat_silinemez_basvuru_var%' then
          v_hatalar := v_hatalar || ('silme kapisinda beklenmeyen hata: ' || sqlerrm);
        end if;
      end;
      if v_gecti then
        v_hatalar := v_hatalar || 'bagli basvurusu olan seyahat SILINEBILDI (app tam bunu cagiriyor)'::text;
      end if;

      -- TERSTEN: bağsız seyahat silinebilmeli
      select v.id into v_bos from visits v
       where not exists (select 1 from requests r where r.visit_id = v.id)
       limit 1;
      if v_bos is not null then
        begin
          delete from visits where id = v_bos;
          if exists (select 1 from visits where id = v_bos) then
            v_hatalar := v_hatalar || 'bagsiz seyahat de silinemedi — kapi fazla genis'::text;
          end if;
        exception when others then
          v_hatalar := v_hatalar || ('bagsiz seyahat silinemedi: ' || sqlerrm);
        end;
      end if;

      v_notlar := v_notlar || 'seyahat yolu olculdu'::text;
    end if;

    -- ═══ HER ŞEYİ GERİ AL ═══
    raise exception 'GERI_AL_240';
  exception when others then
    if sqlerrm <> 'GERI_AL_240' then
      v_hatalar := v_hatalar || ('olcum alt islemi coktu: ' || sqlerrm);
    end if;
  end;

  ------------------------------------------------------------------ GRANTLAR
  -- (veri yazmaz — alt işlemin dışında)
  if exists (select 1 from information_schema.table_privileges
              where table_schema='public' and table_name='availabilities'
                and grantee in ('authenticated','anon')
                and privilege_type in ('INSERT','UPDATE','DELETE')) then
    v_hatalar := v_hatalar || 'availabilities uzerinde istemci yazma hakki DURUYOR'::text;
  end if;
  if exists (select 1 from information_schema.table_privileges
              where table_schema='public' and table_name='visits'
                and grantee in ('authenticated','anon') and privilege_type='UPDATE') then
    v_hatalar := v_hatalar || 'visits uzerinde istemci UPDATE hakki DURUYOR'::text;
  end if;
  if not exists (select 1 from information_schema.column_privileges
                  where table_schema='public' and table_name='visits'
                    and grantee='authenticated' and privilege_type='INSERT') then
    v_hatalar := v_hatalar || 'visits INSERT de kalkti — app seyahat ekleyemez, fazla kestim'::text;
  end if;
  if not exists (select 1 from information_schema.column_privileges
                  where table_schema='public' and table_name='notifications'
                    and grantee='authenticated' and privilege_type='UPDATE'
                    and column_name='read') then
    v_hatalar := v_hatalar || 'bildirim OKUNDU isaretlenemez oldu — fazla kestim'::text;
  end if;
  -- 🔴 İLK YAZDIĞIMDA `privilege_type` filtresini KOYMADIM ve bu kontrol
  -- SELECT haklarını da sayıp yanlış alarm verdi. Bir nöbetçi, aradığı
  -- şeyi tam söylemezse bulduğu şeyi yanlış adlandırır.
  if exists (select 1 from information_schema.column_privileges
              where table_schema='public' and table_name='notifications'
                and grantee='authenticated' and privilege_type='UPDATE'
                and column_name in ('title','body')) then
    v_hatalar := v_hatalar || 'bildirim METNI hala istemciden yazilabiliyor'::text;
  end if;

  ------------------------------------------------------------------ RAPOR
  if array_length(v_hatalar,1) is not null then
    raise exception '240 NOBETCI: %', array_to_string(v_hatalar, ' | ');
  end if;
  raise notice '240 OK · % · grantlar temiz · olcum geri alindi (veri degismedi)',
               array_to_string(v_notlar, ' · ');
end $n240$;

select '240 KURAL ODAYA TASINDI' as sonuc,
       (select count(*) from information_schema.table_privileges
         where table_schema='public' and table_name='availabilities'
           and grantee in ('authenticated','anon')
           and privilege_type in ('INSERT','UPDATE','DELETE'))            as acik_ilan_yazma,
       (select count(*) from pg_trigger where tgname='trg_visit_sozlesme' and not tgisinternal) as seyahat_kapisi,
       (select count(*) from information_schema.column_privileges
         where table_schema='public' and table_name='notifications'
           and grantee='authenticated' and privilege_type='UPDATE')       as bildirim_yazilabilir_kolon;
