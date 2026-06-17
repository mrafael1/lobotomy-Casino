import { SYMBOL_WEIGHTS } from '../content/symbols';
import {
  JACKPOT_SCORE,
  JACKPOT_COINS,
  JACKPOT_FREE_SPIN_GRANT,
  TRIPLE_SCORE,
  TRIPLE_COINS,
  PAIR_SCORE,
  PAIR_COINS,
  BOOK_BONUS_PER_VISIBLE,
} from '../content/payouts';
import { weightedPick } from './rng';
import type { SpinInput, SpinResult, ReelResult, SymbolId, WinType } from './types';

export interface ScoreOptions {
  readonly allowFreeSpinGrant: boolean;
  readonly pattern23Triple: boolean;
  readonly learningActive: boolean;
  readonly lucidityMultiplier: number;
}

export interface ReelScore {
  readonly winType: WinType;
  readonly scoreEarned: number;  // multiplied — accumulates toward the wealth ending
  readonly coinsEarned: number;  // flat — banks to wallet, drives ability-restore cadence
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
// Book bonus is score-only (no coin equivalent — it's already a multiplied bonus).
export function scoreReels(
  reels: ReelResult,
  lucidityMultiplier: number,
  allowFreeSpinGrant: boolean,
  pattern23Triple = false,
  learningActive = false,
): ReelScore {
  const [a, b, c] = reels;

  const bookBonus = learningActive
    ? reels.filter(r => r === 'book').length * BOOK_BONUS_PER_VISIBLE
    : 0;

  // Triple: all three identical
  if (a === b && b === c) {
    if (a === 'brain') {
      return {
        winType: 'jackpot',
        scoreEarned: Math.round((JACKPOT_SCORE + bookBonus) * lucidityMultiplier),
        coinsEarned: JACKPOT_COINS,
        freeSpinsGranted: allowFreeSpinGrant ? JACKPOT_FREE_SPIN_GRANT : 0,
      };
    }
    return {
      winType: 'triple',
      scoreEarned: Math.round(((TRIPLE_SCORE[a] ?? 0) + bookBonus) * lucidityMultiplier),
      coinsEarned: TRIPLE_COINS[a] ?? 0,
      freeSpinsGranted: 0,
    };
  }

  // Pattern Fabrication: any two identical reels pay as a doubled pair.
  // Brain matches through this effect are not jackpots and never grant free spins.
  if (pattern23Triple) {
    const matchSym: SymbolId | null =
      a === b ? a :
      b === c ? b :
      a === c ? a :
      null;

    if (matchSym !== null) {
      return {
        winType: 'pair',
        scoreEarned: Math.round((((PAIR_SCORE[matchSym] ?? 0) * 2) + bookBonus) * lucidityMultiplier),
        coinsEarned: PAIR_COINS[matchSym] ?? 0,
        freeSpinsGranted: 0,
      };
    }
  } else {
    // Standard adjacent pair (a===b or b===c; a===c without b match is a miss)
    if (a === b || b === c) {
      const matchSymbol: SymbolId = a === b ? a : b;
      return {
        winType: 'pair',
        scoreEarned: Math.round(((PAIR_SCORE[matchSymbol] ?? 0) + bookBonus) * lucidityMultiplier),
        coinsEarned: PAIR_COINS[matchSymbol] ?? 0,
        freeSpinsGranted: 0,
      };
    }
  }

  // Miss — still pay book score bonus if Learning active; coins are always 0 on a miss
  return {
    winType: 'miss',
    scoreEarned: bookBonus > 0 ? Math.round(bookBonus * lucidityMultiplier) : 0,
    coinsEarned: 0,
    freeSpinsGranted: 0,
  };
}

// evaluate() is the single source of truth for a spin's outcome.
// Call it synchronously BEFORE starting any animation.
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

  let reels: ReelResult = [
    lockedReels[0] && previousReels ? previousReels[0] : weightedPick(weights, rng),
    lockedReels[1] && previousReels ? previousReels[1] : weightedPick(weights, rng),
    lockedReels[2] && previousReels ? previousReels[2] : weightedPick(weights, rng),
  ];

  // Guaranteed win: force a pair if result would be a miss
  if (guaranteedWin) {
    const tempScore = scoreReels(reels, 1, false, pattern23Triple, learningActive);
    if (tempScore.winType === 'miss') {
      reels = [reels[0], reels[0], reels[2]];
    }
  }

  const neuronsAfter = isFreeSpin
    ? neurons
    : Math.max(0, neurons - neuronDecayAmount);

  // Free spins NEVER generate free spins (structural enforcement)
  const score = scoreReels(reels, lucidityMultiplier, !isFreeSpin, pattern23Triple, learningActive);

  const freeSpinsAfter = isFreeSpin
    ? Math.max(0, freeSpinsRemaining - 1)
    : Math.min(freeSpinsRemaining + score.freeSpinsGranted, maxFreeSpins);

  return {
    reels,
    scoreEarned: score.scoreEarned,
    coinsEarned: score.coinsEarned,
    neuronsAfter,
    freeSpinsGranted: score.freeSpinsGranted,
    freeSpinsAfter,
    isJackpot: score.winType === 'jackpot',
    isFreeSpin,
    winType: score.winType,
  };
}
