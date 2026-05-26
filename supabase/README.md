# Supabase — Scuola Nautica Liana

## Contenuto

- `migrations/` — SQL versionati (Postgres) per progetto Supabase collegato.
- `functions/create-student-app-access/` — Edge Function per credenziali app allievo da backoffice (vedi `docs/STUDENT_APP_ACCESS_BACKOFFICE.md`).

## Uso rapido

```bash
# se usi Supabase CLI localmente
supabase start
supabase db reset
```

In alternativa, copiare il file in **SQL Editor** del dashboard Supabase ed eseguirlo una volta per ambiente.

## Documentazione dominio / mapping

Vedi **`docs/BACKOFFICE_SUPABASE.md`** nella root del package Flutter.
