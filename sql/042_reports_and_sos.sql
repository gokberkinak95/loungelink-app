-- ============================================================
-- 042 — BİLDİRME ve SOS: ekranı gerçekten arkaya bağla
--
-- 040a→040→041'den SONRA çalıştır. PRE_drop gerekmiyor (hepsi yeni).
--
-- BULGULAR (v1.22 BE bağlantı denetimi):
--
-- 1) 🔴 `create_report` DİYE BİR ŞEY YOK.
--    `reports` tablosu 001'den beri var, `resolve_report` (BO tarafı)
--    029'da var — ama kullanıcının rapor OLUŞTURACAĞI fonksiyon hiç
--    yazılmamış. Yani Güvenlik Merkezi'ndeki "🚩 Bildir" satırının
--    onPress'i bile yoktu; olsaydı da çağıracak bir şey yoktu.
--    BO'daki moderasyon kuyruğu bu yüzden hep boş kalıyordu:
--    doldurmanın bir yolu yoktu.
--
-- 2) 🔴 SOS KARŞILIKSIZ BİR VAAT.
--    Ekran "acil durum kişine konumunu ve oturum bilgini gönderiyoruz"
--    diyor. Şemada acil durum kişisi diye bir alan YOK. Gönderecek
--    kimse yok. Bu, Gokberk'in reddettiği sahte uçuş verisiyle AYNI
--    kategoride: kullanıcının güvendiği ama var olmayan bir özellik.
--    Güvenlik özelliğinde bu daha ağır — insan ona güvenip riskli
--    bir duruma girebilir.
--
--    DÜRÜST TASARIM (beta için):
--      · SOS ACİL bir rapor satırı açar -> BO'da anında görünür
--      · Tüm adminlere bildirim gider
--      · Ekran 112'yi arama butonu gösterir (gerçek acil yardım)
--      · "Acil kişine haber verdik" DEMEZ — öyle bir kişi yok
--    Acil durum kişisi ileride eklenebilir; o zamana kadar vaat
--    edilmez. Emniyet vaadi, tutulabilenden fazlası olmamalı.
--
-- 3) report_type enum'u SABİT: ('harassment','fraud','fake_profile',
--    'off_platform_payment','other'). SOS için yeni değer EKLEMİYORUZ
--    (enum cerrahisi Supabase editöründe riskli) — 'other' + description
--    başına '[SOS]' etiketi + reports.is_urgent kolonu kullanıyoruz.
-- ============================================================

-- ---- Aciliyet işareti ----
alter table reports add column if not exists is_urgent boolean not null default false;

create index if not exists idx_reports_urgent on reports(is_urgent, status)
  where is_urgent = true and status = 'open';

comment on column reports.is_urgent is
  'SOS ile açılan raporlar. BO moderasyon kuyruğunda en üstte gösterilir (042).';


-- ============================================================
-- create_report — kullanıcı bir kişiyi bildirir
--
-- Kurallar:
--   · Kendini bildiremezsin
--   · Aynı kişiyi 24 saat içinde tekrar bildiremezsin (spam koruması);
--     zaten açık raporun varsa açıklaman ona EKLENİR
--   · session_id verilmişse gerçekten o oturumun tarafı olmalısın
-- ============================================================
create or replace function public.create_report(
  p_target uuid, p_type text, p_description text, p_session uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_id uuid; v_existing uuid; v_ok boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_target = v_uid then raise exception 'cannot_report_self'; end if;
  if not exists (select 1 from users where id = p_target) then
    raise exception 'target_not_found';
  end if;
  if coalesce(trim(p_description),'') = '' then raise exception 'description_required'; end if;

  -- oturum verildiyse: gerçekten tarafı mısın?
  if p_session is not null then
    select exists (
      select 1 from sessions s join requests r on r.id = s.request_id
       where s.id = p_session and (r.guest_id = v_uid or r.host_id = v_uid)
    ) into v_ok;
    if not v_ok then raise exception 'not_your_session'; end if;
  end if;

  -- 24 saat içinde aynı kişi için açık raporun var mı?
  select id into v_existing from reports
   where reporter_id = v_uid and target_id = p_target
     and status in ('open','reviewing')
     and created_at > now() - interval '24 hours'
   limit 1;

  if v_existing is not null then
    update reports
       set description = description || E'\n---\n' || trim(p_description),
           updated_at = now()
     where id = v_existing;
    return jsonb_build_object('ok', true, 'id', v_existing, 'merged', true);
  end if;

  insert into reports (reporter_id, target_id, session_id, type, description, status)
  values (v_uid, p_target, p_session, p_type::report_type, trim(p_description), 'open')
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id, 'merged', false);
end $$;


-- ============================================================
-- sos_alert — acil yardım çağrısı
--
-- NE YAPAR (ve yalnızca bunu):
--   · is_urgent=true bir rapor açar -> BO'da en üstte görünür
--   · Aktif oturumu varsa karşı tarafı hedef alır (kim olduğunu biliriz)
--   · Tüm adminlere bildirim gönderir
-- NE YAPMAZ:
--   · Acil durum kişisine haber vermez — öyle bir alan yok
--   · Konum göndermez — konum yalnızca radar için, opt-in ve karşılıklı
-- Uygulama ayrıca 112 arama butonu gösterir. Gerçek acil durumda
-- doğru cevap 112'dir; biz onun yerini almayız.
-- ============================================================
create or replace function public.sos_alert(p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_sess uuid; v_other uuid; v_id uuid; v_name text;
  v_desc text; a record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  -- aktif oturum ve karşı taraf
  select s.id,
         case when r.guest_id = v_uid then r.host_id else r.guest_id end
    into v_sess, v_other
    from sessions s join requests r on r.id = s.request_id
   where s.status = 'active' and (r.guest_id = v_uid or r.host_id = v_uid)
   order by s.started_at desc limit 1;

  select name into v_name from profiles where user_id = v_uid;

  v_desc := '[SOS] ' || coalesce(v_name, 'Kullanıcı') || ' acil yardım çağrısı gönderdi.'
         || case when v_sess is not null then ' Aktif oturum var.' else ' Aktif oturum yok.' end
         || case when coalesce(trim(p_note),'') <> '' then E'\nNot: ' || trim(p_note) else '' end;

  -- Hedef: aktif oturumdaki karşı taraf; yoksa kendisi (yalnız kayıt için —
  -- moderatör kimin çağırdığını reporter_id'den görür)
  insert into reports (reporter_id, target_id, session_id, type, description, status, is_urgent)
  values (v_uid, coalesce(v_other, v_uid), v_sess, 'other', v_desc, 'open', true)
  returning id into v_id;

  -- tüm adminlere bildirim
  for a in select user_id from admin_roles loop
    begin
      insert into notifications (user_id, category, icon, title, body)
      values (a.user_id, 'safety', '🆘', 'SOS çağrısı',
              coalesce(v_name,'Bir kullanıcı') || ' acil yardım istedi. Moderasyon kuyruğuna bak.');
    exception when others then null;   -- bildirim patlarsa SOS kaydı yine dursun
    end;
  end loop;

  return jsonb_build_object('ok', true, 'id', v_id, 'has_session', v_sess is not null);
end $$;


-- ============================================================
-- my_reports — kullanıcı kendi bildirimlerinin durumunu görsün
-- (BO bir raporu çözünce kullanıcı ne olduğunu bilmeli)
-- ============================================================
create or replace function public.my_reports()
returns table (id uuid, type text, description text, status text,
               resolution text, is_urgent boolean, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.type::text, r.description, r.status::text,
         r.resolution, r.is_urgent, r.created_at
  from reports r
  where r.reporter_id = auth.uid()
  order by r.created_at desc
  limit 50;
$$;


grant execute on function public.create_report(uuid,text,text,uuid) to authenticated;
grant execute on function public.sos_alert(text) to authenticated;
grant execute on function public.my_reports() to authenticated;


-- ============================================================
-- DOĞRULAMA
-- ============================================================
select 'create_report var mi' as kontrol,
  case when exists (select 1 from pg_proc where proname='create_report') then '✓ OK' else '🔴 YOK' end as sonuc
union all
select 'sos_alert var mi',
  case when exists (select 1 from pg_proc where proname='sos_alert') then '✓ OK' else '🔴 YOK' end
union all
select 'reports.is_urgent kolonu',
  case when exists (select 1 from information_schema.columns
    where table_name='reports' and column_name='is_urgent') then '✓ OK' else '🔴 YOK' end
union all
select 'acik SOS raporu sayisi', count(*)::text from reports where is_urgent and status='open';
