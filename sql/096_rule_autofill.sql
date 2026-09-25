-- ============================================================
-- LoungeLink · 096_rule_autofill.sql
-- KURAL MATRİSİNİ ELLE DOLDURMAYI BİTİRMEK
--
-- ⚠️ Uygulamayı ETKİLER (veri seviyesinde): kural motoru artık daha çok
-- salonda "bilinmiyor" yerine bir cevap üretebilir.
--
-- ------------------------------------------------------------
-- 🔴 SORUN: Gokberk haklı — "kural linkini sana verdim, BO'da tek tek
-- ayarlama yapmak istemiyorum."
--
-- 086 zaten KAYNAKTAN OKUDUĞUM her şeyi tohumladı (THY, Star Gold,
-- Pegasus ücretli giriş). Ama salon sayısı arttıkça matris kombinatoryal
-- büyüyor: 11 salon × 12 program = 132 hücre. Bunların çoğu için
-- resmî kaynak YOK; elle doldurmak da imkânsız, boş bırakmak da
-- kullanıcıya sürekli "doğrulanmadı" göstermek demek.
--
-- ÇÖZÜM: PROGRAM VARSAYILANINDAN OTOMATİK DOLDUR, AMA YALAN SÖYLEME.
-- Otomatik üretilen her satır:
--   · guest_policy  = programın kendi varsayılanı (086/088'den)
--   · checked_at    = NULL          → sağlık raporunda kırmızı
--   · conditions    = "otomatik türetildi" notu
--   · enforcement   = 'warn'        → ASLA engellemez
-- Yani kullanıcı "bilmiyoruz" yerine "genellikle şöyle, kapıda teyit et"
-- görür; biz de hangi satırın gerçek hangisinin varsayım olduğunu
-- kaybetmeyiz. Elle girilmiş ya da doğrulanmış satıra DOKUNMAZ.
--
-- Bu, kapsamı artırırken güveni artırmaz — ve bu ayrım korunmalıdır.
-- Kural motoru bu satırlar için `confidence='assumed'` üretir.
-- ============================================================

create or replace function public.autofill_venue_acceptance(
  p_venue_id uuid default null,     -- null = tüm aktif salonlar
  p_dry_run  boolean default false
) returns table (venue text, program text, policy text, eylem text)
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in
    select v.id as vid, v.name as vname, v.airport_code, v.section,
           p.id as pid, p.code as pcode, p.name as pname,
           p.guest_default, p.guest_included_count, p.guest_flight_coupling,
           p.typical_guest_fee, p.guest_fee_currency, p.max_stay_hours,
           p.entitlement_model
      from lounge_venues v
      cross join lounge_programs p
     where v.active and p.active
       and (p_venue_id is null or v.id = p_venue_id)
       -- Zaten satırı olan hücreye DOKUNMA (elle girilmiş olabilir)
       and not exists (select 1 from lounge_venue_acceptance a
                        where a.venue_id = v.id and a.program_id = p.id)
       -- 🔴 HAVAYOLU PROGRAMLARINI OTOMATİK YAYMA. "TK Miles&Smiles
       -- Plaza Premium'da geçerlidir" gibi bir varsayım üretmek,
       -- bilmemekten kötüdür: havayolu salonları programa BAĞLIDIR,
       -- kart programları ise genellikle geniş ağlıdır.
       and p.entitlement_model in ('card_membership','paid_entry','operator_program')
       -- İşletmeci programı yalnız KENDİ salonuna uygulanır
       and (p.entitlement_model <> 'operator_program'
            or lower(v.name) like '%' || lower(split_part(p.name, ' ', 1)) || '%')
  loop
    if not p_dry_run then
      insert into lounge_venue_acceptance
        (venue_id, program_id, accepted, guest_policy, guest_included_count,
         guest_fee_amount, guest_fee_currency, guest_flight_coupling,
         max_stay_hours, enforcement, conditions, checked_at)
      values
        (r.vid, r.pid, true,
         -- 🔴 GOKBERK'İN KARARI (7 Ağu): bilmediğimiz hücrede program
         -- varsayılanını GERÇEK gibi yazmıyoruz. Bilinmeyen "unknown"
         -- kalır → karar motoru confidence='unknown' üretir → kullanıcıya
         -- BO'dan düzenlenebilen GENEL UYARI çıkar.
         --
         -- Neden: bir salonun bir programı kabul edip etmediği, o programın
         -- kendi kuralından BAĞIMSIZ bir olgudur. "Priority Pass ziyaret
         -- başı ücretlidir" doğrudur; "bu salon Priority Pass kabul eder"
         -- ise AYRI bir iddiadır ve elimizde kanıtı yoktur. İkisini
         -- karıştırmak, bilmediğimizi biliyormuş gibi göstermektir.
         'unknown',
         0, null, null,
         r.guest_flight_coupling,      -- program olgusu: bunu biliyoruz
         r.max_stay_hours,
         'warn',                       -- otomatik satır ASLA engellemez
         'Bu salonun bu programı kabul edip etmediği DOĞRULANMADI (096 otomatik satır). '
         || 'Programın kendi kuralı: '
         || case r.guest_default
              when 'paid'     then 'misafir girişi ziyaret başı ÜCRETLİDİR'
              when 'included' then 'misafir hakkı programa dahildir'
              when 'not_allowed' then 'program misafir kabul etmiyor'
              else 'misafir politikası tanımsız' end
         || coalesce(' (yaklaşık ' || r.typical_guest_fee::text || ' ' || r.guest_fee_currency || ')', '')
         || '. Salon kabulü sahada doğrulanınca "Doğruladım" ile işaretle.',
         null)                         -- checked_at NULL = doğrulanmadı
      on conflict (venue_id, program_id) do nothing;
    end if;

    venue   := r.airport_code || ' · ' || r.vname
               || case when r.section is not null then ' (' || r.section || ')' else '' end;
    program := r.pcode;
    policy  := coalesce(nullif(r.guest_default,''), 'unknown');
    eylem   := case when p_dry_run then 'eklenecek' else 'eklendi' end;
    return next;
  end loop;
end $$;
revoke all on function public.autofill_venue_acceptance(uuid, boolean) from public, authenticated;
-- Yalnız sunucu (BO service_role) çağırır.


-- ============================================================
-- HAVAYOLU SALONU × HAVAYOLU PROGRAMI — elle ama TOPLU
--
-- Otomatik doldurma havayolu programlarını bilerek atlıyor. Ama THY
-- salonlarının THY programını kabul ettiği aşikâr; bunu 086 zaten
-- girdi. Burada eksik kalan tek şey: 086'dan SONRA eklenmiş THY
-- salonları varsa onlar. Aynı kural onlara da uygulanır.
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true,
       case when v.section = 'business' then 'not_allowed' else 'included' end,
       case when v.section = 'business' then 0 else 1 end,
       'same_carrier', 'warn',
       case when v.section = 'business'
            then 'IST dis hat Business bolumunde misafir/aile hakki yok; misafir '
                 || 'getirilecekse Miles&Smiles bolumune girilmeli.'
            else 'Misafir hakki kart tipine gore degisir; Classic/Classic Plus''ta hak yok.' end,
       'https://www.turkishairlines.com/tr-tr/bilgi-edin/lounge/kurallar-ve-kosullar/',
       current_date
  from lounge_venues v
  join lounge_programs p on p.code = 'TK_MS'
 where v.active
   and (lower(v.name) like '%turkish airlines%' or lower(v.name) like '%thy%')
   and not exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.program_id = p.id);



-- ============================================================
-- 🔴 KANITLI SATIRLAR — Priority Pass'in KENDİ SALON DİZİNİNDEN
--
-- prioritypass.com/lounges/turkey/... altında listelenen salonlar,
-- Priority Pass'in kendi beyanıdır: yani "bu salon PP kabul eder"
-- iddiasının BİRİNCİL kaynağı. Bu yüzden checked_at doluyor.
--
-- Misafir politikası yine 'paid' — PP koşulları md.4: erişim kişi başı
-- ve ziyaret başı ücretlidir, misafir ziyaretleri de üyenin kartından
-- tahsil edilir. Ücret salona/plana göre değiştiği için TUTAR YAZMIYORUZ;
-- yanlış rakam, rakam olmamasından kötüdür.
-- ============================================================
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, guest_included_count,
   guest_flight_coupling, guest_fee_note, enforcement, conditions, source_url, checked_at)
select v.id, p.id, true, 'paid', 0, 'any',
       'Ücret kişi başı ve ziyaret başına; misafir de üyenin kartından tahsil edilir. '
       || 'Tutar üyelik planına ve salona göre değişir — kapıda teyit et.',
       'warn',
       'Misafirin uçtuğu havayolu ÖNEMSİZ. Misafir üyeyle AYNI ANDA kaydolup girmeli; '
       || 'kendi biniş kartı ve kimliği gerekir. Erişim aracı devredilemez.',
       'https://www.prioritypass.com/lounges/turkey', current_date
  from lounge_venues v
  join lounge_programs p on p.code = 'PRIORITY_PASS'
 where v.active
   and (   (v.airport_code = 'IST' and lower(v.name) like '%iga lounge%'
            and coalesce(v.scope,'') <> 'domestic')
        or (v.airport_code = 'SAW' and lower(v.name) like '%plaza premium%'))
on conflict (venue_id, program_id) do update set
  accepted = true, guest_policy = 'paid',
  source_url = excluded.source_url, checked_at = excluded.checked_at,
  conditions = excluded.conditions, guest_fee_note = excluded.guest_fee_note;

-- IST iç hat Miles&Smiles salonu — misafir ayrıntısı
-- (Elite Plus, TK iç hat seferi, kabin fark etmez: 1 misafir VEYA aile —
--  eş ve 25 yaş altı çocuklar.)
update lounge_venue_acceptance a
   set guest_included_count = 1,
       conditions = 'Elite Plus, TK iç hat seferinde — kabin fark etmez. 1 misafir VEYA aile '
                 || '(eş + 25 yaş altı çocuklar). Misafirin de TK seferinde uçuyor olması gerekir.',
       checked_at = current_date
  from lounge_venues v, lounge_programs p
 where a.venue_id = v.id and a.program_id = p.id
   and p.code = 'TK_MS' and v.airport_code = 'IST'
   and lower(v.name) like '%turkish airlines%' and lower(coalesce(v.terminal,'')) like '%ic hat%'
   -- 🔴 KISIT: lva_included_chk -> (guest_policy='included' or guest_included_count=0)
   -- Bu update politikaya bakmadan sayiyi 1 yapiyordu ve IST ic hat
   -- BUSINESS bolumune de carpiyordu (o satirin politikasi 'not_allowed').
   -- Misafir sayisi yalniz misafirin GERCEKTEN kabul edildigi satirda
   -- anlamlidir; 'not_allowed' bir satirda "1 misafir" celiskidir.
   and a.guest_policy = 'included';

-- ============================================================
-- ÇALIŞTIR — önce kuru deneme, sonra gerçek
-- ============================================================
-- Ne eklenecek? (hiçbir şey yazmaz)
select * from public.autofill_venue_acceptance(null, true);

-- Gerçekten ekle
select count(*) as otomatik_eklenen from public.autofill_venue_acceptance(null, false);

-- ============================================================
-- DOĞRULAMA — kapsama ve dürüstlük birlikte ölçülür
-- ============================================================
select
  (select count(*) from lounge_venue_acceptance)                              as toplam_satir,
  (select count(*) from lounge_venue_acceptance where checked_at is not null) as dogrulanmis,
  (select count(*) from lounge_venue_acceptance where checked_at is null)     as varsayim,
  (select count(*) from lounge_venue_acceptance where guest_policy='unknown') as hala_bilinmiyor,
  (select count(*) from lounge_venues v where v.active
     and not exists (select 1 from lounge_venue_acceptance a where a.venue_id=v.id)) as bos_salon;

select v.airport_code, v.name, p.code,
       a.guest_policy, a.guest_flight_coupling,
       case when a.checked_at is null then 'varsayim' else 'dogrulandi' end as kaynak
  from lounge_venue_acceptance a
  join lounge_venues v on v.id = a.venue_id
  join lounge_programs p on p.id = a.program_id
 order by v.airport_code, v.name, p.code;

select '096 OK - matris otomatik dolduruldu; varsayim satirlari ENGELLEMEZ ve kirmizi kalir' as sonuc;
