// In-run items offered by the Dealer at neuron thresholds (65% and 35%).
// These are never bought in the pre-run shop — they appear during gameplay.

export type InRunEffect =
  | { type: 'skipDecay';     spins: number; blockBet: 'x3' } // Energy Drink: neurons preserved, x3 bet blocked for the free spins
  | { type: 'cocktailBoost'; spins: number; compulsiveSpins: number }
  | { type: 'addLucidity';         amount: number }
  | { type: 'forceFlatlinesThenTriple'; flatSpins: number; guaranteedTripleNext: boolean }; // Red Pill

export interface InRunItem {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly corrupt?: boolean; // renders in the corrupt (purple) hint colour (issue #33)
  readonly effect: InRunEffect;
}

export const IN_RUN_ITEMS: ReadonlyArray<InRunItem> = [
  {
    id: 'item_energy_drink',
    name: 'Energy Drink',
    description: 'Next 5 spins cost 0 neurons. The machine jitters too hard for x3 bets.',
    corrupt: true,
    effect: { type: 'skipDecay', spins: 5, blockBet: 'x3' },
  },
  {
    id: 'item_cocktail',
    name: 'Cocktail',
    description: 'Next 3 spins gain the rarity sum of all visible symbols, even on losses. Then the machine steals 2 x1 spins.',
    effect: { type: 'cocktailBoost', spins: 3, compulsiveSpins: 2 },
  },
  {
    id: 'item_water',
    name: 'Water',
    description: '+40 Lucidity.',
    effect: { type: 'addLucidity', amount: 40 },
  },
  {
    id: 'item_pill',
    name: 'Red Pill',
    description: 'Your next spin flatlines, then the spin after is a guaranteed triple.',
    corrupt: true,
    effect: { type: 'forceFlatlinesThenTriple', flatSpins: 1, guaranteedTripleNext: true },
  },
];

export const IN_RUN_ITEM_MAP: Readonly<Record<string, InRunItem>> = Object.fromEntries(
  IN_RUN_ITEMS.map(i => [i.id, i])
);
