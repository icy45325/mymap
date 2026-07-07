-- Lumi 邮局 v1.1 —— Supabase 一次性初始化脚本
-- 用法：Supabase 控制台 → SQL Editor → 整段粘贴执行。
-- 设计说明见 docs/design/DESIGN-v1.1-lumi-post.md（零 Auth 能力密钥模型，客户端仅可调 RPC）。

-- ── 表 ─────────────────────────────────────────────
create table if not exists mailbox (
  box_id     text primary key,
  read_token text not null,
  created_at timestamptz not null default now()
);

create table if not exists mail (
  id         bigint generated always as identity primary key,
  to_box     text not null references mailbox(box_id),
  from_box   text,
  payload    text not null check (length(payload) < 150000),
  delivered  boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists mail_inbox_idx on mail (to_box, delivered);

-- 客户端(anon)不允许直接碰表
revoke all on mailbox from anon;
revoke all on mail from anon;

-- ── RPC ────────────────────────────────────────────
-- 开箱：生成两码（唯一一次返回 read_token）
create or replace function create_mailbox()
returns json language plpgsql security definer as $$
declare
  v_box text; v_token text; alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  loop
    v_box := 'LUMI-';
    for i in 1..6 loop
      v_box := v_box || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from mailbox where box_id = v_box);
  end loop;
  v_token := encode(gen_random_bytes(24), 'hex');
  insert into mailbox (box_id, read_token) values (v_box, v_token);
  return json_build_object('box_id', v_box, 'read_token', v_token);
end $$;

-- 寄信：校验信箱存在 + 每箱每日限量 200；返回信件 id（发件方记本地台账 → 送达回执）
-- （若曾执行过 returns void 的旧版：先 drop function send_mail(text,text,text); 再跑本段）
create or replace function send_mail(p_to text, p_from text, p_payload text)
returns bigint language plpgsql security definer as $$
declare
  v_id bigint;
begin
  if not exists (select 1 from mailbox where box_id = p_to) then
    raise sqlstate 'PT404' using message = 'box not found';
  end if;
  if (select count(*) from mail where to_box = p_to and created_at > now() - interval '1 day') >= 200 then
    raise sqlstate 'PT429' using message = 'daily limit reached';
  end if;
  insert into mail (to_box, from_box, payload) values (p_to, p_from, p_payload)
    returning id into v_id;
  return v_id;
end $$;

-- 收信：校验读取密钥 → 返回未送达信件并置 delivered
create or replace function fetch_mail(p_box text, p_token text)
returns setof json language plpgsql security definer as $$
begin
  if not exists (select 1 from mailbox where box_id = p_box and read_token = p_token) then
    raise sqlstate 'PT403' using message = 'bad token';
  end if;
  return query
    with picked as (
      update mail set delivered = true
      where to_box = p_box and delivered = false
      returning id, from_box, payload
    )
    select json_build_object('id', id, 'from_box', from_box, 'payload', payload) from picked;
end $$;

-- 回执：查自己寄出的信件里已送达的 id
create or replace function check_delivered(p_box text, p_token text, p_ids bigint[])
returns setof bigint language plpgsql security definer as $$
begin
  if not exists (select 1 from mailbox where box_id = p_box and read_token = p_token) then
    raise sqlstate 'PT403' using message = 'bad token';
  end if;
  return query select id from mail where id = any(p_ids) and from_box = p_box and delivered;
end $$;

grant execute on function create_mailbox(), send_mail(text,text,text),
  fetch_mail(text,text), check_delivered(text,text,bigint[]) to anon;

-- ── TTL 清理（30 天）。需在 Dashboard 启用 pg_cron 扩展后执行： ──
-- select cron.schedule('purge-old-mail', '17 3 * * *', $$delete from mail where created_at < now() - interval '30 days'$$);
