# Stage 05 — Synchronization API

## Pull changes
`GET /v1/health-records/{vault_id}/sync?after=0&limit=200`

Example response:
```json
{
  "changes": [
    {
      "sequence": 1,
      "record_id": "opaque-uuid",
      "version": 1,
      "operation": "upsert",
      "created_at": "2026-11-02T08:00:00+00:00"
    }
  ],
  "next_cursor": 1,
  "has_more": false
}
```

## Semantics
- Cursor is a monotonically increasing sequence within the server's sync journal.
- Cursor is scoped to the authenticated patient and vault.
- `upsert` means fetch the indicated encrypted record version.
- `delete` means apply a local tombstone for the indicated record version.
- The endpoint is read-only and contains no plaintext clinical content.
- A client should persist `next_cursor` only after applying all changes in the page.
- Replaying a page is safe if the client applies changes idempotently.
- The journal currently uses relational database rows; retention/compaction and cursor-expiry behavior must be designed before production.
