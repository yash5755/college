# Create Profiles for All Students - Simple Instructions

You have all students in the `students` table. Here's how to create profiles for ALL of them.

## Method 1: Using SQL Only (Recommended if you have some auth users already)

### Step 1: Run the SQL Script

Open **Supabase SQL Editor** and run this file:
- `supabase/CREATE_ALL_PROFILES_SIMPLE.sql`

This will:
1. ✅ Create profiles for students who already have auth users
2. 📊 Show you how many students still need auth users
3. 📋 Give you a list to create auth users

### Step 2: Create Auth Users for Remaining Students

If there are students without auth users:

1. **Export the query results** from Step 3 of the SQL script (the list of students needing auth users)

2. **Go to Supabase Dashboard:**
   - Navigate to: **Authentication → Users**
   - Click **"Add User" → "Import Users"**

3. **Create a CSV file** with these columns:
   ```
   email,password,user_metadata
   VVCE24CSE0402@VVCE.AC.IN,4TV24CS001@VVCE2024,"{""role"":""student"",""usn"":""4TV24CS001""}"
   ```

4. **Import the CSV** in Supabase Dashboard

5. **Run Step 1 of the SQL script again** to create profiles for the newly imported auth users

---

## Method 2: Using Node.js Script (Automated - Creates Everything)

If you want to automate everything (creates auth users AND profiles):

### Prerequisites:
- Node.js installed
- Supabase Service Role Key (get from: Supabase Dashboard → Settings → API)

### Steps:

1. **Install dependencies:**
   ```bash
   cd vvceapp
   npm install @supabase/supabase-js
   ```

2. **Edit the script:**
   - Open `scripts/bulk_create_profiles.js`
   - Replace `YOUR_SUPABASE_URL` with your Supabase project URL
   - Replace `YOUR_SERVICE_ROLE_KEY` with your Service Role Key

3. **Run the script:**
   ```bash
   node scripts/bulk_create_profiles.js
   ```

This script will:
- ✅ Create auth users for all students
- ✅ Create profiles for all students
- ✅ Skip students that already have profiles
- ✅ Show progress and results

---

## Quick Check: Verify All Profiles Are Created

Run this query in Supabase SQL Editor:

```sql
SELECT 
    COUNT(*) as total_students,
    COUNT(DISTINCT p.id) as students_with_profiles,
    COUNT(*) - COUNT(DISTINCT p.id) as students_missing_profiles
FROM students s
LEFT JOIN public.profiles p ON s.usn = p.usn OR LOWER(TRIM(s.email)) = LOWER(TRIM(p.email));
```

If `students_missing_profiles` is 0, **all profiles are created!** ✅

---

## Which Method Should I Use?

- **Use Method 1 (SQL)** if:
  - You already have some auth users created
  - You prefer using Supabase Dashboard
  - You have < 100 students to process

- **Use Method 2 (Node.js)** if:
  - You want to automate everything
  - You have 100+ students
  - You're comfortable with Node.js
  - You have the Service Role Key

---

## Troubleshooting

**Q: I get "duplicate key" errors**
- A: Some profiles already exist. The script uses `ON CONFLICT` to handle this safely. It's normal.

**Q: How do I get my Service Role Key?**
- A: Supabase Dashboard → Settings → API → Service Role Key (keep this secret!)

**Q: Can I create auth users directly via SQL?**
- A: No, Supabase doesn't allow direct SQL inserts into `auth.users` for security. Use Dashboard or Admin API.

**Q: The script says "already registered" for some users**
- A: Those students already have auth users. The script will create their profiles automatically.

