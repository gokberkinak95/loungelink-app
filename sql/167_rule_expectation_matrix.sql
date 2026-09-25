-- ============================================================
-- LoungeLink · 167_rule_expectation_matrix.sql
-- YÜZLERCE VAKALIK KURAL DOĞRULUK MATRİSİ
--
-- ⚠️ Uygulamayı ETKİLEMEZ (yalnız test tablosu + koşucu ekler).
--
-- ------------------------------------------------------------
-- 🔴 GÖKBERK HAKLI: 17 SENARYO BU KURAL YÜZEYİ İÇİN AZ
-- ------------------------------------------------------------
-- Bugüne kadar iki farklı şey vardı ve ben ikisini aynı cümlede
-- kullanıp yanıltıcı bir güven verdim:
--   · rule_coverage_audit: 607 kombinasyonu tarar ama yalnız
--     "BİR kural bulundu mu?" diye sorar — DOĞRU MU diye sormaz
--   · decision_chain_check + mixed_case_check: 17 vakada doğruluğu
--     sınar ama 17 vaka, 20 program × 9 tier × 3 kapsam × 5
--     taşıyıcı sınıfı yüzeyinin yanında hiçbir şey
--
-- Bu dosya aradaki boşluğu kapatır: BEKLENTİLER VERİ OLARAK
-- yazılır (rule_test_cases tablosu), üretici bunları eksenlerin
-- ÇARPIMINA açar, koşucu her birini motora sorar ve uyuşmazlıkları
-- listeler. Vaka eklemek artık kod yazmak değil SATIR EKLEMEK.
--
-- ------------------------------------------------------------
-- DÜRÜSTLÜK NOTU — bu testin NE KANITLAMADIĞI
-- ------------------------------------------------------------
-- Beklentiler resmî tablolardan (THY Tablo-2/4/5, AJet kart
-- matrisi, PP/DP plan sayfaları) benim tarafımdan kodlandı. Yani
-- test, VERİ GİRİŞ hatasını sınırlı yakalar: kuralı da beklentiyi
-- de aynı kaynaktan yazdım. GERÇEKTEN yakaladığı şey MOTOR
-- hatalarıdır — ve bu oturumda bulunan hataların hepsi o sınıftandı:
-- taşıyıcı null'ken kuralın elenmesi, tier körlüğü, kabul ekseninin
-- kuralı ezmesi, süresi dolan satırın boşluk bırakması, SA
-- çevirisinin olmaması. Bunların hiçbiri veri hatası değildi.
--
-- İKİ SEVİYE BEKLENTİ:
--   'exact'   → misafir sayısı ve aile hakkı TAM eşleşmeli
--               (resmî tablodan kesin bildiğimiz satırlar)
--   'defined' → en azından bir kural ÇÖZÜLMELİ, program
--               varsayılanına düşmemeli (kesin sayıyı iddia
--               etmediğimiz satırlar — uydurmuyoruz)
-- ============================================================

create table if not exists rule_test_cases (
  id            bigserial primary key,
  program_code  text not null,
  card_tier     text,                    -- null = tier belirtilmemiş
  venue_scope   text not null,           -- domestic | international | abroad
  carrier_class text not null,           -- TK | VF | SA | OTHER | UNKNOWN
  level         text not null default 'defined',   -- exact | defined
  exp_guests    int,                     -- level='exact' ise zorunlu
  exp_family    boolean,
  exp_paid      boolean,                 -- kapıda ücretli giriş açık mı
  kaynak        text,                    -- hangi resmî tablodan
  created_at    timestamptz default now()
);
create unique index if not exists uq_rule_test_case
  on rule_test_cases (program_code, coalesce(card_tier,'-'), venue_scope, carrier_class);

-- ---- BEKLENTİ ÜRETİCİSİ ----
-- 🔴 178'DE TEK KAYNAĞA TAŞINDI. Buradaki üreteç, beklentileri resmî
-- tablodan ÖNCE yazılmış hâliyle dolduruyordu; düzeltmeler ise 177'de
-- ayrı bir dosyadaydı. Sıra bozulduğunda (167 tekrar koşarsa)
-- düzeltmeler siliniyor ve matris yeniden kırmızı yanıyordu — canlıda
-- tam bu oldu. Üretim artık `rebuild_rule_test_cases()` içinde ve
-- beklentiler zaten DOĞRU üretiliyor; bu blok yalnız tabloyu var
-- ediyor ki 178 öncesi kurulumlar bozulmasın.
do $$
begin
  if to_regclass('public.rule_test_cases') is null then
    raise notice '167: vaka tablosu yok — 178 üretecinden doldurulacak';
  end if;
end $$;

-- ---- KOŞUCU ----
-- Her vakayı motora sorar. Kapsam ve taşıyıcı GERÇEK bir venue
-- üzerinden verilir (motor kapsamı venue'dan türetiyor), böylece
-- test motorun kendi yolunu kullanır — kısa devre yok.
drop function if exists public.rule_matrix_test(boolean);
create or replace function public.rule_matrix_test(p_only_fail boolean default true)
returns table (vaka text, seviye text, beklenen text, gercek text, sonuc text)
language plpgsql stable security definer set search_path = public as $$
declare r record; v_pid uuid; v_venue uuid; v_carr text; j jsonb;
        v_g int; v_f boolean; v_p boolean; v_found boolean;
begin
  for r in select * from rule_test_cases order by program_code, card_tier nulls first, venue_scope, carrier_class loop
    select id into v_pid from lounge_programs where code = r.program_code and active;
    continue when v_pid is null;

    -- Kapsama uyan GERÇEK bir salon seç (abroad = yurt dışı ülke)
    select v.id into v_venue
      from lounge_venues v join airports a on a.code = v.airport_code
     where v.active
       and case r.venue_scope
             when 'abroad' then coalesce(a.country,'TR') not in ('TR','Türkiye','Turkiye','Turkey')
             else v.scope = r.venue_scope
                  and coalesce(a.country,'TR') in ('TR','Türkiye','Turkiye','Turkey')
           end
     limit 1;
    continue when v_venue is null;

    v_carr := case r.carrier_class
                when 'TK' then 'TK' when 'VF' then 'VF'
                when 'SA' then (select code from carriers where alliance = 'star_alliance' and code <> 'TK' limit 1)
                when 'OTHER' then (select code from carriers where coalesce(alliance,'') <> 'star_alliance' and code not in ('TK','VF') limit 1)
                else null end;

    j := public.resolve_guest_rule(v_pid, v_venue, r.card_tier, v_carr, null);
    v_found := coalesce((j ->> 'found')::boolean, false);
    v_g := coalesce((j ->> 'guest_allowance')::int, -1);
    v_f := coalesce((j ->> 'family_allowed')::boolean, false);
    v_p := coalesce((j ->> 'paid_entry_allowed')::boolean, false);

    vaka := r.program_code || ' · ' || coalesce(r.card_tier,'(tier yok)')
            || ' · ' || r.venue_scope || ' · ' || r.carrier_class;
    seviye := r.level;

    if r.level = 'exact' then
      beklenen := 'misafir=' || r.exp_guests
                  || case when r.exp_family is not null then ' aile=' || r.exp_family else '' end
                  || case when r.exp_paid then ' ücretli=✓' else '' end;
      gercek := 'misafir=' || v_g || ' aile=' || v_f || case when v_p then ' ücretli=✓' else '' end;
      sonuc := case
        when not v_found then '✗ KURAL ÇÖZÜLMEDİ'
        when v_g <> r.exp_guests then '✗ MİSAFİR SAYISI'
        when r.exp_family is not null and v_f <> r.exp_family then '✗ AİLE HAKKI'
        when coalesce(r.exp_paid,false) and not v_p then '✗ ÜCRETLİ GİRİŞ KAPALI'
        else '✓' end;
    else
      beklenen := 'bir kural çözülmeli';
      gercek := case when v_found then 'çözüldü (misafir=' || v_g || ')' else 'program varsayılanına düştü' end;
      sonuc := case when v_found then '✓' else '✗ ÇÖZÜLMEDİ' end;
    end if;

    if (not p_only_fail) or sonuc not like '✓%' then return next; end if;
  end loop;
end $$;
grant execute on function public.rule_matrix_test(boolean) to authenticated;

-- ---- ÖZET (SEED ve BO bunu okur) ----
drop function if exists public.rule_matrix_summary();
create or replace function public.rule_matrix_summary()
returns table (toplam int, gecen int, kalan int, exact_vaka int, defined_vaka int)
language sql stable security definer set search_path = public as $$
  select (select count(*)::int from rule_test_cases),
         (select count(*)::int from rule_test_cases)
           - (select count(*)::int from public.rule_matrix_test(true)),
         (select count(*)::int from public.rule_matrix_test(true)),
         (select count(*)::int from rule_test_cases where level = 'exact'),
         (select count(*)::int from rule_test_cases where level = 'defined');
$$;
grant execute on function public.rule_matrix_summary() to authenticated;

select '167 OK - beklenti matrisi kuruldu' as sonuc;
