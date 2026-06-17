import type { SymbolId } from './symbols';

// ── Score (multiplied by bet × reward-amp, drives the wealth ending) ─────────

export const JACKPOT_SCORE = 200;
export const JACKPOT_FREE_SPIN_GRANT = 1;

export const TRIPLE_SCORE: Readonly<Partial<Record<SymbolId, number>>> = {
  eye:      50,
  pill:     35,
  syringe:  25,
  scalpel:  15,
  flatline: 0,
  book:     15,
  // brain → jackpot, handled separately
};

export const PAIR_SCORE: Readonly<Partial<Record<SymbolId, number>>> = {
  brain:    20,
  eye:      10,
  pill:     7,
  syringe:  5,
  scalpel:  3,
  flatline: 0,
  book:     5,
};

// Bonus score per book symbol visible (requires Learning upgrade).
export const BOOK_BONUS_PER_VISIBLE = 10;

// ── Lucidity coins (FLAT — ignore bet / reward-amp, bank straight to wallet) ──
// Pairs: 1–5 coins by rarity. Triples: 3× pair. Brain triple: flat 50 (jackpot).
// Flatline always 0. Coins bypass all multipliers so the 30-coin restore cadence
// stays predictable regardless of upgrades.

export const JACKPOT_COINS = 50;

export const TRIPLE_COINS: Readonly<Partial<Record<SymbolId, number>>> = {
  eye:      12,
  pill:     9,
  syringe:  6,
  scalpel:  3,
  book:     9,
  flatline: 0,
};

export const PAIR_COINS: Readonly<Partial<Record<SymbolId, number>>> = {
  brain:    5,
  eye:      4,
  pill:     3,
  syringe:  2,
  scalpel:  1,
  book:     3,
  flatline: 0,
};

// ── Legacy aliases kept for the test suite ────────────────────────────────────
export const JACKPOT_LUCIDITY = JACKPOT_SCORE;
export const TRIPLE_PAYOUTS   = TRIPLE_SCORE;
export const PAIR_PAYOUTS     = PAIR_SCORE;
