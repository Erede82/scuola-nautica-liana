# Tassonomia corso: percorso iscrizione vs moduli contenuto

## Due assi distinti

1. **Percorso di iscrizione / course track** (`EnrollmentCoursePath`)  
   Scelta in segreteria o in onboarding: cosa ha “comprato” / segue l’allievo come pacchetto didattico.
   - `entro_12_miglia` — Entro 12 miglia  
   - `d1` — D1  
   - `entro_12_miglia_vela` — Entro 12 miglia **+** Vela (percorso misto reale, anche se i contenuti vela possono essere ancora parziali)

   In Supabase: colonna `students.enrolled_course_path` (stringa stabile: `entro_12_miglia`, `d1`, `entro_12_miglia_vela`).

2. **Moduli di contenuto app** (`ContentModuleId`)  
   Aree dell’app dove vivono quiz, lezioni, esami, ripasso (possono essere più di uno per lo stesso studente).
   - `motore_entro_12` — allineato oggi al catalogo `LicenseCategoryId.motore`  
   - `d1`  
   - `vela`  

   Le tabelle di unlock/accesso possono continuare a usare `license_category` (`motore` / `vela` / `d1`) finché non si introduce una colonna dedicata `content_module`.

## Mappa percorso → moduli

Definita in **`lib/domain/enrollment_content_mapping.dart`** (`EnrollmentContentMapping.contentModulesForPath`):

| Percorso iscrizione      | Moduli contenuto                         |
|-------------------------|-------------------------------------------|
| `entro_12_miglia`       | `motore_entro_12`                         |
| `d1`                    | `d1`                                      |
| `entro_12_miglia_vela` | `motore_entro_12` + `vela`                |

## Percorso misto senza ridisegno

- Il percorso **`entro_12_miglia_vela`** esiste già come valore di iscrizione.
- I contenuti **vela** possono essere completati in iterazioni successive: banca domande, lezioni, flag `isAvailable` in catalogo, ecc.
- Finché il modulo vela è incompleto, l’UI può mostrare **“Coming soon”** usando i metadati del catalogo (`LicenseCategory`), senza cambiare il modello di iscrizione.

## Estensioni future

- **Nuovi percorsi**: aggiungere un valore a `EnrollmentCoursePath` + relativo valore in `EnrollmentCoursePathStorage` e migrazione SQL `CHECK`.
- **Nuovi moduli**: aggiungere `ContentModuleId`, aggiornare `contentModulesForPath` e (se serve) il mapping verso `LicenseCategoryId`.
- **Supabase**: nuove colonne o tabelle di mapping solo se servono query lato server; la logica centrale di derivazione resta in **`EnrollmentContentMapping`**.
