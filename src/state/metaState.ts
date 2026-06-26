import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { MetaState, RunState, EndingType, UpgradeId } from '../game/types';
import { bankRunToMeta } from '../game/endings';
import { UPGRADE_MAP } from '../content/upgrades';
import { CONSUMABLE_MAP, MAX_CONSUMABLE_SLOTS, totalConsumableCopies } from '../content/consumables';
import { storage } from '../persistence/storage';

export interface MetaStore extends MetaState {
  bankRun: (run: RunState, ending: EndingType) => void;
  buyUpgrade: (upgradeId: UpgradeId) => void;
  buyConsumableCharge: (consumableId: string) => void;
  discardPendingConsumable: (consumableId: string) => void;
  markEndingReached: (ending: EndingType) => void;
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
  removeItem: (name: string) => { storage.remove(name); },
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

        // Duplicates allowed: only the total-copies cap (stash full) blocks a buy.
        if (totalConsumableCopies(state.pendingConsumables) >= MAX_CONSUMABLE_SLOTS) return;

        set({
          lucidityWallet: state.lucidityWallet - consumable.shopCost,
          pendingConsumables: {
            ...state.pendingConsumables,
            [consumableId]: (state.pendingConsumables[consumableId] ?? 0) + 1,
          },
        });
      },

      // Throw a queued consumable back to the dealer to free a stash slot. The
      // pre-run buy hasn't committed to a run yet, so the Lucidity is refunded
      // (mirrors the in-run throw freeing a slot — here it also undoes the buy).
      discardPendingConsumable(consumableId: string): void {
        const state = get();
        const current = state.pendingConsumables[consumableId] ?? 0;
        if (current <= 0) return;
        const consumable = CONSUMABLE_MAP[consumableId];
        const next = { ...state.pendingConsumables };
        if (current <= 1) delete next[consumableId];
        else next[consumableId] = current - 1;
        set({
          pendingConsumables: next,
          lucidityWallet: state.lucidityWallet + (consumable?.shopCost ?? 0),
        });
      },

      // Record that an ending was reached WITHOUT banking a payout. Used for the
      // wealth screen: the win counts as reached the moment it shows, even if the
      // player Continues and the run later banks as a flatline. Idempotent.
      markEndingReached(ending: EndingType): void {
        const state = get();
        const endingsReached = state.endingsReached.includes(ending)
          ? state.endingsReached
          : ([...state.endingsReached, ending] as MetaState['endingsReached']);
        set({
          endingsReached,
          history: {
            ...state.history,
            wealthEndingReachedAt:
              ending === 'wealth' && !state.history.wealthEndingReachedAt
                ? Date.now()
                : state.history.wealthEndingReachedAt,
            exitEndingReachedAt:
              ending === 'exit' && !state.history.exitEndingReachedAt
                ? Date.now()
                : state.history.exitEndingReachedAt,
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
