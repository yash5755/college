-- Create students table for Supabase (PostgreSQL)
CREATE TABLE IF NOT EXISTS students (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  usn VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL,
  phone VARCHAR(100) NOT NULL,
  department VARCHAR(100) NOT NULL,
  semester VARCHAR(5) NOT NULL,
  section VARCHAR(50) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_students_usn ON students(usn);
CREATE INDEX IF NOT EXISTS idx_students_semester_section ON students(semester, section);
CREATE INDEX IF NOT EXISTS idx_students_department ON students(department);

-- ============================================
-- BULK INSERT STUDENTS DATA
-- ============================================
-- Option 1: Use this SQL INSERT statement (paste all 570 students below)
-- Option 2: Use Supabase Table Editor to import CSV (recommended for 570 rows)
-- Option 3: Use Supabase Storage + SQL to import from CSV file

-- INSERT statement format - paste all your students here:
INSERT INTO students (usn, name, email, phone, department, semester, section) VALUES
-- Paste all 570 student records here in this format:
-- ('USN', 'Name', 'Email', 'Phone', 'Department', 'Semester', 'Section'),
-- Example:
('4TV24CS001', 'AATHMIK M S ', 'VVCE24CSE0402@VVCE.AC.IN', '7022377797', 'CSE', '2', 'A'),
('4TV24CS002', 'ABHAY CHANDRA ', 'VVCE24CSE0133@VVCE.AC.IN', '6363794760', 'CSE', '2', 'A'),
('4TV24CS003', 'ABHYUDAYA KRISHNA ', 'VVCE24CSE0126@VVCE.AC.IN', '7996794480', 'CSE', '2', 'A'),
('4TV24CS004', 'ADIL REHAAN F R ', 'VVCE24CSE0019@VVCE.AC.IN', '7204349257', 'CSE', '2', 'A'),
('4TV24CS005', 'ADITHYA A ', 'VVCE24CSE0238@VVCE.AC.IN', '9108746444', 'CSE', '2', 'A'),
('4TV24CS006', 'ADITI CHOUDHARY ', 'VVCE24CSE0049@VVCE.AC.IN', '8431581164', 'CSE', '2', 'A'),
('4TV24CS007', 'ADITI VENKATRAMAN BHAT ', 'VVCE24CSE0096@VVCE.AC.IN', '8762975118', 'CSE', '2', 'A'),
('4TV24CS008', 'ADITYA B K ', 'VVCE24CSE0116@VVCE.AC.IN', '9945684792', 'CSE', '2', 'A'),
('4TV24CS009', 'AISHWARYA A V ', 'VVCE24CSE0360@VVCE.AC.IN', '7975495234', 'CSE', '2', 'A'),
('4TV24CS010', 'AISIRI M ', 'VVCE24CSE0379@VVCE.AC.IN', '8277826565', 'CSE', '2', 'A'),
('4TV24CS011', 'AKASH K B ', 'VVCE24CSE0007@VVCE.AC.IN', '8123179963', 'CSE', '2', 'A'),
('4TV24CS012', 'AKSHAY GUNA S ', 'VVCE24CSE0122@VVCE.AC.IN', '9741982006', 'CSE', '2', 'A'),
('4TV24CS013', 'AKSHAY H S ', 'VVCE24CSE0084@VVCE.AC.IN', '8217752945', 'CSE', '2', 'A'),
('4TV24CS014', 'AKSHAY KUMAR M S ', 'VVCE24CSE0021@VVCE.AC.IN', '6364917807', 'CSE', '2', 'A')
-- ... (paste all remaining 556 students here)
-- Remove the last comma before running
ON CONFLICT (usn) DO NOTHING;

-- Enable Row Level Security (RLS) - adjust policies as needed
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Policy to allow all authenticated users to read students
CREATE POLICY "Allow authenticated users to read students" ON students
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy to allow admins to insert/update/delete
CREATE POLICY "Allow admins to manage students" ON students
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

