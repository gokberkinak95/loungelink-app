-- ============================================================
-- LoungeLink · 027_companion_chat.sql — CompanionChat (§17)
-- Bağlantı kabul edilince sohbet açılır. chat_channels'a connection desteği.
-- ============================================================

alter table chat_channels add column if not exists connection_id uuid references connection_requests(id) on delete cascade;
alter table chat_channels add column if not exists kind text default 'lounge';  -- lounge | companion
create unique index if not exists chat_channels_conn_uniq on chat_channels (connection_id) where connection_id is not null;

-- Bağlantı kabul → kanal aç (respond_connection'ı güncelle)
create or replace function public.respond_connection(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_cr connection_requests%rowtype; v_chan uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_cr from connection_requests where id = p_id for update;
  if not found then raise exception 'connection_not_found'; end if;
  if v_cr.to_id <> v_uid then raise exception 'not_recipient'; end if;
  if v_cr.status <> 'pending' then raise exception 'already_responded'; end if;

  update connection_requests set status = case when p_accept then 'accepted' else 'declined' end,
         responded_at = now() where id = p_id;

  if p_accept then
    -- §17: bağlantı kurulunca CompanionChat açılır
    insert into chat_channels (connection_id, kind, created_at)
    values (p_id, 'companion', now())
    on conflict (connection_id) do nothing
    returning id into v_chan;
    if v_chan is null then select id into v_chan from chat_channels where connection_id = p_id; end if;

    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_cr.from_id, 'connections', 'Bağlantı kabul edildi ✓',
            'Sohbet açıldı.', 'connection', p_id);
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_uid, 'connections', 'Bağlantı kuruldu ✓', 'Sohbet açıldı.', 'connection', p_id);
  else
    insert into notifications (user_id, category, title, body, ref_type, ref_id)
    values (v_cr.from_id, 'connections', 'Bağlantı isteği yanıtlandı', 'İstek reddedildi.', 'connection', p_id);
  end if;

  return jsonb_build_object('ok', true, 'accepted', p_accept, 'channel_id', v_chan);
end $$;
grant execute on function public.respond_connection(uuid, boolean) to authenticated;

-- Companion kanal RLS: yalnız iki taraf
drop policy if exists "chat_companion_read" on chat_channels;
create policy "chat_companion_read" on chat_channels for select to authenticated
using (
  connection_id is null or exists (
    select 1 from connection_requests cr where cr.id = chat_channels.connection_id
      and (cr.from_id = auth.uid() or cr.to_id = auth.uid()) and cr.status = 'accepted'
  )
);

-- Mesaj RLS companion kanalları için
drop policy if exists "messages_companion_rw" on messages;
create policy "messages_companion_rw" on messages for all to authenticated
using (
  exists (
    select 1 from chat_channels c
    left join connection_requests cr on cr.id = c.connection_id
    left join requests r on r.id = c.request_id
    where c.id = messages.channel_id and (
      (cr.id is not null and (cr.from_id = auth.uid() or cr.to_id = auth.uid()) and cr.status='accepted')
      or (r.id is not null and (r.guest_id = auth.uid() or r.host_id = auth.uid()))
    )
  )
)
with check (
  from_id = auth.uid() and exists (
    select 1 from chat_channels c
    left join connection_requests cr on cr.id = c.connection_id
    left join requests r on r.id = c.request_id
    where c.id = messages.channel_id and (
      (cr.id is not null and (cr.from_id = auth.uid() or cr.to_id = auth.uid()) and cr.status='accepted')
      or (r.id is not null and (r.guest_id = auth.uid() or r.host_id = auth.uid()))
    )
  )
);

-- Bağlantı listesi + kanal id (Meet ekranı için)
create or replace function public.my_connections()
returns table (conn_id uuid, other_id uuid, other_name text, other_photo text,
               status text, channel_id uuid, intent text)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  return query
  select cr.id,
         case when cr.from_id = v_uid then cr.to_id else cr.from_id end,
         p.name,
         case when p.photo_url is not null and (
                coalesce(p.photo_connections_only,false)=false or cr.status='accepted'
              ) then p.photo_url else null end,
         cr.status::text, c.id, cr.intent
    from connection_requests cr
    join profiles p on p.user_id = (case when cr.from_id = v_uid then cr.to_id else cr.from_id end)
    left join chat_channels c on c.connection_id = cr.id
   where cr.from_id = v_uid or cr.to_id = v_uid
   order by cr.created_at desc;
end $$;
grant execute on function public.my_connections() to authenticated;

select 'COMPANION CHAT OK' as sonuc;
