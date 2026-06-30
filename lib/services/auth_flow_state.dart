import 'package:flutter/foundation.dart';

/// Segnala una registrazione studente in corso.
///
/// Tra `auth.signUp` e `applyStudentSession` la sessione Supabase esiste già
/// ma la riga `students` non è ancora idratata: in quella finestra
/// [AppAuthGate] vedrebbe un utente autenticato "senza studente/staff" e
/// forzerebbe il logout (race condition → ritorno alla Welcome dopo una
/// registrazione in realtà riuscita).
///
/// Il gate consulta questo flag per attendere (loading) invece di sloggare.
final ValueNotifier<bool> registrationInProgress = ValueNotifier<bool>(false);

/// Segnala un login email/password in corso.
///
/// Supabase emette l'evento auth appena `signInWithPassword` crea la sessione,
/// prima che il repository abbia idratato `studentSession` o risolto il ruolo
/// staff. In quella finestra il gate deve attendere, non sloggare.
final ValueNotifier<bool> loginInProgress = ValueNotifier<bool>(false);

bool get authFlowInProgress =>
    registrationInProgress.value || loginInProgress.value;
