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
// The stash holds up to MAX_CONSUMABLE_SLOTS copies total; the same item may take
// more than one slot (duplicates allowed). Copies transfer to runConsumables when
// the run starts and are lost at run end.
export const CONSUMABLES: ReadonlyArray<Consumable> = [
  {
    id: 'cons_focus',
    name: 'Focus Serum',
    description: 'Next spin earns 3× Lucidity. Side effect: your neuron count is hidden for 5 spins.',
    shopCost: 12,
    effect: { type: 'lucidityMultiplierNextSpin', multiplier: 3.0, hideNeuronsSpins: 5 },
  },
  {
    id: 'cons_white_powder',
    name: 'White Powder',
    description: 'Copy one reel\'s symbol onto another. Side effect: consume a random other supply or lose 20 neurons.',
    shopCost: 14,
    effect: { type: 'copyReel' },
  },
  {
    id: 'cons_syringe',
    name: 'Syringe',
    description: 'Brain is 5× more likely for 5 spins. Reduced Lucidity and no abilities during boost. Permanently blocks a random ability.',
    shopCost: 18,
    effect: { type: 'brainBoost', spins: 5 },
  },
  {
    id: 'cons_tea',
    name: 'Herbal Tea',
    description: 'Restore a random ability you have already used this run.',
    shopCost: 10,
    effect: { type: 'restoreAbility' },
  },
];

export const CONSUMABLE_MAP: Readonly<Record<string, Consumable>> = Object.fromEntries(
  CONSUMABLES.map(c => [c.id, c])
);

// Stash capacity, counted in item COPIES (not distinct types). Each copy is one
// physical slot and one independent use, so the same consumable may occupy more
// than one slot (e.g. WATER + WATER). A purchase is allowed whenever the total
// number of copies held is below this cap; "stash full" is the only block.
export const MAX_CONSUMABLE_SLOTS = 2;

// Total copies currently held across all consumable types in a stash map.
export function totalConsumableCopies(map: Partial<Record<string, number>>): number {
  return Object.values(map).reduce<number>((sum, n) => sum + (n ?? 0), 0);
}

export interface StashSlot { id: string; name: string; charges: number }

// Expand a stash map (id → copies) into one slot PER copy, so a duplicate item
// fills two slots (WATER, WATER) instead of stacking into one with a ×2 badge.
// `pool` provides display names; result length is exactly MAX_CONSUMABLE_SLOTS.
export function buildStashSlots(
  map: Partial<Record<string, number>>,
  pool: ReadonlyArray<{ id: string; name: string }>,
): Array<StashSlot | null> {
  const instances: StashSlot[] = [];
  for (const item of pool) {
    const copies = map[item.id] ?? 0;
    for (let k = 0; k < copies && instances.length < MAX_CONSUMABLE_SLOTS; k++) {
      instances.push({ id: item.id, name: item.name, charges: 1 });
    }
  }
  return Array.from({ length: MAX_CONSUMABLE_SLOTS }, (_, i) => instances[i] ?? null);
}
