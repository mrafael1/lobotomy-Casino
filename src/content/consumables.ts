export type ConsumableEffect =
  | { type: 'skipDecay';                  spins: number }
  | { type: 'lucidityMultiplierNextSpin'; multiplier: number; hideNeuronsSpins?: number }
  | { type: 'copyReel' }                    // White Powder: copy one reel symbol to another via UI
  | { type: 'brainBoost';                 spins: number }  // Syringe: brain 5× more likely for N spins
  | { type: 'restoreAbility' };             // Tea: restore one random used ability

export interface Consumable {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly shopCost: number; // paid with wallet lucidity before the run
  readonly effect: ConsumableEffect;
}

// Pre-run consumables: bought in the shop with wallet Lucidity before a run.
// Max 2 distinct consumable types can be brought into a run (slots cap).
// Each type stacks to at most MAX_CONSUMABLE_CHARGES_PER_SLOT charges.
// Charges transfer to runConsumables when the run starts and are lost at run end.
export const CONSUMABLES: ReadonlyArray<Consumable> = [
  {
    id: 'cons_focus',
    name: 'Focus Serum',
    description: 'Next spin earns 3× Lucidity. Side effect: your neuron count is hidden for 5 spins.',
    shopCost: 60,
    effect: { type: 'lucidityMultiplierNextSpin', multiplier: 3.0, hideNeuronsSpins: 5 },
  },
  {
    id: 'cons_white_powder',
    name: 'White Powder',
    description: 'Copy one reel\'s symbol onto another. Side effect: consume a random other supply or lose 20 neurons.',
    shopCost: 70,
    effect: { type: 'copyReel' },
  },
  {
    id: 'cons_syringe',
    name: 'Syringe',
    description: 'Brain is 5× more likely for 5 spins. Reduced Lucidity and no abilities during boost. Permanently blocks a random ability.',
    shopCost: 90,
    effect: { type: 'brainBoost', spins: 5 },
  },
  {
    id: 'cons_tea',
    name: 'Herbal Tea',
    description: 'Restore a random ability you have already used this run.',
    shopCost: 50,
    effect: { type: 'restoreAbility' },
  },
];

export const CONSUMABLE_MAP: Readonly<Record<string, Consumable>> = Object.fromEntries(
  CONSUMABLES.map(c => [c.id, c])
);

// Maximum number of distinct consumable types that can be brought into a run.
export const MAX_CONSUMABLE_SLOTS = 2;

// Maximum charges of a single consumable type that can be queued for a run.
export const MAX_CONSUMABLE_CHARGES_PER_SLOT = 2;
