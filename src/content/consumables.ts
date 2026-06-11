export type ConsumableEffect =
  | { type: 'skipDecay';                  spins: number }
  | { type: 'grantFreeSpins';             amount: number }
  | { type: 'lucidityMultiplierNextSpin'; multiplier: number };

export interface Consumable {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly shopCost: number; // paid with wallet lucidity before the run
  readonly effect: ConsumableEffect;
}

// Consumables are bought in the shop with wallet Lucidity before a run.
// Each purchase adds 1 charge to pendingConsumables; charges transfer to
// runConsumables when the run starts and are lost (unused) at run end.
export const CONSUMABLES: ReadonlyArray<Consumable> = [
  {
    id: 'cons_override',
    name: 'Override',
    description: 'Skip neuron decay for your next spin.',
    shopCost: 50,
    effect: { type: 'skipDecay', spins: 1 },
  },
  {
    id: 'cons_focus',
    name: 'Focus Serum',
    description: 'Next spin earns 3× Lucidity.',
    shopCost: 60,
    effect: { type: 'lucidityMultiplierNextSpin', multiplier: 3.0 },
  },
  {
    id: 'cons_stasis',
    name: 'Stasis Patch',
    description: 'Your next 3 spins consume no neurons.',
    shopCost: 80,
    effect: { type: 'skipDecay', spins: 3 },
  },
  {
    id: 'cons_free_spin',
    name: 'Free Spin',
    description: 'Grant 1 free spin.',
    shopCost: 45,
    effect: { type: 'grantFreeSpins', amount: 1 },
  },
];

export const CONSUMABLE_MAP: Readonly<Record<string, Consumable>> = Object.fromEntries(
  CONSUMABLES.map(c => [c.id, c])
);
