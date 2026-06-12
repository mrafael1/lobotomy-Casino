import { scoreReels } from './evaluate';
import { SYMBOL_WEIGHTS } from '../content/symbols';
import { weightedPick } from './rng';
import type { ReelResult, SymbolId, WinType } from './types';

// Pure ability transforms. Each returns the new reels plus the Lucidity DELTA
// the player gains (or loses — rearranging a win away is the player's choice).
//
// Constraints:
// - Neurons are never touched (Sacred Rule 1).
// - Free spins are granted only when the transform CREATES a jackpot that
//   wasn't there before, and only when allowFreeSpinGrant is true (the caller
//   passes false when the underlying spin was itself a free spin — free spins
//   never chain).

// Fixed cycle order for Move Column. Book is excluded (can't Shift to/from book).
export const MOVE_ORDER: ReadonlyArray<SymbolId> = [
  'brain', 'eye', 'pill', 'syringe', 'scalpel', 'flatline',
];

export interface AbilityOutcome {
  readonly reels: ReelResult;
  readonly lucidityDelta: number; // newScore - oldScore, may be negative
  readonly isJackpot: boolean;
  readonly winType: WinType;
  // > 0 only when the transform created a NEW jackpot and the grant is allowed.
  readonly freeSpinsGranted: number;
}

function rescore(
  before: ReelResult,
  after: ReelResult,
  lucidityMultiplier: number,
  pattern23Triple: boolean,
  learningActive: boolean,
  allowFreeSpinGrant: boolean,
): AbilityOutcome {
  const oldScore = scoreReels(before, lucidityMultiplier, false, pattern23Triple, learningActive);
  const newScore = scoreReels(after,  lucidityMultiplier, allowFreeSpinGrant, pattern23Triple, learningActive);
  return {
    reels: after,
    lucidityDelta: newScore.lucidityEarned - oldScore.lucidityEarned,
    isJackpot: newScore.winType === 'jackpot',
    winType: newScore.winType,
    // The original spin already granted if it landed a jackpot itself —
    // only pay out when the ability turned a non-jackpot into one.
    freeSpinsGranted: oldScore.winType !== 'jackpot' ? newScore.freeSpinsGranted : 0,
  };
}

// Reroll: pick a fresh random symbol for one reel using the same weighted
// distribution as a normal spin. Accepts effective symbol weights so Syringe
// brain boost and book (Learning) are reflected correctly.
export function applyReroll(
  reels: ReelResult,
  reelIndex: number,
  rng: () => number,
  lucidityMultiplier: number,
  symbolWeights = SYMBOL_WEIGHTS,
  pattern23Triple = false,
  learningActive = false,
  allowFreeSpinGrant = false,
): AbilityOutcome {
  const next = [...reels] as ReelResult;
  next[reelIndex] = weightedPick(symbolWeights, rng);
  return rescore(reels, next, lucidityMultiplier, pattern23Triple, learningActive, allowFreeSpinGrant);
}

// Move Column: shift one reel's symbol up (-1) or down (+1) in the cycle order.
export function applyMoveColumn(
  reels: ReelResult,
  reelIndex: number,
  direction: -1 | 1,
  lucidityMultiplier: number,
  pattern23Triple = false,
  learningActive = false,
  allowFreeSpinGrant = false,
): AbilityOutcome {
  const current = MOVE_ORDER.indexOf(reels[reelIndex]);
  const idx = current < 0 ? 0 : current; // book not in MOVE_ORDER → clamp to start
  const nextSymbol = MOVE_ORDER[(idx + direction + MOVE_ORDER.length) % MOVE_ORDER.length];
  const next = [...reels] as ReelResult;
  next[reelIndex] = nextSymbol;
  return rescore(reels, next, lucidityMultiplier, pattern23Triple, learningActive, allowFreeSpinGrant);
}

// Copy Column: copy the symbol from sourceReel onto targetReel.
// Returns the Lucidity delta (may be negative — player's choice).
export function applyCopyReel(
  reels: ReelResult,
  sourceReel: number,
  targetReel: number,
  lucidityMultiplier: number,
  pattern23Triple = false,
  learningActive = false,
  allowFreeSpinGrant = false,
): AbilityOutcome {
  const next = [...reels] as ReelResult;
  next[targetReel] = reels[sourceReel];
  return rescore(reels, next, lucidityMultiplier, pattern23Triple, learningActive, allowFreeSpinGrant);
}
