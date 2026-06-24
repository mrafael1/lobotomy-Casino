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
    positiveHint: 'CLEAR',
    negativeHint: 'LOW PAY',
    flavorText: 'Still water. Still hands.',
  },
  item_pill: { // Red Pill — the "tablet" asset
    positiveHint: 'SLOW FALL',
    negativeHint: 'NUMB',
    flavorText: 'Quiet hands. Heavy thoughts.',
  },
  cons_white_powder: {
    positiveHint: 'RUSH',
    negativeHint: 'CRASH',
    flavorText: 'Bright. Then gone.',
  },

  // ── Other run / shop consumables (short hints so the TV is never blank) ──
  // Keep every hint short enough to fit the TV on one line at a fixed size.
  item_energy_drink: {
    positiveHint: 'FREE',
    negativeHint: 'SHAKY',
    flavorText: "Wired. Won't hold.",
  },
  item_cocktail: {
    positiveHint: 'EASY',
    negativeHint: 'STEALS',
    flavorText: 'Sweet now. Costs later.',
  },
  cons_focus: {
    positiveHint: 'BIG PAY',
    negativeHint: 'BLIND',
    flavorText: 'Sharp eyes. Blind count.',
  },
  cons_syringe: {
    positiveHint: 'BRAINS',
    negativeHint: 'DULL',
    flavorText: 'Smarter. Slower.',
  },
  cons_tea: {
    positiveHint: 'RESTORE',
    negativeHint: 'RANDOM',
    flavorText: 'Warmth returns. Who knows what.',
  },
};

export const FALLBACK_HINTS: ConsumableDisplayHints = {
  positiveHint: 'GIFT',
  negativeHint: 'PRICE',
  flavorText: 'Everything costs something.',
};
