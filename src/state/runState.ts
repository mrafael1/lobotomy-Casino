import { create } from 'zustand';
import type { RunState, SpinResult, UpgradeId } from '../game/types';
import { evaluate } from '../game/evaluate';
import { createRNG } from '../game/rng';
import {
  computeNeuronDecay,
  computeStartingNeurons,
  computeLucidityMultiplier,
  computeMaxFreeSpins,
} from '../game/economy';
import { ECONOMY } from '../content/economy';

export type RunPhase = 'idle' | 'running' | 'over';

export interface RunStore extends RunState {
  runPhase: RunPhase;

  spin: () => SpinResult | null;
  setSpinning: (v: boolean) => void;
  startNewRun: (ownedPermanents: ReadonlyArray<UpgradeId>) => void;
  endRun: () => void;
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
};

export const useRunStore = create<RunStore>((set, get) => ({
  ...INITIAL_RUN_STATE,
  runPhase: 'idle',

  spin(): SpinResult | null {
    const state = get();

    if (
      state.runPhase !== 'running' ||
      state.isSpinning ||
      state.neurons < ECONOMY.MIN_NEURONS_TO_SPIN
    ) {
      return null;
    }

    const seed = ((Date.now() ^ (state.spinCount * 0x9e3779b9)) >>> 0);
    const rng = createRNG(seed);

    const isFreeSpin = state.freeSpinsRemaining > 0;
    const neuronDecayAmount = computeNeuronDecay(state.ownedUpgrades);
    const effectiveMultiplier =
      state.lucidityMultiplier * state.nextSpinLucidityMultiplier;

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

    const nextPhase: RunPhase =
      result.neuronsAfter <= 0 ? 'over' : 'running';

    set({
      neurons:                    result.neuronsAfter,
      lucidityEarned:             state.lucidityEarned + result.lucidityEarned,
      freeSpinsRemaining:         result.freeSpinsAfter,
      isFreeSpin:                 result.isFreeSpin,
      isSpinning:                 true,
      lastResult:                 result,
      spinCount:                  state.spinCount + 1,
      nextSpinLucidityMultiplier: 1.0,
      runPhase:                   nextPhase,
    });

    return result;
  },

  setSpinning(v: boolean): void {
    set({ isSpinning: v });
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
      ownedUpgrades:    ownedPermanents,
      runPhase:         'running',
    });
  },

  endRun(): void {
    set({ runPhase: 'over' });
  },
}));
