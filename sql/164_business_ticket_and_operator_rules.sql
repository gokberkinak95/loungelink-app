-- ============================================================
-- LoungeLink · 164_business_ticket_and_operator_rules.sql
-- KAPSAM BOŞLUĞUNUN SON %3'Ü — Gökberk haklıydı
--
-- 163 "kalan 18 boşluk hiç kural yazılmamış programlardan" dedi ve
-- listeyi mazeret gibi bıraktı. Gökberk itiraz etti:
--   · "Business bileti için THY kural tablosundan biliyor olman lazım"
--   · "Primeclass, iGA, Amex, Plaza zaten lounge adı değil mi?
--      hangi salona hangi sağlayıcıyla girileceğini vermiştim"
-- İkisi de doğru. Model zaten ayırıyordu (lounge_programs.kind =
-- 'operator' | 'airline' | 'card_program') ama bu programların
-- DAVRANIŞI hiç yazılmamıştı. Kural yazılmayınca motor program
-- varsayılanına düşüyor — yani en cömert cevaba.
--
-- Bu dosya dört davranışı da AÇIKÇA yazar. Hiçbiri uydurma değil;
-- her biri elimizdeki resmî kaynağın söylediği şey:
-- ============================================================

-- ---- 1) BUSINESS BİLETİ (THY kural tablosu) ----
-- Business bileti SAHİBİNİ salona sokar. Misafir hakkı bilete
-- değil STATÜ KARTINA bağlıdır (Tablo-4'ün Business bölümü notu:
-- "Business bölümünde misafir/aile hakkı yoktur; misafirle girmek
-- için girişte Miles&Smiles bölümünü isteyin"). Yani: kendisi
-- girer, misafir götüremez — ve bunu kullanıcıya söylemek, sessiz
-- kalıp sonra kapıda reddedilmesinden iyidir.
insert into lounge_guest_rules
  (program_id, venue_id, venue_scope, card_tier, carrier,
   guest_allowance, family_allowed, paid_entry_allowed, notes)
select p.id, null, null, null, null,
       0, false, false,
       'Business bileti kendi girişini sağlar; misafir hakkı bilete değil statü kartına bağlıdır. '
       'Business bölümünde misafir/aile kabul edilmez — misafirle girecekseniz girişte Miles&Smiles bölümünü isteyin.'
  from lounge_programs p
 where p.code = 'BUSINESS_TICKET'
   and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);

-- ---- 2) OPERATÖR SALONLARI (Primeclass · iGA · Plaza Premium) ----
-- Bunlar bir "üyelik" değil, salonun KENDİ kapı satışı. Kimse
-- "Primeclass üyesi" değildir; kapıda ödeyip girer ve yanındakini
-- de ödeyerek sokar. Dolayısıyla misafir DAHİL DEĞİL ama YASAK da
-- değil: ücretli. Bu ayrım ürün için kritik — "misafir alamazsın"
-- demek yanlış, "misafir de ödeyerek girer" doğru.
insert into lounge_guest_rules
  (program_id, venue_id, venue_scope, card_tier, carrier,
   guest_allowance, family_allowed, paid_entry_allowed, notes)
select p.id, null, null, null, null,
       0, false, true,
       case p.code
         when 'PRIMECLASS' then 'Primeclass salonları kapıda ücretli girişe açıktır (TAV işletmesi). '
              'Misafiriniz de aynı tarifeden girer; ücret kapıda kişi başı tahsil edilir.'
         when 'IGA_LOUNGE' then 'iGA salonları İstanbul Havalimanı''nda kapıda ücretli girişe açıktır. '
              'Misafiriniz de aynı tarifeden girer.'
         when 'PLAZA_PREMIUM' then 'Plaza Premium salonları kapıda ücretli girişe açıktır. '
              'Misafiriniz de aynı tarifeden girer; kalış süresi paketine göre değişir.'
       end
  from lounge_programs p
 where p.code in ('PRIMECLASS','IGA_LOUNGE','PLAZA_PREMIUM')
   and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);

-- ---- 3) AMEX / BANKA KARTI — DÜRÜST BİLİNMEZLİK ----
-- Amex Platinum ve benzeri kartların misafir hakkı KARTI VEREN
-- KURUMA göre değişir ve elimizde doğrulanmış bir tablo YOK.
-- Uydurmak yerine bunu kuralın kendisine yazıyoruz: hak var
-- SAYILMAZ, kapıda teyit istenir. 162'nin "doğrulandı" rozeti de
-- bu programlara verilmez (kural sayısı > 0 ama checked_at boş).
insert into lounge_guest_rules
  (program_id, venue_id, venue_scope, card_tier, carrier,
   guest_allowance, family_allowed, paid_entry_allowed, notes)
select p.id, null, null, null, null,
       0, false, true,
       'Bu kartın misafir hakkı kartı veren kuruma göre değişir ve tarafımızca doğrulanmamıştır. '
       'Misafir götürmeyi planlıyorsanız bankanızdan teyit alın; salon kapıda ücret isteyebilir.'
  from lounge_programs p
 where p.code in ('AMEX_GLOBAL','BANK_CARD','DREAMFOLKS','EVERYLOUNGE','ONPASS','ST_PASS')
   and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);

-- ---- DOĞRULAMA: dört davranış da artık motorda ----
do $$
declare j jsonb;
begin
  -- Business bileti: girer ama misafir yok
  j := public.resolve_guest_rule((select id from lounge_programs where code='BUSINESS_TICKET'),
                                 null, null, null, null);
  if not coalesce((j ->> 'found')::boolean,false) then
    raise exception '164: BUSINESS_TICKET hâlâ kuralsız';
  end if;
  if coalesce((j ->> 'guest_allowance')::int, 9) <> 0 then
    raise exception '164: Business bileti misafir hakkı 0 olmalı';
  end if;

  -- Operatör: misafir dahil DEĞİL ama ücretli giriş AÇIK
  j := public.resolve_guest_rule((select id from lounge_programs where code='PRIMECLASS'),
                                 null, null, null, null);
  if not coalesce((j ->> 'paid_entry_allowed')::boolean,false) then
    raise exception '164: Primeclass ücretli giriş açık olmalı (yasak değil)';
  end if;
end $$;

-- ---- KAPSAM EŞİĞİ SIKILAŞTIRILIR ----
-- 163'te eşik 20'ydi çünkü beş program modellenmemişti. Artık
-- hepsinin davranışı yazılı; boşluk kalırsa GERÇEK bir eksiktir.
create or replace function public.rule_coverage_audit()
returns table (kontrol text, deger int, esik int, sonuc text)
language plpgsql stable security definer set search_path = public as $$
begin
  kontrol := 'Kuralsız kalan kabul kombinasyonu (taşıyıcısız)';
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
  esik := 0;   -- 164 sonrası SIFIR tolerans: her kabul edilen kombinasyonun kuralı var
  sonuc := case when deger <= esik then '✓' else '✗ KAPSAM BOŞLUĞU' end;
  return next;

  kontrol := 'Pasif salona bağlı erişilemez kural';
  select count(*) into deger from lounge_guest_rules r
    join lounge_venues v on v.id = r.venue_id where not v.active;
  esik := 80;
  sonuc := case when deger <= esik then '✓' else '✗ TEMİZLİK GEREK' end;
  return next;

  kontrol := 'checked_at dolu ama kuralı olmayan program';
  select count(*) into deger from lounge_programs p
   where p.active and p.checked_at is not null
     and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '✗ SAHTE DOĞRULAMA RİSKİ' end;
  return next;

  kontrol := 'Aktif salonu olmayan havalimanı';
  select count(*) into deger from airports a
   where not exists (select 1 from lounge_venues v where v.airport_code = a.code and v.active);
  esik := 4;
  sonuc := case when deger <= esik then '✓' else '✗ KATALOG EKSİĞİ' end;
  return next;

  kontrol := 'Hiçbir programın kabul etmediği aktif salon';
  select count(*) into deger from lounge_venues v
   where v.active and not exists (select 1 from lounge_venue_acceptance a
                                   where a.venue_id = v.id and a.active);
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '✗ ERİŞİLEMEZ SALON' end;
  return next;

  -- YENİ 6. ÖLÇÜM: hiç kuralı olmayan AKTİF program. 163'ün
  -- "mazeret listesi" bir daha oluşmasın diye sayıya bağlandı.
  kontrol := 'Hiç kuralı olmayan aktif program';
  select count(*) into deger from lounge_programs p
   where p.active and not exists (select 1 from lounge_guest_rules r where r.program_id = p.id);
  esik := 0;
  sonuc := case when deger <= esik then '✓' else '✗ DAVRANIŞI YAZILMAMIŞ PROGRAM' end;
  return next;
end $$;
grant execute on function public.rule_coverage_audit() to authenticated;

select '164 OK - business bileti + operator salonlari + amex kurallari' as sonuc;
