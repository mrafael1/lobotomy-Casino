export type AbilityId = 'reroll' | 'shift' | 'memory';

export interface Ability {
  readonly id: AbilityId;
  readonly name: string;
  readonly description: string;
  readonly upgradeId?: string; // undefined = built-in (REROLL)
}

// Each ability has 1 use per run and costs nothing during the run.
// REROLL is built-in. SHIFT and MEMORY require a permanent upgrade from the shop.
export const ABILITIES: Readonly<Record<AbilityId, Ability>> = {
  reroll: {
    id: 'reroll',
    name: 'Reroll',
    description: 'Spin one selected reel again for a new random symbol.',
  },
  shift: {
    id: 'shift',
    name: 'Shift',
    description: "Move a reel's symbol up or down one step in the cycle.",
    upgradeId: 'perm_shift',
  },
  memory: {
    id: 'memory',
    name: 'Memory',
    description: 'Lock one reel in its current position for the next spin.',
    upgradeId: 'perm_memory',
  },
} as const;
