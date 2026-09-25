-- ============================================================
-- LoungeLink · 066_request_status_completed.sql
--
-- 🔴 GERCEK VERITABANINDA CALISTIRARAK bulundu.
--
-- confirm_session, iki taraf da onayladiginda sunu yapiyor:
--     update requests set status = 'completed' where id = v_s.request_id;
-- Ama request_status enum'unda 'completed' YOK:
--     pending, accepted, declined, cancelled, expired
--
-- SONUC: OTURUM HIC TAMAMLANAMIYOR. Iki taraf da "Tamamla" dese bile son
-- adimda "invalid input value for enum request_status" hatasi aliniyor;
-- escrow cozulmuyor, puanlama ekrani hic acilmiyor.
--
-- COZUM: enum'a 'completed' eklenir (ekleme islemi, hicbir sey bozmaz).
-- Kodun niyeti korunur: oturumu tamamlanan istek de "completed" olur.
--
-- NOT: ALTER TYPE ... ADD VALUE ayri bir ifade olarak calismalidir;
-- ayni islem blogunda hemen kullanilamaz. Bu dosya tek basina calistirilir.
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
     where t.typname = 'request_status' and e.enumlabel = 'completed'
  ) then
    alter type request_status add value 'completed';
  end if;
end $$;

-- DOGRULAMA: enum degerleri
select string_agg(e.enumlabel, ', ' order by e.enumsortorder) as "request_status degerleri"
from pg_enum e join pg_type t on t.oid = e.enumtypid
where t.typname = 'request_status';

select '066 OK - request_status enumuna completed eklendi, oturum tamamlanabilir' as sonuc;
