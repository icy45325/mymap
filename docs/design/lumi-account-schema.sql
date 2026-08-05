-- Lumi v1.2 —— 账号 + 云同步 一次性初始化脚本
-- 用法：Supabase 控制台 → SQL Editor → 整段粘贴执行（可与 lumi-post-schema.sql 共存，先跑过邮局脚本）。
-- 另需在 Dashboard → Authentication → Providers → Apple：启用，Client IDs 填 App 的 Bundle ID（com.lumi.v0）。
-- 设计：足迹/心愿以 JSONB 整体存（schema 灵活，客户端 DTO 演进不改表）；RLS 仅本人可读写。

-- ── 同步表 ─────────────────────────────────────────
create table if not exists sync_footprints (
  id         uuid primary key,                       -- 客户端 Footprint.id（UUID 认领）
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  payload    jsonb not null,                         -- FootprintDTO 全量
  updated_at timestamptz not null,                   -- 客户端 updatedAt（LWW 判定）
  synced_at  timestamptz not null default now()
);
create index if not exists sync_fp_user_idx on sync_footprints (user_id, updated_at);

create table if not exists sync_wishes (
  id         uuid primary key,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  payload    jsonb not null,
  updated_at timestamptz not null,
  synced_at  timestamptz not null default now()
);
create index if not exists sync_wish_user_idx on sync_wishes (user_id);

-- ── RLS：仅本人 ────────────────────────────────────
alter table sync_footprints enable row level security;
alter table sync_wishes     enable row level security;

create policy "own footprints" on sync_footprints
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own wishes" on sync_wishes
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on sync_footprints, sync_wishes to authenticated;

-- ── 邮箱认领：登录后把 v1.1 匿名信箱绑到账号（换机可找回） ──
alter table mailbox add column if not exists user_id uuid references auth.users (id);

create or replace function claim_mailbox(p_box text, p_token text)
returns void language plpgsql security definer as $$
begin
  if auth.uid() is null then
    raise sqlstate 'PT401' using message = 'not signed in';
  end if;
  update mailbox set user_id = auth.uid()
   where box_id = p_box and read_token = p_token;
  if not found then
    raise sqlstate 'PT403' using message = 'bad box or token';
  end if;
end $$;

-- 找回：已认领账号在新设备重新拿回两码（read_token 只回给箱主）
create or replace function recover_mailbox()
returns json language plpgsql security definer as $$
declare v_box text; v_token text;
begin
  if auth.uid() is null then
    raise sqlstate 'PT401' using message = 'not signed in';
  end if;
  select box_id, read_token into v_box, v_token
    from mailbox where user_id = auth.uid() limit 1;
  if v_box is null then
    raise sqlstate 'PT404' using message = 'no mailbox bound';
  end if;
  return json_build_object('box_id', v_box, 'read_token', v_token);
end $$;

grant execute on function claim_mailbox(text, text), recover_mailbox() to authenticated;
