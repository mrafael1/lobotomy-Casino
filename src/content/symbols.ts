export type SymbolId =
  | 'brain'
  | 'eye'
  | 'pill'
  | 'syringe'
  | 'scalpel'
  | 'flatline';

export interface SlotSymbol {
  readonly id: SymbolId;
  readonly name: string;
  readonly weight: number;
}

// Weights must always sum to 52.
// Brain is listed first so () => 0 always selects it (useful in tests).
export const SYMBOLS: Readonly<Record<SymbolId, SlotSymbol>> = {
  brain:    { id: 'brain',    name: 'Brain',    weight: 6  },
  eye:      { id: 'eye',      name: 'Eye',      weight: 8  },
  pill:     { id: 'pill',     name: 'Pill',     weight: 9  },
  syringe:  { id: 'syringe',  name: 'Syringe',  weight: 9  },
  scalpel:  { id: 'scalpel',  name: 'Scalpel',  weight: 10 },
  flatline: { id: 'flatline', name: 'Flatline', weight: 10 },
} as const;

// Sum = 6+8+9+9+10+10 = 52
export const TOTAL_SYMBOL_WEIGHT = 52;

export const SYMBOL_WEIGHTS: ReadonlyArray<{ weight: number; value: SymbolId }> = [
  { weight: SYMBOLS.brain.weight,    value: 'brain'    },
  { weight: SYMBOLS.eye.weight,      value: 'eye'      },
  { weight: SYMBOLS.pill.weight,     value: 'pill'     },
  { weight: SYMBOLS.syringe.weight,  value: 'syringe'  },
  { weight: SYMBOLS.scalpel.weight,  value: 'scalpel'  },
  { weight: SYMBOLS.flatline.weight, value: 'flatline' },
];
