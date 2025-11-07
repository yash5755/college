-- ============================================
-- BULK CREATE STUDENT PROFILES FROM STUDENTS TABLE
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Create profiles for students that already have auth users (matching by email)
-- This will create/update profiles for any students whose emails match existing auth users

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

-- Step 2: Check how many students still need profiles
-- Run this to see the status:

SELECT 
    COUNT(*) as total_students,
    COUNT(p.id) as students_with_profiles,
    COUNT(*) - COUNT(p.id) as students_needing_profiles
FROM students s
LEFT JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email));

-- Step 3: See which students need auth users created
-- This shows students that don't have matching auth users:

SELECT 
    s.usn,
    s.name,
    s.email,
    s.semester,
    s.section,
    CASE 
        WHEN au.id IS NULL THEN '❌ Needs Auth User'
        WHEN p.id IS NULL THEN '⚠️ Auth User Exists, Profile Missing'
        ELSE '✅ Complete'
    END as status
FROM students s
LEFT JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
LEFT JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email))
WHERE p.id IS NULL
ORDER BY s.usn
LIMIT 100;

-- ============================================
-- IMPORTANT: To create auth users, you have two options:
-- ============================================

-- OPTION A: Use Supabase Dashboard (Recommended for 500+ students)
-- 1. Go to Supabase Dashboard → Authentication → Users
-- 2. Click "Add User" → "Import Users"
-- 3. Export your students table to CSV with columns: email, password, user_metadata
-- 4. Import the CSV
-- 
-- CSV Format:
-- email,password,user_metadata
-- VVCE24CSE0402@VVCE.AC.IN,4TV24CS001@VVCE2024,"{""role"":""student"",""usn"":""4TV24CS001""}"
-- VVCE24CSE0133@VVCE.AC.IN,4TV24CS002@VVCE2024,"{""role"":""student"",""usn"":""4TV24CS002""}"

-- OPTION B: Generate SQL INSERT statements for auth.users (if you have direct DB access)
-- Note: This requires superuser access and is not recommended
-- The following generates the INSERT statements (DO NOT RUN DIRECTLY - copy output):

-- SELECT 
--     'INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data) VALUES (' ||
--     'gen_random_uuid(), ' ||
--     quote_literal(s.email) || ', ' ||
--     quote_literal(crypt('' || s.usn || '@VVCE2024'', gen_salt(''bf''))) || ', ' ||
--     'now(), now(), now(), ' ||
--     quote_literal(json_build_object(
--         'role', 'student',
--         'usn', s.usn,
--         'display_name', s.name,
--         'department', s.department,
--         'year', CAST(s.semester AS INTEGER)
--     )::text) || ');' as insert_statement
-- FROM students s
-- WHERE NOT EXISTS (
--     SELECT 1 FROM auth.users au WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
-- )
-- LIMIT 10; -- Test with 10 first

-- ============================================
-- HELPER: Create a function to sync profiles after auth users are created
-- ============================================

CREATE OR REPLACE FUNCTION sync_all_student_profiles()
RETURNS TABLE(
    created_count BIGINT,
    updated_count BIGINT,
    skipped_count BIGINT
) AS $$
DECLARE
    created BIGINT := 0;
    updated BIGINT := 0;
    skipped BIGINT := 0;
BEGIN
    -- Create profiles for students with auth users
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
    
    GET DIAGNOSTICS created = ROW_COUNT;
    
    -- Count skipped (students without auth users)
    SELECT COUNT(*) INTO skipped
    FROM students s
    WHERE NOT EXISTS (
        SELECT 1 FROM auth.users au 
        WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
    );
    
    RETURN QUERY SELECT created, updated, skipped;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Run the sync function:
-- SELECT * FROM sync_all_student_profiles();

-- ============================================
-- QUICK CHECK: See current status
-- ============================================

-- This query shows you exactly what needs to be done:
SELECT 
    'Total Students' as metric,
    COUNT(*)::text as value
FROM students
UNION ALL
SELECT 
    'Students with Auth Users' as metric,
    COUNT(DISTINCT au.id)::text
FROM students s
INNER JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
UNION ALL
SELECT 
    'Students with Profiles' as metric,
    COUNT(DISTINCT p.id)::text
FROM students s
INNER JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email))
UNION ALL
SELECT 
    'Students Needing Auth Users' as metric,
    COUNT(*)::text
FROM students s
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users au 
    WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
)
UNION ALL
SELECT 
    'Students Needing Profiles' as metric,
    COUNT(*)::text
FROM students s
INNER JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = au.id
);
