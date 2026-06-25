export type SymbolId =
  | 'brain'
  | 'eye'
  | 'pill'
  | 'syringe'
  | 'scalpel'
  | 'flatline'
  | 'book';

export interface SlotSymbol {
  readonly id: SymbolId;
  readonly name: string;
  readonly weight: number;  // base weight without upgrades (book=0 without Learning)
  readonly rarityScore: number; // used by Cocktail dealer item
}

// Weights sum to 52 for base symbols (brain through flatline).
// Brain is listed first so () => 0 always selects it (useful in tests).
// Book weight is 0 by default; activated by the Learning upgrade (weight 7).
export const SYMBOLS: Readonly<Record<SymbolId, SlotSymbol>> = {
  brain:    { id: 'brain',    name: 'Brain',    weight: 6,  rarityScore: 10 },
  eye:      { id: 'eye',      name: 'Eye',      weight: 8,  rarityScore: 8  },
  pill:     { id: 'pill',     name: 'Pill',     weight: 9,  rarityScore: 6  },
  syringe:  { id: 'syringe',  name: 'Syringe',  weight: 9,  rarityScore: 6  },
  scalpel:  { id: 'scalpel',  name: 'Scalpel',  weight: 10, rarityScore: 4  },
  flatline: { id: 'flatline', name: 'Flatline', weight: 10, rarityScore: 4  },
  book:     { id: 'book',     name: 'Book',     weight: 0,  rarityScore: 9  },
} as const;

// Canonical reel cycle order of the base symbols (book sits outside the visible
// strip). Single source of truth for the order reels cycle through and abilities
// step along — keep reel visuals and ability logic in sync by importing this.
export const BASE_SYMBOL_CYCLE: ReadonlyArray<SymbolId> = [
  'brain', 'eye', 'pill', 'syringe', 'scalpel', 'flatline',
];

export const SYMBOL_WEIGHTS: ReadonlyArray<{ weight: number; value: SymbolId }> = [
  { weight: SYMBOLS.brain.weight,    value: 'brain'    },
  { weight: SYMBOLS.eye.weight,      value: 'eye'      },
  { weight: SYMBOLS.pill.weight,     value: 'pill'     },
  { weight: SYMBOLS.syringe.weight,  value: 'syringe'  },
  { weight: SYMBOLS.scalpel.weight,  value: 'scalpel'  },
  { weight: SYMBOLS.flatline.weight, value: 'flatline' },
];

// Weight for book when Learning upgrade is owned.
export const BOOK_SYMBOL_WEIGHT = 7;
