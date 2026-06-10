// Act/ending gate checks. Pure functions — read state, return decisions.
// Phase 2: fill in IAP-backed Act II gating here.

import type { MetaState, GlobalState, EndingType } from '../game/types';

export function isAct2Unlocked(global: GlobalState): boolean {
  return global.act2Unlocked;
}

export function hasReachedEnding(meta: MetaState, ending: EndingType): boolean {
  return meta.endingsReached.includes(ending);
}

// The Exit Route cannot be reached on a tainted slot, full stop.
export function canAttemptExitRoute(meta: MetaState): boolean {
  return !meta.corruptionEverUsed;
}
