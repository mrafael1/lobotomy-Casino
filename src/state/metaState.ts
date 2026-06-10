// Phase 1: Wire this to Zustand + MMKV persistence.
// MetaState is the only state that survives across runs.

import type { MetaState } from '../game/types';

export const INITIAL_META_STATE: MetaState = {
  schemaVersion:    1,
  lucidityWallet:   0,
  ownedPermanents:  [],
  corruptionEverUsed: false,
  endingsReached:   [],
  history: {
    runsPlayed:       0,
    bestLucidityRun:  0,
  },
};

// TODO (Phase 1): create(set => ({ ...INITIAL_META_STATE, spendLucidity, buyUpgrade, ... }))
