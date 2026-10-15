# Cinema project database

This repository contains a PostgreSQL database structure for a cinema system.
It supports a movie catalog, screening schedules, seat selection, bookings,
payments, digital tickets, favorites and booking notifications.

## Files

- `project.sql` — tables, data types, keys, relationships and constraints.
- `database-diagram.png` — ER diagram image ready for submission.
- `database-diagram.svg` — scalable version of the same diagram.
- `generate-diagram.ps1` — recreates the diagram directly from the SQL file.

## Main design decisions

- A user's birth date is stored instead of their changing age.
- Passwords are represented by `password_hash`; plain-text passwords are never stored.
- Movies and cinema facilities can be hidden with `is_active` without deleting history.
- One movie can have several genres through the `movie_genres` table.
- Each seat belongs to one hall, and each screening belongs to one hall and movie.
- `UNIQUE (screening_id, seat_id)` prevents the same seat from being sold twice
  for one screening.
- Nullable fields are used only when a value may genuinely be absent, for example
  subtitles, payment completion time or booking cancellation time.

## Regenerating the diagram

Run the following command from the repository folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate-diagram.ps1
```

The script reads the actual `CREATE TABLE` and `REFERENCES` declarations in
`project.sql`; the diagram is not maintained separately by hand.

