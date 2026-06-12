// In-run items offered by the Dealer at neuron thresholds (65% and 35%).
// These are never bought in the pre-run shop — they appear during gameplay.

export type InRunEffect =
  | { type: 'skipDecay';     spins: number; forcedRandomBetSpins: number } // Energy Drink: neurons preserved, erratic bet
  | { type: 'cocktailBoost' }      // grants Lucidity = sum(rarity scores of current reels) × 3
  | { type: 'addLucidity';         amount: number }
  | { type: 'guaranteedWin';       spins: number; blockPowersSpins: number }
  | { type: 'giveConsumable' };    // gives a random consumable; if slots are full the player must discard one

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
    description: '×5 random-bet spins, then ×5 free spins.',
    effect: { type: 'skipDecay', spins: 5, forcedRandomBetSpins: 5 },
  },
  {
    id: 'item_cocktail',
    name: 'Cocktail',
    description: 'Gain Lucidity equal to 3× the rarity sum of your current reels.',
    effect: { type: 'cocktailBoost' },
  },
  {
    id: 'item_water',
    name: 'Glass of Water',
    description: '+40 Lucidity.',
    effect: { type: 'addLucidity', amount: 40 },
  },
  {
    id: 'item_pill',
    name: 'The Pill',
    description: 'Your next 3 spins are guaranteed to win. No abilities for 5 spins.',
    effect: { type: 'guaranteedWin', spins: 3, blockPowersSpins: 5 },
  },
  {
    id: 'item_stash',
    name: 'The Stash',
    description: 'A random supply from his coat. If your slots are full, you\'ll have to make room.',
    effect: { type: 'giveConsumable' },
  },
];

export const IN_RUN_ITEM_MAP: Readonly<Record<string, InRunItem>> = Object.fromEntries(
  IN_RUN_ITEMS.map(i => [i.id, i])
);
