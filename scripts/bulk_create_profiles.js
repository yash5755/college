/**
 * Bulk Create Student Profiles Script
 * 
 * This script creates auth users and profiles for all students in the students table.
 * 
 * Setup:
 * 1. Install Node.js dependencies: npm install @supabase/supabase-js
 * 2. Set your Supabase URL and Service Role Key below
 * 3. Run: node scripts/bulk_create_profiles.js
 * 
 * IMPORTANT: Keep your Service Role Key secret! Never commit it to git.
 */

const { createClient } = require('@supabase/supabase-js');

// ============================================
// CONFIGURATION - UPDATE THESE VALUES
// ============================================
const SUPABASE_URL = 'YOUR_SUPABASE_URL'; // e.g., 'https://xxxxx.supabase.co'
const SUPABASE_SERVICE_ROLE_KEY = 'YOUR_SERVICE_ROLE_KEY'; // Get from Supabase Dashboard → Settings → API

// ============================================
// SCRIPT
// ============================================

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function bulkCreateProfiles() {
  console.log('🚀 Starting bulk profile creation...\n');

  // Step 1: Get all students
  console.log('📋 Fetching students from database...');
  const { data: students, error: studentsError } = await supabase
    .from('students')
    .select('*')
    .order('usn');

  if (studentsError) {
    console.error('❌ Error fetching students:', studentsError);
    return;
  }

  if (!students || students.length === 0) {
    console.log('⚠️  No students found in database');
    return;
  }

  console.log(`✓ Found ${students.length} students\n`);

  // Step 2: Get existing profiles to skip
  console.log('📋 Checking existing profiles...');
  const { data: existingProfiles } = await supabase
    .from('profiles')
    .select('usn, email')
    .eq('role', 'student');

  const existingUsns = new Set(
    existingProfiles?.map(p => p.usn?.trim()).filter(Boolean) || []
  );
  const existingEmails = new Set(
    existingProfiles?.map(p => p.email?.trim()).filter(Boolean) || []
  );

  console.log(`✓ Found ${existingProfiles?.length || 0} existing profiles\n`);

  // Step 3: Filter students needing profiles
  const studentsNeedingProfiles = students.filter(student => {
    const usn = student.usn?.trim();
    const email = student.email?.trim();
    return usn && email && 
           !existingUsns.has(usn) && 
           !existingEmails.has(email);
  });

  console.log(`📊 Statistics:`);
  console.log(`   Total students: ${students.length}`);
  console.log(`   Already have profiles: ${students.length - studentsNeedingProfiles.length}`);
  console.log(`   Need profiles: ${studentsNeedingProfiles.length}\n`);

  if (studentsNeedingProfiles.length === 0) {
    console.log('✅ All students already have profiles!');
    return;
  }

  // Step 4: Create profiles in batches
  const batchSize = 20; // Process 20 at a time
  let created = 0;
  let skipped = 0;
  let errors = 0;
  const errorList = [];

  console.log(`🔄 Processing ${studentsNeedingProfiles.length} students in batches of ${batchSize}...\n`);

  for (let i = 0; i < studentsNeedingProfiles.length; i += batchSize) {
    const batch = studentsNeedingProfiles.slice(i, i + batchSize);
    const batchNum = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(studentsNeedingProfiles.length / batchSize);

    console.log(`\n📦 Batch ${batchNum}/${totalBatches} (${batch.length} students)...`);

    for (const student of batch) {
      try {
        const email = student.email?.trim();
        const usn = student.usn?.trim();
        const name = student.name?.trim() || '';
        const phone = student.phone?.trim() || '';
        const department = student.department?.trim() || '';
        const semester = student.semester?.toString()?.trim() || '';

        if (!email || !usn) {
          skipped++;
          errorList.push(`Skipped: Missing email or USN for ${usn || email || 'unknown'}`);
          continue;
        }

        // Create auth user
        const defaultPassword = `${usn}@VVCE2024`; // Students should change this
        
        const { data: authData, error: authError } = await supabase.auth.admin.createUser({
          email: email,
          password: defaultPassword,
          email_confirm: true, // Auto-confirm email
          user_metadata: {
            role: 'student',
            display_name: name,
            usn: usn,
            department: department,
            year: parseInt(semester) || null,
          }
        });

        if (authError) {
          // Check if user already exists
          if (authError.message?.includes('already registered') || 
              authError.message?.includes('already exists')) {
            // User exists, try to get their ID and create profile
            const { data: existingUser } = await supabase.auth.admin.listUsers();
            const user = existingUser?.users?.find(u => u.email === email);
            
            if (user) {
              // Create/update profile for existing user
              const { error: profileError } = await supabase
                .from('profiles')
                .upsert({
                  id: user.id,
                  email: email,
                  name: name,
                  usn: usn,
                  phone: phone,
                  department: department,
                  role: 'student',
                  year: parseInt(semester) || null,
                });

              if (profileError) {
                errors++;
                errorList.push(`${usn}: Profile creation failed - ${profileError.message}`);
              } else {
                created++;
                process.stdout.write(`✓ ${usn} `);
              }
            } else {
              skipped++;
              errorList.push(`${usn}: Auth user exists but couldn't find ID`);
            }
          } else {
            errors++;
            errorList.push(`${usn}: ${authError.message}`);
          }
          continue;
        }

        // Auth user created successfully, now create/update profile
        const { error: profileError } = await supabase
          .from('profiles')
          .upsert({
            id: authData.user.id,
            email: email,
            name: name,
            usn: usn,
            phone: phone,
            department: department,
            role: 'student',
            year: parseInt(semester) || null,
          });

        if (profileError) {
          errors++;
          errorList.push(`${usn}: Profile creation failed - ${profileError.message}`);
        } else {
          created++;
          process.stdout.write(`✓ ${usn} `);
        }

        // Small delay to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 50));

      } catch (error) {
        errors++;
        const usn = student.usn || 'unknown';
        errorList.push(`${usn}: ${error.message}`);
        console.error(`\n❌ Error processing ${usn}:`, error.message);
      }
    }

    // Delay between batches
    if (i + batchSize < studentsNeedingProfiles.length) {
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }

  // Final summary
  console.log('\n\n' + '='.repeat(50));
  console.log('📊 FINAL RESULTS');
  console.log('='.repeat(50));
  console.log(`✅ Created: ${created}`);
  console.log(`⏭️  Skipped: ${skipped}`);
  console.log(`❌ Errors: ${errors}`);
  console.log(`📈 Success rate: ${((created / studentsNeedingProfiles.length) * 100).toFixed(1)}%`);

  if (errorList.length > 0) {
    console.log('\n⚠️  Errors/Warnings:');
    errorList.slice(0, 20).forEach(err => console.log(`   • ${err}`));
    if (errorList.length > 20) {
      console.log(`   ... and ${errorList.length - 20} more`);
    }
  }

  console.log('\n✅ Done!');
  console.log('\n📝 Next steps:');
  console.log('   1. Students can now log in with their email');
  console.log('   2. Default password: {USN}@VVCE2024');
  console.log('   3. Students should change their password on first login');
}

// Run the script
bulkCreateProfiles().catch(console.error);

