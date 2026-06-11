import { SYMBOL_WEIGHTS, BOOK_SYMBOL_WEIGHT } from '../content/symbols';
import {
  JACKPOT_LUCIDITY,
  JACKPOT_FREE_SPIN_GRANT,
  TRIPLE_PAYOUTS,
  PAIR_PAYOUTS,
  BOOK_BONUS_PER_VISIBLE,
} from '../content/payouts';
import { weightedPick } from './rng';
import type { SpinInput, SpinResult, ReelResult, SymbolId, WinType } from './types';

export interface ScoreOptions {
  readonly allowFreeSpinGrant: boolean;
  readonly pattern23Triple: boolean; // ⅔ match → triple payout (Pattern Fabrication)
  readonly learningActive: boolean;  // book symbol pays + +10/book visible
  readonly lucidityMultiplier: number;
}

export interface ReelScore {
  readonly winType: WinType;
  readonly lucidityEarned: number;
  readonly freeSpinsGranted: number;
}

function buildWeights(
  brainWeightBonus: number,
  bookWeight: number,
): ReadonlyArray<{ weight: number; value: SymbolId }> {
  const weights = brainWeightBonus > 0
    ? SYMBOL_WEIGHTS.map(w =>
        w.value === 'brain' ? { ...w, weight: w.weight + brainWeightBonus } : w,
      )
    : SYMBOL_WEIGHTS;

  return bookWeight > 0
    ? [...weights, { weight: bookWeight, value: 'book' as SymbolId }]
    : weights;
}

// Single source of truth for what a reel combination is worth.
// Used by evaluate() for spins and by abilities.ts to re-score modified reels.
export function scoreReels(
  reels: ReelResult,
  lucidityMultiplier: number,
  allowFreeSpinGrant: boolean,
  pattern23Triple = false,
  learningActive = false,
): ReelScore {
  const [a, b, c] = reels;

  // Count book symbols for bonus (only when Learning active)
  const bookBonus = learningActive
    ? reels.filter(r => r === 'book').length * BOOK_BONUS_PER_VISIBLE
    : 0;

  // Triple: all three identical
  if (a === b && b === c) {
    if (a === 'brain') {
      return {
        winType: 'jackpot',
        lucidityEarned: Math.round((JACKPOT_LUCIDITY + bookBonus) * lucidityMultiplier),
        freeSpinsGranted: allowFreeSpinGrant ? JACKPOT_FREE_SPIN_GRANT : 0,
      };
    }
    return {
      winType: 'triple',
      lucidityEarned: Math.round(((TRIPLE_PAYOUTS[a] ?? 0) + bookBonus) * lucidityMultiplier),
      freeSpinsGranted: 0,
    };
  }

  // Pattern Fabrication (⅔): any two identical reels pay as a triple
  if (pattern23Triple) {
    const matchSym: SymbolId | null =
      a === b ? a :
      b === c ? b :
      a === c ? a :
      null;

    if (matchSym !== null) {
      if (matchSym === 'brain') {
        // Brain pair-as-triple still jackpot
        return {
          winType: 'jackpot',
          lucidityEarned: Math.round((JACKPOT_LUCIDITY + bookBonus) * lucidityMultiplier),
          freeSpinsGranted: allowFreeSpinGrant ? JACKPOT_FREE_SPIN_GRANT : 0,
        };
      }
      return {
        winType: 'triple',
        lucidityEarned: Math.round(((TRIPLE_PAYOUTS[matchSym] ?? 0) + bookBonus) * lucidityMultiplier),
        freeSpinsGranted: 0,
      };
    }
  } else {
    // Standard adjacent pair detection (a===b or b===c; a===c without b match is a miss)
    if (a === b || b === c) {
      const matchSymbol: SymbolId = a === b ? a : b;
      return {
        winType: 'pair',
        lucidityEarned: Math.round(((PAIR_PAYOUTS[matchSymbol] ?? 0) + bookBonus) * lucidityMultiplier),
        freeSpinsGranted: 0,
      };
    }
  }

  // Miss — still pay book bonus if Learning active
  return {
    winType: 'miss',
    lucidityEarned: bookBonus > 0 ? Math.round(bookBonus * lucidityMultiplier) : 0,
    freeSpinsGranted: 0,
  };
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
    bookWeight,
    brainWeightBonus,
    guaranteedWin,
    pattern23Triple,
    learningActive,
  } = input;

  const weights = buildWeights(brainWeightBonus, bookWeight);

  // Spin each reel; locked reels keep the previous symbol
  let reels: ReelResult = [
    lockedReels[0] && previousReels ? previousReels[0] : weightedPick(weights, rng),
    lockedReels[1] && previousReels ? previousReels[1] : weightedPick(weights, rng),
    lockedReels[2] && previousReels ? previousReels[2] : weightedPick(weights, rng),
  ];

  // Guaranteed win: if result would be a miss, force reel[1] to match reel[0]
  if (guaranteedWin) {
    const tempScore = scoreReels(reels, 1, false, pattern23Triple, learningActive);
    if (tempScore.winType === 'miss') {
      reels = [reels[0], reels[0], reels[2]]; // pair in positions 0+1
    }
  }

  // Neurons: free spins and stasis cost nothing
  const neuronsAfter = isFreeSpin
    ? neurons
    : Math.max(0, neurons - neuronDecayAmount);

  // Structural enforcement: free spins NEVER generate free spins
  const score = scoreReels(reels, lucidityMultiplier, !isFreeSpin, pattern23Triple, learningActive);

  const freeSpinsAfter = isFreeSpin
    ? Math.max(0, freeSpinsRemaining - 1)
    : Math.min(freeSpinsRemaining + score.freeSpinsGranted, maxFreeSpins);

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
