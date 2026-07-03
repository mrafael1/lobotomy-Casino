// Potion (resetPowersRandomEffect) rolls ONE of these per boosted spin, equal-weight
// with a deterministic per-spin seed so parity stays reproducible (issue #32).
export type PotionRandomEffect =
  | { kind: 'multNextSpin'; multiplier: number } // 0.75 / 1.25 / 1.5× lucidity next spin
  | { kind: 'lucidity';     amount: number }     // +10 / -5 lucidity
  | { kind: 'freeReroll' }                       // grant a free reroll ability charge
  | { kind: 'symbolToBrain' };                   // convert one reel symbol to brain

export type ConsumableEffect =
  | { type: 'hideReelPairBoost';        spins: number; hiddenReels: number; pairMult: number } // Tobacco
  | { type: 'guaranteeSymbol';          excludes: string[]; appearSpins: number; blurSpins: number } // Serum
  | { type: 'scrambleThenHide';         hideNextSpin: boolean }                                 // White Powder
  | { type: 'resetPowersRandomEffect';  spins: number; pool: PotionRandomEffect[] }             // Potion
  | { type: 'restoreAbilityOrSpins';    fallbackSpins: number };                                // Tea

export interface Consumable {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly shopCost: number; // paid with wallet lucidity before the run
  readonly corrupt?: boolean; // renders in the corrupt (purple) hint colour (issue #33)
  readonly effect: ConsumableEffect;
}

// Shared equal-weight Potion pool (issue #32): 0.75/1.25/1.5× mult, +10/-5 lucidity,
// free reroll, symbol→brain.
export const POTION_RANDOM_POOL: ReadonlyArray<PotionRandomEffect> = [
  { kind: 'multNextSpin', multiplier: 0.75 },
  { kind: 'multNextSpin', multiplier: 1.25 },
  { kind: 'multNextSpin', multiplier: 1.5 },
  { kind: 'lucidity', amount: 10 },
  { kind: 'lucidity', amount: -5 },
  { kind: 'freeReroll' },
  { kind: 'symbolToBrain' },
];

// Pre-run consumables: bought in the shop with wallet Lucidity before a run.
// The stash holds up to MAX_CONSUMABLE_SLOTS copies total; the same item may take
// more than one slot (duplicates allowed). Copies transfer to runConsumables when
// the run starts and are lost at run end.
export const CONSUMABLES: ReadonlyArray<Consumable> = [
  {
    id: 'cons_cigarette',
    name: 'Tobacco',
    description: 'For 2 spins one reel goes fully dark (scored on the two you can see), 3× effects are blocked, and pairs pay 3× on top of your bet.',
    shopCost: 20,
    corrupt: true,
    effect: { type: 'hideReelPairBoost', spins: 2, hiddenReels: 1, pairMult: 3 },
  },
  {
    id: 'cons_focus',
    name: 'Serum',
    description: 'Pick a non-brain symbol: it appears at least once next spin. The spin after shows blurry reels.',
    shopCost: 15,
    effect: { type: 'guaranteeSymbol', excludes: ['brain'], appearSpins: 1, blurSpins: 1 },
  },
  {
    id: 'cons_white_powder',
    name: 'White Powder',
    description: 'Scramble one reel onto another, then your next spin is hidden.',
    shopCost: 10,
    corrupt: true,
    effect: { type: 'scrambleThenHide', hideNextSpin: true },
  },
  {
    id: 'cons_potion',
    name: 'Potion',
    description: 'Restores all powers and rolls a random effect each spin for 3 spins.',
    shopCost: 40,
    effect: { type: 'resetPowersRandomEffect', spins: 3, pool: [...POTION_RANDOM_POOL] },
  },
  {
    id: 'cons_tea',
    name: 'Tea',
    description: 'Restore a used ability, or gain 3 free spins if none were used.',
    shopCost: 8,
    effect: { type: 'restoreAbilityOrSpins', fallbackSpins: 3 },
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
