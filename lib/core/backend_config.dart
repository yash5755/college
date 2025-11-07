// Toggle which backend to use
const bool kUseSupabase = true;

// Supabase configuration
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ajwccvtojrtsmknhcuia.supabase.co');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFqd2NjdnRvanJ0c21rbmhjdWlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMTMxMzUsImV4cCI6MjA3NzU4OTEzNX0.ukjP3ZPa6AniLe1kjwr4HyrbumDml7V8Fa2_vMHxGk8');

// Google Gemini API configuration (optional). If empty, heuristics are used instead of AI
// 
// IMPORTANT: To use Gemini API, set your API key in one of these ways:
// 1. Set environment variable: GEMINI_API_KEY=your-key-here (recommended for production)
// 2. Replace the empty string below with your API key directly (for development)
// 
// To get your API key: https://makersuite.google.com/app/apikey
// Or: https://aistudio.google.com/app/apikey
//
// NOTE: Replace the empty string below with your actual Gemini API key
// Example: const String kGeminiApiKey = 'AIza...';
const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyDoWK4j5hZEhdcFnDlPRkMim_sUHowE-gU');
const String kGeminiModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-pro');

