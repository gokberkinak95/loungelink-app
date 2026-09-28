-- ============================================================================
-- 305 · ERİŞİM KAYNAĞI: HAM KOD DEĞİL, ETİKET                     (26 Eylül)
--
-- 🔴 NEDEN (Gökberk md.10 · 10.1 · 10.2 — cihazda görüldü):
-- Profili Düzenle > Erişim Kaynağı "airline_status" yazıyordu; kullanıcı
-- "Banka / Özel Bankacılık" seçip kaydedince satır
-- "airline_status, Banka / Özel Bankacılık" oldu — kod silinemiyordu.
--
-- Kök (ölçüldü): SEED8_AKIS_TEZGAHI.sql §237 ve SEED6 test hesaplarına
-- `access_source`u SUNUCU KODUYLA yazdı ('airline_status', 'priority_pass').
-- Uygulama bu alanı ETİKET listesi olarak okuyor (ortak.js ACCESS_SOURCES):
-- tanımadığı kodu hiçbir çipe eşleyemiyor, kullanıcı onu kaldıramıyor ve
-- `save_host_access` her kayıtta aynen geri yazıyordu.
--
-- Bu dosya:
--   1) `erisim_kaynagi_etiketle(text)` — virgüllü listeyi etiketlere çevirir
--      (bilinmeyen değer düşürülmez, olduğu gibi kalır; tekrarlar ayıklanır)
--   2) profiles ve host_applications'taki mevcut kayıtları bir kez düzeltir
-- App 6.1 aynı eşlemeyi istemcide de yapıyor (eski kayıt gelse bile çip seçili
-- görünür ve kaldırılabilir). İkisi birlikte: veri temiz, ekran dayanıklı.
-- Tekrar koşulabilir. Supabase SQL Editor uyumlu (temp tablo / meta-komut yok).
-- ============================================================================
create or replace function public.erisim_kaynagi_etiketle(p text)
returns text
language sql
immutable
set search_path = public
as $$
  select nullif(string_agg(e, ', ' order by ilk), '')
    from (
      select e, min(sira) as ilk
        from (
          select case lower(btrim(x))
                   when 'priority_pass'    then 'Priority Pass'
                   when 'lounge_key'       then 'LoungeKey'
                   when 'loungekey'        then 'LoungeKey'
                   when 'dragon_pass'      then 'DragonPass'
                   when 'dragonpass'       then 'DragonPass'
                   when 'credit_card'      then 'Kredi Kartı Avantajı'
                   when 'bank_card'        then 'Kredi Kartı Avantajı'
                   when 'card_membership'  then 'Kredi Kartı Avantajı'
                   when 'kredi kartı'      then 'Kredi Kartı Avantajı'
                   when 'credit card'      then 'Kredi Kartı Avantajı'
                   when 'airline_status'   then 'Havayolu Statüsü'
                   when 'alliance_status'  then 'Havayolu Statüsü'
                   when 'airline status'   then 'Havayolu Statüsü'
                   when 'business_class'   then 'Business Class'
                   when 'ticket_class'     then 'Business Class'
                   when 'private_bank'     then 'Banka / Özel Bankacılık'
                   when 'private_banking'  then 'Banka / Özel Bankacılık'
                   when 'corporate'        then 'Kurumsal Seyahat'
                   else btrim(x)
                 end as e,
                 sira
            from unnest(string_to_array(coalesce(p, ''), ',')) with ordinality as u(x, sira)
           where btrim(x) <> ''
        ) m
       group by e
    ) t;
$$;

revoke all on function public.erisim_kaynagi_etiketle(text) from public;
grant execute on function public.erisim_kaynagi_etiketle(text) to authenticated;

update public.profiles
   set access_source = public.erisim_kaynagi_etiketle(access_source)
 where access_source is not null
   and access_source is distinct from public.erisim_kaynagi_etiketle(access_source);

update public.host_applications
   set access_source = public.erisim_kaynagi_etiketle(access_source)
 where access_source is not null
   and access_source is distinct from public.erisim_kaynagi_etiketle(access_source);

-- §Z · kendini ölçer: alt çizgili kaynak kaldıysa dur.
do $$
declare n int;
begin
  select count(*) into n from public.profiles where access_source ~ '_';
  if n > 0 then
    raise exception '305: % profilde hâlâ alt çizgili erişim kaynağı var', n;
  end if;
end $$;
