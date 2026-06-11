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
  takePendingConsumables: () => Partial<Record<string, number>>;
}

const INITIAL_META_STATE: MetaState = {
  schemaVersion:      1,
  lucidityWallet:     0,
  ownedPermanents:    [],
  corruptionEverUsed: false,
  endingsReached:     [],
  pendingConsumables: {},
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
          pendingConsumables: state.pendingConsumables,
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

      buyConsumableCharge(consumableId: string): void {
        const state = get();
        const consumable = CONSUMABLE_MAP[consumableId];
        if (!consumable) return;
        if (state.lucidityWallet < consumable.shopCost) return;

        // Enforce slot cap (max 2 types) and per-slot charge cap (max 2 charges)
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

      takePendingConsumables(): Partial<Record<string, number>> {
        const state = get();
        const pending = state.pendingConsumables;
        set({ pendingConsumables: {} });
        return pending;
      },
    }),
    {
      name:    'lobotomy-meta',
      storage: mmkvStorage,
    },
  ),
);
