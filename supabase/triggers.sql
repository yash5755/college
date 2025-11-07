-- Database Triggers for Automatic Profile Creation

-- Function to handle new user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, role)
  values (
    new.id,
    new.email,
    'student' -- default role, can be updated by the app
  );
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to automatically create profile when user signs up
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

