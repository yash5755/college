-- ============================================
-- GENERATE CSV FOR SUPABASE USER IMPORT
-- Run this query and copy the results to a CSV file
-- Then import in Supabase Dashboard → Authentication → Users → Import Users
-- ============================================

-- This generates a CSV format that Supabase can import
-- Format: email,password,user_metadata

SELECT 
    s.email || ',' ||
    s.usn || '@VVCE2024' || ',' ||
    '{"role":"student","usn":"' || s.usn || '","display_name":"' || REPLACE(s.name, '"', '""') || '","department":"' || COALESCE(s.department, '') || '","year":' || COALESCE(s.semester::text, 'null') || '}' as csv_line
FROM students s
WHERE s.email IS NOT NULL 
  AND s.usn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM auth.users au 
      WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
  )
ORDER BY s.usn;

-- ============================================
-- ALTERNATIVE: Generate JSON format for bulk import
-- ============================================

SELECT 
    json_build_object(
        'email', s.email,
        'password', s.usn || '@VVCE2024',
        'user_metadata', json_build_object(
            'role', 'student',
            'usn', s.usn,
            'display_name', s.name,
            'department', s.department,
            'year', CAST(s.semester AS INTEGER)
        )
    ) as user_data
FROM students s
WHERE s.email IS NOT NULL 
  AND s.usn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM auth.users au 
      WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
  )
ORDER BY s.usn
LIMIT 100; -- Test with 100 first

-- ============================================
-- SIMPLE: Just get the list of emails and USNs
-- ============================================

SELECT 
    s.usn,
    s.email,
    s.name,
    s.usn || '@VVCE2024' as suggested_password
FROM students s
WHERE s.email IS NOT NULL 
  AND s.usn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM auth.users au 
      WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
  )
ORDER BY s.usn;

