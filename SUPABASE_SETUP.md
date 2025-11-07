# Supabase Setup Instructions

## Email Confirmation Issue

If you're getting "Invalid login credentials" after signing up, it's likely because **email confirmation is enabled** in your Supabase project.

### Solution 1: Disable Email Confirmation (For Testing)

1. Go to your Supabase Dashboard
2. Navigate to **Authentication** → **Settings**
3. Scroll down to **Email Auth** section
4. **Disable** "Enable email confirmations"
5. Save the changes

Now users can sign up and log in immediately without email confirmation.

### Solution 2: Keep Email Confirmation Enabled (For Production)

If you want to keep email confirmation enabled:

1. When users sign up, they'll receive a confirmation email
2. They need to click the confirmation link in the email
3. Only after confirming can they log in

The app will now show a clearer error message: **"Please check your email and confirm your account before signing in."**

### Testing Email Confirmation

If you want to test with email confirmation enabled:

1. Sign up with a real email address
2. Check your email inbox (including spam folder)
3. Click the confirmation link
4. Then try logging in

### Check Email Confirmation Status

To check if email confirmation is enabled in your Supabase project:

1. Go to Supabase Dashboard
2. Authentication → Settings
3. Look for "Enable email confirmations" toggle

---

## Other Common Issues

### Users Created but Can't Login

If users are created in `auth.users` but can't log in:
- Check if email confirmation is required (see above)
- Verify the password is correct
- Check Supabase logs for any errors

### Profile Not Created

If the profile isn't created in the `profiles` table:
- Make sure you ran the `reset_database.sql` script
- Check that the trigger `on_auth_user_created` exists
- Verify the trigger function `handle_new_user()` exists

---

## Quick Fix Commands

If you need to manually confirm a user's email in Supabase:

```sql
-- Check user status
SELECT id, email, email_confirmed_at, confirmed_at 
FROM auth.users 
WHERE email = 'your-email@vvce.ac.in';

-- Manually confirm email (only if needed for testing)
UPDATE auth.users 
SET email_confirmed_at = now(), confirmed_at = now()
WHERE email = 'your-email@vvce.ac.in';
```

---

**Note**: For production, always keep email confirmation enabled for security. Only disable it for development/testing purposes.

