// Phase 1: Implement MMKV read/write here.
// Every write should be atomic (serialize entire record at once).
// Keep a last-good backup key per record for crash recovery.

// TODO (Phase 1):
// import { MMKV } from 'react-native-mmkv';
// export const storage = new MMKV({ id: 'lobotomy' });

export const STORAGE_KEYS = {
  GLOBAL_STATE:  'global',
  SAVE_SLOT:     (id: string) => `slot:${id}`,
  SLOT_BACKUP:   (id: string) => `slot:${id}:backup`,
} as const;
