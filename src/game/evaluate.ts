import { SYMBOL_WEIGHTS, BASE_SYMBOL_CYCLE } from '../content/symbols';
import {
  JACKPOT_SCORE,
  JACKPOT_FREE_SPIN_GRANT,
  TRIPLE_SCORE,
  PAIR_SCORE,
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
  readonly coinsEarned: number;  // 1:1 with scoreEarned — Lucidity gained equals the win shown
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
//
// Lucidity is now 1:1 with the win shown: coinsEarned always equals scoreEarned
// (no separate flat-coin table, no conversion ratio). A pair worth +6 gives 6
// Lucidity; a triple worth +18 gives 18. Book bonus is included in both.
export function scoreReels(
  reels: ReelResult,
  lucidityMultiplier: number,
  allowFreeSpinGrant: boolean,
  pattern23Triple = false,
  learningActive = false,
  pairScoreMult = 1,      // Tobacco (issue #32): multiply pair payouts
  hiddenReelCount = 0,    // Tobacco (issue #32): score only the visible reels
): ReelScore {
  const [a, b, c] = reels;

  // Tobacco: one or more reels go dark and only the visible remainder scores — no
  // triples, and any visible pair pays at pairScoreMult. Gated so the default path
  // (hiddenReelCount === 0) is byte-for-byte the pinned behaviour.
  if (hiddenReelCount > 0) {
    const visible = reels.slice(0, Math.max(1, reels.length - hiddenReelCount));
    const vBook = learningActive
      ? visible.filter(r => r === 'book').length * BOOK_BONUS_PER_VISIBLE
      : 0;
    let matched: SymbolId | null = null;
    for (let i = 0; i < visible.length - 1; i++) {
      if (visible[i] === visible[i + 1]) { matched = visible[i]; break; }
    }
    if (matched !== null) {
      const s = Math.round(((PAIR_SCORE[matched] ?? 0) * pairScoreMult + vBook) * lucidityMultiplier);
      return { winType: 'pair', scoreEarned: s, coinsEarned: s, freeSpinsGranted: 0 };
    }
    const ms = vBook > 0 ? Math.round(vBook * lucidityMultiplier) : 0;
    return { winType: 'miss', scoreEarned: ms, coinsEarned: ms, freeSpinsGranted: 0 };
  }

  const bookBonus = learningActive
    ? reels.filter(r => r === 'book').length * BOOK_BONUS_PER_VISIBLE
    : 0;

  // Triple: all three identical
  if (a === b && b === c) {
    if (a === 'brain') {
      const score = Math.round((JACKPOT_SCORE + bookBonus) * lucidityMultiplier);
      return {
        winType: 'jackpot',
        scoreEarned: score,
        coinsEarned: score,
        freeSpinsGranted: allowFreeSpinGrant ? JACKPOT_FREE_SPIN_GRANT : 0,
      };
    }
    const score = Math.round(((TRIPLE_SCORE[a] ?? 0) + bookBonus) * lucidityMultiplier);
    return {
      winType: 'triple',
      scoreEarned: score,
      coinsEarned: score,
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
      const score = Math.round((((PAIR_SCORE[matchSym] ?? 0) * 2) + bookBonus) * lucidityMultiplier);
      return {
        winType: 'pair',
        scoreEarned: score,
        coinsEarned: score,
        freeSpinsGranted: 0,
      };
    }
  } else {
    // Standard adjacent pair (a===b or b===c; a===c without b match is a miss)
    if (a === b || b === c) {
      const matchSymbol: SymbolId = a === b ? a : b;
      const score = Math.round(((PAIR_SCORE[matchSymbol] ?? 0) + bookBonus) * lucidityMultiplier);
      return {
        winType: 'pair',
        scoreEarned: score,
        coinsEarned: score,
        freeSpinsGranted: 0,
      };
    }
  }

  // Miss — still pay book score bonus if Learning active; Lucidity mirrors it.
  const missScore = bookBonus > 0 ? Math.round(bookBonus * lucidityMultiplier) : 0;
  return {
    winType: 'miss',
    scoreEarned: missScore,
    coinsEarned: missScore,
    freeSpinsGranted: 0,
  };
}

// Deterministic non-excluded reel symbol (issue #32, Serum). Picks along the
// canonical visible cycle so it never lands on `book` or the excluded symbol.
function pickNonExcluded(excluded: SymbolId, rng: () => number): SymbolId {
  const pool = BASE_SYMBOL_CYCLE.filter(s => s !== excluded);
  return pool[Math.floor(rng() * pool.length)] ?? pool[0];
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
    forceAllSymbol = null,
    forceTripleFrom = null,
    excludeSymbol = null,
    banExcluded = false,
    guaranteeNonExcluded = false,
    symbolToBrainCount = 0,
    pairScoreMult = 1,
    hiddenReelCount = 0,
    guaranteeSymbolId = null,
    forceReelSymbols = null,
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

  // Consumable reel transforms (issue #32) — all gated, no-op at defaults.
  if (forceAllSymbol) {
    reels = [forceAllSymbol, forceAllSymbol, forceAllSymbol];
  } else if (forceTripleFrom && forceTripleFrom.length > 0) {
    const pick = forceTripleFrom[Math.floor(rng() * forceTripleFrom.length)];
    reels = [pick, pick, pick];
  } else {
    if (banExcluded && excludeSymbol) {
      reels = reels.map(r => (r === excludeSymbol ? pickNonExcluded(excludeSymbol, rng) : r)) as ReelResult;
    }
    if (symbolToBrainCount > 0) {
      reels = reels.map((r, i) => (i < symbolToBrainCount ? 'brain' : r)) as ReelResult;
    }
    if (guaranteeNonExcluded && excludeSymbol && reels.every(r => r === excludeSymbol)) {
      reels = [pickNonExcluded(excludeSymbol, rng), reels[1], reels[2]];
    }
    // Serum (issue #53): the player-picked symbol appears at least once.
    if (guaranteeSymbolId && !reels.includes(guaranteeSymbolId)) {
      const idx = Math.floor(rng() * 3);
      reels = reels.map((r, i) => (i === idx ? guaranteeSymbolId : r)) as ReelResult;
    }
  }

  // 3x eye (issue #53): reels whose symbol was already revealed to the player are
  // committed to that symbol — the reveal is a promise, so it wins over everything.
  if (forceReelSymbols) {
    reels = reels.map((r, i) => forceReelSymbols[i] ?? r) as ReelResult;
  }

  const neuronsAfter = isFreeSpin
    ? neurons
    : Math.max(0, neurons - neuronDecayAmount);

  // Free spins NEVER generate free spins (structural enforcement)
  const score = scoreReels(reels, lucidityMultiplier, !isFreeSpin, pattern23Triple, learningActive, pairScoreMult, hiddenReelCount);

  const freeSpinsAfter = isFreeSpin
    ? Math.max(0, freeSpinsRemaining - 1)
    : Math.min(freeSpinsRemaining + score.freeSpinsGranted, maxFreeSpins);

  return {
    reels,
    scoreMultiplier: lucidityMultiplier,
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
