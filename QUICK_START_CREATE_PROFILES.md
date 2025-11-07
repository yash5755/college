# Quick Start: Create All Student Profiles

This guide will help you create profiles for all 59 students (or however many are missing) in your database.

## Overview

Student profiles require **two things**:
1. **Auth User** (in `auth.users` table) - for login/authentication
2. **Profile** (in `public.profiles` table) - for app data

## Step-by-Step Process

### Step 1: Check Current Status

Open Supabase SQL Editor and run:

```sql
-- See how many students need profiles
SELECT 
    'Total Students' as metric,
    COUNT(*)::text as value
FROM students
UNION ALL
SELECT 
    'Students with Profiles' as metric,
    COUNT(DISTINCT p.id)::text
FROM students s
INNER JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email))
UNION ALL
SELECT 
    'Students Needing Profiles' as metric,
    (COUNT(*) - COUNT(DISTINCT p.id))::text
FROM students s
LEFT JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email));
```

### Step 2: Create Profiles for Students with Auth Users

If some students already have auth users, run this to create their profiles:

```sql
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
```

### Step 3: Get List of Students Needing Auth Users

Run this to see which students need auth users created:

```sql
SELECT 
    s.usn,
    s.name,
    s.email,
    s.usn || '@VVCE2024' as password
FROM students s
WHERE s.email IS NOT NULL 
  AND s.usn IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM auth.users au 
      WHERE LOWER(TRIM(au.email)) = LOWER(TRIM(s.email))
  )
ORDER BY s.usn;
```

### Step 4: Create Auth Users via Supabase Dashboard

**Option A: Import CSV (Recommended for 59+ students)**

1. Export the query results from Step 3 to CSV
2. Go to: **Supabase Dashboard → Authentication → Users**
3. Click **"Add User" → "Import Users"**
4. Upload your CSV file with columns: `email`, `password`
5. Wait for import to complete

**Option B: Create Users One by One (Only if < 10 students)**

1. Go to: **Supabase Dashboard → Authentication → Users**
2. Click **"Add User"**
3. Enter email and password (format: `USN@VVCE2024`)
4. Click **"Create User"**
5. Repeat for each student

### Step 5: Create Profiles After Auth Users Are Created

After importing auth users, run **Step 2 again** to create profiles for the newly created auth users.

### Step 6: Verify All Profiles Are Created

Run this to check if all students now have profiles:

```sql
SELECT 
    s.usn,
    s.name,
    CASE 
        WHEN p.id IS NULL THEN '❌ Still Missing Profile'
        ELSE '✅ Profile Created'
    END as status
FROM students s
LEFT JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email))
WHERE p.id IS NULL
ORDER BY s.usn;
```

If this query returns 0 rows, **all profiles are created!** ✅

## Alternative: Use the Complete SQL Script

For a more automated approach, use the complete script:
- File: `supabase/CREATE_ALL_STUDENT_PROFILES.sql`
- This includes all queries and helper functions

## Troubleshooting

**Q: I get an error "duplicate key value violates unique constraint"**
- A: Some profiles already exist. The script uses `ON CONFLICT` to handle this safely.

**Q: How do I know which students still need profiles?**
- A: Run Step 6 query to see the list.

**Q: Can I create auth users directly via SQL?**
- A: No, Supabase doesn't allow direct SQL inserts into `auth.users` for security. You must use the Dashboard or Admin API.

**Q: I have 500+ students, is there a faster way?**
- A: Yes! Use the CSV import method (Step 4, Option A). It can handle thousands of users at once.

## Quick Reference

- **Check status**: Run Step 1 query
- **Create profiles**: Run Step 2 query (after auth users exist)
- **Get list for import**: Run Step 3 query
- **Import auth users**: Use Supabase Dashboard
- **Verify**: Run Step 6 query

