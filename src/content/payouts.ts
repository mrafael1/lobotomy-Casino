import type { SymbolId } from './symbols';

// All Lucidity values live here. Tune via the headless simulator.

export const JACKPOT_LUCIDITY = 200;
export const JACKPOT_FREE_SPIN_GRANT = 1;

export const TRIPLE_PAYOUTS: Readonly<Partial<Record<SymbolId, number>>> = {
  eye:      50,
  pill:     35,
  syringe:  25,
  scalpel:  15,
  flatline: 0,
  // brain → jackpot, handled separately
};

export const PAIR_PAYOUTS: Readonly<Partial<Record<SymbolId, number>>> = {
  brain:    20,
  eye:      10,
  pill:     7,
  syringe:  5,
  scalpel:  3,
  flatline: 0,
};
