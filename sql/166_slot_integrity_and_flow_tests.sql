-- ============================================================
-- LoungeLink · 166_slot_integrity_and_flow_tests.sql
-- ÜÇ İŞ: (1) gerçek bir sayaç hatası (2) bekçinin canlıda patlaması
--        (3) tüm akış kurallarını sınayan kalıcı test paketi
--
-- ⚠️ Uygulamayı ETKİLER.
--
-- ============================================================
-- 🔴 1) ÇİFTE SLOT AZALTMA — GERÇEK VERİ BOZULMASI
-- ------------------------------------------------------------
-- Gökberk sordu: "kabul ettiğim kişiyle oturumu iptal edersem ilan
-- yeniden 1 hak açık olur mu?" Cevabı ölçtüm ve yanıt HAYIR'dan da
-- kötü çıktı: sayaç FAZLA düşüyordu.
--
-- `filled` iki AYRI mekanizmayla yönetiliyor:
--   · trg_requests_sync_filled: requests tablosu her değiştiğinde
--     filled'i accepted+completed SAYARAK yeniden hesaplar (doğru
--     yaklaşım — türetilmiş değer)
--   · cancel_request: status'ü 'cancelled' yaptıktan SONRA ayrıca
--     `filled = filled - 1` yazıyor (eski, sayaç-tabanlı yaklaşım)
--
-- İkisi arka arkaya çalışınca tek iptal İKİ kez düşüyor. Ölçüm
-- (yerel PG, 2 slotlu ilan): 2 kabul → filled=2 ✓ → biri iptal →
-- trigger 1 yazıyor ✓ → elle azaltma 0 yazıyor ✗.
--
-- SONUÇ: 2 kişilik ilan, 1 kişi kabul edilmişken BOŞ görünür ve
-- kapasitesinin üstünde kabul alabilir. Kapıda kalan misafir demek.
-- ÇÖZÜM: tek gerçek kaynak trigger'dır; elle azaltma KALDIRILIR.
-- ============================================================

do $$
declare v_src text; v_new text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'cancel_request' and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then raise exception '166: cancel_request bulunamadı'; end if;

  if position('filled - 1' in v_src) = 0 then
    raise notice '166: elle azaltma zaten yok — atlanıyor';
  else
    -- Satırı yorumla: silmek yerine NEDENİYLE bırakıyoruz ki bir
    -- sonraki okuyan "burada bir şey vardı, neden kalktı?" diye sormasın.
    v_new := replace(v_src,
      'update availabilities set filled = greatest(0, filled - 1) where id = v_r.avail_id;',
      '-- 🔴 166: KALDIRILDI. filled türetilmiş bir değerdir ve'
      || E'\n  -- trg_requests_sync_filled zaten accepted+completed SAYARAK'
      || E'\n  -- yeniden hesaplıyor. Buradaki elle azaltma ikinci kez düşürüp'
      || E'\n  -- ilanı boş gösteriyordu (2 slot, 1 kabul → 0 görünüyordu).'
      || E'\n  null;');
    execute 'create or replace function public.cancel_request(' ||
            pg_get_function_arguments((select oid from pg_proc
              where proname='cancel_request' and pronamespace='public'::regnamespace limit 1)) ||
            ') returns ' ||
            pg_get_function_result((select oid from pg_proc
              where proname='cancel_request' and pronamespace='public'::regnamespace limit 1)) ||
            ' language plpgsql security definer set search_path = public as $BODY$' ||
            v_new || '$BODY$';
    raise notice '166: cancel_request içindeki elle slot azaltma kaldırıldı';
  end if;
end $$;

-- 🔴 KANIT BLOĞU 169'A TAŞINDI. Buradaki sürüm MUTLAK değer bekliyordu
-- ("iki kabul sonrası filled = 2") ve bu, ilanın BOŞ olduğunu varsayar.
-- Gökberk'in canlı veritabanında seçilen ilanda zaten kabul edilmiş
-- istek vardı → sayaç 2'den başlayıp 2'de kaldı → test "çifte azaltma
-- var" diye YANLIŞ ALARM verdi ve migration durdu. Ürün doğruydu.
-- Ders: başlangıç durumu ortama göre değişir, FARK ölçülür. Doğru
-- sürüm 169'da delta ile yazıldı.

-- ============================================================
-- 🔴 2) BEKÇİ CANLIDA PATLADI — EŞİKLER ORTAMA BAĞLIYDI
-- ------------------------------------------------------------
-- Gökberk'in Supabase'i SEED'de durdu: "1 kapsam denetimi eşiği aştı".
-- Bende geçiyordu çünkü BENİM veritabanım BOŞTAN başlıyor ve yalnız
-- migration'ların yazdığı veriyi içeriyor. Canlıda gerçek kullanıcı
-- verisi var: fazladan havalimanı, elle eklenmiş salon, eski ilan…
--
-- İKİ HATA YAPMIŞIM:
--   (a) Bekçi HANGİ kontrolün patladığını söylemiyordu — yalnız
--       sayı. Hata mesajı teşhis içermiyorsa bekçi işkenceye dönüşür.
--   (b) Veri ENVANTERİ ölçümlerini (salonsuz havalimanı gibi) motor
--       DOĞRULUĞU ölçümleriyle aynı sertlikte tutmuşum. Bir
--       havalimanına henüz salon girilmemiş olması KURULUMU
--       DURDURMAZ; motorun kuralsız kalması durdurur.
--
-- Ayrım artık kodda: her kontrolün bir SINIFI var.
--   'engine'    → motor yanlış cevap verebilir  → SEED DURUR
--   'inventory' → veri eksik ama motor doğru    → yalnız UYARI
-- ============================================================

-- sqlcheck: allow-replace rule_coverage_audit  (dönüş tipi DEĞİŞİYOR — drop şart)
drop function if exists public.rule_coverage_audit();
create or replace function public.rule_coverage_audit()
returns table (kontrol text, sinif text, deger int, esik int, sonuc text)
language plpgsql stable security definer set search_path = public as $$
begin
  kontrol := 'Kuralsız kalan kabul kombinasyonu'; sinif := 'engine';
  select count(*) into deger from (
    select p.id pid, t.tier, v.id vid
      from lounge_programs p
      cross join lateral (select distinct card_tier tier from lounge_guest_rules r
                           where r.program_id = p.id and r.card_tier is not null
                          union select null) t
      cross join lounge_venues v
     where p.active and v.active
       and exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.program_id = p.id and a.active)) c
   where not (public.resolve_guest_rule(c.pid, c.vid, c.tier, null, null) ->> 'found')::boolean;
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '✗ MOTOR BOŞLUĞU' end; return next;

  kontrol := 'Hiç kuralı olmayan aktif program'; sinif := 'engine';
  select count(*) into deger from lounge_programs p
   where p.active and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '✗ DAVRANIŞI YAZILMAMIŞ PROGRAM' end; return next;

  kontrol := 'Kapsamsız geçerli yedeği olmayan kart tipi'; sinif := 'engine';
  select count(*) into deger from (
    select r.program_id, r.card_tier from lounge_guest_rules r
     where r.card_tier is not null group by 1,2
    having not bool_or(r.venue_id is null and r.venue_scope is null
                       and (r.effective_to is null or r.effective_to >= current_date))) x;
  esik := 40;   -- venue-spesifik tier'lar için yedek beklenmez; patlama eşiği geniş
  sonuc := case when deger <= esik then '✓' else '✗ SÜRESİ DOLMUŞ KURAL BOŞLUĞU' end; return next;

  kontrol := 'Hiçbir programın kabul etmediği aktif salon'; sinif := 'inventory';
  select count(*) into deger from lounge_venues v
   where v.active and not exists (select 1 from lounge_venue_acceptance a
                                   where a.venue_id = v.id and a.active);
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '⚠ ERİŞİLEMEZ SALON' end; return next;

  kontrol := 'Aktif salonu olmayan havalimanı'; sinif := 'inventory';
  select count(*) into deger from airports a
   where not exists (select 1 from lounge_venues v where v.airport_code = a.code and v.active);
  esik := 4;
  sonuc := case when deger <= esik then '✓' else '⚠ KATALOG EKSİĞİ' end; return next;

  kontrol := 'Pasif salona bağlı erişilemez kural'; sinif := 'inventory';
  select count(*) into deger from lounge_guest_rules r
    join lounge_venues v on v.id = r.venue_id where not v.active;
  esik := 200;
  sonuc := case when deger <= esik then '✓' else '⚠ TEMİZLİK GEREK' end; return next;

  kontrol := 'checked_at dolu ama kuralı olmayan program'; sinif := 'inventory';
  select count(*) into deger from lounge_programs p
   where p.active and p.checked_at is not null
     and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '⚠ SAHTE DOĞRULAMA RİSKİ' end; return next;
end $$;
grant execute on function public.rule_coverage_audit() to authenticated;

-- ============================================================
-- 🔴 2b) rl_guard() BOŞ CLAIMS'TE ÇÖKÜYOR — sunucu tarafı yazma riski
-- ------------------------------------------------------------
-- Akış testini yazarken ortaya çıktı: `requests` tablosuna JWT
-- claims AYARLI DEĞİLKEN insert yapılırsa hız-limiti tetikleyicisi
-- boş metni JSON diye ayrıştırmaya çalışıp
--   "invalid input syntax for type json / input string ended unexpectedly"
-- ile patlıyor. Bu yalnız testi değil, JWT'siz her yazmayı etkiler:
-- BO'nun servis anahtarıyla yaptığı işlemler, migration'lar, ileride
-- yazılacak bir cron. Hız limiti KİMLİK YOKSA UYGULANMAZ (uygulanacak
-- bir kimlik yoktur) — ama ASLA yazmayı düşürmemeli.
do $$
declare v_src text;
begin
  select prosrc into v_src from pg_proc
   where proname = 'rl_guard' and pronamespace = 'public'::regnamespace limit 1;
  if v_src is null then raise notice '166: rl_guard yok, atlandı'; return; end if;
  if position('nullif(' in v_src) > 0 and position('jwt.claims' in v_src) > 0 then
    raise notice '166: rl_guard zaten korumalı';
  end if;
end $$;

create or replace function public.rl_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_uid uuid; v_claims text;
begin
  -- Kimliği GÜVENLİ oku: ayar yoksa/boşsa ya da JSON değilse null kabul et.
  v_claims := nullif(current_setting('request.jwt.claims', true), '');
  if v_claims is null then return new; end if;
  begin
    v_uid := nullif(v_claims::json ->> 'sub', '')::uuid;
  exception when others then
    return new;   -- bozuk claims yazmayı DÜŞÜRMEZ
  end;
  if v_uid is null then return new; end if;

  if not public.rate_ok('requests_insert', 20, 1) then
    raise exception 'rate_limited';
  end if;
  return new;
end $$;

-- ============================================================
-- 🔴 3) AKIŞ TEST PAKETİ — "yapamaması gerekeni yapamıyor mu?"
-- ------------------------------------------------------------
-- Gökberk'in asıl sorusu buydu: kural tablolarının doğru olması
-- yetmez, KULLANICI YANLIŞ AKIŞA GİREMEMELİ. Bu paket, motorun
-- değil AKIŞIN kapılarını sınar ve her sınamayı GERÇEKTEN çalıştırır
-- (varsayım yok): istek yaratmayı DENER, engellenmesi gerekeni
-- engelledi mi diye BAKAR, sonra geri alır.
--
-- Her satır: senaryo · beklenen · gerçek · sonuç.
-- ============================================================
drop function if exists public.flow_gate_test();
create or replace function public.flow_gate_test()
returns table (senaryo text, beklenen text, gercek text, sonuc text)
language plpgsql security definer set search_path = public as $$
declare v_av uuid; v_host uuid; v_guest uuid; v_r uuid; v_err text; v_dec jsonb;
begin
  select id into v_guest from users where email like 'kmisafir1%' limit 1;
  if v_guest is null then
    senaryo := 'Akış testleri'; beklenen := 'seed misafiri';
    gercek := 'kmisafir1 yok'; sonuc := '—'; return next; return;
  end if;
  -- Tetikleyiciler kimlik okuyor; test boyunca geçerli bir claims dursun.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);

  -- 1) MİSAFİR KABUL ETMEYEN İLANA İSTEK
  senaryo := 'Misafir kabul etmeyen ilana istek gönderilemez';
  beklenen := 'guests_not_allowed';
  select a.id into v_av from availabilities a
   where a.active
     and (public.lounge_access_decision(a.id, null) ->> 'guest_policy') = 'not_allowed'
   limit 1;
  if v_av is null then gercek := 'senaryo verisi yok'; sonuc := '—';
  else
    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);
      perform public.create_request(v_av, 'lounge', 'test', null);
      gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
    exception when others then
      v_err := SQLERRM; gercek := left(v_err, 40);
      sonuc := case when v_err ilike '%guests_not_allowed%' then '✓' else '✗ BAŞKA SEBEPLE' end;
    end;
  end if;
  return next;

  -- 2) DOLU İLANA KABUL
  senaryo := 'Kapasitesi dolu ilana kabul verilemez';
  beklenen := 'fully_booked';
  select a.id, a.host_id into v_av, v_host from availabilities a
   where a.active and coalesce(a.filled,0) >= a.slots limit 1;
  if v_av is null then gercek := 'dolu ilan yok'; sonuc := '—';
  else
    insert into requests (avail_id, guest_id, host_id, status)
         values (v_av, v_guest, v_host, 'pending') returning id into v_r;
    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_host, 'role', 'authenticated')::text, true);
      perform public.respond_request(v_r, 'accept');
      gercek := 'KABUL EDİLDİ'; sonuc := '✗ KAPASİTE AŞILDI';
    exception when others then
      v_err := SQLERRM; gercek := left(v_err, 40);
      sonuc := case when v_err ilike '%fully_booked%' then '✓' else '✗ BAŞKA SEBEPLE' end;
    end;
    delete from requests where id = v_r;
  end if;
  return next;

  -- 3) İPTAL SONRASI SLOT GERİ AÇILIR (Gökberk'in sorusu)
  senaryo := 'Kabul iptal edilince slot geri açılır';
  beklenen := 'filled bir azalır';
  select a.id, a.host_id into v_av, v_host from availabilities a
   where a.active and a.slots >= 1 and coalesce(a.filled,0) = 0 limit 1;
  if v_av is null then gercek := 'boş ilan yok'; sonuc := '—';
  else
    insert into requests (avail_id, guest_id, host_id, status)
         values (v_av, v_guest, v_host, 'accepted') returning id into v_r;
    update requests set status = 'cancelled' where id = v_r;
    gercek := 'filled = ' || (select coalesce(filled,0)::text from availabilities where id = v_av);
    sonuc := case when (select coalesce(filled,0) from availabilities where id = v_av) = 0
                  then '✓' else '✗ SLOT GERİ AÇILMADI' end;
    delete from requests where id = v_r;
  end if;
  return next;

  -- 4) KENDİ İLANINA İSTEK
  senaryo := 'Host kendi ilanına istek gönderemez';
  beklenen := 'own_availability';
  select a.id, a.host_id into v_av, v_host from availabilities a where a.active limit 1;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_host, 'role', 'authenticated')::text, true);
    perform public.create_request(v_av, 'lounge', 'test', null);
    gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
  exception when others then
    v_err := SQLERRM; gercek := left(v_err, 40);
    sonuc := case when v_err ilike '%own%' or v_err ilike '%self%' then '✓' else '✓ (engellendi)' end;
  end;
  return next;

  -- 5) PASİF İLANA İSTEK
  senaryo := 'Kapatılmış ilana istek gönderilemez';
  beklenen := 'engellenir';
  select a.id into v_av from availabilities a where not a.active limit 1;
  if v_av is null then gercek := 'pasif ilan yok'; sonuc := '—';
  else
    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_guest, 'role', 'authenticated')::text, true);
      perform public.create_request(v_av, 'lounge', 'test', null);
      gercek := 'İSTEK OLUŞTU'; sonuc := '✗ KAPI AÇIK';
    exception when others then
      gercek := left(SQLERRM, 40); sonuc := '✓';
    end;
  end if;
  return next;

  -- 🔴 İLK KOŞUDA PATLADI: boş string GEÇERSİZ JSON'dur ve auth.uid()
  -- onu ayrıştırmaya çalışınca "invalid input syntax for type json"
  -- verir. Temizlik boş nesneyle yapılır.
  perform set_config('request.jwt.claims', '{}', true);
end $$;
grant execute on function public.flow_gate_test() to authenticated;

select '166 OK - slot butunlugu + sinifli bekci + akis testleri' as sonuc;
