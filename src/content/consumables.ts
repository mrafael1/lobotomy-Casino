export type ConsumableEffect =
  | { type: 'restoreNeurons';             amount: number }
  | { type: 'grantFreeSpins';             amount: number }
  | { type: 'lucidityMultiplierNextSpin'; multiplier: number }
  | { type: 'lockReelNextSpin' };  // player chooses which reel at use-time

export interface Consumable {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly cost: number;
  readonly effect: ConsumableEffect;
}

export const CONSUMABLES: ReadonlyArray<Consumable> = [
  {
    id: 'cons_neuron_restore',
    name: 'Neural Patch',
    description: 'Restore 20 neurons immediately.',
    cost: 50,
    effect: { type: 'restoreNeurons', amount: 20 },
  },
  {
    id: 'cons_free_spin',
    name: 'Complimentary Spin',
    description: 'Grant 1 free spin immediately.',
    cost: 40,
    effect: { type: 'grantFreeSpins', amount: 1 },
  },
  {
    id: 'cons_lucidity_boost',
    name: 'Focus Serum',
    description: 'Next spin earns 3× Lucidity.',
    cost: 60,
    effect: { type: 'lucidityMultiplierNextSpin', multiplier: 3.0 },
  },
  {
    id: 'cons_reel_lock',
    name: 'Memory Anchor',
    description: 'Lock one reel in its current position for the next spin.',
    cost: 35,
    effect: { type: 'lockReelNextSpin' },
  },
];

export const CONSUMABLE_MAP: Readonly<Record<string, Consumable>> = Object.fromEntries(
  CONSUMABLES.map(c => [c.id, c])
);
