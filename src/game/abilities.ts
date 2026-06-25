import { scoreReels } from './evaluate';
import { SYMBOL_WEIGHTS, BASE_SYMBOL_CYCLE } from '../content/symbols';
import { weightedPick } from './rng';
import type { ReelResult, WinType } from './types';

// Pure ability transforms. Each returns new reels plus both deltas so the
// caller can apply them to scoreEarned and lucidityCoins independently.
//
// Constraints:
// - Neurons are never touched (Sacred Rule 1).
// - Free spins are granted only when the transform CREATES a jackpot that
//   wasn't there before, and only when allowFreeSpinGrant is true.

// SHIFT steps a reel along the canonical base-symbol cycle (content/symbols.ts).
export const MOVE_ORDER = BASE_SYMBOL_CYCLE;

export interface AbilityOutcome {
  readonly reels: ReelResult;
  readonly scoreDelta: number; // newScore - oldScore, may be negative
  readonly coinsDelta: number; // newCoins - oldCoins, may be negative
  readonly isJackpot: boolean;
  readonly winType: WinType;
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
    scoreDelta: newScore.scoreEarned - oldScore.scoreEarned,
    coinsDelta: newScore.coinsEarned - oldScore.coinsEarned,
    isJackpot: newScore.winType === 'jackpot',
    winType: newScore.winType,
    freeSpinsGranted: oldScore.winType !== 'jackpot' ? newScore.freeSpinsGranted : 0,
  };
}

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
  const idx = current < 0 ? 0 : current;
  const nextSymbol = MOVE_ORDER[(idx + direction + MOVE_ORDER.length) % MOVE_ORDER.length];
  const next = [...reels] as ReelResult;
  next[reelIndex] = nextSymbol;
  return rescore(reels, next, lucidityMultiplier, pattern23Triple, learningActive, allowFreeSpinGrant);
}

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
