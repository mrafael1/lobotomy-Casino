import { MMKV } from 'react-native-mmkv';

export const storage = new MMKV({ id: 'lobotomy' });

export const STORAGE_KEYS = {
  GLOBAL_STATE: 'global',
  META_STATE:   'meta',
  SAVE_SLOT:    (id: string) => `slot:${id}`,
  SLOT_BACKUP:  (id: string) => `slot:${id}:backup`,
} as const;
