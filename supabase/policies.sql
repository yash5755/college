-- RLS Policies
alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.room_reservations enable row level security;
alter table public.timetables enable row level security;
alter table public.announcements enable row level security;
alter table public.events enable row level security;
alter table public.exams enable row level security;
alter table public.exam_allocations enable row level security;

-- Profiles: users can view their own profile; admins can view all
create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles_admin_read" on public.profiles
  for select using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- Profiles: insert/update self (signup flow), admin can manage
-- Allow users to insert their own profile during signup
create policy "profiles_insert_self" on public.profiles
  for insert with check (auth.uid() = id);
  
-- Allow inserts during signup (when user is authenticated but profile doesn't exist yet)
-- This policy uses security definer to bypass RLS checks during trigger execution

create policy "profiles_update_self" on public.profiles
  for update using (auth.uid() = id);

create policy "profiles_admin_write" on public.profiles
  for all using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- Rooms: everyone can read; only admin can write
create policy "rooms_read_all" on public.rooms for select using (true);
create policy "rooms_admin_write" on public.rooms for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- Room reservations: read all; faculty/admin can insert own; admin can approve
create policy "reservations_read_all" on public.room_reservations for select using (true);

create policy "reservations_insert_faculty" on public.room_reservations for insert with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty','admin'))
);

create policy "reservations_update_owner_or_admin" on public.room_reservations for update using (
  created_by = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- Timetables: users can read their own; faculty/admin can read where they teach; admin write
create policy "timetables_read_self" on public.timetables for select using (user_id = auth.uid());

create policy "timetables_faculty_read" on public.timetables for select using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty','admin'))
);

create policy "timetables_admin_write" on public.timetables for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- Announcements & events: read all; admin write
create policy "announcements_read_all" on public.announcements for select using (true);
create policy "announcements_admin_write" on public.announcements for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy "events_read_all" on public.events for select using (true);
create policy "events_admin_write" on public.events for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- Exams & allocations: read all; admin write
create policy "exams_read_all" on public.exams for select using (true);
create policy "exams_admin_write" on public.exams for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy "allocations_read_all" on public.exam_allocations for select using (true);
create policy "allocations_admin_write" on public.exam_allocations for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);


