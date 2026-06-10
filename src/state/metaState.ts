import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { MetaState, RunState, EndingType, UpgradeId } from '../game/types';
import { bankRunToMeta } from '../game/endings';
import { UPGRADE_MAP } from '../content/upgrades';
import { storage } from '../persistence/storage';

export interface MetaStore extends MetaState {
  bankRun: (run: RunState, ending: EndingType) => void;
  buyUpgrade: (upgradeId: UpgradeId) => void;
}

const INITIAL_META_STATE: MetaState = {
  schemaVersion:      1,
  lucidityWallet:     0,
  ownedPermanents:    [],
  corruptionEverUsed: false,
  endingsReached:     [],
  history: {
    runsPlayed:      0,
    bestLucidityRun: 0,
  },
};

const mmkvStorage = createJSONStorage(() => ({
  getItem:    (name: string) => storage.getString(name) ?? null,
  setItem:    (name: string, value: string) => storage.set(name, value),
  removeItem: (name: string) => storage.delete(name),
}));

export const useMetaStore = create<MetaStore>()(
  persist(
    (set, get) => ({
      ...INITIAL_META_STATE,

      bankRun(run: RunState, ending: EndingType): void {
        const state = get();
        const metaSnapshot: MetaState = {
          schemaVersion:      state.schemaVersion,
          lucidityWallet:     state.lucidityWallet,
          ownedPermanents:    state.ownedPermanents,
          corruptionEverUsed: state.corruptionEverUsed,
          endingsReached:     state.endingsReached,
          history:            state.history,
        };
        const next = bankRunToMeta(run, metaSnapshot, ending);
        set(next);
      },

      buyUpgrade(upgradeId: UpgradeId): void {
        const state = get();
        const upgrade = UPGRADE_MAP[upgradeId];

        if (!upgrade) return;
        if (state.ownedPermanents.includes(upgradeId)) return;
        if (upgrade.requiresId && !state.ownedPermanents.includes(upgrade.requiresId)) return;
        if (state.lucidityWallet < upgrade.cost) return;

        set({
          lucidityWallet:     state.lucidityWallet - upgrade.cost,
          ownedPermanents:    [...state.ownedPermanents, upgradeId],
          corruptionEverUsed:
            upgrade.category === 'corrupted' ? true : state.corruptionEverUsed,
        });
      },
    }),
    {
      name:    'lobotomy-meta',
      storage: mmkvStorage,
    },
  ),
);
