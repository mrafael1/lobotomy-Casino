import { scoreReels } from './evaluate';
import type { ReelResult, SymbolId } from './types';

// Pure ability transforms. Each returns the new reels plus the Lucidity DELTA
// the player gains (or loses — rearranging a win away is the player's choice).
//
// Constraints these functions guarantee:
// - Neurons are never touched (Sacred Rule 1).
// - Free spins are never granted, even if a transform creates a brain triple
//   (re-scores pass allowFreeSpinGrant = false). The jackpot Lucidity still pays.

// Fixed cycle order for Move Column. Independent of RNG weights.
const MOVE_ORDER: ReadonlyArray<SymbolId> = [
  'brain', 'eye', 'pill', 'syringe', 'scalpel', 'flatline',
];

export interface AbilityOutcome {
  readonly reels: ReelResult;
  readonly lucidityDelta: number; // newScore - oldScore, may be negative
  readonly isJackpot: boolean;
}

function rescore(
  before: ReelResult,
  after: ReelResult,
  lucidityMultiplier: number,
): AbilityOutcome {
  const oldScore = scoreReels(before, lucidityMultiplier, false);
  const newScore = scoreReels(after, lucidityMultiplier, false);
  return {
    reels: after,
    lucidityDelta: newScore.lucidityEarned - oldScore.lucidityEarned,
    isJackpot: newScore.winType === 'jackpot',
  };
}

// Swap: exchange the symbols of two reel positions on the current result.
export function applySwap(
  reels: ReelResult,
  i: number,
  j: number,
  lucidityMultiplier: number,
): AbilityOutcome {
  const next = [...reels] as ReelResult;
  [next[i], next[j]] = [next[j], next[i]];
  return rescore(reels, next, lucidityMultiplier);
}

// Move Column: shift one reel's symbol up (-1) or down (+1) in the cycle order.
export function applyMoveColumn(
  reels: ReelResult,
  reelIndex: number,
  direction: -1 | 1,
  lucidityMultiplier: number,
): AbilityOutcome {
  const current = MOVE_ORDER.indexOf(reels[reelIndex]);
  const nextSymbol =
    MOVE_ORDER[(current + direction + MOVE_ORDER.length) % MOVE_ORDER.length];
  const next = [...reels] as ReelResult;
  next[reelIndex] = nextSymbol;
  return rescore(reels, next, lucidityMultiplier);
}
