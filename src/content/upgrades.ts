export type UpgradeCategory = 'corrupted' | 'positive';

export type UpgradeEffect =
  | { type: 'neuronDecayReduction';     amount: number }
  | { type: 'lucidityMultiplier';       multiplier: number }   // multiplicative, no corruption
  | { type: 'rewardAmpBonus';           bonus: number }        // additive corrupted lucidity bonus
  | { type: 'jackpotLucidityMultiplier'; multiplier: number }
  | { type: 'startingNeuronBonus';      amount: number }
  | { type: 'passiveLucidityPerSpin';   amount: number }
  | { type: 'brainWeightBonus';         amount: number }
  | { type: 'sedativeBonusSpin' }                              // every 3rd spin costs no neurons
  | { type: 'pattern23Triple' }                                // any ⅔ matching reels → triple payout
  | { type: 'bookSymbol';               weight: number }       // adds book to spin pool
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

// --- Corrupted upgrades ---
// Buying any of these permanently taints the save slot.

export const CORRUPTED_UPGRADES: ReadonlyArray<Upgrade> = [
  {
    id: 'corr_reward_amp_1',
    name: 'Reward Amplification I',
    description: 'All wins pay 15% more Lucidity.',
    category: 'corrupted',
    cost: 100,
    effect: { type: 'rewardAmpBonus', bonus: 0.15 },
  },
  {
    id: 'corr_reward_amp_2',
    name: 'Reward Amplification II',
    description: 'All wins pay 25% more Lucidity (combined with tier I).',
    category: 'corrupted',
    cost: 160,
    requiresId: 'corr_reward_amp_1',
    effect: { type: 'rewardAmpBonus', bonus: 0.10 },
  },
  {
    id: 'corr_reward_amp_3',
    name: 'Reward Amplification III',
    description: 'All wins pay 40% more Lucidity (combined with tiers I & II).',
    category: 'corrupted',
    cost: 220,
    requiresId: 'corr_reward_amp_2',
    effect: { type: 'rewardAmpBonus', bonus: 0.15 },
  },
  {
    id: 'corr_sedative',
    name: 'Sedative Protocol',
    description: 'Every 3rd spin costs no neurons (bonus spin — no ×3 penalty).',
    category: 'corrupted',
    cost: 180,
    effect: { type: 'sedativeBonusSpin' },
  },
  {
    id: 'corr_pattern_23',
    name: 'Pattern Fabrication',
    description: 'Any 2 of 3 matching reels (including non-adjacent) pay as a triple.',
    category: 'corrupted',
    cost: 200,
    effect: { type: 'pattern23Triple' },
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

// --- Positive upgrades ---
// These never set corruptionEverUsed.

export const POSITIVE_UPGRADES: ReadonlyArray<Upgrade> = [
  {
    id: 'pos_hydration_1',
    name: 'Hydration I',
    description: 'Start each run with +10 neurons.',
    category: 'positive',
    cost: 80,
    effect: { type: 'startingNeuronBonus', amount: 10 },
  },
  {
    id: 'pos_hydration_2',
    name: 'Hydration II',
    description: 'Start each run with +15 more neurons (+25 total with Hydration I).',
    category: 'positive',
    cost: 140,
    requiresId: 'pos_hydration_1',
    effect: { type: 'startingNeuronBonus', amount: 15 },
  },
  {
    id: 'pos_hydration_3',
    name: 'Hydration III',
    description: 'Start each run with +15 more neurons (+40 total with Hydration I & II).',
    category: 'positive',
    cost: 200,
    requiresId: 'pos_hydration_2',
    effect: { type: 'startingNeuronBonus', amount: 15 },
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
    id: 'pos_brain_weight',
    name: 'Pattern Recognition',
    description: 'Brain symbol appears more frequently (+2 weight).',
    category: 'positive',
    cost: 400,
    effect: { type: 'brainWeightBonus', amount: 2 },
  },
  {
    id: 'pos_enlightenment',
    name: 'Enlightenment',
    description: 'All wins pay 25% more Lucidity. Does not corrupt.',
    category: 'positive',
    cost: 450,
    effect: { type: 'lucidityMultiplier', multiplier: 1.25 },
  },
  {
    id: 'pos_learning',
    name: 'Learning',
    description: 'Adds the Book symbol to the reels. Book pair: +5 Lucidity. Book triple: +15. +10 per Book visible.',
    category: 'positive',
    cost: 300,
    effect: { type: 'bookSymbol', weight: 7 },
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
