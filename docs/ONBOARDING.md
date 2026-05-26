# Onboarding allievi (backoffice)

## Modello stato (`students.onboarding_status`)

Colonna testuale in Supabase, mappata su `StudentOnboardingStatus` nel dominio:

| Valore DB           | Significato operativo |
|---------------------|------------------------|
| `pending_review`    | Nuovo iscritto da revisionare (es. prima registrazione app). |
| `awaiting_contact` | Da contattare / richiamare. |
| `awaiting_documents` | Documenti o verifiche mancanti. |
| `approved`          | Accettato dalla scuola, prima dell’avvio operativo del percorso. |
| `active_course`     | Percorso avviato (tipicamente con `registration_status = active`). |
| `suspended` / `completed` | Gestione eccezioni / chiusura flusso onboarding. |

È **complementare** a `registration_status` (pending/active/…): la segreteria usa l’onboarding per il lavoro quotidiano; lo stato legale/iscrizione resta su `registration_status`.

## Come compaiono le nuove iscrizioni da app

1. L’utente completa la registrazione nell’app (Supabase Auth + RPC `register_student_app`).
2. Viene creato il record in `students` con `registration_status = 'pending'` e `onboarding_status = 'pending_review'`.
3. In backoffice, l’allievo compare in elenco (ordinamento: i `pending_review` in cima). Filtri **Nuovi iscritti** / **In attesa** aiutano la coda operativa.

## Flusso suggerito per la segreteria

1. **Nuovi iscritti** (`pending_review`): controllare dati e percorso; usare **Approva iscritto** o segmentare con **Da contattare** / **Documenti mancanti** se serve.
2. **Primo contatto**: dopo la chiamata, **Registra primo contatto** (salva `first_contacted_at`).
3. **Quota**: **Imposta quota iscrizione** se serve un importo atteso (aggiorna `student_financial_summaries`).
4. **Attiva percorso**: quando documenti e condizioni sono ok, **Attiva percorso** (`registration_status = active`, `onboarding_status = active_course`).
5. **Note**: usare note interne / onboarding per tracciare richieste specifiche.

## Audit

Le modifiche di stato rilevanti generano eventi in `backoffice_activity_events` con `event_type = onboardingStatusChanged` (titoli dedicati anche per primo contatto e quota).

## Riferimenti codice

- Dominio: `lib/domain/backoffice/backoffice_enums.dart`, `onboarding_status_mapping.dart`
- Repository: `lib/repositories/backoffice/backoffice_repository.dart`
- UI elenco: `lib/pages/backoffice/school_management_shell_page.dart`
- UI scheda: `lib/widgets/backoffice/student_onboarding_section.dart`
- Migrazione SQL: `supabase/migrations/20260322120000_students_onboarding.sql`
