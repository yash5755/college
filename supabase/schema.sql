-- VVCE College Management System - Supabase Schema

-- Profiles (users)
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text unique,
  name text,
  role text check (role in ('admin','faculty','student')) not null default 'student',
  department text,
  year int,
  usn text,
  phone text,
  profile_pic text,
  avatar_url text,
  approved boolean not null default false,
  created_at timestamp with time zone default now()
);

-- Rooms
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  building text,
  capacity int not null default 40,
  room_type text default 'classroom',
  is_maintenance boolean not null default false,
  created_at timestamp with time zone default now()
);

-- Room Reservations
create table if not exists public.room_reservations (
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
create table if not exists public.timetables (
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
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  audience text[] default array['student','faculty']::text[],
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default now()
);

-- Events (simple calendar)
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  start_at timestamp with time zone not null,
  end_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- Exams
create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  exam_date date not null,
  start_time text not null,
  subject text not null,
  semester text,
  section text,
  created_at timestamp with time zone default now()
);

-- Exam allocations (JSON-based publish flow)
create table if not exists public.exam_allocations (
  id uuid primary key default gen_random_uuid(),
  exam_name text not null,
  generated_by uuid references public.profiles(id) on delete set null,
  method text check (method in ('csv','ai','auto')) not null default 'auto',
  status text check (status in ('draft','published')) not null default 'draft',
  allocation_json jsonb not null,
  created_at timestamp with time zone default now()
);

-- Helper: prevent overlapping reservations via exclusion constraint (if pgcrypto/ btree_gist available)
-- Note: Requires btree_gist extension
create extension if not exists btree_gist;
do $$ begin
  alter table public.room_reservations
    add constraint no_overlap exclude using gist (
      room_id with =,
      tstzrange(start_time, end_time) with &&
    );
exception when duplicate_object then null; end $$;


