// Parity-vector drift guard (runs inside `npx jest`): re-derives every committed
// golden vector from the REAL implementation and asserts it still matches. This is
// the Expo-side half of the parity contract — if a rule changes without the
// vectors being regenerated, this fails. (The Godot GUT suite is the other half:
// it asserts the GDScript port reproduces these same files.)
//
// `npm run vectors:check` additionally proves the exporter is deterministic.

import { readFileSync } from 'fs';
import { join } from 'path';
import { createRNG } from '../src/game/rng';
import { evaluate, scoreReels } from '../src/game/evaluate';
import { applyReroll, applyMoveColumn, applyCopyReel } from '../src/game/abilities';
import { bankRunToMeta, checkEnding, checkExitEligibility } from '../src/game/endings';
import { planLucidityGain } from '../src/state/runState';
import { pickDealerItems, evaluateDealerTrigger } from '../src/game/dealer';
import { SYMBOL_WEIGHTS } from '../src/content/symbols';
import type { ReelResult, RunState, MetaState, SpinInput, AbilityId } from '../src/game/types';

const DIR = join(__dirname, '..', 'parity', 'vectors');
const load = (name: string): any => JSON.parse(readFileSync(join(DIR, name), 'utf8'));

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
    pendingCompulsiveSpinSkips: 0, decaySkips: 0,
    pairBoostSpins: 0, pairBoostMult: 1, pairBoostHiddenReels: 0, guaranteeSymbolSpins: 0,
    banBrainSpins: 0, potionSpins: 0, forceFlatlineSpins: 0, guaranteedTripleSpins: 0, hideResultSpins: 0,
    ...overrides,
  };
}

test('rng.json matches createRNG', () => {
  const data = load('rng.json');
  for (const seed of data.seeds) {
    const rng = createRNG(seed);
    const u32 = data.vectors[String(seed >>> 0)].u32;
    for (let i = 0; i < u32.length; i++) {
      expect(Math.round(rng() * 4294967296)).toBe(u32[i]);
    }
  }
});

test('score_reels.json matches scoreReels', () => {
  for (const c of load('score_reels.json').cases) {
    expect(scoreReels(c.reels, c.lucidityMultiplier, c.allowFreeSpinGrant, c.pattern23Triple, c.learningActive))
      .toEqual(c.expect);
  }
});

test('rounding.json matches Math.round(value*multiplier)', () => {
  for (const c of load('rounding.json').cases) {
    expect(Math.round(c.value * c.multiplier)).toBe(c.expect);
  }
});

test('evaluate.json matches evaluate', () => {
  for (const c of load('evaluate.json').cases) {
    const input: SpinInput = { ...c.input, rng: createRNG(c.seed) };
    expect(evaluate(input)).toEqual(c.expect);
  }
});

test('abilities.json matches ability transforms', () => {
  for (const c of load('abilities.json').cases) {
    let out;
    if (c.op === 'reroll') {
      out = applyReroll(c.reels as ReelResult, c.reelIndex, createRNG(c.seed), c.lucidityMultiplier, SYMBOL_WEIGHTS, c.pattern23Triple, c.learningActive, c.allowFreeSpinGrant);
    } else if (c.op === 'move') {
      out = applyMoveColumn(c.reels as ReelResult, c.reelIndex, c.direction, c.lucidityMultiplier, c.pattern23Triple, c.learningActive, c.allowFreeSpinGrant);
    } else {
      out = applyCopyReel(c.reels as ReelResult, c.sourceReel, c.targetReel, c.lucidityMultiplier, c.pattern23Triple, c.learningActive, c.allowFreeSpinGrant);
    }
    expect(out).toEqual(c.expect);
  }
});

test('dealer_vectors.json matches dealer logic', () => {
  const data = load('dealer_vectors.json');
  for (const c of data.pickDealerItems) {
    expect(pickDealerItems(c.seed)).toEqual(c.expect);
  }
  for (const c of data.evaluateDealerTrigger) {
    expect(evaluateDealerTrigger(c.input)).toEqual(c.expect);
  }
});

test('bank.json matches bankRunToMeta (with frozen now)', () => {
  const realNow = Date.now;
  try {
    for (const c of load('bank.json').cases) {
      Date.now = () => c.now;
      const run = baseRun({ lucidityCoins: c.run.lucidityCoins, scoreEarned: c.run.scoreEarned });
      expect(bankRunToMeta(run, c.meta as MetaState, c.ending)).toEqual(c.expect);
    }
  } finally {
    Date.now = realNow;
  }
});

test('lucidity_restore.json matches planLucidityGain', () => {
  for (const c of load('lucidity_restore.json').cases) {
    const { prevCoins, gain, abilitiesUsed, seed } = c.input;
    expect(planLucidityGain(prevCoins, gain, abilitiesUsed as AbilityId[], seed)).toEqual(c.expect);
  }
});

test('endings.json matches checkEnding / checkExitEligibility', () => {
  const data = load('endings.json');
  const emptyMeta: MetaState = { schemaVersion: 2, lucidityWallet: 0, ownedPermanents: [], corruptionEverUsed: false, endingsReached: [], pendingConsumables: {}, is_first_launch: false, history: { runsPlayed: 0, bestScoreRun: 0 } };
  for (const c of data.checkEnding) {
    const run = baseRun({ neurons: c.input.neurons, scoreEarned: c.input.scoreEarned });
    expect(checkEnding(run, emptyMeta)).toBe(c.expect);
  }
  for (const c of data.checkExitEligibility) {
    const run = baseRun({ lucidityCoins: c.input.lucidityCoins });
    const meta = { schemaVersion: 2, lucidityWallet: 0, ownedPermanents: [], corruptionEverUsed: c.input.corruptionEverUsed, endingsReached: [], pendingConsumables: {}, is_first_launch: false, history: { runsPlayed: 0, bestScoreRun: 0 } } as MetaState;
    expect(checkExitEligibility(run, meta)).toBe(c.expect);
  }
});
