-- Seed demo data safely (idempotent-ish)
-- Run in Supabase SQL Editor

-- ROOMS
with to_insert(name, building, capacity, room_type) as (
  values
    ('CSE-101', 'Block A', 60, 'classroom'),
    ('CSE-102', 'Block A', 60, 'classroom'),
    ('ECE-201', 'Block B', 40, 'lab'),
    ('Auditorium', 'Main', 300, 'auditorium')
)
insert into public.rooms (name, building, capacity, room_type)
select t.name, t.building, t.capacity, t.room_type
from to_insert t
where not exists (
  select 1 from public.rooms r where r.name = t.name and coalesce(r.building,'') = coalesce(t.building,'')
);

-- ANNOUNCEMENTS
with to_insert(title, body, audience) as (
  values
    ('Welcome to VVCE', 'Classes commence from next Monday. All the best!', array['student','faculty']::text[]),
    ('Maintenance', 'Block B labs will be under maintenance this weekend.', array['student','faculty']::text[])
)
insert into public.announcements (title, body, audience)
select t.title, t.body, t.audience
from to_insert t
where not exists (
  select 1 from public.announcements a where a.title = t.title
);

-- EVENTS
with to_insert(title, start_at, end_at) as (
  values
    ('Orientation', now() + interval '2 day', now() + interval '2 day 2 hour'),
    ('Tech Talk',  now() + interval '5 day', now() + interval '5 day 1 hour')
)
insert into public.events (title, start_at, end_at)
select t.title, t.start_at, t.end_at
from to_insert t
where not exists (
  select 1 from public.events e where e.title = t.title
);

-- SAMPLE TIMETABLE for an EXISTING USER
-- Picks the most recently created student (fallback: any user) from public.profiles
-- To target a specific user, replace the me CTE with: select id as uid from public.profiles where email = 'your.email@vvce.ac.in'
with me as (
  select id as uid from public.profiles where role = 'student' order by id desc limit 1
),
me_fallback as (
  -- if me is empty, take latest any user
  select uid from me
  union all
  select p.uid from (
    select id as uid from public.profiles order by id desc limit 1
  ) p
  where not exists (select 1 from me)
),
room_sel as (
  select id, name from public.rooms where name = 'CSE-101' limit 1
)
insert into public.timetables (
  user_id, day_of_week, subject, room, room_id, start_time, end_time, semester, section, department
)
select mf.uid, d.dow, s.subject, rs.name, rs.id, '10:00', '11:00', '5', 'A', 'CSE'
from me_fallback mf
join room_sel rs on true
join (values (1), (3), (5)) as d(dow) on true
join (values ('Data Structures')) as s(subject) on true
where not exists (
  select 1 from public.timetables t
  where t.user_id = mf.uid and t.day_of_week = d.dow and t.start_time = '10:00' and t.subject = s.subject
);

-- OPTIONAL: simple room reservation for a user with permission
-- insert into public.room_reservations (room_id, start_time, end_time, purpose, created_by)
-- select rs.id, now() + interval '1 day 09:00', now() + interval '1 day 10:00', 'Study Group', mf.uid
-- from (select uid from me_fallback) mf, (select id from public.rooms where name = 'CSE-101' limit 1) rs
-- where not exists (
--   select 1 from public.room_reservations r where r.room_id = rs.id and r.start_time = now() + interval '1 day 09:00'
-- );
