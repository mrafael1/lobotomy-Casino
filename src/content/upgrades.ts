export type UpgradeCategory = 'corrupted' | 'positive';

export type UpgradeEffect =
  | { type: 'neuronDecayReduction';     amount: number }
  | { type: 'lucidityMultiplier';       multiplier: number }
  | { type: 'freeSpinMaxIncrease';      newMax: number }
  | { type: 'pairAsTriple' }
  | { type: 'jackpotLucidityMultiplier'; multiplier: number }
  | { type: 'startingNeuronBonus';      amount: number }
  | { type: 'passiveLucidityPerSpin';   amount: number }
  | { type: 'neuronCapIncrease';        newCap: number }
  | { type: 'brainWeightBonus';         amount: number }
  | { type: 'cleanLucidityMultiplier';  multiplier: number }
  | { type: 'abilityUnlock';            abilityId: string };

export interface Upgrade {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly category: UpgradeCategory;
  readonly cost: number;
  readonly effect: UpgradeEffect;
  readonly requiresId?: string; // prerequisite upgrade
}

// --- Ability upgrades: permanent abilities unlocked per-run ---
// Buying these adds the id to ownedPermanents; runState checks presence to
// grant 1 use of the corresponding ability each run.

export const ABILITY_UPGRADES: ReadonlyArray<Upgrade> = [
  {
    id: 'perm_shift',
    name: 'Shift',
    description: "Gain 1 use of Shift per run: move a reel's symbol up or down one step in the cycle.",
    category: 'positive',
    cost: 80,
    effect: { type: 'abilityUnlock', abilityId: 'shift' },
  },
  {
    id: 'perm_memory',
    name: 'Memory',
    description: 'Gain 1 use of Memory per run: lock one reel in its current position for the next spin.',
    category: 'positive',
    cost: 100,
    effect: { type: 'abilityUnlock', abilityId: 'memory' },
  },
];

// --- Act I: Corrupted upgrades (6) ---
// Buying any of these permanently taints the save slot.

export const CORRUPTED_UPGRADES: ReadonlyArray<Upgrade> = [
  {
    id: 'corr_lucidity_amplifier',
    name: 'Reward Amplification',
    description: 'All wins pay 50% more Lucidity.',
    category: 'corrupted',
    cost: 120,
    effect: { type: 'lucidityMultiplier', multiplier: 1.5 },
  },
  {
    id: 'corr_slow_decay',
    name: 'Sedative Protocol',
    description: 'Reduce neuron decay by 1 per spin.',
    category: 'corrupted',
    cost: 200,
    requiresId: 'corr_lucidity_amplifier',
    effect: { type: 'neuronDecayReduction', amount: 1 },
  },
  {
    id: 'corr_free_spin_max_2',
    name: 'Compulsive Loop I',
    description: 'Raise free spin cap to 2.',
    category: 'corrupted',
    cost: 100,
    effect: { type: 'freeSpinMaxIncrease', newMax: 2 },
  },
  {
    id: 'corr_free_spin_max_3',
    name: 'Compulsive Loop II',
    description: 'Raise free spin cap to 3.',
    category: 'corrupted',
    cost: 150,
    effect: { type: 'freeSpinMaxIncrease', newMax: 3 },
    requiresId: 'corr_free_spin_max_2',
  },
  {
    id: 'corr_pair_as_triple',
    name: 'Pattern Fabrication',
    description: 'Pairs pay as if they were triples.',
    category: 'corrupted',
    cost: 200,
    effect: { type: 'pairAsTriple' },
  },
  {
    id: 'corr_jackpot_double',
    name: 'Euphoria Spiral',
    description: 'Jackpot pays double Lucidity.',
    category: 'corrupted',
    cost: 250,
    effect: { type: 'jackpotLucidityMultiplier', multiplier: 2.0 },
  },
];

// --- Act II: Positive upgrades (6) ---
// These never set corruptionEverUsed.

export const POSITIVE_UPGRADES: ReadonlyArray<Upgrade> = [
  {
    id: 'pos_neuron_start',
    name: 'Neural Regeneration',
    description: 'Start each run with +20 neurons.',
    category: 'positive',
    cost: 300,
    effect: { type: 'startingNeuronBonus', amount: 20 },
  },
  {
    id: 'pos_passive_lucidity',
    name: 'Passive Cognition',
    description: 'Earn +5 Lucidity per spin regardless of result.',
    category: 'positive',
    cost: 200,
    effect: { type: 'passiveLucidityPerSpin', amount: 5 },
  },
  {
    id: 'pos_neuron_cap',
    name: 'Expanded Capacity',
    description: 'Raise maximum neurons to 200.',
    category: 'positive',
    cost: 350,
    effect: { type: 'neuronCapIncrease', newCap: 200 },
  },
  {
    id: 'pos_brain_weight',
    name: 'Pattern Recognition',
    description: 'Brain symbol appears more frequently (+2 weight).',
    category: 'positive',
    cost: 400,
    effect: { type: 'brainWeightBonus', amount: 2 },
  },
  {
    id: 'pos_neuron_cap_2',
    name: 'Expanded Capacity II',
    description: 'Raise maximum neurons to 300.',
    category: 'positive',
    cost: 500,
    effect: { type: 'neuronCapIncrease', newCap: 300 },
    requiresId: 'pos_neuron_cap',
  },
  {
    id: 'pos_clean_multiplier',
    name: 'Clean Cognition',
    description: 'All wins pay 25% more Lucidity. Does not corrupt.',
    category: 'positive',
    cost: 450,
    effect: { type: 'cleanLucidityMultiplier', multiplier: 1.25 },
  },
];

export const ALL_UPGRADES: ReadonlyArray<Upgrade> = [
  ...ABILITY_UPGRADES,
  ...CORRUPTED_UPGRADES,
  ...POSITIVE_UPGRADES,
];

export const UPGRADE_MAP: Readonly<Record<string, Upgrade>> = Object.fromEntries(
  ALL_UPGRADES.map(u => [u.id, u])
);
