-- Fix RLS policies for signup flow
-- Run this in your Supabase SQL Editor

-- First, drop existing policies if they exist (to recreate them cleanly)
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;

-- Recreate the insert policy - allow users to insert their own profile
-- This is needed for the signup flow when the trigger doesn't fire or fails
create policy "profiles_insert_self" on public.profiles
  for insert 
  with check (auth.uid() = id);

-- Recreate the update policy - allow users to update their own profile
create policy "profiles_update_self" on public.profiles
  for update 
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Verify the trigger function exists and is properly set up
-- The trigger should automatically create a profile when a user signs up
-- This function runs with SECURITY DEFINER, so it bypasses RLS
create or replace function public.handle_new_user()
returns trigger 
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role)
  values (
    new.id,
    new.email,
    'student' -- default role, can be updated by the app
  )
  on conflict (id) do nothing; -- Prevent errors if profile already exists
  return new;
end;
$$ language plpgsql;

-- Ensure the trigger exists
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Grant necessary permissions to authenticated users
grant usage on schema public to authenticated;
grant all on public.profiles to authenticated;

