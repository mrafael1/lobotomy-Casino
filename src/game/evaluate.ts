import { SYMBOL_WEIGHTS } from '../content/symbols';
import {
  JACKPOT_LUCIDITY,
  JACKPOT_FREE_SPIN_GRANT,
  TRIPLE_PAYOUTS,
  PAIR_PAYOUTS,
} from '../content/payouts';
import { weightedPick } from './rng';
import type { SpinInput, SpinResult, ReelResult, SymbolId, WinType } from './types';

function spinReel(rng: SpinInput['rng']): SymbolId {
  return weightedPick(SYMBOL_WEIGHTS, rng);
}

export interface ReelScore {
  readonly winType: WinType;
  readonly lucidityEarned: number;
  readonly freeSpinsGranted: number;
}

// Single source of truth for what a reel combination is worth.
// Used by evaluate() for spins and by abilities.ts to re-score modified reels.
// allowFreeSpinGrant is false for free spins (Sacred Rule 2) and for ability
// re-scores (abilities can earn jackpot Lucidity but never mint free spins).
export function scoreReels(
  reels: ReelResult,
  lucidityMultiplier: number,
  allowFreeSpinGrant: boolean,
): ReelScore {
  const [a, b, c] = reels;

  if (a === b && b === c) {
    if (a === 'brain') {
      return {
        winType: 'jackpot',
        lucidityEarned: Math.round(JACKPOT_LUCIDITY * lucidityMultiplier),
        freeSpinsGranted: allowFreeSpinGrant ? JACKPOT_FREE_SPIN_GRANT : 0,
      };
    }
    return {
      winType: 'triple',
      lucidityEarned: Math.round((TRIPLE_PAYOUTS[a] ?? 0) * lucidityMultiplier),
      freeSpinsGranted: 0,
    };
  }

  if (a === b || b === c) {
    // Only adjacent pairs count (left-to-right read; a===c without matching b is a miss)
    const matchSymbol: SymbolId = a === b ? a : b;
    return {
      winType: 'pair',
      lucidityEarned: Math.round((PAIR_PAYOUTS[matchSymbol] ?? 0) * lucidityMultiplier),
      freeSpinsGranted: 0,
    };
  }

  return { winType: 'miss', lucidityEarned: 0, freeSpinsGranted: 0 };
}

// evaluate() is the single source of truth for a spin's outcome.
// Call it synchronously BEFORE starting any animation. The animation plays
// toward the already-decided result — it can never change the outcome.
export function evaluate(input: SpinInput): SpinResult {
  const {
    neurons,
    neuronDecayAmount,
    freeSpinsRemaining,
    maxFreeSpins,
    lucidityMultiplier,
    isFreeSpin,
    lockedReels,
    previousReels,
    rng,
  } = input;

  // Spin each reel; locked reels keep the previous symbol (reel-lock consumable)
  const reels: ReelResult = [
    lockedReels[0] && previousReels ? previousReels[0] : spinReel(rng),
    lockedReels[1] && previousReels ? previousReels[1] : spinReel(rng),
    lockedReels[2] && previousReels ? previousReels[2] : spinReel(rng),
  ];

  // Neurons: free spins cost nothing
  const neuronsAfter = isFreeSpin
    ? neurons
    : Math.max(0, neurons - neuronDecayAmount);

  // Structural enforcement: free spins NEVER generate free spins (§4 of arch doc)
  const score = scoreReels(reels, lucidityMultiplier, !isFreeSpin);

  // Free spin accounting
  const freeSpinsAfter = isFreeSpin
    ? Math.max(0, freeSpinsRemaining - 1)                                 // consumed one
    : Math.min(freeSpinsRemaining + score.freeSpinsGranted, maxFreeSpins); // may gain one

  return {
    reels,
    lucidityEarned: score.lucidityEarned,
    neuronsAfter,
    freeSpinsGranted: score.freeSpinsGranted,
    freeSpinsAfter,
    isJackpot: score.winType === 'jackpot',
    isFreeSpin,
    winType: score.winType,
  };
}
