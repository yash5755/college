# Bulk Create Student Profiles Guide

You have 500+ students in the `students` table but they don't have corresponding profiles. Here are the best ways to create profiles for all of them:

## Option 1: Using Supabase Admin API (Recommended for 500+ students)

This is the fastest and most reliable method for bulk creating profiles.

### Step 1: Get Your Service Role Key
1. Go to Supabase Dashboard → Settings → API
2. Copy your **Service Role Key** (keep this secret!)

### Step 2: Create a Script

Create a file `bulk_create_profiles.js` (Node.js) or use Python:

```javascript
// bulk_create_profiles.js
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'YOUR_SUPABASE_URL';
const supabaseServiceKey = 'YOUR_SERVICE_ROLE_KEY'; // Keep this secret!

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createProfiles() {
  // Get all students
  const { data: students, error: studentsError } = await supabase
    .from('students')
    .select('*');
  
  if (studentsError) {
    console.error('Error fetching students:', studentsError);
    return;
  }
  
  console.log(`Found ${students.length} students`);
  
  // Process in batches of 50
  const batchSize = 50;
  let created = 0;
  let skipped = 0;
  let errors = 0;
  
  for (let i = 0; i < students.length; i += batchSize) {
    const batch = students.slice(i, i + batchSize);
    
    for (const student of batch) {
      try {
        const email = student.email?.trim();
        const usn = student.usn?.trim();
        
        if (!email) {
          console.log(`Skipping ${usn}: No email`);
          skipped++;
          continue;
        }
        
        // Check if profile already exists
        const { data: existingProfile } = await supabase
          .from('profiles')
          .select('id')
          .or(`usn.eq.${usn},email.eq.${email}`)
          .single();
        
        if (existingProfile) {
          console.log(`Profile already exists for ${usn}`);
          skipped++;
          continue;
        }
        
        // Create auth user
        const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
          email: email,
          password: `${usn}@VVCE2024`, // Default password - students should change this
          email_confirm: true, // Auto-confirm email
          user_metadata: {
            role: 'student',
            display_name: student.name,
            usn: usn,
            department: student.department,
            year: parseInt(student.semester) || null,
          }
        });
        
        if (authError) {
          console.error(`Error creating auth user for ${usn}:`, authError.message);
          errors++;
          continue;
        }
        
        // Create profile (trigger should do this, but we'll ensure it)
        const { error: profileError } = await supabase
          .from('profiles')
          .upsert({
            id: authUser.user.id,
            email: email,
            name: student.name,
            usn: usn,
            phone: student.phone,
            department: student.department,
            role: 'student',
            year: parseInt(student.semester) || null,
          });
        
        if (profileError) {
          console.error(`Error creating profile for ${usn}:`, profileError.message);
          errors++;
        } else {
          created++;
          console.log(`✓ Created profile for ${usn} (${created}/${students.length})`);
        }
        
        // Small delay to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 100));
      } catch (error) {
        console.error(`Error processing ${student.usn}:`, error.message);
        errors++;
      }
    }
    
    console.log(`Batch ${Math.floor(i / batchSize) + 1} completed. Created: ${created}, Skipped: ${skipped}, Errors: ${errors}`);
  }
  
  console.log(`\n=== Final Results ===`);
  console.log(`Total students: ${students.length}`);
  console.log(`Created: ${created}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Errors: ${errors}`);
}

createProfiles();
```

### Step 3: Run the Script

```bash
npm install @supabase/supabase-js
node bulk_create_profiles.js
```

## Option 2: Using SQL Function (If you have admin access)

Run this in Supabase SQL Editor:

```sql
-- This function creates profiles for students that have matching auth users
-- Note: You still need to create auth users first using Admin API or manually

CREATE OR REPLACE FUNCTION sync_student_profiles()
RETURNS TABLE(created_count INT, updated_count INT) AS $$
DECLARE
    student_record RECORD;
    auth_user_record RECORD;
    created INT := 0;
    updated INT := 0;
BEGIN
    FOR student_record IN 
        SELECT usn, name, email, phone, department, semester, section
        FROM students
        WHERE usn IS NOT NULL AND email IS NOT NULL
    LOOP
        -- Find matching auth user by email
        SELECT * INTO auth_user_record
        FROM auth.users
        WHERE email = student_record.email
        LIMIT 1;
        
        IF FOUND THEN
            -- Check if profile exists
            IF EXISTS(SELECT 1 FROM profiles WHERE id = auth_user_record.id) THEN
                -- Update existing profile
                UPDATE profiles SET
                    name = student_record.name,
                    usn = student_record.usn,
                    phone = student_record.phone,
                    department = student_record.department,
                    year = CAST(student_record.semester AS INTEGER)
                WHERE id = auth_user_record.id;
                updated := updated + 1;
            ELSE
                -- Create new profile
                INSERT INTO profiles (id, email, name, usn, phone, department, role, year)
                VALUES (
                    auth_user_record.id,
                    student_record.email,
                    student_record.name,
                    student_record.usn,
                    student_record.phone,
                    student_record.department,
                    'student',
                    CAST(student_record.semester AS INTEGER)
                );
                created := created + 1;
            END IF;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT created, updated;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Run the function
SELECT * FROM sync_student_profiles();
```

## Option 3: Using the Flutter App (For smaller batches)

1. Navigate to Admin Dashboard
2. Click "Bulk Create Profiles"
3. Click "Create Profiles for All Students"
4. The app will process students in batches of 10

**Note**: This method requires auth users to already exist. It's slower but safer for testing.

## Recommended Approach

For 500+ students, use **Option 1 (Admin API)** because:
- ✅ Fastest (can process 50+ per minute)
- ✅ Creates both auth users and profiles
- ✅ Handles errors gracefully
- ✅ Can be run multiple times safely (skips existing)

## After Creating Profiles

1. Students can log in with:
   - Email: Their email from students table
   - Password: `{USN}@VVCE2024` (they should change this)

2. Verify profiles were created:
```sql
SELECT COUNT(*) FROM profiles WHERE role = 'student';
```

3. Check for any missing:
```sql
SELECT s.usn, s.name, s.email
FROM students s
LEFT JOIN profiles p ON s.usn = p.usn OR s.email = p.email
WHERE p.id IS NULL;
```

