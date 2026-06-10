export type AbilityId = 'swap' | 'moveColumn' | 'freeSpinAbility';

export interface Ability {
  readonly id: AbilityId;
  readonly name: string;
  readonly description: string;
  readonly cost: number; // Lucidity cost per use
}

export const ABILITIES: Readonly<Record<AbilityId, Ability>> = {
  swap: {
    id: 'swap',
    name: 'Swap',
    description: 'Swap the symbols of any two reel positions before the next spin.',
    cost: 15,
  },
  moveColumn: {
    id: 'moveColumn',
    name: 'Move Column',
    description: 'Shift one reel\'s symbol up or down by one position.',
    cost: 10,
  },
  freeSpinAbility: {
    id: 'freeSpinAbility',
    name: 'Override',
    description: 'Force the next spin to be free (no neuron cost).',
    cost: 25,
  },
} as const;
