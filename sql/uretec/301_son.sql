-- ════════════════════════════════════════════════════════════════════════
-- §Z — KENDİNİ ÖLÇ
-- ════════════════════════════════════════════════════════════════════════
do $z301$
declare v_n int; v_l text;
begin
  select count(*), string_agg(p.proname, ', ') into v_n, v_l
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('engelle','engeli_kaldir','engellediklerim','gelmedi_bildir','gelmedi_esigi')
     and not has_function_privilege('authenticated', p.oid, 'execute');
  if v_n > 0 then raise exception '301 §Z: authenticated çağıramıyor: %', v_l; end if;
  select count(*) into v_n from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace and p.prosecdef and a.grantee = 0 and a.privilege_type = 'EXECUTE';
  if v_n > 0 then raise exception '301 §Z: PUBLIC''e açık % fonksiyon (300 §A2 geriledi)', v_n; end if;
  if position('test_hesabi_gizli_mi' in (select prosrc from pg_proc where proname = 'is_visible')) = 0 then
    raise exception '301 §Z: is_visible yamasız';
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'trg_mesaj_engel') then
    raise exception '301 §Z: mesaj engel tetikleyicisi yok';
  end if;
  raise notice '301 §Z: kapılar ölçüldü';
end $z301$;

select '301 OK — engelleme · gelmedi · test hesabı gizleme · rehber sayacı' as sonuc;
