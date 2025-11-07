-- ============================================
-- SIMPLE SQL TO CREATE STUDENT PROFILES
-- Copy and paste this in Supabase SQL Editor
-- ============================================

-- STEP 1: Create profiles for students that already have auth users
-- (This matches students table with auth.users by email)

INSERT INTO public.profiles (id, email, name, usn, phone, department, role, year)
SELECT 
    au.id,
    s.email,
    s.name,
    s.usn,
    s.phone,
    s.department,
    'student',
    CAST(s.semester AS INTEGER)
FROM students s
INNER JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = au.id
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    usn = EXCLUDED.usn,
    phone = EXCLUDED.phone,
    department = EXCLUDED.department,
    year = EXCLUDED.year;

-- STEP 2: Check how many students still need auth users
-- Run this to see the count:

SELECT COUNT(*) as students_needing_auth_users
FROM students s
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users au 
    WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
);

-- STEP 3: See the list of students needing auth users
-- Copy the results and use them to create auth users:

SELECT 
    s.usn,
    s.email,
    s.name,
    s.usn || '@VVCE2024' as default_password
FROM students s
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users au 
    WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
)
ORDER BY s.usn;

-- ============================================
-- IMPORTANT: To create auth users, you MUST use one of these methods:
-- ============================================

-- METHOD 1: Supabase Dashboard (Easiest)
-- 1. Go to: Supabase Dashboard → Authentication → Users → Add User → Import Users
-- 2. Use the query above (STEP 3) to get the list
-- 3. Create a CSV with columns: email, password
-- 4. Import the CSV

-- METHOD 2: Use Supabase Admin API (if you have access)
-- This requires making HTTP requests, not SQL

-- NOTE: You CANNOT directly INSERT into auth.users table via SQL
-- for security reasons. You must use the Dashboard or Admin API.

-- ============================================
-- After creating auth users, run STEP 1 again to create profiles
-- ============================================

