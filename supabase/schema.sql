-- โครงสร้างฐานข้อมูล Supabase ของเว็บเช็คชื่อ (v2.0.0)
-- ติดตั้งแล้วในโปรเจกต์ hxwsjksgfptlhbogdyux ไฟล์นี้เก็บไว้อ้างอิง หรือใช้สร้างโปรเจกต์ใหม่ (SQL Editor > วางทั้งไฟล์ > Run)
-- เพิ่มผู้ดูแลคนใหม่: insert into public.admins values ('someone@gmail.com');

create table public.admins (email text primary key check (email = lower(email)));
insert into public.admins values ('thanawanv6@gmail.com');

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins a where a.email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

create table public.roster (
  id text primary key default ('r' || substr(replace(gen_random_uuid()::text,'-',''),1,10)),
  name text not null check (length(trim(name)) > 0),
  org text not null default '', pos text not null default '', email text not null default '',
  phone text not null default '', by_name text not null default '',
  sort int not null default 0, created_at timestamptz not null default now()
);
create table public.checkins (
  roster_id text primary key references public.roster(id) on delete cascade,
  at timestamptz not null default now(), late int not null default 0,
  status text not null default 'ตรงเวลา', sig text not null default '' check (length(sig) < 300000)
);
create table public.class_settings (
  id int primary key default 1 check (id = 1), title text not null default 'Claude AI',
  start_time time not null default '09:00', grace int not null default 10 check (grace between 0 and 240),
  require_sig boolean not null default true
);
insert into public.class_settings default values;

alter table public.admins enable row level security;
alter table public.roster enable row level security;
alter table public.checkins enable row level security;
alter table public.class_settings enable row level security;
create policy admin_read_admins on public.admins for select to authenticated using (public.is_admin());
create policy admin_all_roster on public.roster for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_checkins on public.checkins for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_settings on public.class_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on public.roster, public.checkins, public.class_settings, public.admins from anon;
grant select, insert, update, delete on public.roster, public.checkins, public.class_settings to authenticated;
grant select on public.admins to authenticated;

-- กระดานสาธารณะ: ชื่อ บริษัท และเวลาเช็คอิน (ไม่มีอีเมล เบอร์โทร ลายเซ็น)
create or replace function public.get_board() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('now', now(),
    'settings', (select jsonb_build_object('title', title, 'start', to_char(start_time,'HH24:MI'), 'grace', grace, 'requireSig', require_sig) from class_settings where id = 1),
    'roster', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'org', org, 'by', by_name) order by sort, created_at, name) from roster), '[]'::jsonb),
    'checks', coalesce((select jsonb_object_agg(roster_id, jsonb_build_object('at', at, 'late', late, 'status', status, 'hasSig', sig <> '')) from checkins), '{}'::jsonb));
$$;

-- เช็คอิน: ใช้เวลาเซิร์ฟเวอร์ (Asia/Bangkok) เช็คอินซ้ำไม่ได้
create or replace function public.check_in(p_id text, p_sig text default '') returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare s class_settings; t timestamptz := now(); m int;
begin
  select * into s from class_settings where id = 1;
  if not exists (select 1 from roster where id = p_id) then raise exception 'ไม่พบรายชื่อนี้'; end if;
  p_sig := coalesce(p_sig, '');
  if p_sig <> '' and (p_sig not like 'data:image/png;base64,%' or length(p_sig) >= 300000) then raise exception 'ลายเซ็นไม่ถูกต้อง'; end if;
  if s.require_sig and p_sig = '' then raise exception 'กรุณาเซ็นชื่อก่อนยืนยัน'; end if;
  m := floor(extract(epoch from ((t at time zone 'Asia/Bangkok')::time - s.start_time)) / 60)::int;
  insert into checkins (roster_id, at, late, status, sig)
  values (p_id, t, greatest(m, 0), case when m > s.grace then 'สาย' else 'ตรงเวลา' end, p_sig)
  on conflict (roster_id) do nothing;
  return get_board();
end; $$;

revoke all on function public.get_board() from public;
revoke all on function public.check_in(text, text) from public;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.get_board() to anon, authenticated;
grant execute on function public.check_in(text, text) to anon, authenticated;
grant execute on function public.is_admin() to authenticated;
