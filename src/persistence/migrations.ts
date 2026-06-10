// Save migrations. Add one migration function per schema bump.
// Current schema version: 1 (initial).
// When adding fields in a future update:
//   1. Bump CURRENT_SCHEMA_VERSION
//   2. Add migrate_v1_to_v2(old) → new
//   3. Add an entry to MIGRATIONS

export const CURRENT_SCHEMA_VERSION = 1;

type AnyRecord = Record<string, unknown>;

type MigrationFn = (old: AnyRecord) => AnyRecord;

const MIGRATIONS: Record<number, MigrationFn> = {
  // Example (not yet needed):
  // 1: (old) => ({ ...old, newField: defaultValue, schemaVersion: 2 }),
};

export function migrateRecord(record: AnyRecord): AnyRecord {
  let current = record;
  let version = (current.schemaVersion as number) ?? 0;

  while (version < CURRENT_SCHEMA_VERSION) {
    const migration = MIGRATIONS[version];
    if (!migration) break;
    current = migration(current);
    version = (current.schemaVersion as number);
  }

  return current;
}
