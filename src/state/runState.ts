import { create } from 'zustand';
import type { RunState, SpinResult, UpgradeId, EndingType } from '../game/types';
import { evaluate } from '../game/evaluate';
import { applyReroll, applyMoveColumn } from '../game/abilities';
import { createRNG } from '../game/rng';
import {
  computeNeuronDecay,
  computeStartingNeurons,
  computeLucidityMultiplier,
  computeMaxFreeSpins,
} from '../game/economy';
import { ECONOMY } from '../content/economy';
import { CONSUMABLE_MAP } from '../content/consumables';

export type RunPhase = 'idle' | 'running' | 'over';

export interface RunStore extends RunState {
  runPhase: RunPhase;
  lastEnding: EndingType | null;
  decaySkips: number; // Stasis/Override: spins remaining that cost 0 neurons

  spin: () => SpinResult | null;
  setSpinning: (v: boolean) => void;
  setBetMultiplier: (m: 1 | 2 | 3) => void;
  startNewRun: (
    ownedPermanents: ReadonlyArray<UpgradeId>,
    pendingConsumables: Partial<Record<string, number>>,
  ) => void;
  endRun: (ending: EndingType) => void;

  useConsumable: (consumableId: string) => boolean;
  lockReel: (reelIndex: number) => void;
  rerollReel: (reelIndex: number) => boolean;
  moveReel: (reelIndex: number, direction: -1 | 1) => boolean;
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
  runConsumables:             {},
  abilitiesUsed:              [],
  ownedUpgrades:              [],
  spinCount:                  0,
  isFreeSpin:                 false,
  betMultiplier:              1,
};

function canAct(state: RunStore): boolean {
  return state.runPhase === 'running' && !state.isSpinning;
}

export const useRunStore = create<RunStore>((set, get) => ({
  ...INITIAL_RUN_STATE,
  runPhase: 'idle',
  lastEnding: null,
  decaySkips: 0,

  spin(): SpinResult | null {
    const state = get();

    const isFreeSpin = state.freeSpinsRemaining > 0;
    if (state.runPhase !== 'running' || state.isSpinning) return null;
    if (!isFreeSpin && state.neurons < 1) return null;

    const seed = ((Date.now() ^ (state.spinCount * 0x9e3779b9)) >>> 0);
    const rng = createRNG(seed);

    const stasisActive = !isFreeSpin && state.decaySkips > 0;
    const baseDecay = computeNeuronDecay(state.ownedUpgrades);
    const neuronDecayAmount = stasisActive
      ? 0
      : Math.min(state.betMultiplier * baseDecay, state.neurons);

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

    set({
      neurons:                    result.neuronsAfter,
      lucidityEarned:             state.lucidityEarned + result.lucidityEarned,
      freeSpinsRemaining:         result.freeSpinsAfter,
      isFreeSpin:                 result.isFreeSpin,
      isSpinning:                 true,
      lastResult:                 result,
      spinCount:                  state.spinCount + 1,
      nextSpinLucidityMultiplier: 1.0,
      // lockedReels intentionally NOT reset here — SlotMachine reads them during
      // animation to skip the spin on locked reels. Reset happens in setSpinning(false).
      decaySkips:                 stasisActive ? state.decaySkips - 1 : state.decaySkips,
    });

    return result;
  },

  setSpinning(v: boolean): void {
    if (v) {
      set({ isSpinning: true });
    } else {
      // Clear locks here so SlotMachine still reads them during the spin animation.
      set({ isSpinning: false, lockedReels: [false, false, false] });
    }
  },

  setBetMultiplier(m: 1 | 2 | 3): void {
    set({ betMultiplier: m });
  },

  startNewRun(
    ownedPermanents: ReadonlyArray<UpgradeId>,
    pendingConsumables: Partial<Record<string, number>>,
  ): void {
    const startingNeurons  = computeStartingNeurons(ownedPermanents);
    const lucidityMultiplier = computeLucidityMultiplier(ownedPermanents);
    const maxFreeSpins     = computeMaxFreeSpins(ownedPermanents);

    set({
      ...INITIAL_RUN_STATE,
      neurons:          startingNeurons,
      startingNeurons:  startingNeurons,
      lucidityMultiplier,
      maxFreeSpins,
      ownedUpgrades:  ownedPermanents,
      runConsumables: pendingConsumables,
      abilitiesUsed:  [],
      runPhase:       'running',
      lastEnding:     null,
      decaySkips:     0,
    });
  },

  endRun(ending: EndingType): void {
    set({ runPhase: 'over', lastEnding: ending });
  },

  useConsumable(consumableId: string): boolean {
    const state = get();
    if (!canAct(state)) return false;

    const consumable = CONSUMABLE_MAP[consumableId];
    if (!consumable) return false;

    const charges = state.runConsumables[consumableId] ?? 0;
    if (charges < 1) return false;

    const newRunConsumables = { ...state.runConsumables, [consumableId]: charges - 1 };
    const effect = consumable.effect;

    switch (effect.type) {
      case 'skipDecay':
        set({ runConsumables: newRunConsumables, decaySkips: state.decaySkips + effect.spins });
        return true;

      case 'grantFreeSpins':
        if (state.freeSpinsRemaining >= state.maxFreeSpins) return false;
        set({
          runConsumables: newRunConsumables,
          freeSpinsRemaining: Math.min(
            state.freeSpinsRemaining + effect.amount,
            state.maxFreeSpins,
          ),
        });
        return true;

      case 'lucidityMultiplierNextSpin':
        set({ runConsumables: newRunConsumables, nextSpinLucidityMultiplier: effect.multiplier });
        return true;
    }
  },

  lockReel(reelIndex: number): void {
    const state = get();
    if (!canAct(state)) return;
    if (!state.ownedUpgrades.includes('perm_memory')) return;
    if (state.abilitiesUsed.includes('memory')) return;

    const locks: [boolean, boolean, boolean] = [false, false, false];
    locks[reelIndex] = true;
    set({
      lockedReels:   locks,
      abilitiesUsed: [...state.abilitiesUsed, 'memory'],
    });
  },

  rerollReel(reelIndex: number): boolean {
    const state = get();
    if (!canAct(state) || !state.lastResult) return false;
    if (state.abilitiesUsed.includes('reroll')) return false;

    const seed = ((Date.now() ^ (state.spinCount * 0x5bd1e995 + reelIndex)) >>> 0);
    const rng = createRNG(seed);
    const outcome = applyReroll(state.lastResult.reels, reelIndex, rng, state.lucidityMultiplier);
    set({
      abilitiesUsed: [...state.abilitiesUsed, 'reroll'],
      lucidityEarned: Math.max(0, state.lucidityEarned + outcome.lucidityDelta),
      lastResult: {
        ...state.lastResult,
        reels:          outcome.reels,
        isJackpot:      outcome.isJackpot,
        winType:        outcome.winType,
        lucidityEarned: Math.max(0, state.lastResult.lucidityEarned + outcome.lucidityDelta),
      },
    });
    return true;
  },

  moveReel(reelIndex: number, direction: -1 | 1): boolean {
    const state = get();
    if (!canAct(state) || !state.lastResult) return false;
    if (!state.ownedUpgrades.includes('perm_shift')) return false;
    if (state.abilitiesUsed.includes('shift')) return false;

    const outcome = applyMoveColumn(
      state.lastResult.reels, reelIndex, direction, state.lucidityMultiplier,
    );
    set({
      abilitiesUsed: [...state.abilitiesUsed, 'shift'],
      lucidityEarned: Math.max(0, state.lucidityEarned + outcome.lucidityDelta),
      lastResult: {
        ...state.lastResult,
        reels:          outcome.reels,
        isJackpot:      outcome.isJackpot,
        winType:        outcome.winType,
        lucidityEarned: Math.max(0, state.lastResult.lucidityEarned + outcome.lucidityDelta),
      },
    });
    return true;
  },
}));
