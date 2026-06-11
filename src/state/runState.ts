import { create } from 'zustand';
import type { RunState, SpinResult, UpgradeId, EndingType } from '../game/types';
import { evaluate } from '../game/evaluate';
import { applySwap, applyMoveColumn } from '../game/abilities';
import { createRNG } from '../game/rng';
import {
  computeNeuronDecay,
  computeStartingNeurons,
  computeLucidityMultiplier,
  computeMaxFreeSpins,
} from '../game/economy';
import { ECONOMY } from '../content/economy';
import { CONSUMABLE_MAP } from '../content/consumables';
import { ABILITIES } from '../content/abilities';

export type RunPhase = 'idle' | 'running' | 'over';

// Returned by buyConsumable so the UI knows whether to enter reel-pick mode.
export type ConsumablePurchase = 'applied' | 'needsReelPick' | 'rejected';

export interface RunStore extends RunState {
  runPhase: RunPhase;
  lastEnding: EndingType | null;
  decaySkips: number;        // Stasis Patch: spins remaining that cost 0 neurons
  pendingLockPayment: number; // cons_reel_lock cost held until lockReel() confirms

  spin: () => SpinResult | null;
  setSpinning: (v: boolean) => void;
  setBetMultiplier: (m: 1 | 2 | 3) => void;
  startNewRun: (ownedPermanents: ReadonlyArray<UpgradeId>) => void;
  endRun: (ending: EndingType) => void;

  buyConsumable: (consumableId: string) => ConsumablePurchase;
  lockReel: (reelIndex: number) => void;

  swapReels: (i: number, j: number) => boolean;
  moveReel: (reelIndex: number, direction: -1 | 1) => boolean;
  buyOverrideFreeSpin: () => boolean;
}

const INITIAL_RUN_STATE: RunState = {
  neurons:                    0,
  startingNeurons:            0,
  lucidityEarned:             0,
  freeSpinsRemaining:         0,
  maxFreeSpins:               ECONOMY.BASE_MAX_FREE_SPINS,
  lucidityMultiplier:         ECONOMY.BASE_LUCIDITY_MULTIPLIER,
  nextSpinLucidityMultiplier: 1.0,
  isSpinning:                 false,
  lastResult:                 null,
  lockedReels:                [false, false, false],
  activeAbilities:            [],
  ownedConsumables:           [],
  ownedUpgrades:              [],
  spinCount:                  0,
  isFreeSpin:                 false,
  betMultiplier:              1,
};

// Abilities and consumables are paid with THIS-RUN Lucidity, not the wallet.
// Spending it lowers what banks at run end — that's the trade.
function canAct(state: RunStore, cost: number): boolean {
  return (
    state.runPhase === 'running' &&
    !state.isSpinning &&
    state.lucidityEarned >= cost
  );
}

export const useRunStore = create<RunStore>((set, get) => ({
  ...INITIAL_RUN_STATE,
  runPhase: 'idle',
  lastEnding: null,
  decaySkips: 0,
  pendingLockPayment: 0,

  spin(): SpinResult | null {
    const state = get();

    // Free spins bypass neuron cost; paid spins need >= 1 neuron (remainder rule)
    const isFreeSpin = state.freeSpinsRemaining > 0;
    if (state.runPhase !== 'running' || state.isSpinning) return null;
    if (!isFreeSpin && state.neurons < 1) return null;

    const seed = ((Date.now() ^ (state.spinCount * 0x9e3779b9)) >>> 0);
    const rng = createRNG(seed);

    // Stasis Patch: paid spins cost 0 neurons while skips remain.
    // Free spins don't consume a skip — they're already free.
    const stasisActive = !isFreeSpin && state.decaySkips > 0;
    // Bet multiplier scales neuron cost; "use the rest" caps it at available neurons
    const baseDecay = computeNeuronDecay(state.ownedUpgrades);
    const neuronDecayAmount = stasisActive
      ? 0
      : Math.min(state.betMultiplier * baseDecay, state.neurons);

    // Bet multiplier also scales payout
    const effectiveMultiplier =
      state.lucidityMultiplier * state.nextSpinLucidityMultiplier * state.betMultiplier;

    const result = evaluate({
      neurons:            state.neurons,
      neuronDecayAmount,
      freeSpinsRemaining: state.freeSpinsRemaining,
      maxFreeSpins:       state.maxFreeSpins,
      lucidityMultiplier: effectiveMultiplier,
      isFreeSpin,
      lockedReels:        state.lockedReels,
      previousReels:      state.lastResult?.reels ?? null,
      rng,
    });

    // runPhase stays 'running' during the animation. GameScreen transitions
    // to 'over' in handleAllReelsDone, after the last reel settles.
    set({
      neurons:                    result.neuronsAfter,
      lucidityEarned:             state.lucidityEarned + result.lucidityEarned,
      freeSpinsRemaining:         result.freeSpinsAfter,
      isFreeSpin:                 result.isFreeSpin,
      isSpinning:                 true,
      lastResult:                 result,
      spinCount:                  state.spinCount + 1,
      nextSpinLucidityMultiplier: 1.0,
      lockedReels:                [false, false, false], // reel locks are single-use
      decaySkips:                 stasisActive ? state.decaySkips - 1 : state.decaySkips,
      pendingLockPayment:         0, // abandoned lock pick — no charge
    });

    return result;
  },

  setSpinning(v: boolean): void {
    set({ isSpinning: v });
  },

  setBetMultiplier(m: 1 | 2 | 3): void {
    set({ betMultiplier: m });
  },

  startNewRun(ownedPermanents: ReadonlyArray<UpgradeId>): void {
    const startingNeurons = computeStartingNeurons(ownedPermanents);
    const lucidityMultiplier = computeLucidityMultiplier(ownedPermanents);
    const maxFreeSpins = computeMaxFreeSpins(ownedPermanents);

    set({
      ...INITIAL_RUN_STATE,
      neurons:          startingNeurons,
      startingNeurons:  startingNeurons,
      lucidityMultiplier,
      maxFreeSpins,
      ownedUpgrades:      ownedPermanents,
      runPhase:           'running',
      lastEnding:         null,
      decaySkips:         0,
      pendingLockPayment: 0,
    });
  },

  endRun(ending: EndingType): void {
    set({ runPhase: 'over', lastEnding: ending });
  },

  buyConsumable(consumableId: string): ConsumablePurchase {
    const state = get();
    const consumable = CONSUMABLE_MAP[consumableId];
    if (!consumable || !canAct(state, consumable.cost)) return 'rejected';

    const effect = consumable.effect;
    const paid = state.lucidityEarned - consumable.cost;

    switch (effect.type) {
      case 'skipDecay':
        set({ lucidityEarned: paid, decaySkips: state.decaySkips + effect.spins });
        return 'applied';

      case 'grantFreeSpins':
        // Reject rather than charge for nothing when already at cap
        if (state.freeSpinsRemaining >= state.maxFreeSpins) return 'rejected';
        // Clamped to maxFreeSpins on every write (§4 of arch doc)
        set({
          lucidityEarned: paid,
          freeSpinsRemaining: Math.min(
            state.freeSpinsRemaining + effect.amount,
            state.maxFreeSpins,
          ),
        });
        return 'applied';

      case 'lucidityMultiplierNextSpin':
        set({ lucidityEarned: paid, nextSpinLucidityMultiplier: effect.multiplier });
        return 'applied';

      case 'lockReelNextSpin':
        // Payment is deferred until lockReel(index) confirms the pick,
        // so a cancellation never silently consumes Lucidity.
        if (!state.lastResult) return 'rejected';
        set({ pendingLockPayment: consumable.cost });
        return 'needsReelPick';
    }
  },

  lockReel(reelIndex: number): void {
    const state = get();
    const locks: [boolean, boolean, boolean] = [false, false, false];
    locks[reelIndex] = true;
    set({
      lockedReels: locks,
      lucidityEarned: Math.max(0, state.lucidityEarned - state.pendingLockPayment),
      pendingLockPayment: 0,
    });
  },

  swapReels(i: number, j: number): boolean {
    const state = get();
    const cost = ABILITIES.swap.cost;
    if (!canAct(state, cost) || !state.lastResult || i === j) return false;

    const outcome = applySwap(state.lastResult.reels, i, j, state.lucidityMultiplier);
    set({
      lucidityEarned: Math.max(0, state.lucidityEarned - cost + outcome.lucidityDelta),
      lastResult: {
        ...state.lastResult,
        reels: outcome.reels,
        isJackpot: outcome.isJackpot,
        winType: outcome.winType,
        lucidityEarned: Math.max(0, state.lastResult.lucidityEarned + outcome.lucidityDelta),
      },
    });
    return true;
  },

  moveReel(reelIndex: number, direction: -1 | 1): boolean {
    const state = get();
    const cost = ABILITIES.moveColumn.cost;
    if (!canAct(state, cost) || !state.lastResult) return false;

    const outcome = applyMoveColumn(
      state.lastResult.reels, reelIndex, direction, state.lucidityMultiplier,
    );
    set({
      lucidityEarned: Math.max(0, state.lucidityEarned - cost + outcome.lucidityDelta),
      lastResult: {
        ...state.lastResult,
        reels: outcome.reels,
        isJackpot: outcome.isJackpot,
        winType: outcome.winType,
        lucidityEarned: Math.max(0, state.lastResult.lucidityEarned + outcome.lucidityDelta),
      },
    });
    return true;
  },

  buyOverrideFreeSpin(): boolean {
    const state = get();
    const cost = ABILITIES.freeSpinAbility.cost;
    if (!canAct(state, cost)) return false;
    if (state.freeSpinsRemaining >= state.maxFreeSpins) return false;

    set({
      lucidityEarned: state.lucidityEarned - cost,
      freeSpinsRemaining: Math.min(
        state.freeSpinsRemaining + 1,
        state.maxFreeSpins,
      ),
    });
    return true;
  },
}));
