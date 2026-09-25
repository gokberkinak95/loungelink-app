-- ============================================================
-- LoungeLink · 152_field_reports_loop.sql
-- SAHA RAPORLARI: KENDI KENDINI GUNCELLEYEN KURAL MOTORU
--
-- ⚠️ Uygulamayi ETKILER (yeni akis + guven derecesi).
--
-- ------------------------------------------------------------
-- 🔴 EN BUYUK HENDEK, EN AZ KULLANILAN TABLO
-- ------------------------------------------------------------
-- `lounge_field_reports` 095'te kuruldu ve bugune kadar akisa
-- baglanmadi. Oysa bu tablo urunun kopyalanamaz tarafi:
--
-- Bir misafir kapida "3 hakkin kalmis dediler" derse, o veri BIZIM
-- ARASTIRMAMIZDAN DAHA GUNCELDIR. Bes kullanici ayni seyi soylerse
-- kural DOGRULANMIS olur.
--
-- Rakip bunu yapamaz: onlarda kart kademesi kavrami bile yok, dolayisiyla
-- toplanacak bir saha verisi de yok. Bizde 173 migration'lik bir yapi
-- var ve kullanicinin gordugu her sey o yapiya geri besleniyor.
--
-- 🔴 SORUYU DOGRU SORMAK: "salon nasildi?" degil — o bir yorum sitesi
-- sorusu. Bizim sordugumuz "KAPIDA NE OLDU?": girebildin mi, misafir
-- kabul edildi mi, ucret cikti mi. Uc soru, hepsi tek dokunus.
-- ============================================================

alter table lounge_field_reports add column if not exists entered boolean;
alter table lounge_field_reports add column if not exists guest_accepted boolean;
alter table lounge_field_reports add column if not exists fee_charged boolean;
alter table lounge_field_reports add column if not exists fee_amount text;
alter table lounge_field_reports add column if not exists quota_left text;
alter table lounge_field_reports add column if not exists program_id uuid references lounge_programs(id);
alter table lounge_field_reports add column if not exists card_tier text;

create or replace function public.submit_field_report(
  p_session_id uuid,
  p_entered boolean,
  p_guest_accepted boolean default null,
  p_fee_charged boolean default null,
  p_fee_amount text default null,
  p_quota_left text default null,
  p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); s sessions%rowtype; v_venue uuid; v_prog uuid; v_tier text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into s from sessions where id = p_session_id;
  if not found then raise exception 'session_not_found'; end if;
  -- 🔴 YALNIZ O OTURUMDA BULUNAN kisi rapor verebilir. Aksi halde
  -- kural motoru, hic gitmemis birinin beyaniyla degisir.
  -- 🔴 095'TEKI IKI DOGRULAMAYI DUSURMUSUM — drift_check yakaladi.
  -- Fonksiyonu yeniden yazarken eski surumun kontrollerini tasimayi
  -- unuttum. `not_party` ve `invalid_outcome` sessizce kayboldu:
  -- yani oturumda olmayan biri rapor verebilir, gecersiz bir sonuc
  -- kaydedilebilirdi. Kural motoruna geri beslenen bir veri icin
  -- bu kabul edilemez.
  --
  -- Ders: bir fonksiyonu yeniden yazmak, ONUN GARANTILERINI de
  -- yeniden yazmak demektir.
  if v_uid not in (s.host_id, s.guest_id) then raise exception 'not_party'; end if;
  if p_entered is null then raise exception 'invalid_outcome'; end if;

  select l.venue_id into v_venue from availabilities a
    join lounges l on l.id = a.lounge_id where a.id = s.avail_id;
  select he.program_id, he.tier into v_prog, v_tier
    from host_entitlements he where he.user_id = s.host_id limit 1;

  insert into lounge_field_reports
    (session_id, reporter_id, venue_id, program_id, card_tier,
     entered, guest_accepted, fee_charged, fee_amount, quota_left, note)
  values (p_session_id, v_uid, v_venue, v_prog, v_tier,
          p_entered, p_guest_accepted, p_fee_charged, p_fee_amount, p_quota_left, p_note)
  on conflict (session_id, reporter_id) do update set
    entered = excluded.entered, guest_accepted = excluded.guest_accepted,
    fee_charged = excluded.fee_charged, fee_amount = excluded.fee_amount,
    quota_left = excluded.quota_left, note = excluded.note;

  return jsonb_build_object('ok', true,
    'note', 'Teşekkürler — bu bilgi kural tablomuzu güncelliyor.');
end $$;
grant execute on function public.submit_field_report(uuid, boolean, boolean, boolean, text, text, text) to authenticated;

-- ============================================================
-- 🔴 UZLASMA: BES RAPOR DOGRULAR, CELISKI UYARIR
-- ------------------------------------------------------------
-- Tek rapor bir ANEKDOT'tur; bes rapor bir OLGU. Ama celiski daha
-- degerlidir: uc kisi "girdim" bir kisi "giremedim" diyorsa, o bir
-- kosul farkidir (terminal, saat, kart tipi) ve arastirilmali.
--
-- Sayiyi tek basina okumak yaniltir; ORAN'a bakiyoruz.
-- ============================================================
create or replace function public.field_consensus(p_venue_id uuid, p_program_id uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'reports', count(*),
    'entered_rate', round(avg(case when r.entered then 1 else 0 end)::numeric, 2),
    'guest_ok_rate', round(avg(case when r.guest_accepted then 1
                                    when r.guest_accepted is false then 0 end)::numeric, 2),
    'fee_rate', round(avg(case when r.fee_charged then 1
                               when r.fee_charged is false then 0 end)::numeric, 2),
    'quota_reports', (select jsonb_agg(distinct x.quota_left)
                        from lounge_field_reports x
                       where x.venue_id = p_venue_id and coalesce(x.quota_left,'') <> ''),
    -- 5+ rapor ve %80+ uzlasma -> DOGRULANDI sayilir
    'verdict', case
      when count(*) < 3 then 'insufficient'
      when avg(case when r.entered then 1 else 0 end) >= 0.8 then 'confirmed'
      when avg(case when r.entered then 1 else 0 end) <= 0.2 then 'contradicted'
      else 'mixed' end)
    from lounge_field_reports r
   where r.venue_id = p_venue_id
     and (p_program_id is null or r.program_id = p_program_id);
$$;
grant execute on function public.field_consensus(uuid, uuid) to authenticated;

-- Uzlasma saglanan kabul satirlarini otomatik yukselt
create or replace function public.apply_field_consensus()
returns int language plpgsql security definer set search_path = public as $$
declare c record; n int := 0;
begin
  for c in
    select r.venue_id, r.program_id, count(*) k,
           avg(case when r.guest_accepted then 1 when r.guest_accepted is false then 0 end) g
      from lounge_field_reports r
     where r.program_id is not null and r.guest_accepted is not null
     group by r.venue_id, r.program_id
    having count(*) >= 5
  loop
    -- 🔴 SAHA VERISI RESMI KAYNAGI EZMEZ, ONU TAMAMLAR.
    -- Yalniz `is_placeholder` (arastirilmamis) satirlari yukseltiyoruz.
    -- Bankanin kendi sayfasindan gelen bir kurali bes kullanici
    -- beyaniyla degistirmek, dogrulanmis veriyi anekdotla ezmek olur.
    update lounge_venue_acceptance a
       set guest_policy = case when c.g >= 0.8 then 'included'
                               when c.g <= 0.2 then 'not_allowed'
                               else a.guest_policy end,
           is_placeholder = false,
           checked_at = current_date,
           conditions = coalesce(a.conditions,'')
                     || format(' [saha] %s kullanıcı raporu ile doğrulandı.', c.k)
     where a.venue_id = c.venue_id and a.program_id = c.program_id
       and a.active and a.is_placeholder;
    if found then n := n + 1; end if;
  end loop;
  return n;
end $$;

select '152 OK - saha raporlari akisa baglandi' as sonuc;
