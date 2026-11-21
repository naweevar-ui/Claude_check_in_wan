-- ติดตั้งฐานข้อมูลเว็บเช็คชื่อทั้งหมดในครั้งเดียว: Supabase > SQL Editor > วางทั้งไฟล์ > Run


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

-- รายชื่อผู้เข้าเรียน 22 คน
insert into public.roster (id,name,org,by_name,sort) values
('r01','ภณธกร วงศ์เจริญ','เบทาโกร','',1),
('r02','วิภาดา พลาธนพร','Foodle NoodleCo., Ltd','',2),
('r03','สิริวรรณ รอดศิริ','Foodle NoodleCo., Ltd','วิภาดา พลาธนพร',3),
('r04','วิศรุต สุดสัตย์','Foodle NoodleCo., Ltd','วิภาดา พลาธนพร',4),
('r05','กิตติธัช ธูปถมพงศ์','Foodle NoodleCo., Ltd','วิภาดา พลาธนพร',5),
('r06','วราภรณ์ หวานล้ำ','บริษัท โอชาฟูดแพ็ค จำกัด','',6),
('r07','ณัฏชา แสวงหอม','บริษัท โอชาฟูดแพ็ค จำกัด','วราภรณ์ หวานล้ำ',7),
('r08','นรพนธ์ จิรัฐิติกาลพงศ์','บริษัท ซีเอ็ม พรีเมี่ยม ไรซ์ จำกัด','',8),
('r09','คงติภูมิ มณีโชค','บริษัท ซีเอ็ม พรีเมี่ยม ไรซ์ จำกัด','นรพนธ์ จิรัฐิติกาลพงศ์',9),
('r10','จิดาภา ทองเกิด','เทพผดุงพรมะพร้าว จำกัด','',10),
('r11','สุชาดา เอี่ยมสำอางค์','เทพผดุงพรมะพร้าว จำกัด','จิดาภา ทองเกิด',11),
('r12','พิชญา พิสุทธิ์พิเชฎฐ์','เทพผดุงพรมะพร้าว จำกัด','จิดาภา ทองเกิด',12),
('r13','วันทนา จุตาลานนท์','เทพผดุงพรมะพร้าว จำกัด','จิดาภา ทองเกิด',13),
('r14','ธนวรรณ ตั้งตรงพานิช','บริษัท โอชาฟูดแพ็ค จำกัด','',14),
('r15','ระวีวรรณ การภักดี','บริษัท โอชาฟูดแพ็ค จำกัด','ธนวรรณ ตั้งตรงพานิช',15),
('r16','คณาธิป จำนงค์','บริษัท ลาโต้ ฟู้ดแอนด์ดริ้งส์','',16),
('r17','พรพิมล ผลเพิ่ม','บริษัท ลาโต้ ฟู้ดแอนด์ดริ้งส์','คณาธิป จำนงค์',17),
('r18','รัตติยากร ฉายหิรัญ','บริษัท สยาม คอนซูมเมอร์ โปรดักส์ จำกัด','',18),
('r19','วิชยุตม์ กีรติธนาภรณ์','บริษัท เมอร์เดียนท์ จำกัด','',19),
('r20','จิตรา คำแหง','บริษัท โอชาฟูดแพ็ค จำกัด','',20),
('r21','อรณิชา ครองศักดิ์ศิริ','บริษัท โอชาฟูดแพ็ค จำกัด','จิตรา คำแหง',21),
('r22','นัทธมน พุทธพรม','บริษัท โอชาฟูดแพ็ค จำกัด','จิตรา คำแหง',22);
select 'ติดตั้งเสร็จแล้ว' as status, (select count(*) from public.roster) as roster_count;
