-- ============================================================
-- Mewati Tune Player — additive schema sync
-- Safe to re-run. Does NOT drop tables, columns, or rows.
-- Only creates what is missing and refreshes functions/policies.
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- TABLES (create if missing) ----------
create table if not exists public.singers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  bio text,
  photo_url text
);

create table if not exists public.songs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  singer_id uuid,
  category text,
  audio_url text not null default '',
  cover_image_url text,
  duration integer,
  play_count integer not null default 0,
  like_count integer not null default 0,
  is_premium boolean not null default false
);

create table if not exists public.profiles (
  id uuid primary key,
  subscription_status text not null default 'free',
  subscription_expiry timestamptz
);

create table if not exists public.favorites (
  user_id uuid not null,
  song_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, song_id)
);

create table if not exists public.likes (
  user_id uuid not null,
  song_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, song_id)
);

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  category text,
  message text not null,
  song_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.play_count_log (
  user_id uuid not null,
  song_id uuid not null,
  played_at timestamptz not null default now(),
  primary key (user_id, song_id, played_at)
);

-- ---------- COLUMNS the Dart models/services read/write ----------
alter table public.singers add column if not exists name text;
alter table public.singers add column if not exists bio text;
alter table public.singers add column if not exists photo_url text;

alter table public.songs add column if not exists title text;
alter table public.songs add column if not exists singer_id uuid;
alter table public.songs add column if not exists category text;
alter table public.songs add column if not exists audio_url text;
alter table public.songs add column if not exists cover_image_url text;
alter table public.songs add column if not exists duration integer;
alter table public.songs add column if not exists play_count integer;
alter table public.songs add column if not exists like_count integer;
alter table public.songs add column if not exists is_premium boolean;
-- lyrics_text already on live DB — not used by app; leave it.

alter table public.profiles add column if not exists subscription_status text;
alter table public.profiles add column if not exists subscription_expiry timestamptz;

alter table public.favorites add column if not exists user_id uuid;
alter table public.favorites add column if not exists song_id uuid;
alter table public.favorites add column if not exists created_at timestamptz;

alter table public.likes add column if not exists user_id uuid;
alter table public.likes add column if not exists song_id uuid;
alter table public.likes add column if not exists created_at timestamptz;

alter table public.feedback add column if not exists user_id uuid;
alter table public.feedback add column if not exists category text;
alter table public.feedback add column if not exists message text;
alter table public.feedback add column if not exists song_id uuid;
alter table public.feedback add column if not exists created_at timestamptz;

-- defaults / not-null only where safe
alter table public.songs alter column play_count set default 0;
alter table public.songs alter column like_count set default 0;
alter table public.songs alter column is_premium set default false;
update public.songs set play_count = 0 where play_count is null;
update public.songs set like_count = 0 where like_count is null;
update public.songs set is_premium = false where is_premium is null;
update public.songs set audio_url = '' where audio_url is null;
alter table public.songs alter column play_count set not null;
alter table public.songs alter column like_count set not null;
alter table public.songs alter column is_premium set not null;

alter table public.profiles alter column subscription_status set default 'free';
update public.profiles set subscription_status = 'free' where subscription_status is null;
alter table public.profiles alter column subscription_status set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'songs_like_count_nonneg'
  ) then
    alter table public.songs
      add constraint songs_like_count_nonneg check (like_count >= 0);
  end if;
end $$;

-- FKs only if missing (never drop existing)
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'songs_singer_id_fkey') then
    alter table public.songs
      add constraint songs_singer_id_fkey
      foreign key (singer_id) references public.singers(id);
  end if;
exception when others then
  raise notice 'songs_singer_id_fkey skipped: %', sqlerrm;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_id_fkey') then
    alter table public.profiles
      add constraint profiles_id_fkey
      foreign key (id) references auth.users(id) on delete cascade;
  end if;
exception when others then
  raise notice 'profiles_id_fkey skipped: %', sqlerrm;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'favorites_user_id_fkey') then
    alter table public.favorites
      add constraint favorites_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
exception when others then
  raise notice 'favorites_user_id_fkey skipped: %', sqlerrm;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'favorites_song_id_fkey') then
    alter table public.favorites
      add constraint favorites_song_id_fkey
      foreign key (song_id) references public.songs(id) on delete cascade;
  end if;
exception when others then
  raise notice 'favorites_song_id_fkey skipped: %', sqlerrm;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'likes_user_id_fkey') then
    alter table public.likes
      add constraint likes_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
exception when others then
  raise notice 'likes_user_id_fkey skipped: %', sqlerrm;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'likes_song_id_fkey') then
    alter table public.likes
      add constraint likes_song_id_fkey
      foreign key (song_id) references public.songs(id) on delete cascade;
  end if;
exception when others then
  raise notice 'likes_song_id_fkey skipped: %', sqlerrm;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'feedback_user_id_fkey') then
    alter table public.feedback
      add constraint feedback_user_id_fkey
      foreign key (user_id) references auth.users(id);
  end if;
exception when others then
  raise notice 'feedback_user_id_fkey skipped: %', sqlerrm;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'feedback_song_id_fkey') then
    alter table public.feedback
      add constraint feedback_song_id_fkey
      foreign key (song_id) references public.songs(id);
  end if;
exception when others then
  raise notice 'feedback_song_id_fkey skipped: %', sqlerrm;
end $$;

-- ---------- INDEXES ----------
create index if not exists idx_songs_singer_id on public.songs(singer_id);
create index if not exists idx_songs_title on public.songs(title);
create index if not exists idx_songs_play_count_desc on public.songs(play_count desc);
create index if not exists idx_favorites_user_id on public.favorites(user_id);
create index if not exists idx_likes_user_id on public.likes(user_id);
create index if not exists idx_likes_song_id on public.likes(song_id);
create index if not exists idx_play_count_log_user_song on public.play_count_log(user_id, song_id);

-- ---------- VIEW (replace definition only; no table drop) ----------
create or replace view public.singers_with_song_count as
select
  s.id,
  s.name,
  s.bio,
  s.photo_url,
  coalesce(c.n, 0)::int as song_count
from public.singers s
left join (
  select singer_id, count(*)::int as n
  from public.songs
  group by singer_id
) c on c.singer_id = s.id;

alter view public.singers_with_song_count set (security_invoker = true);

-- ---------- RLS ----------
alter table public.songs enable row level security;
alter table public.singers enable row level security;
alter table public.profiles enable row level security;
alter table public.favorites enable row level security;
alter table public.likes enable row level security;
alter table public.feedback enable row level security;
alter table public.play_count_log enable row level security;

-- Catalog: public read, no client writes
drop policy if exists "songs_select_public" on public.songs;
create policy "songs_select_public" on public.songs for select using (true);
drop policy if exists "songs_no_insert" on public.songs;
create policy "songs_no_insert" on public.songs for insert to anon, authenticated with check (false);
drop policy if exists "songs_no_update" on public.songs;
create policy "songs_no_update" on public.songs for update to anon, authenticated using (false);
drop policy if exists "songs_no_delete" on public.songs;
create policy "songs_no_delete" on public.songs for delete to anon, authenticated using (false);

drop policy if exists "singers_select_public" on public.singers;
create policy "singers_select_public" on public.singers for select using (true);
drop policy if exists "singers_no_insert" on public.singers;
create policy "singers_no_insert" on public.singers for insert to anon, authenticated with check (false);
drop policy if exists "singers_no_update" on public.singers;
create policy "singers_no_update" on public.singers for update to anon, authenticated using (false);
drop policy if exists "singers_no_delete" on public.singers;
create policy "singers_no_delete" on public.singers for delete to anon, authenticated using (false);

-- Profiles: owner only
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.prevent_subscription_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.subscription_status is distinct from old.subscription_status
     and auth.role() <> 'service_role' then
    raise exception 'subscription_status can only be changed by an admin process';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_subscription_status_change on public.profiles;
create trigger trg_prevent_subscription_status_change
  before update on public.profiles
  for each row
  execute function public.prevent_subscription_status_change();

-- Favorites / likes: owner only
drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own" on public.favorites for select using (auth.uid() = user_id);
drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own" on public.favorites for insert with check (auth.uid() = user_id);
drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own" on public.favorites for delete using (auth.uid() = user_id);

drop policy if exists "Users can view all likes" on public.likes;
drop policy if exists "likes_select_own" on public.likes;
create policy "likes_select_own" on public.likes for select using (auth.uid() = user_id);
drop policy if exists "likes_insert_own" on public.likes;
create policy "likes_insert_own" on public.likes for insert with check (auth.uid() = user_id);
drop policy if exists "likes_delete_own" on public.likes;
create policy "likes_delete_own" on public.likes for delete using (auth.uid() = user_id);

-- Feedback: insert own, no client read/update/delete
drop policy if exists "feedback_insert_own" on public.feedback;
create policy "feedback_insert_own" on public.feedback for insert with check (auth.uid() = user_id);
drop policy if exists "feedback_no_select" on public.feedback;
create policy "feedback_no_select" on public.feedback for select to anon, authenticated using (false);
drop policy if exists "feedback_no_update" on public.feedback;
create policy "feedback_no_update" on public.feedback for update to anon, authenticated using (false);
drop policy if exists "feedback_no_delete" on public.feedback;
create policy "feedback_no_delete" on public.feedback for delete to anon, authenticated using (false);

-- Play log: no direct client access (RPC only)
revoke all on table public.play_count_log from public, anon, authenticated;
drop policy if exists "play_count_log_no_select" on public.play_count_log;
create policy "play_count_log_no_select" on public.play_count_log for select to anon, authenticated using (false);
drop policy if exists "play_count_log_no_insert" on public.play_count_log;
create policy "play_count_log_no_insert" on public.play_count_log for insert to anon, authenticated with check (false);
drop policy if exists "play_count_log_no_update" on public.play_count_log;
create policy "play_count_log_no_update" on public.play_count_log for update to anon, authenticated using (false);
drop policy if exists "play_count_log_no_delete" on public.play_count_log;
create policy "play_count_log_no_delete" on public.play_count_log for delete to anon, authenticated using (false);

-- ---------- RPCs the app calls ----------
create or replace function public.toggle_like(p_song_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_new_count int;
  v_deleted int;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtext(v_uid::text || ':' || p_song_id::text));

  delete from public.likes
  where user_id = v_uid and song_id = p_song_id;
  get diagnostics v_deleted = row_count;

  if v_deleted > 0 then
    update public.songs
      set like_count = greatest(0, like_count - 1)
      where id = p_song_id
      returning like_count into v_new_count;
  else
    insert into public.likes (user_id, song_id)
    values (v_uid, p_song_id)
    on conflict (user_id, song_id) do nothing;
    update public.songs
      set like_count = like_count + 1
      where id = p_song_id
      returning like_count into v_new_count;
  end if;

  return coalesce(v_new_count, 0);
end;
$$;

revoke all on function public.toggle_like(uuid) from public;
grant execute on function public.toggle_like(uuid) to authenticated;

create or replace function public.increment_play_count(p_song_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_last timestamptz;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtext(v_uid::text || ':pc:' || p_song_id::text));

  select max(played_at) into v_last
  from public.play_count_log
  where user_id = v_uid and song_id = p_song_id;

  if v_last is not null and now() - v_last < interval '30 seconds' then
    return;
  end if;

  insert into public.play_count_log (user_id, song_id) values (v_uid, p_song_id);

  update public.songs
    set play_count = coalesce(play_count, 0) + 1
    where id = p_song_id;
end;
$$;

revoke all on function public.increment_play_count(uuid) from public;
grant execute on function public.increment_play_count(uuid) to authenticated;

do $$
begin
  revoke all on function public.increment_like_count(uuid) from public, anon, authenticated;
exception when undefined_function then null;
end $$;

do $$
begin
  revoke all on function public.decrement_like_count(uuid) from public, anon, authenticated;
exception when undefined_function then null;
end $$;

-- ---------- GRANTS the Flutter anon/authenticated client needs ----------
grant usage on schema public to anon, authenticated;

grant select on public.songs to anon, authenticated;
grant select on public.singers to anon, authenticated;
grant select on public.singers_with_song_count to anon, authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select, insert, delete on public.likes to authenticated;
grant insert on public.feedback to authenticated;

notify pgrst, 'reload schema';