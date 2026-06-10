// Phase 1: Wire this to Zustand.
// The store holds all RunState and exposes actions that call into game/.
// No game logic lives here — only state transitions delegated to game/ functions.

import type { RunState } from '../game/types';
import { ECONOMY } from '../content/economy';

export const INITIAL_RUN_STATE: RunState = {
  neurons:                   ECONOMY.STARTING_NEURONS,
  startingNeurons:           ECONOMY.STARTING_NEURONS,
  lucidityEarned:            0,
  freeSpinsRemaining:        0,
  maxFreeSpins:              ECONOMY.BASE_MAX_FREE_SPINS,
  lucidityMultiplier:        ECONOMY.BASE_LUCIDITY_MULTIPLIER,
  nextSpinLucidityMultiplier: 1.0,
  isSpinning:                false,
  lastResult:                null,
  lockedReels:               [false, false, false],
  activeAbilities:           [],
  ownedConsumables:          [],
  ownedUpgrades:             [],
  spinCount:                 0,
  isFreeSpin:                false,
};

// TODO (Phase 1): create(set => ({ ...INITIAL_RUN_STATE, spin, applyResult, ... }))
