import type { SymbolId } from './symbols';

// ── Score (multiplied by bet × reward-amp, drives the wealth ending) ─────────

export const JACKPOT_SCORE = 200;
export const JACKPOT_FREE_SPIN_GRANT = 1;

export const TRIPLE_SCORE: Readonly<Partial<Record<SymbolId, number>>> = {
  eye:      50,
  pill:     35,
  syringe:  25,
  vial:  15,
  flatline: 0,
  book:     15,
  // brain → jackpot, handled separately
};

export const PAIR_SCORE: Readonly<Partial<Record<SymbolId, number>>> = {
  brain:    20,
  eye:      10,
  pill:     7,
  syringe:  5,
  vial:  3,
  flatline: 0,
  book:     5,
};

// Bonus score per book symbol visible (requires Learning upgrade).
export const BOOK_BONUS_PER_VISIBLE = 10;

// ── Lucidity ─────────────────────────────────────────────────────────────────
// Lucidity gained per spin is 1:1 with the score shown (the win label) — there is
// no separate flat-coin table and no conversion ratio. See scoreReels() in
// game/evaluate.ts, where coinsEarned === scoreEarned.
