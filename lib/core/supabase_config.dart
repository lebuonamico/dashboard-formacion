/// Datos de conexión al proyecto de Supabase "dashboard-formacion".
///
/// La publishable key es pública por diseño: se puede usar en la app y subir
/// al repo. Lo que protege los datos son las políticas RLS de cada tabla.
/// NUNCA pongas acá la secret key (sb_secret_...).
class SupabaseConfig {
  static const url = 'https://xlpiuqtjrdtjqorithnm.supabase.co';
  static const publishableKey = 'sb_publishable_9sirI5rNbOXEzdCWMJ5Fcg_HKXgCTBx';
}
