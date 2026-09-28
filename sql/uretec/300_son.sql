-- ════════════════════════════════════════════════════════════════════════
-- §Z — KENDİNİ ÖLÇ. Açık kalan kapı varsa DUR.
-- ════════════════════════════════════════════════════════════════════════
do $z300$
declare v_n int; v_liste text;
begin
  -- A1: kilitli olanlar authenticated/anon tarafından çağrılamaz
  select count(*), string_agg(p.proname, ', ') into v_n, v_liste
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('change_plan','kredi_akis_raporu','anonymized_users',
                       'host_kota_durumu','doluluk_reddi_sayisi','oturum_kural_hedefi',
                       'kural_guncelligi','access_options_for_user','bo_slot_asimlari')
     and (has_function_privilege('authenticated', p.oid, 'execute')
          or has_function_privilege('anon', p.oid, 'execute'));
  if v_n > 0 then raise exception '300 §Z/A1: hâlâ açık: %', v_liste; end if;

  -- A2: PUBLIC'e açık SECURITY DEFINER fonksiyon kalmadı
  select count(distinct p.oid), string_agg(distinct p.proname, ', ') into v_n, v_liste
    from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace and p.prosecdef
     and a.grantee = 0 and a.privilege_type = 'EXECUTE';
  if v_n > 0 then raise exception '300 §Z/A2: PUBLIC''e açık % fonksiyon: %', v_n, v_liste; end if;

  -- A2: küresel varsayılan gerçekten yazıldı mı?
  if not exists (select 1 from pg_default_acl d
                  where d.defaclnamespace = 0 and d.defaclobjtype = 'f'
                    and d.defaclrole = 'postgres'::regrole) then
    raise exception '300 §Z/A2: küresel varsayılan yetki kaydı yok';
  end if;

  -- Uygulamanın çağırdığı beş fonksiyon authenticated'da KALDI mı?
  select count(*), string_agg(p.proname, ', ') into v_n, v_liste
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('cancel_availability','binis_karti_kaydet','ilani_yeniden_yayinla',
                       'hikaye_davetini_ertele','kesifte_gorun','profil_karti',
                       'create_request','respond_request','confirm_session')
     and not has_function_privilege('authenticated', p.oid, 'execute');
  if v_n > 0 then raise exception '300 §Z: uygulama fonksiyonu KAPANDI: %', v_liste; end if;

  -- A3 / B6 tetikleyicileri yerinde mi?
  if not exists (select 1 from pg_trigger where tgname = 'trg_visit_0_beyan_temizle') then
    raise exception '300 §Z/A3: tetikleyici yok';
  end if;
  if position('pg_advisory_xact_lock' in
       (select prosrc from pg_proc where proname = 'trg_bakiye_negatife_dusemez')) = 0 then
    raise exception '300 §Z/B6: kredi kilidi tetikleyicide yok';
  end if;
  if position('availability_expired' in
       (select prosrc from pg_proc where proname = 'respond_request')) = 0 then
    raise exception '300 §Z/B1: kabul kapısı yok';
  end if;
  if position('already_requested' in
       (select prosrc from pg_proc where proname = 'create_request_impl')) = 0 then
    raise exception '300 §Z/B5: mükerrer başvuru kapısı yok';
  end if;

  raise notice '300 §Z: bütün kapılar ölçüldü — kapalı';
end $z300$;

select '300 OK — uçtan uca denetim bulguları kapatıldı' as sonuc;
