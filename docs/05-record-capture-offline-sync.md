# Stage 05 — Record Capture, Offline Storage & Synchronization

**Build:** 0.5.0 foundation  
**Status:** Opaque sync journal and tombstones implemented in the API; Flutter SQLCipher store and AES-GCM codec foundation added. Full app wiring and end-to-end device sync remain pending.

## Implemented in this stage
- Cursor-based encrypted health-record synchronization endpoint.
- Opaque sync journal records for encrypted record upserts and deletions.
- Tombstone events are emitted when a record version is soft-deleted.
- Client can page sync changes with `after`, `limit`, `next_cursor`, and `has_more`.
- Flutter project manifest and dependencies added.
- SQLCipher local database store for encrypted record bytes.
- Local database encryption key is generated independently and held in platform secure storage.
- Flutter AES-256-GCM codec with 96-bit nonce and 128-bit tag.
- Associated data binds ciphertext to vault ID, record ID and version.
- Local sync cursor persistence.
- Immutable local record versions and local tombstone support.

## Sync contract
`GET /v1/health-records/{vault_id}/sync?after={cursor}&limit={1..500}`

The server returns ordered opaque changes:
- `sequence`
- `record_id`
- `version`
- `operation`: `upsert` or `delete`
- `created_at`

The response contains no clinical type, date of service, display label, measurement, diagnosis or plaintext.

Clients should:
1. Read their last committed cursor.
2. Fetch a page of changes.
3. Download each upsert's ciphertext from the record endpoint.
4. Verify the ciphertext hash and decrypt locally.
5. Apply deletions as tombstones locally.
6. Commit the new cursor only after the page is safely applied.
7. Repeat while `has_more` is true.

The client must make page application idempotent. If interrupted, it may replay a page without creating duplicate record versions.

## Conflict policy
The API uses immutable `(record_id, subject, version)` keys. A concurrent attempt to create the same version is rejected with HTTP 409. Clients must not silently overwrite clinical history. A conflict should be resolved by preserving both branches and creating a new reviewed version.

## Important integration boundary
The Flutter codec requires a `VaultDekProvider` backed by the Stage 03 key manager. No default key provider is included; a missing key must fail closed. The SQLCipher database key protects the local database file, while the vault DEK encrypts record payloads. These are separate keys and serve separate purposes.

The repository stores ciphertext only. Its `record_type` and timestamp index are local metadata; production privacy review should decide whether to encrypt or minimize them as well.

## Not yet complete
- Wire the repository into app startup and the records/checkup forms.
- Implement a production VaultDekProvider and test against Python Stage 03 conformance vectors.
- Implement API client authentication, upload/download, retries and cursor-based sync orchestration.
- Add SQLCipher migration, secure database-key rotation and recovery behavior.
- Implement typed create/edit flows for profile, allergies, conditions, medications and observations.
- Convert checkup form submission into a typed EncounterRecord and related ObservationRecords.
- Add encrypted attachment upload and document references.
- Add multi-device conflict UI, tombstone propagation and offline retry queue.
- Run `flutter pub get`, analyzer and tests in a real Flutter SDK environment.
- Perform device-specific key storage and backup-exclusion review.

## Safety
This is a development foundation. Do not use real patient data until Flutter compilation, cryptographic conformance, recovery, backup/restore and security reviews pass.
