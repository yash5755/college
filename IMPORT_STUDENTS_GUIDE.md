# How to Import 570 Students into Supabase

## Option 1: CSV Import (RECOMMENDED - Easiest for 570 rows)

1. **Create a CSV file** with these columns:
   ```
   usn,name,email,phone,department,semester,section
   4TV24CS001,AATHMIK M S,VVCE24CSE0402@VVCE.AC.IN,7022377797,CSE,2,A
   4TV24CS002,ABHAY CHANDRA,VVCE24CSE0133@VVCE.AC.IN,6363794760,CSE,2,A
   ... (all 570 students)
   ```

2. **In Supabase Dashboard:**
   - Go to **Table Editor** → **students** table
   - Click **Insert** → **Import data from CSV**
   - Upload your CSV file
   - Map columns if needed
   - Click **Import**

## Option 2: SQL INSERT (For bulk SQL insertion)

1. **Format your data** like this:
   ```sql
   INSERT INTO students (usn, name, email, phone, department, semester, section) VALUES
   ('4TV24CS001', 'AATHMIK M S', 'VVCE24CSE0402@VVCE.AC.IN', '7022377797', 'CSE', '2', 'A'),
   ('4TV24CS002', 'ABHAY CHANDRA', 'VVCE24CSE0133@VVCE.AC.IN', '6363794760', 'CSE', '2', 'A'),
   -- ... (all 570 students)
   -- IMPORTANT: Remove the last comma before ON CONFLICT
   ON CONFLICT (usn) DO NOTHING;
   ```

2. **Run in Supabase SQL Editor:**
   - Go to **SQL Editor** in Supabase Dashboard
   - Paste the INSERT statement
   - Click **Run**

## Option 3: Batch Insert (For very large datasets)

If you have issues with a single large INSERT, split into batches of 100:

```sql
-- Batch 1 (rows 1-100)
INSERT INTO students (usn, name, email, phone, department, semester, section) VALUES
-- ... first 100 students
ON CONFLICT (usn) DO NOTHING;

-- Batch 2 (rows 101-200)
INSERT INTO students (usn, name, email, phone, department, semester, section) VALUES
-- ... next 100 students
ON CONFLICT (usn) DO NOTHING;

-- Continue for all batches...
```

## Tips:

- **Escape single quotes** in names: `'O''Brien'` → `'O''Brien'`
- **Remove trailing commas** before `ON CONFLICT`
- **CSV import is fastest** for 570 rows
- **ON CONFLICT (usn) DO NOTHING** prevents duplicate errors if you run it multiple times

