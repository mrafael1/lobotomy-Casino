import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { MetaState, RunState, EndingType, UpgradeId } from '../game/types';
import { bankRunToMeta } from '../game/endings';
import { UPGRADE_MAP } from '../content/upgrades';
import { CONSUMABLE_MAP, MAX_CONSUMABLE_SLOTS, MAX_CONSUMABLE_CHARGES_PER_SLOT } from '../content/consumables';
import { storage } from '../persistence/storage';

export interface MetaStore extends MetaState {
  bankRun: (run: RunState, ending: EndingType) => void;
  buyUpgrade: (upgradeId: UpgradeId) => void;
  buyConsumableCharge: (consumableId: string) => void;
  getPendingConsumables: () => Partial<Record<string, number>>;
}

const INITIAL_META_STATE: MetaState = {
  schemaVersion:      2,
  lucidityWallet:     0,
  ownedPermanents:    [],
  corruptionEverUsed: false,
  endingsReached:     [],
  pendingConsumables: {},
  history: {
    runsPlayed:   0,
    bestScoreRun: 0,
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
          pendingConsumables: state.pendingConsumables,
          history:            state.history,
        };
        const next = bankRunToMeta(run, metaSnapshot, ending);
        set({ ...next, pendingConsumables: {} });
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

      buyConsumableCharge(consumableId: string): void {
        const state = get();
        const consumable = CONSUMABLE_MAP[consumableId];
        if (!consumable) return;
        if (state.lucidityWallet < consumable.shopCost) return;

        const currentCharges = state.pendingConsumables[consumableId] ?? 0;
        if (currentCharges >= MAX_CONSUMABLE_CHARGES_PER_SLOT) return;
        if (currentCharges === 0) {
          const distinctSlots = Object.values(state.pendingConsumables).filter(c => (c ?? 0) > 0).length;
          if (distinctSlots >= MAX_CONSUMABLE_SLOTS) return;
        }

        set({
          lucidityWallet: state.lucidityWallet - consumable.shopCost,
          pendingConsumables: {
            ...state.pendingConsumables,
            [consumableId]: (state.pendingConsumables[consumableId] ?? 0) + 1,
          },
        });
      },

      getPendingConsumables(): Partial<Record<string, number>> {
        return get().pendingConsumables;
      },
    }),
    {
      name:    'lobotomy-meta',
      storage: mmkvStorage,
    },
  ),
);
