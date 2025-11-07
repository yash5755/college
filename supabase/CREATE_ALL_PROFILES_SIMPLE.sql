-- ============================================
-- SIMPLE SCRIPT: CREATE PROFILES FOR ALL STUDENTS
-- Run this in Supabase SQL Editor
-- ============================================

-- STEP 1: Create profiles for students who already have auth users
-- This will create profiles immediately for any students that already have auth accounts

INSERT INTO public.profiles (id, email, name, usn, phone, department, role, year)
SELECT 
    au.id as id,
    s.email,
    s.name,
    s.usn,
    s.phone,
    s.department,
    'student' as role,
    CAST(s.semester AS INTEGER) as year
FROM students s
INNER JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p 
    WHERE p.id = au.id
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    usn = EXCLUDED.usn,
    phone = EXCLUDED.phone,
    department = EXCLUDED.department,
    year = EXCLUDED.year;

-- STEP 2: Check how many profiles were created and how many still need auth users
SELECT 
    'Profiles Created/Updated' as status,
    COUNT(*)::text as count
FROM public.profiles
WHERE role = 'student'
UNION ALL
SELECT 
    'Students Still Needing Auth Users' as status,
    COUNT(*)::text
FROM students s
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users au 
    WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
);

-- STEP 3: Get list of students that need auth users (for CSV import)
-- Copy these results and use them to create auth users via Supabase Dashboard
SELECT 
    s.email,
    s.usn || '@VVCE2024' as password,
    json_build_object(
        'role', 'student',
        'usn', s.usn,
        'display_name', s.name,
        'department', s.department,
        'year', CAST(s.semester AS INTEGER)
    )::text as user_metadata
FROM students s
WHERE s.email IS NOT NULL 
  AND s.usn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM auth.users au 
      WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
  )
ORDER BY s.usn;

-- ============================================
-- AFTER IMPORTING AUTH USERS, RUN STEP 1 AGAIN
-- ============================================
-- This will create profiles for the newly imported auth users

