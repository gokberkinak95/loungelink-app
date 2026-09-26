-- ============================================================================
-- 302 · KEŞFET ENGELİNİN GERÇEK SEBEBİ                             (26 Eylül)
--
-- 🔴 NEDEN (Gökberk md.34 / 34.1 · cihazda görüldü): THY hostunun ilanına
-- AJet biletli yolcu bakınca liste "Başvuru kapalı · Neden?" diyordu ama
-- sebep kutusu "Host bu salona girebiliyor ama yanında misafir götürme
-- hakkı yok" yazıyordu — aynı kartta "Misafir ücretsiz" rozeti dururken.
-- Kök: `discovery_rule_badges` her engeli (taşıyıcı uyuşmazlığı, charter,
-- kesin kural) tek anahtara, `guest_none`a eşliyordu.
--
-- Kural (kural_tabloları.xlsx · THY md.17 + AJet simetriği): THY seferindeki
-- yolcu yalnız THY seferindeki yolcuyu misafir alabilir; AJet için aynısı.
-- Yani "farklı havayolu" bir MİSAFİR HAKKI eksikliği değil, bir EŞLEŞME
-- şartıdır — kullanıcıya ayrı cümleyle söylenmeli.
--
-- Değişiklik: engel sebebi üçe ayrıldı — `carrier_bad` · `charter_block` ·
-- `guest_none`. Kapı (blocks_request) aynen; yalnız etiket ve açıklama.
-- İmza değişmiyor.
-- ============================================================================
update public.beta_settings
   set value = value
     || jsonb_build_object('carrier_bad', jsonb_build_object(
          'label', 'Farklı havayolu',
          'info',  'Bu salon misafirin host ile aynı havayoluyla uçmasını şart koşuyor: THY seferindeki host yalnız THY yolcusunu, AJet seferindeki host yalnız AJet yolcusunu misafir alabilir. Senin uçuşun farklı taşıyıcıda — host''un misafir hakkı olsa da bu ilana başvuramazsın.'))
     || jsonb_build_object('charter_block', jsonb_build_object(
          'label', 'Charter uçuş',
          'info',  'Charter seferle uçan yolcular havayolu salonlarına misafir olarak da kabul edilmiyor. Priority Pass / LoungeKey / DragonPass ilanlarında bu engel yok.'))
 where key = 'badge_labels';

CREATE OR REPLACE FUNCTION public.discovery_rule_badges(p_ids uuid[])
 RETURNS TABLE(avail_id uuid, severity text, label text, info text, detail text, same_flight_match boolean, blocks_request boolean, sort_boost integer, can_ask_host boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record; d jsonb; b jsonb; v_flight text; v_key text;
  v_boost int; v_same boolean; v_block boolean; v_prog lounge_programs%rowtype;
begin
  foreach avail_id in array coalesce(p_ids, '{}'::uuid[]) loop
    select * into r from availabilities where id = avail_id;
    continue when not found;

    select v.flight_number into v_flight from visits v
     where v.user_id = auth.uid() and v.airport_code = r.airport_code
       and v.visit_date = r.avail_date and coalesce(v.flight_number,'') <> ''
     order by v.created_at desc limit 1;

    d := public.lounge_access_decision_v5(avail_id, v_flight, public.guest_carrier_for(avail_id));
    select * into v_prog from lounge_programs where id = nullif(d ->> 'program_id','')::uuid;

    v_same := coalesce(v_flight,'') <> '' and coalesce(r.flight_number,'') <> ''
              and upper(replace(v_flight,' ','')) = upper(replace(r.flight_number,' ',''));

    v_block := coalesce((d ->> 'severity') = 'block' and (d ->> 'enforcement') = 'block', false)
               or coalesce((d ->> 'carrier_ok') = 'false', false)
               or coalesce((d ->> 'charter') = 'true', false);
    if v_prog.id is null or v_prog.entitlement_model = 'bank_card' then
      v_block := false;
    end if;

    v_boost := 0;
    -- 302: engelin SEBEBİ ayrı anahtar — farklı havayolu "misafir hakkı yok" değildir.
    if v_block and coalesce((d ->> 'carrier_ok') = 'false', false) then
                                                     v_key := 'carrier_bad';   v_boost := -1000;
    elsif v_block and coalesce((d ->> 'charter') = 'true', false) then
                                                     v_key := 'charter_block'; v_boost := -1000;
    elsif v_block then                               v_key := 'guest_none';  v_boost := -1000;
    elsif v_same then                                v_key := 'same_flight'; v_boost := 100;
    elsif (d ->> 'fits') = 'false' then              v_key := 'flight_bad';  v_boost := -100;
    elsif (d ->> 'guest_policy') = 'not_allowed' then
      v_key := 'guest_none_soft'; v_boost := -200;
    elsif (d ->> 'guest_policy') = 'paid' then       v_key := 'guest_paid';  v_boost := -20;
    elsif (d ->> 'confidence') in ('unknown','assumed') then v_key := 'unverified'; v_boost := -10;
    elsif (d ->> 'guest_policy') = 'included' then   v_key := 'guest_free';  v_boost := 20;
    else v_key := null;
    end if;

    -- 219 kapı hizası korunuyor
    if (d ->> 'guest_policy') = 'not_allowed' then
      v_block := true;
    end if;

    b := case when v_key is null then null else public.badge_text(v_key) end;

    severity := coalesce(d ->> 'severity','info');
    label    := b ->> 'label';
    info     := b ->> 'info';
    detail   := d ->> 'headline';
    same_flight_match := v_same;
    blocks_request := v_block;
    sort_boost := v_boost;
    can_ask_host := public.kural_sorusu_uygun_mu(avail_id);
    return next;
  end loop;
end $function$;
