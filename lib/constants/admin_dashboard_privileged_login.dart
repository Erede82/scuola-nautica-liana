/// Account che può aprire il pannello gestionale lato app se il ruolo DB non è ancora allineato.
///
/// I dati sensibili restano protetti da RLS e `school_user_roles` su Supabase.
abstract final class AdminDashboardPrivilegedLogin {
  static const String email = 'erede82@gmail.com';
}
