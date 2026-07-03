// Display-only dealer hints — NOT mechanics. The big TV shows the compact
// green (+) / red (−) hints; the dealer speech bubble shows the flavor line.
// Keyed by the existing consumable / in-run item IDs (see content/consumables.ts
// and content/inRunItems.ts) — no consumable effects or data are duplicated.
//
// Rules: each hint is 1–3 words, NO exact numbers, no full mechanics.

export type ConsumableDisplayHints = {
  positiveHint: string;
  negativeHint: string;
  flavorText: string;
};

export const ITEM_HINTS: Record<string, ConsumableDisplayHints> = {
  // ── The three new item assets (water / tablet / white powder) ──
  item_water: {
    positiveHint: 'MYSTERY',
    negativeHint: 'THIN',
    flavorText: 'A mysterious liquid. Too quiet.',
  },
  item_pill: { // Red Pill — the "tablet" asset
    positiveHint: 'LUCK?',
    negativeHint: 'NUMB',
    flavorText: 'Smells like luck. Tastes like sleep.',
  },
  cons_white_powder: {
    positiveHint: 'BRIGHT',
    negativeHint: 'GONE',
    flavorText: 'A flash in a folded packet.',
  },

  // ── Other run / shop consumables (short hints so the TV is never blank) ──
  // Keep every hint short enough to fit the TV on one line at a fixed size.
  item_energy_drink: {
    positiveHint: 'SPARKS',
    negativeHint: 'SHAKY',
    flavorText: 'The can hums in your hand.',
  },
  item_cocktail: {
    positiveHint: 'LUCKY',
    negativeHint: 'STICKY',
    flavorText: 'Smells like luck and old fruit.',
  },
  cons_focus: {
    positiveHint: 'SHARP',
    negativeHint: 'HIDDEN',
    flavorText: 'A thin serum with a staring shine.',
  },
  cons_potion: {
    positiveHint: 'WARM',
    negativeHint: 'DULL',
    flavorText: 'Warm glass. Unclear promise.',
  },
  cons_tea: {
    positiveHint: 'OLD',
    negativeHint: 'RANDOM',
    flavorText: 'Steam curls into familiar shapes.',
  },
};

export const FALLBACK_HINTS: ConsumableDisplayHints = {
  positiveHint: 'ODD',
  negativeHint: 'PRICE',
  flavorText: 'Everything costs something.',
};
