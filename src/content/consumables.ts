export type ConsumableEffect =
  | { type: 'skipDecay';                  spins: number }
  | { type: 'grantFreeSpins';             amount: number }
  | { type: 'lucidityMultiplierNextSpin'; multiplier: number }
  | { type: 'lockReelNextSpin' };  // player chooses which reel at use-time

export interface Consumable {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly cost: number; // paid with THIS-RUN Lucidity, not the wallet
  readonly effect: ConsumableEffect;
}

// Note: no consumable may ever ADD neurons — Sacred Rule 1 says neurons only
// go down during a run. Stasis prevents future loss; it never restores.
export const CONSUMABLES: ReadonlyArray<Consumable> = [
  {
    id: 'cons_stasis',
    name: 'Stasis Patch',
    description: 'Your next 3 spins consume no neurons.',
    cost: 50,
    effect: { type: 'skipDecay', spins: 3 },
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
