-- ============================================
-- VVCE APP - COMPLETE DATABASE RESET
-- Run this in Supabase SQL Editor to reset everything
-- ============================================

-- STEP 1: Drop all existing policies first (with error handling)
-- Use a more robust approach: drop policies only if tables exist
do $$ 
begin
  -- Profiles policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'profiles') then
    drop policy if exists "profiles_read_own" on public.profiles;
    drop policy if exists "profiles_admin_read" on public.profiles;
    drop policy if exists "profiles_insert_self" on public.profiles;
    drop policy if exists "profiles_update_self" on public.profiles;
    drop policy if exists "profiles_admin_update" on public.profiles;
    drop policy if exists "profiles_admin_delete" on public.profiles;
    drop policy if exists "profiles_admin_write" on public.profiles; -- legacy name
  end if;
  
  -- Rooms policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'rooms') then
    drop policy if exists "rooms_read_all" on public.rooms;
    drop policy if exists "rooms_admin_write" on public.rooms;
  end if;
  
  -- Room reservations policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'room_reservations') then
    drop policy if exists "reservations_read_all" on public.room_reservations;
    drop policy if exists "reservations_insert_faculty" on public.room_reservations;
    drop policy if exists "reservations_update_owner_or_admin" on public.room_reservations;
  end if;
  
  -- Timetables policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'timetables') then
    drop policy if exists "timetables_read_self" on public.timetables;
    drop policy if exists "timetables_faculty_read" on public.timetables;
    drop policy if exists "timetables_admin_write" on public.timetables;
  end if;
  
  -- Announcements policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'announcements') then
    drop policy if exists "announcements_read_all" on public.announcements;
    drop policy if exists "announcements_admin_write" on public.announcements;
  end if;
  
  -- Events policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'events') then
    drop policy if exists "events_read_all" on public.events;
    drop policy if exists "events_admin_write" on public.events;
  end if;
  
  -- Exams policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'exams') then
    drop policy if exists "exams_read_all" on public.exams;
    drop policy if exists "exams_admin_write" on public.exams;
  end if;
  
  -- Exam allocations policies
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'exam_allocations') then
    drop policy if exists "allocations_read_all" on public.exam_allocations;
    drop policy if exists "allocations_admin_write" on public.exam_allocations;
  end if;
end $$;

-- STEP 2: Drop triggers
drop trigger if exists on_auth_user_created on auth.users;

-- STEP 3: Drop functions
drop function if exists public.handle_new_user();
drop function if exists public.is_admin();
drop function if exists public.is_faculty_or_admin();

-- STEP 4: Drop all tables in correct order (respecting foreign keys)
drop table if exists public.exam_allocations cascade;
drop table if exists public.exams cascade;
drop table if exists public.events cascade;
drop table if exists public.announcements cascade;
drop table if exists public.timetables cascade;
drop table if exists public.room_reservations cascade;
drop table if exists public.rooms cascade;
drop table if exists public.profiles cascade;

-- STEP 5: Create extensions
create extension if not exists btree_gist;

-- ============================================
-- STEP 6: CREATE ALL TABLES
-- ============================================

-- Profiles (users)
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text unique,
  name text,
  role text check (role in ('admin','faculty','student')) not null default 'student',
  department text,
  year int,
  usn text,
  phone text,
  profile_pic text,
  created_at timestamp with time zone default now()
);

-- Rooms
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  building text,
  capacity int not null default 40,
  room_type text default 'classroom',
  is_maintenance boolean not null default false,
  created_at timestamp with time zone default now()
);

-- Room Reservations
create table public.room_reservations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  start_time timestamp with time zone not null,
  end_time timestamp with time zone not null,
  purpose text,
  status text not null default 'approved', -- pending/approved/rejected
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default now()
);

-- Timetables (per user)
create table public.timetables (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  day_of_week int not null check (day_of_week between 1 and 7),
  subject text not null,
  room text,
  room_id uuid references public.rooms(id) on delete set null,
  faculty_id uuid references public.profiles(id) on delete set null,
  start_time text not null, -- HH:mm
  end_time text not null,
  semester text,
  section text,
  department text,
  created_at timestamp with time zone default now()
);

-- Announcements
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  audience text[] default array['student','faculty']::text[],
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default now()
);

-- Events (simple calendar)
create table public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  start_at timestamp with time zone not null,
  end_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- Exams
create table public.exams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  exam_date date not null,
  start_time text not null,
  subject text not null,
  semester text,
  section text,
  created_at timestamp with time zone default now()
);

-- Exam allocations
create table public.exam_allocations (
  id uuid primary key default gen_random_uuid(),
  exam_id text not null,
  student_id uuid not null references public.profiles(id) on delete cascade,
  student_usn text,
  student_name text,
  room_id text,
  room_name text,
  seat_number text,
  exam_date timestamp with time zone,
  exam_time text,
  subject text,
  semester text,
  section text,
  created_at timestamp with time zone default now()
);

-- Helper: prevent overlapping reservations via exclusion constraint
do $$ 
begin
  alter table public.room_reservations
    add constraint no_overlap exclude using gist (
      room_id with =,
      tstzrange(start_time, end_time) with &&
    );
exception when duplicate_object then null; 
end $$;

-- ============================================
-- STEP 7: CREATE TRIGGERS
-- ============================================

-- Function to handle new user signup
create or replace function public.handle_new_user()
returns trigger 
security definer
set search_path = public
as $$
declare
  user_role text := 'student';
  user_name text;
  user_dept text;
  user_usn text;
  user_year int;
  user_pic text;
begin
  -- Extract role from metadata if available, otherwise default to 'student'
  if new.raw_user_meta_data ? 'role' then
    user_role := new.raw_user_meta_data->>'role';
  end if;
  
  -- Extract other metadata fields
  if new.raw_user_meta_data ? 'display_name' then
    user_name := new.raw_user_meta_data->>'display_name';
  end if;
  
  if new.raw_user_meta_data ? 'department' then
    user_dept := new.raw_user_meta_data->>'department';
  end if;
  
  if new.raw_user_meta_data ? 'usn' then
    user_usn := new.raw_user_meta_data->>'usn';
  end if;
  
  if new.raw_user_meta_data ? 'year' then
    user_year := (new.raw_user_meta_data->>'year')::int;
  end if;
  
  if new.raw_user_meta_data ? 'profile_pic' then
    user_pic := new.raw_user_meta_data->>'profile_pic';
  end if;
  
  -- Insert profile with all available data
  insert into public.profiles (id, email, role, name, department, usn, year, profile_pic)
  values (
    new.id,
    new.email,
    user_role,
    user_name,
    user_dept,
    user_usn,
    user_year,
    user_pic
  )
  on conflict (id) do update set
    email = excluded.email,
    role = excluded.role,
    name = coalesce(excluded.name, profiles.name),
    department = coalesce(excluded.department, profiles.department),
    usn = coalesce(excluded.usn, profiles.usn),
    year = coalesce(excluded.year, profiles.year),
    profile_pic = coalesce(excluded.profile_pic, profiles.profile_pic);
  
  return new;
end;
$$ language plpgsql;

-- Trigger to automatically create profile when user signs up
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================
-- STEP 7.5: CREATE HELPER FUNCTION FOR ADMIN CHECK
-- ============================================
-- This function bypasses RLS to avoid infinite recursion
create or replace function public.is_admin()
returns boolean
security definer
set search_path = public
as $$
begin
  -- Use SECURITY DEFINER to bypass RLS when checking profiles
  return exists (
    select 1 from public.profiles 
    where id = auth.uid() and role = 'admin'
  );
end;
$$ language plpgsql;

-- Function to check if user is faculty or admin
create or replace function public.is_faculty_or_admin()
returns boolean
security definer
set search_path = public
as $$
begin
  -- Use SECURITY DEFINER to bypass RLS when checking profiles
  return exists (
    select 1 from public.profiles 
    where id = auth.uid() and role in ('faculty', 'admin')
  );
end;
$$ language plpgsql;

-- ============================================
-- STEP 8: ENABLE RLS AND CREATE POLICIES
-- ============================================

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.room_reservations enable row level security;
alter table public.timetables enable row level security;
alter table public.announcements enable row level security;
alter table public.events enable row level security;
alter table public.exams enable row level security;
alter table public.exam_allocations enable row level security;

-- ============================================
-- PROFILES POLICIES
-- ============================================

-- Profiles: users can view their own profile
create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id);

-- Profiles: admins can view all profiles (using helper function to avoid recursion)
create policy "profiles_admin_read" on public.profiles
  for select using (public.is_admin());

-- Profiles: users can insert their own profile during signup
create policy "profiles_insert_self" on public.profiles
  for insert with check (auth.uid() = id);

-- Profiles: users can update their own profile
create policy "profiles_update_self" on public.profiles
  for update 
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Profiles: admins can update and delete (but not insert - users insert their own)
-- Note: We don't need a separate admin insert policy since users insert their own profiles
create policy "profiles_admin_update" on public.profiles
  for update using (public.is_admin());
  
create policy "profiles_admin_delete" on public.profiles
  for delete using (public.is_admin());

-- ============================================
-- ROOMS POLICIES
-- ============================================

-- Rooms: everyone can read
create policy "rooms_read_all" on public.rooms 
  for select using (true);

-- Rooms: only admin can write (using helper function to avoid recursion)
create policy "rooms_admin_write" on public.rooms 
  for all using (public.is_admin());

-- ============================================
-- ROOM RESERVATIONS POLICIES
-- ============================================

-- Room reservations: everyone can read
create policy "reservations_read_all" on public.room_reservations 
  for select using (true);

-- Room reservations: faculty/admin can insert (using helper function to avoid recursion)
create policy "reservations_insert_faculty" on public.room_reservations 
  for insert with check (public.is_faculty_or_admin());

-- Room reservations: owner or admin can update (using helper function to avoid recursion)
create policy "reservations_update_owner_or_admin" on public.room_reservations 
  for update using (
    created_by = auth.uid() or public.is_admin()
  );

-- ============================================
-- TIMETABLES POLICIES
-- ============================================

-- Timetables: users can read their own
create policy "timetables_read_self" on public.timetables 
  for select using (user_id = auth.uid());

-- Timetables: faculty/admin can read all (using helper function to avoid recursion)
create policy "timetables_faculty_read" on public.timetables 
  for select using (public.is_faculty_or_admin());

-- Timetables: only admin can write (using helper function to avoid recursion)
create policy "timetables_admin_write" on public.timetables 
  for all using (public.is_admin());

-- ============================================
-- ANNOUNCEMENTS POLICIES
-- ============================================

-- Announcements: everyone can read
create policy "announcements_read_all" on public.announcements 
  for select using (true);

-- Announcements: only admin can write (using helper function to avoid recursion)
create policy "announcements_admin_write" on public.announcements 
  for all using (public.is_admin());

-- ============================================
-- EVENTS POLICIES
-- ============================================

-- Events: everyone can read
create policy "events_read_all" on public.events 
  for select using (true);

-- Events: only admin can write (using helper function to avoid recursion)
create policy "events_admin_write" on public.events 
  for all using (public.is_admin());

-- ============================================
-- EXAMS POLICIES
-- ============================================

-- Exams: everyone can read
create policy "exams_read_all" on public.exams 
  for select using (true);

-- Exams: only admin can write (using helper function to avoid recursion)
create policy "exams_admin_write" on public.exams 
  for all using (public.is_admin());

-- ============================================
-- EXAM ALLOCATIONS POLICIES
-- ============================================

-- Exam allocations: everyone can read
create policy "allocations_read_all" on public.exam_allocations 
  for select using (true);

-- Exam allocations: only admin can write (using helper function to avoid recursion)
create policy "allocations_admin_write" on public.exam_allocations 
  for all using (public.is_admin());

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant necessary permissions to authenticated users
grant usage on schema public to authenticated;
grant all on public.profiles to authenticated;
grant all on public.rooms to authenticated;
grant all on public.room_reservations to authenticated;
grant all on public.timetables to authenticated;
grant all on public.announcements to authenticated;
grant all on public.events to authenticated;
grant all on public.exams to authenticated;
grant all on public.exam_allocations to authenticated;

-- ============================================
-- RESET COMPLETE!
-- ============================================
-- Your database has been reset and is ready to use.
-- Signup should now work correctly!
-- ============================================

