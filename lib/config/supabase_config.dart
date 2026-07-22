/// Supabase connection settings.
///
/// The anon key is a public client key by design — it is safe to ship inside
/// the app. Never place the service_role key or the database password here.
class SupabaseConfig {
  static const String url = 'https://rgsusuzhepuzzlbennri.supabase.co';

  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJnc3VzdXpoZXB1enpsYmVubnJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NjEwMjcsImV4cCI6MjEwMDIzNzAyN30.LIb3ZeYWbox5YV_6fT3pJppNoc1ofDwFPu7RZXXAODA';
}
