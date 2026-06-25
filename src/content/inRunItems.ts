// In-run items offered by the Dealer at neuron thresholds (65% and 35%).
// These are never bought in the pre-run shop — they appear during gameplay.

export type InRunEffect =
  | { type: 'skipDecay';     spins: number; forcedRandomBetSpins: number } // Energy Drink: neurons preserved, x3 bet locked
  | { type: 'cocktailBoost'; spins: number; compulsiveSpins: number }
  | { type: 'addLucidity';         amount: number }
  | { type: 'guaranteedWin';       spins: number; blockPowersSpins: number };

export interface InRunItem {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly effect: InRunEffect;
}

export const IN_RUN_ITEMS: ReadonlyArray<InRunItem> = [
  {
    id: 'item_energy_drink',
    name: 'Energy Drink',
    description: 'Next 5 spins cost 0 neurons. The machine jitters too hard for x3 bets.',
    effect: { type: 'skipDecay', spins: 5, forcedRandomBetSpins: 5 },
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
    description: 'Your next 3 spins are guaranteed to win. No abilities for 5 spins.',
    effect: { type: 'guaranteedWin', spins: 3, blockPowersSpins: 5 },
  },
];

export const IN_RUN_ITEM_MAP: Readonly<Record<string, InRunItem>> = Object.fromEntries(
  IN_RUN_ITEMS.map(i => [i.id, i])
);
