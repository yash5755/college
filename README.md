# VVCE College Management – Flutter + Supabase

This app implements the VVCE College Management System using Flutter and Supabase per the PRD.

## Supabase Setup

1) Create a new Supabase project. Get your Project URL and anon public key.

2) Apply database schema and policies:

```bash
psql "$SUPABASE_DB_URL" -f supabase/schema.sql
psql "$SUPABASE_DB_URL" -f supabase/policies.sql
```

Alternatively, paste `supabase/schema.sql` and `supabase/policies.sql` into the Supabase SQL editor and run them.

3) Configure Flutter with your Supabase credentials via dart-define (recommended):

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_PROJECT_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

You can also set defaults in `lib/core/backend_config.dart`.

## Google Gemini API Setup (Optional)

The app uses Google Gemini for AI-powered features (chatbot and exam allocation). To enable these features:

1. Get your Gemini API key from https://aistudio.google.com/app/apikey

2. Set your API key in one of these ways:

   **Option A: Direct configuration (for development)**
   - Open `lib/core/backend_config.dart`
   - Replace the empty string with your API key:
     ```dart
     const String kGeminiApiKey = 'AIza-your-actual-key-here';
     ```

   **Option B: Environment variable (recommended for production)**
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=AIza-your-actual-key-here
   ```

3. The app will automatically fall back to heuristic algorithms if the API key is not set or invalid.

4. Available models: `gemini-1.5-flash` (default, fast and efficient) or `gemini-pro` (more capable)

## Running the App

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Notes

- Authentication is email/password via Supabase and restricted to `@vvce.ac.in` in the client.
- Core features migrated from Firebase to Supabase: auth, profiles, announcements, events, timetables, rooms, reservations, and exam allocations.
- Real‑time updates use Supabase Realtime streams.
