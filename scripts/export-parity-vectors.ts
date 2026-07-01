// Golden-vector exporter — the canonical parity contract for the Godot port.
//
// Reuses the REAL gameplay implementation (evaluate, scoreReels, abilities,
// bankRunToMeta, planLucidityGain, createRNG, dealer) to emit JSON fixtures under
// parity/vectors/. The Godot GDScript core is asserted against these exact
// numbers, so a rebuild that scores/decays/banks differently fails loudly.
//
// Run:  npm run vectors:export
// Guard: npm run vectors:check  (regenerates to a temp dir and diffs — a rule
//        change on the Expo side that isn't intentional will break the build).
//
// Determinism notes:
//  - RNG floats are pinned via their exact uint32 (float === u32 / 4294967296).
//  - bankRunToMeta reads Date.now() for ending timestamps; we freeze it to a
//    fixed value recorded in the vector so the Godot bank() can inject the same.

import { writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

import { createRNG } from '../src/game/rng';
import { evaluate, scoreReels } from '../src/game/evaluate';
import { applyReroll, applyMoveColumn, applyCopyReel } from '../src/game/abilities';
import { bankRunToMeta, checkEnding, checkExitEligibility } from '../src/game/endings';
import { planLucidityGain } from '../src/state/runState';
import { pickDealerItems, evaluateDealerTrigger } from '../src/game/dealer';
import { SYMBOL_WEIGHTS, BOOK_SYMBOL_WEIGHT } from '../src/content/symbols';
import { IN_RUN_ITEMS } from '../src/content/inRunItems';
import { ECONOMY } from '../src/content/economy';
import type {
  SymbolId, ReelResult, RunState, MetaState, EndingType, AbilityId, SpinInput,
} from '../src/game/types';

const OUT_DIR = process.env.VECTORS_OUT_DIR ?? join(__dirname, '..', 'parity', 'vectors');

const RNG_SEEDS = [1, 42, 7777, 123456, 0xDEADBEEF, 0, 0xFFFFFFFF];
const RNG_COUNT = 1000;

const SYMBOLS_ALL: SymbolId[] = ['brain', 'eye', 'pill', 'syringe', 'vial', 'flatline', 'book'];
const MULTIPLIERS = [1, 0.5, 1.15, 1.25, 1.4, 1.5, 1.5625, 1.75, 2, 3];

function write(name: string, data: unknown): void {
  writeFileSync(join(OUT_DIR, name), JSON.stringify(data, null, 2) + '\n', 'utf8');
}

// ── RNG ───────────────────────────────────────────────────────────────────────
// Store the exact uint32 each step (float = u32 / 4294967296.0). uint32 equality
// is strictly stronger than float equality and is unambiguous across engines.
function exportRng(): void {
  const vectors: Record<string, { u32: number[] }> = {};
  for (const seed of RNG_SEEDS) {
    const rng = createRNG(seed);
    const u32: number[] = [];
    for (let i = 0; i < RNG_COUNT; i++) {
      const f = rng();
      u32.push(Math.round(f * 4294967296)); // exact: f is u32/2^32
    }
    vectors[String(seed >>> 0)] = { u32 };
  }
  write('rng.json', {
    description: 'Mulberry32 — first N uint32 outputs per seed. float = u32 / 4294967296.0',
    count: RNG_COUNT,
    seeds: RNG_SEEDS.map(s => s >>> 0),
    vectors,
  });
}

// ── scoreReels ─────────────────────────────────────────────────────────────────
interface ScoreCase {
  reels: ReelResult;
  lucidityMultiplier: number;
  allowFreeSpinGrant: boolean;
  pattern23Triple: boolean;
  learningActive: boolean;
  expect: ReturnType<typeof scoreReels>;
}

function scoreCase(
  reels: ReelResult, m: number, allow: boolean, p: boolean, l: boolean,
): ScoreCase {
  return {
    reels, lucidityMultiplier: m, allowFreeSpinGrant: allow,
    pattern23Triple: p, learningActive: l,
    expect: scoreReels(reels, m, allow, p, l),
  };
}

function exportScoreReels(): void {
  const cases: ScoreCase[] = [];

  // 1) All 343 reel triples at the base contract (m=1, allow grant, no flags).
  for (const a of SYMBOLS_ALL)
    for (const b of SYMBOLS_ALL)
      for (const c of SYMBOLS_ALL)
        cases.push(scoreCase([a, b, c], 1, true, false, false));

  // 2) Curated "interesting" triples across every multiplier × flag combo ×
  //    allow toggle — exercises Math.round half-up on .5 boundaries and the
  //    pattern23 / learning branches.
  const interesting: ReelResult[] = [
    ['brain', 'brain', 'brain'],   // jackpot
    ['eye', 'eye', 'eye'],         // triple 50
    ['pill', 'pill', 'pill'],      // triple 35
    ['syringe', 'syringe', 'syringe'],
    ['vial', 'vial', 'vial'],
    ['flatline', 'flatline', 'flatline'], // 0
    ['book', 'book', 'book'],
    ['eye', 'eye', 'pill'],        // adjacent pair 10
    ['pill', 'eye', 'eye'],        // adjacent pair (b===c)
    ['brain', 'brain', 'eye'],     // brain pair 20
    ['eye', 'pill', 'eye'],        // non-adjacent (miss unless pattern23)
    ['book', 'pill', 'book'],      // non-adjacent book
    ['book', 'eye', 'pill'],       // single book (learning miss-bonus)
    ['book', 'book', 'eye'],       // two books
    ['syringe', 'vial', 'flatline'], // clean miss
  ];
  const flagCombos = [
    { p: false, l: false }, { p: true, l: false },
    { p: false, l: true }, { p: true, l: true },
  ];
  for (const reels of interesting)
    for (const m of MULTIPLIERS)
      for (const { p, l } of flagCombos)
        for (const allow of [true, false])
          cases.push(scoreCase(reels, m, allow, p, l));

  write('score_reels.json', {
    description: 'scoreReels(reels, lucidityMultiplier, allowFreeSpinGrant, pattern23Triple, learningActive)',
    cases,
  });
}

// ── rounding ───────────────────────────────────────────────────────────────────
// Isolates the Math.round(value * multiplier) contract (JS rounds .5 toward +∞;
// GDScript must mirror with floor(x + 0.5)). Many of these land exactly on .5.
function exportRounding(): void {
  const baseScores = [0, 3, 5, 7, 10, 11, 13, 15, 17, 20, 23, 25, 35, 50, 200];
  const multipliers = [0.5, 1, 1.1, 1.15, 1.25, 1.4, 1.5, 1.5625, 1.75, 2, 2.5, 3];
  const cases: { value: number; multiplier: number; expect: number }[] = [];
  for (const value of baseScores)
    for (const multiplier of multipliers)
      cases.push({ value, multiplier, expect: Math.round(value * multiplier) });
  write('rounding.json', {
    description: 'Math.round(value * multiplier) — JS half-up. Mirror with floor(x + 0.5).',
    cases,
  });
}

// ── evaluate ───────────────────────────────────────────────────────────────────
// Seeded SpinInput → SpinResult. Record everything except the rng fn (Godot
// rebuilds it from `seed` with createRNG). evaluate consumes the rng a
// variable number of times, so seed + config fully determines the result.
interface EvalConfig {
  label: string;
  neurons: number;
  neuronDecayAmount: number;
  freeSpinsRemaining: number;
  maxFreeSpins: number;
  lucidityMultiplier: number;
  isFreeSpin: boolean;
  lockedReels: [boolean, boolean, boolean];
  previousReels: ReelResult | null;
  bookWeight: number;
  brainWeightBonus: number;
  guaranteedWin: boolean;
  pattern23Triple: boolean;
  learningActive: boolean;
}

function exportEvaluate(): void {
  const configs: EvalConfig[] = [
    { label: 'plain', neurons: 100, neuronDecayAmount: 3, freeSpinsRemaining: 0, maxFreeSpins: 1, lucidityMultiplier: 1, isFreeSpin: false, lockedReels: [false, false, false], previousReels: null, bookWeight: 0, brainWeightBonus: 0, guaranteedWin: false, pattern23Triple: false, learningActive: false },
    { label: 'free-spin', neurons: 50, neuronDecayAmount: 3, freeSpinsRemaining: 1, maxFreeSpins: 1, lucidityMultiplier: 1, isFreeSpin: true, lockedReels: [false, false, false], previousReels: null, bookWeight: 0, brainWeightBonus: 0, guaranteedWin: false, pattern23Triple: false, learningActive: false },
    { label: 'locked-first', neurons: 100, neuronDecayAmount: 3, freeSpinsRemaining: 0, maxFreeSpins: 1, lucidityMultiplier: 1, isFreeSpin: false, lockedReels: [true, false, false], previousReels: ['brain', 'eye', 'pill'], bookWeight: 0, brainWeightBonus: 0, guaranteedWin: false, pattern23Triple: false, learningActive: false },
    { label: 'brain-boost', neurons: 100, neuronDecayAmount: 3, freeSpinsRemaining: 0, maxFreeSpins: 1, lucidityMultiplier: 1, isFreeSpin: false, lockedReels: [false, false, false], previousReels: null, bookWeight: 0, brainWeightBonus: 18, guaranteedWin: false, pattern23Triple: false, learningActive: false },
    { label: 'learning-book', neurons: 100, neuronDecayAmount: 3, freeSpinsRemaining: 0, maxFreeSpins: 1, lucidityMultiplier: 1.25, isFreeSpin: false, lockedReels: [false, false, false], previousReels: null, bookWeight: BOOK_SYMBOL_WEIGHT, brainWeightBonus: 0, guaranteedWin: false, pattern23Triple: false, learningActive: true },
    { label: 'guaranteed-win', neurons: 100, neuronDecayAmount: 3, freeSpinsRemaining: 0, maxFreeSpins: 1, lucidityMultiplier: 1, isFreeSpin: false, lockedReels: [false, false, false], previousReels: null, bookWeight: 0, brainWeightBonus: 0, guaranteedWin: true, pattern23Triple: false, learningActive: false },
    { label: 'pattern23', neurons: 100, neuronDecayAmount: 3, freeSpinsRemaining: 0, maxFreeSpins: 1, lucidityMultiplier: 1.5625, isFreeSpin: false, lockedReels: [false, false, false], previousReels: null, bookWeight: 0, brainWeightBonus: 0, guaranteedWin: false, pattern23Triple: true, learningActive: false },
  ];

  const cases = [];
  for (const cfg of configs) {
    for (const seed of RNG_SEEDS) {
      const rng = createRNG(seed);
      const input: SpinInput = {
        neurons: cfg.neurons,
        neuronDecayAmount: cfg.neuronDecayAmount,
        freeSpinsRemaining: cfg.freeSpinsRemaining,
        maxFreeSpins: cfg.maxFreeSpins,
        lucidityMultiplier: cfg.lucidityMultiplier,
        isFreeSpin: cfg.isFreeSpin,
        lockedReels: cfg.lockedReels,
        previousReels: cfg.previousReels,
        rng,
        bookWeight: cfg.bookWeight,
        brainWeightBonus: cfg.brainWeightBonus,
        guaranteedWin: cfg.guaranteedWin,
        pattern23Triple: cfg.pattern23Triple,
        learningActive: cfg.learningActive,
      };
      const { rng: _omit, ...inputSansRng } = input;
      void _omit;
      cases.push({ seed: seed >>> 0, input: inputSansRng, expect: evaluate(input) });
    }
  }
  write('evaluate.json', {
    description: 'evaluate(SpinInput) — rng rebuilt from `seed` via createRNG. Result is seed+config determined.',
    cases,
  });
}

// ── abilities ──────────────────────────────────────────────────────────────────
function exportAbilities(): void {
  const cases: unknown[] = [];
  const baseReelSets: ReelResult[] = [
    ['eye', 'pill', 'syringe'],
    ['brain', 'eye', 'eye'],
    ['eye', 'pill', 'eye'],
    ['flatline', 'vial', 'flatline'],
    ['book', 'book', 'eye'],
  ];

  // reroll (seeded)
  for (const reels of baseReelSets) {
    for (const reelIndex of [0, 1, 2]) {
      for (const seed of [1, 42, 7777]) {
        for (const m of [1, 1.25, 1.5625]) {
          const rng = createRNG(seed);
          const out = applyReroll(reels, reelIndex, rng, m, SYMBOL_WEIGHTS, false, false, true);
          cases.push({ op: 'reroll', reels, reelIndex, seed, lucidityMultiplier: m, pattern23Triple: false, learningActive: false, allowFreeSpinGrant: true, expect: out });
        }
      }
    }
  }

  // move (deterministic)
  for (const reels of baseReelSets) {
    for (const reelIndex of [0, 1, 2]) {
      for (const direction of [-1, 1] as const) {
        for (const m of [1, 1.75]) {
          const out = applyMoveColumn(reels, reelIndex, direction, m, false, false, true);
          cases.push({ op: 'move', reels, reelIndex, direction, lucidityMultiplier: m, pattern23Triple: false, learningActive: false, allowFreeSpinGrant: true, expect: out });
        }
      }
    }
  }

  // copy (deterministic)
  for (const reels of baseReelSets) {
    for (const sourceReel of [0, 1, 2]) {
      for (const targetReel of [0, 1, 2]) {
        if (sourceReel === targetReel) continue;
        const out = applyCopyReel(reels, sourceReel, targetReel, 1.25, false, false, true);
        cases.push({ op: 'copy', reels, sourceReel, targetReel, lucidityMultiplier: 1.25, pattern23Triple: false, learningActive: false, allowFreeSpinGrant: true, expect: out });
      }
    }
  }

  // pattern23 + learning ability variants
  for (const reels of baseReelSets) {
    const out = applyMoveColumn(reels, 1, 1, 1.5, true, true, true);
    cases.push({ op: 'move', reels, reelIndex: 1, direction: 1, lucidityMultiplier: 1.5, pattern23Triple: true, learningActive: true, allowFreeSpinGrant: true, expect: out });
  }

  write('abilities.json', {
    description: 'applyReroll/applyMoveColumn/applyCopyReel → AbilityOutcome. reroll rng from `seed`.',
    cases,
  });
}

// ── dealer ─────────────────────────────────────────────────────────────────────
function exportDealer(): void {
  const dealerSeeds = [1, 42, 7777, 123456, 0xDEADBEEF, 99, 1000, 0, 0xFFFFFFFF, 31337];
  const pick = dealerSeeds.map(seed => ({ seed: seed >>> 0, expect: pickDealerItems(seed) }));

  // Trigger truth table: cover 65%/35% safety thresholds, dealerCount gating,
  // min-spin-gap, and the 15% proc fallback (seed chosen to land both sides).
  const triggerInputs = [
    { neurons: 70, startingNeurons: 100, spinCount: 5, dealerCount: 0, dealerLastSpinCount: 0, dealer65SafetyFired: false, dealer35SafetyFired: false, procSeed: 1 },     // ratio .70 > .65, proc decides
    { neurons: 65, startingNeurons: 100, spinCount: 5, dealerCount: 0, dealerLastSpinCount: 0, dealer65SafetyFired: false, dealer35SafetyFired: false, procSeed: 1 },     // ratio .65 hits 65 safety, count 0 → trigger
    { neurons: 64, startingNeurons: 100, spinCount: 5, dealerCount: 1, dealerLastSpinCount: 0, dealer65SafetyFired: true,  dealer35SafetyFired: false, procSeed: 1 },     // 65 already fired, count 1
    { neurons: 35, startingNeurons: 100, spinCount: 8, dealerCount: 1, dealerLastSpinCount: 0, dealer65SafetyFired: true,  dealer35SafetyFired: false, procSeed: 1 },     // ratio .35 hits 35 safety, count 1 → trigger
    { neurons: 34, startingNeurons: 100, spinCount: 8, dealerCount: 2, dealerLastSpinCount: 0, dealer65SafetyFired: true,  dealer35SafetyFired: true,  procSeed: 1 },     // both fired, count 2, proc only
    { neurons: 90, startingNeurons: 100, spinCount: 2, dealerCount: 0, dealerLastSpinCount: 0, dealer65SafetyFired: false, dealer35SafetyFired: false, procSeed: 1 },     // gap too small (2 < 3) → no trigger
    { neurons: 50, startingNeurons: 100, spinCount: 10, dealerCount: 3, dealerLastSpinCount: 0, dealer65SafetyFired: true, dealer35SafetyFired: true,  procSeed: 1 },     // dealerCount at max → no trigger
    { neurons: 50, startingNeurons: 0,   spinCount: 10, dealerCount: 0, dealerLastSpinCount: 0, dealer65SafetyFired: false, dealer35SafetyFired: false, procSeed: 1 },    // startingNeurons 0 → no trigger
  ];
  // Add a sweep of procSeeds at a neutral state to pin the 15% boundary.
  const procState = { neurons: 80, startingNeurons: 100, spinCount: 5, dealerCount: 0, dealerLastSpinCount: 0, dealer65SafetyFired: true, dealer35SafetyFired: true };
  for (const procSeed of [1, 2, 3, 7, 42, 100, 7777, 123456, 0xDEADBEEF]) {
    triggerInputs.push({ ...procState, procSeed });
  }
  const trigger = triggerInputs.map(input => ({ input, expect: evaluateDealerTrigger(input) }));

  // In-run item effect table — pin each item's deterministic effect deltas so the
  // Godot port applies Energy Drink / Cocktail / Water / Red Pill identically.
  const inRunItems = IN_RUN_ITEMS.map(i => ({ id: i.id, effect: i.effect }));

  write('dealer_vectors.json', {
    description: 'Deterministic dealer: pickDealerItems(seed), evaluateDealerTrigger(input), and the in-run item effect table.',
    pickDealerItems: pick,
    evaluateDealerTrigger: trigger,
    inRunItems,
  });
}

// ── bank ───────────────────────────────────────────────────────────────────────
function baseRun(overrides: Partial<RunState> = {}): RunState {
  return {
    neurons: 0, startingNeurons: 100, scoreEarned: 0, lucidityCoins: 0,
    freeSpinsRemaining: 0, maxFreeSpins: 1, lucidityMultiplier: 1,
    nextSpinLucidityMultiplier: 1, isSpinning: false, lastResult: null,
    lockedReels: [false, false, false], lockedReelSpins: [0, 0, 0],
    runConsumables: {}, abilitiesUsed: [], ownedUpgrades: [], spinCount: 0,
    isFreeSpin: false, betMultiplier: 1, dealerCount: 0, dealerLastSpinCount: 0,
    dealer65SafetyFired: false, dealer35SafetyFired: false, dealerIncoming: false,
    dealerPending: false, dealerOfferIds: null, brainBoostSpins: 0,
    forcedRandomBetSpins: 0, guaranteedWinSpins: 0, blockPowersSpins: 0,
    hideNeuronsSpins: 0, cocktailBoostSpins: 0, compulsiveSpinSkips: 0,
    pendingCompulsiveSpinSkips: 0, decaySkips: 0, ...overrides,
  };
}

function baseMeta(overrides: Partial<MetaState> = {}): MetaState {
  return {
    schemaVersion: 2, lucidityWallet: 0, ownedPermanents: [],
    corruptionEverUsed: false, endingsReached: [], pendingConsumables: {},
    is_first_launch: false, history: { runsPlayed: 0, bestScoreRun: 0 }, ...overrides,
  };
}

function exportBank(): void {
  const FIXED_NOW = 1_700_000_000_000;
  const realNow = Date.now;
  Date.now = () => FIXED_NOW;
  try {
    const cases: unknown[] = [];
    const scenarios: { label: string; run: RunState; meta: MetaState; ending: EndingType }[] = [
      { label: 'flatline-basic', run: baseRun({ lucidityCoins: 150, scoreEarned: 320 }), meta: baseMeta(), ending: 'flatline' },
      { label: 'wealth-first', run: baseRun({ lucidityCoins: 999, scoreEarned: 2000 }), meta: baseMeta(), ending: 'wealth' },
      { label: 'wealth-already-reached', run: baseRun({ lucidityCoins: 500, scoreEarned: 1200 }), meta: baseMeta({ endingsReached: ['wealth'], history: { runsPlayed: 3, bestScoreRun: 1100, wealthEndingReachedAt: 111 } }), ending: 'wealth' },
      { label: 'exit-first', run: baseRun({ lucidityCoins: 800, scoreEarned: 400 }), meta: baseMeta({ lucidityWallet: 50 }), ending: 'exit' },
      { label: 'flatline-keeps-best', run: baseRun({ lucidityCoins: 73, scoreEarned: 90 }), meta: baseMeta({ history: { runsPlayed: 9, bestScoreRun: 500 } }), ending: 'flatline' },
      { label: 'rounding-floor', run: baseRun({ lucidityCoins: 155, scoreEarned: 200 }), meta: baseMeta({ lucidityWallet: 7 }), ending: 'flatline' }, // 155*0.10 = 15.5 → floor 15
    ];
    for (const s of scenarios) {
      cases.push({
        label: s.label, now: FIXED_NOW, ending: s.ending,
        run: { lucidityCoins: s.run.lucidityCoins, scoreEarned: s.run.scoreEarned },
        meta: s.meta,
        expect: bankRunToMeta(s.run, s.meta, s.ending),
      });
    }
    write('bank.json', {
      description: 'bankRunToMeta(run, meta, ending) with Date.now() frozen to `now`. Keeps floor(coins*0.10); sets *At only on first reach.',
      lucidityKept: ECONOMY.END_OF_RUN_LUCIDITY_KEPT,
      cases,
    });
  } finally {
    Date.now = realNow;
  }
}

// ── lucidity restore (planLucidityGain) ─────────────────────────────────────────
function exportLucidityRestore(): void {
  const cases: unknown[] = [];
  const used3: AbilityId[] = ['reroll', 'shift', 'memory'];
  const inputs: { prevCoins: number; gain: number; abilitiesUsed: AbilityId[]; seed: number }[] = [
    { prevCoins: 0, gain: 0, abilitiesUsed: used3, seed: 1 },
    { prevCoins: 0, gain: 49, abilitiesUsed: used3, seed: 1 },
    { prevCoins: 0, gain: 50, abilitiesUsed: used3, seed: 1 },         // 1 crossing
    { prevCoins: 49, gain: 1, abilitiesUsed: used3, seed: 42 },        // crosses 50
    { prevCoins: 40, gain: 120, abilitiesUsed: used3, seed: 7777 },    // crosses 50 & 100 & 150 -> 2 restores (list shrinks)
    { prevCoins: 0, gain: 200, abilitiesUsed: ['reroll'], seed: 123 }, // 4 crossings, only 1 spent → 1 restore, rest lost
    { prevCoins: 0, gain: 100, abilitiesUsed: [], seed: 9 },           // nothing spent
    { prevCoins: 95, gain: 10, abilitiesUsed: ['shift', 'memory'], seed: 555 },
    { prevCoins: 10, gain: -5, abilitiesUsed: used3, seed: 1 },        // negative gain
    { prevCoins: 0, gain: 150, abilitiesUsed: ['reroll', 'reroll', 'shift'], seed: 8888 }, // duplicate spent instances
  ];
  for (const inp of inputs) {
    cases.push({
      input: { ...inp },
      expect: planLucidityGain(inp.prevCoins, inp.gain, inp.abilitiesUsed, inp.seed),
    });
  }
  write('lucidity_restore.json', {
    description: 'planLucidityGain(prevCoins, gain, abilitiesUsed, seed). Restores one spent power per 50-coin crossing; list shrinks each crossing.',
    coinsPerRestore: ECONOMY.LUCIDITY_COINS_PER_RESTORE,
    cases,
  });
}

// ── endings ────────────────────────────────────────────────────────────────────
function exportEndings(): void {
  const checkEndingCases: unknown[] = [];
  const endingScenarios: { neurons: number; scoreEarned: number }[] = [
    { neurons: 0, scoreEarned: 0 }, { neurons: -1, scoreEarned: 2000 },
    { neurons: 100, scoreEarned: 0 }, { neurons: 100, scoreEarned: 1999 },
    { neurons: 100, scoreEarned: 2000 }, { neurons: 100, scoreEarned: 2001 },
    { neurons: 1, scoreEarned: 500 },
  ];
  for (const s of endingScenarios) {
    const run = baseRun({ neurons: s.neurons, scoreEarned: s.scoreEarned });
    checkEndingCases.push({ input: s, expect: checkEnding(run, baseMeta()) });
  }

  const exitCases: unknown[] = [];
  const exitScenarios: { lucidityCoins: number; corruptionEverUsed: boolean }[] = [
    { lucidityCoins: 749, corruptionEverUsed: false },
    { lucidityCoins: 750, corruptionEverUsed: false },
    { lucidityCoins: 1000, corruptionEverUsed: false },
    { lucidityCoins: 1000, corruptionEverUsed: true },
    { lucidityCoins: 0, corruptionEverUsed: false },
  ];
  for (const s of exitScenarios) {
    const run = baseRun({ lucidityCoins: s.lucidityCoins });
    const meta = baseMeta({ corruptionEverUsed: s.corruptionEverUsed });
    exitCases.push({ input: s, expect: checkExitEligibility(run, meta) });
  }

  write('endings.json', {
    description: 'checkEnding(run,meta) and checkExitEligibility(run,meta) truth tables.',
    wealthThreshold: ECONOMY.WEALTH_SCORE_THRESHOLD,
    exitThreshold: ECONOMY.EXIT_LUCIDITY_THRESHOLD,
    checkEnding: checkEndingCases,
    checkExitEligibility: exitCases,
  });
}

function main(): void {
  mkdirSync(OUT_DIR, { recursive: true });
  exportRng();
  exportScoreReels();
  exportRounding();
  exportEvaluate();
  exportAbilities();
  exportDealer();
  exportBank();
  exportLucidityRestore();
  exportEndings();
  // eslint-disable-next-line no-console
  console.log(`Parity vectors written to ${OUT_DIR}`);
}

main();
