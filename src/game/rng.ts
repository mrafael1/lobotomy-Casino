// Mulberry32 — fast, high-quality 32-bit PRNG with explicit seed.
// Use createRNG(seed) everywhere instead of Math.random() so that:
//   1. Tests are deterministic ("seed 42 always produces X")
//   2. Headless simulator can run 100k reproducible spins
//   3. Bugs are reproducible: "broke on seed N"

export type RNG = () => number;

export function createRNG(seed: number): RNG {
  let s = seed >>> 0;
  return (): number => {
    s += 0x6d2b79f5;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Weighted random selection. Items must be provided in a stable order.
// Passing () => 0 always returns items[0]; () => 0.999... always returns items[last].
export function weightedPick<T>(
  items: ReadonlyArray<{ weight: number; value: T }>,
  rng: RNG,
): T {
  const total = items.reduce((sum, item) => sum + item.weight, 0);
  let roll = rng() * total;
  for (const item of items) {
    roll -= item.weight;
    if (roll < 0) return item.value;
  }
  // Floating-point guard: return last item if roll lands exactly on the boundary
  return items[items.length - 1].value;
}
