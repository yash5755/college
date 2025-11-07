-- ============================================
-- COMPLETE GUIDE: CREATE ALL STUDENT PROFILES
-- Run these queries step by step in Supabase SQL Editor
-- ============================================

-- ============================================
-- STEP 1: CHECK CURRENT STATUS
-- ============================================
-- Run this first to see how many students need profiles

SELECT 
    'Total Students in Database' as metric,
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
    'Students Needing Profiles (Auth exists, Profile missing)' as metric,
    COUNT(*)::text
FROM students s
INNER JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = au.id
);

-- ============================================
-- STEP 2: CREATE PROFILES FOR STUDENTS WITH AUTH USERS
-- ============================================
-- This creates profiles for students who already have auth users
-- Run this NOW if you have some auth users already

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

-- Check how many profiles were created:
SELECT 
    'Profiles created/updated in this run' as metric,
    COUNT(*)::text as value
FROM public.profiles
WHERE role = 'student';

-- ============================================
-- STEP 3: GENERATE CSV FOR AUTH USER IMPORT
-- ============================================
-- Run this query and copy the results to create a CSV file
-- Then import it in Supabase Dashboard → Authentication → Users → Import Users

-- Option A: Generate CSV format (copy all results, paste into Excel/Google Sheets, save as CSV)
SELECT 
    s.email as email,
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

-- Option B: Simple list (easier to read)
SELECT 
    s.usn,
    s.name,
    s.email,
    s.usn || '@VVCE2024' as password,
    s.semester,
    s.section
FROM students s
WHERE s.email IS NOT NULL 
  AND s.usn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM auth.users au 
      WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
  )
ORDER BY s.usn;

-- ============================================
-- STEP 4: AFTER IMPORTING AUTH USERS, RUN STEP 2 AGAIN
-- ============================================
-- After you import auth users via Supabase Dashboard, 
-- run STEP 2 again to create profiles for the newly created auth users

-- ============================================
-- STEP 5: VERIFY ALL PROFILES ARE CREATED
-- ============================================
-- Run this to see which students still don't have profiles

SELECT 
    s.usn,
    s.name,
    s.email,
    s.semester,
    s.section,
    CASE 
        WHEN au.id IS NULL THEN '❌ Needs Auth User - Import via Dashboard'
        WHEN p.id IS NULL THEN '⚠️ Auth User Exists, Profile Missing - Run STEP 2 again'
        ELSE '✅ Complete'
    END as status
FROM students s
LEFT JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
LEFT JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email))
WHERE p.id IS NULL
ORDER BY s.usn;

-- ============================================
-- QUICK REFERENCE: How to Import Auth Users
-- ============================================
-- 
-- METHOD 1: Supabase Dashboard (Recommended)
-- 1. Go to: Supabase Dashboard → Authentication → Users
-- 2. Click "Add User" → "Import Users"
-- 3. Use the CSV from STEP 3 (columns: email, password, user_metadata)
-- 4. Import the CSV
-- 5. After import, run STEP 2 again to create profiles
--
-- METHOD 2: Supabase Admin API (for automation)
-- Use the JavaScript script in: scripts/bulk_create_profiles.js
-- This requires service_role key and can create users programmatically
--
-- ============================================
-- HELPER FUNCTION: Sync all profiles (optional)
-- ============================================
-- This function can be called anytime to sync profiles

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

-- To use the sync function:
-- SELECT * FROM sync_all_student_profiles();

