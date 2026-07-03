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
  | { type: 'pattern23Triple' }                                // any 2/3 matching reels -> doubled pair payout
  | { type: 'bookSymbol';               weight: number }       // adds book to spin pool
  | { type: 'smartSaveRetention';       kept: number }
  | { type: 'abilityUnlock';            abilityId: string };

export interface Upgrade {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly category: UpgradeCategory;
  readonly cost: number;
  readonly effect: UpgradeEffect;
  readonly requiresId?: string; // prerequisite upgrade
  readonly tierGroup?: string;  // upgrades sharing this key are rendered as a single row
  readonly tierLabel?: string;  // short label shown on the tier button (e.g. "I", "II", "III")
}

// --- Ability upgrades: permanent abilities unlocked per-run ---

export const ABILITY_UPGRADES: ReadonlyArray<Upgrade> = [
  {
    id: 'perm_shift',
    name: 'Shift',
    description: "Gain 1 use of Shift per run:\nmove a reel's symbol up or down one step in the cycle.",
    category: 'positive',
    cost: 30,
    effect: { type: 'abilityUnlock', abilityId: 'shift' },
  },
  {
    id: 'perm_memory',
    name: 'Memory',
    description: 'Gain 1 use of Memory per run: lock one reel in its current position for the next spin.',
    category: 'positive',
    cost: 30,
    effect: { type: 'abilityUnlock', abilityId: 'memory' },
  },
];

// --- Corrupted upgrades ---
// Buying any of these permanently taints the save slot.

export const CORRUPTED_UPGRADES: ReadonlyArray<Upgrade> = [
  {
    id: 'corr_reward_amp_1',
    name: 'Reward Amplification',
    description: 'All wins pay 15% more Lucidity.',
    category: 'corrupted',
    cost: 15,
    effect: { type: 'rewardAmpBonus', bonus: 0.15 },
    tierGroup: 'reward_amp',
    tierLabel: 'I',
  },
  {
    id: 'corr_reward_amp_2',
    name: 'Reward Amplification',
    description: 'All wins pay 25% more Lucidity.',
    category: 'corrupted',
    cost: 25,
    requiresId: 'corr_reward_amp_1',
    effect: { type: 'rewardAmpBonus', bonus: 0.10 },
    tierGroup: 'reward_amp',
    tierLabel: 'II',
  },
  {
    id: 'corr_reward_amp_3',
    name: 'Reward Amplification',
    description: 'All wins pay 40% more Lucidity.',
    category: 'corrupted',
    cost: 50,
    requiresId: 'corr_reward_amp_2',
    effect: { type: 'rewardAmpBonus', bonus: 0.15 },
    tierGroup: 'reward_amp',
    tierLabel: 'III',
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
    description: 'Any 2 of 3 matching reels, including non-adjacent, pay double pair value. Brain matches are not jackpots.',
    category: 'corrupted',
    cost: 100,
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
    name: 'Hydration',
    description: 'Start each run with +10 neurons.',
    category: 'positive',
    cost: 80,
    effect: { type: 'startingNeuronBonus', amount: 10 },
    tierGroup: 'hydration',
    tierLabel: 'I',
  },
  {
    id: 'pos_hydration_2',
    name: 'Hydration',
    description: 'Start each run with +25 total bonus neurons.',
    category: 'positive',
    cost: 140,
    requiresId: 'pos_hydration_1',
    effect: { type: 'startingNeuronBonus', amount: 15 },
    tierGroup: 'hydration',
    tierLabel: 'II',
  },
  {
    id: 'pos_hydration_3',
    name: 'Hydration',
    description: 'Start each run with +40 total bonus neurons.',
    category: 'positive',
    cost: 200,
    requiresId: 'pos_hydration_2',
    effect: { type: 'startingNeuronBonus', amount: 15 },
    tierGroup: 'hydration',
    tierLabel: 'III',
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
    id: 'pos_enlightenment',
    name: 'Hallucination',
    description: 'All gains pay 25% more Lucidity.',
    category: 'positive',
    cost: 50,
    effect: { type: 'lucidityMultiplier', multiplier: 1.25 },
  },
  {
    id: 'pos_learning',
    name: 'Learning',
    description: 'Adds the Book symbol to the reels. Book pair: +5 Lucidity. Book triple: +15. +10 per Book visible.',
    category: 'positive',
    cost: 70,
    effect: { type: 'bookSymbol', weight: 7 },
  },
  {
    id: 'pos_smart_save',
    name: 'Smart Save',
    description: 'Keep 20% of run Lucidity on reset instead of 10%.',
    category: 'positive',
    cost: 30,
    effect: { type: 'smartSaveRetention', kept: 0.20 },
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
