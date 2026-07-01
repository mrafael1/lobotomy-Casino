// Sacred-rule tests: these ARE the game's design encoded as assertions.
// A failure here is a release blocker, not a normal bug.
// All 7 rules from §6 of lobotomyarchitecture.md.

import { createRNG } from '../src/game/rng';
import { evaluate } from '../src/game/evaluate';
import { bankRunToMeta, checkExitEligibility } from '../src/game/endings';
import { ECONOMY } from '../src/content/economy';
import type { RunState, MetaState, SpinInput } from '../src/game/types';

// RNG that always returns 0 → always selects 'brain' (first in SYMBOL_WEIGHTS)
const brainRng = (): number => 0;
// RNG that always returns a value near 1 → always selects 'flatline' (last in SYMBOL_WEIGHTS)
const flatlineRng = (): number => 0.999;

function baseRunState(overrides: Partial<RunState> = {}): RunState {
  return {
    neurons:                   ECONOMY.STARTING_NEURONS,
    startingNeurons:           ECONOMY.STARTING_NEURONS,
    scoreEarned:               0,
    lucidityCoins:             0,
    freeSpinsRemaining:        0,
    maxFreeSpins:              ECONOMY.BASE_MAX_FREE_SPINS,
    lucidityMultiplier:        1,
    nextSpinLucidityMultiplier: 1,
    isSpinning:                false,
    lastResult:                null,
    lockedReels:               [false, false, false],
    lockedReelSpins:           [0, 0, 0],
    runConsumables:            {},
    abilitiesUsed:             [],
    ownedUpgrades:             [],
    spinCount:                 0,
    isFreeSpin:                false,
    betMultiplier:             1,
    dealerCount:               0,
    dealerLastSpinCount:       0,
    dealer65SafetyFired:       false,
    dealer35SafetyFired:       false,
    dealerIncoming:            false,
    dealerPending:             false,
    dealerOfferIds:            null,
    brainBoostSpins:           0,
    forcedRandomBetSpins:      0,
    guaranteedWinSpins:        0,
    blockPowersSpins:          0,
    hideNeuronsSpins:          0,
    cocktailBoostSpins:        0,
    compulsiveSpinSkips:       0,
    pendingCompulsiveSpinSkips: 0,
    decaySkips:                0,
    pairBoostSpins:            0,
    pairBoostMult:             1,
    pairBoostHiddenReels:      0,
    guaranteeSymbolSpins:      0,
    banBrainSpins:             0,
    potionSpins:               0,
    forceFlatlineSpins:        0,
    guaranteedTripleSpins:     0,
    hideResultSpins:           0,
    ...overrides,
  };
}

function baseMetaState(overrides: Partial<MetaState> = {}): MetaState {
  return {
    schemaVersion:      2,
    lucidityWallet:     0,
    ownedPermanents:    [],
    corruptionEverUsed: false,
    endingsReached:     [],
    pendingConsumables: {},
    is_first_launch:    false,
    history: { runsPlayed: 0, bestScoreRun: 0 },
    ...overrides,
  };
}

function baseSpinInput(overrides: Partial<SpinInput> = {}): SpinInput {
  return {
    neurons:            ECONOMY.STARTING_NEURONS,
    neuronDecayAmount:  ECONOMY.NEURON_DECAY_PER_SPIN,
    freeSpinsRemaining: 0,
    maxFreeSpins:       ECONOMY.BASE_MAX_FREE_SPINS,
    lucidityMultiplier: 1,
    isFreeSpin:         false,
    lockedReels:        [false, false, false],
    previousReels:      null,
    rng:                createRNG(42),
    bookWeight:         0,
    brainWeightBonus:   0,
    guaranteedWin:      false,
    pattern23Triple:    false,
    learningActive:     false,
    ...overrides,
  };
}

// ─────────────────────────────────────────────
// Rule 1: Neurons never increase during a run
// ─────────────────────────────────────────────
test('Rule 1: neurons never increase on a regular spin', () => {
  const rng = createRNG(42);
  for (let i = 0; i < 500; i++) {
    const startNeurons = 100 - i * 0; // always 100 to isolate the rule
    const result = evaluate(baseSpinInput({ neurons: startNeurons, rng }));
    expect(result.neuronsAfter).toBeLessThanOrEqual(startNeurons);
  }
});

test('Rule 1: neurons never increase on a jackpot spin', () => {
  // brainRng forces jackpot — jackpot gives Lucidity, never neurons
  const result = evaluate(baseSpinInput({ rng: brainRng }));
  expect(result.isJackpot).toBe(true);
  expect(result.neuronsAfter).toBeLessThanOrEqual(ECONOMY.STARTING_NEURONS);
});

// ─────────────────────────────────────────────
// Rule 2: Free spins cannot chain
// ─────────────────────────────────────────────
test('Rule 2: jackpot on a free spin grants 0 additional free spins', () => {
  // brainRng forces jackpot on every spin. With isFreeSpin=true, freeSpinsGranted must be 0.
  const result = evaluate(
    baseSpinInput({
      rng: brainRng,
      isFreeSpin: true,
      freeSpinsRemaining: 1,
      maxFreeSpins: 3,
    }),
  );
  expect(result.isJackpot).toBe(true);
  expect(result.freeSpinsGranted).toBe(0);
});

test('Rule 2: no spin type can grant free spins when isFreeSpin=true (1000 spins)', () => {
  const rng = createRNG(7777);
  for (let i = 0; i < 1000; i++) {
    const result = evaluate(
      baseSpinInput({ rng, isFreeSpin: true, freeSpinsRemaining: 1, maxFreeSpins: 3 }),
    );
    expect(result.freeSpinsGranted).toBe(0);
  }
});

// ─────────────────────────────────────────────
// Rule 3: A free spin does not consume neurons
// ─────────────────────────────────────────────
test('Rule 3: free spin leaves neuron count unchanged', () => {
  const startNeurons = 73;
  const result = evaluate(
    baseSpinInput({ neurons: startNeurons, isFreeSpin: true, freeSpinsRemaining: 1 }),
  );
  expect(result.neuronsAfter).toBe(startNeurons);
});

// ─────────────────────────────────────────────
// Rule 4: Jackpot on a free spin gives Lucidity but no extra free spin
// ─────────────────────────────────────────────
test('Rule 4: jackpot on free spin — Lucidity awarded, no free spin granted', () => {
  const result = evaluate(
    baseSpinInput({
      rng: brainRng,
      isFreeSpin: true,
      freeSpinsRemaining: 1,
      maxFreeSpins: 1,
    }),
  );
  expect(result.isJackpot).toBe(true);
  expect(result.scoreEarned).toBeGreaterThan(0);
  expect(result.freeSpinsGranted).toBe(0);
  // consuming the free spin decrements remaining
  expect(result.freeSpinsAfter).toBe(0);
});

// ─────────────────────────────────────────────
// Rule 5: Buying a corrupted upgrade sets corruptionEverUsed = true permanently
// ─────────────────────────────────────────────
test('Rule 5: tainted meta stays tainted through bankRunToMeta', () => {
  const taintedMeta = baseMetaState({ corruptionEverUsed: true });
  const run = baseRunState({ lucidityCoins: 100 });
  const banked = bankRunToMeta(run, taintedMeta, 'flatline');
  expect(banked.corruptionEverUsed).toBe(true);
});

test('Rule 5: clean meta stays clean through bankRunToMeta', () => {
  const cleanMeta = baseMetaState({ corruptionEverUsed: false });
  const run = baseRunState({ lucidityCoins: 100 });
  const banked = bankRunToMeta(run, cleanMeta, 'flatline');
  // bankRunToMeta never sets corruptionEverUsed to true — only the shop does
  expect(banked.corruptionEverUsed).toBe(false);
});

// ─────────────────────────────────────────────
// Rule 6: Exit Route fails if corruptionEverUsed === true
// ─────────────────────────────────────────────
test('Rule 6: Exit Route blocked when slot is tainted', () => {
  const run = baseRunState({ lucidityCoins: 99999 }); // far above any threshold
  const tainted = baseMetaState({ corruptionEverUsed: true });
  expect(checkExitEligibility(run, tainted)).toBe(false);
});

test('Rule 6: Exit Route available when slot is clean and threshold met', () => {
  const run = baseRunState({ lucidityCoins: ECONOMY.EXIT_LUCIDITY_THRESHOLD });
  const clean = baseMetaState({ corruptionEverUsed: false });
  expect(checkExitEligibility(run, clean)).toBe(true);
});

test('Rule 6: Exit Route blocked even on clean slot if threshold not met', () => {
  const run = baseRunState({ lucidityCoins: ECONOMY.EXIT_LUCIDITY_THRESHOLD - 1 });
  const clean = baseMetaState({ corruptionEverUsed: false });
  expect(checkExitEligibility(run, clean)).toBe(false);
});

// ─────────────────────────────────────────────
// Rule 7: Run end banks only Lucidity — nothing else crosses into meta
// ─────────────────────────────────────────────
test('Rule 7: bankRunToMeta transfers Lucidity and history, nothing else', () => {
  const run = baseRunState({ neurons: 42, lucidityCoins: 150, spinCount: 77 });
  const meta = baseMetaState({ lucidityWallet: 50 });
  const banked = bankRunToMeta(run, meta, 'flatline');

  // Lucidity banks — only 10% of the run's accumulated coins are kept.
  // 50 wallet + floor(150 * 0.10) = 50 + 15 = 65.
  expect(banked.lucidityWallet).toBe(65);

  // Run-only fields are NOT present in MetaState
  expect('neurons' in banked).toBe(false);
  expect('startingNeurons' in banked).toBe(false);
  expect('freeSpinsRemaining' in banked).toBe(false);
  expect('maxFreeSpins' in banked).toBe(false);
  expect('spinCount' in banked).toBe(false);
  expect('isSpinning' in banked).toBe(false);
  expect('lastResult' in banked).toBe(false);
  expect('isFreeSpin' in banked).toBe(false);
  expect('lucidityMultiplier' in banked).toBe(false);
  expect('scoreEarned' in banked).toBe(false);
  expect('lucidityCoins' in banked).toBe(false);
});

test('Rule 7: Smart Save banks 20% of run Lucidity', () => {
  const run = baseRunState({ neurons: 42, lucidityCoins: 200, spinCount: 77 });
  const meta = baseMetaState({
    lucidityWallet: 50,
    ownedPermanents: [ECONOMY.SMART_SAVE_UPGRADE_ID],
  });
  const banked = bankRunToMeta(run, meta, 'flatline');

  expect(banked.lucidityWallet).toBe(90);
});

test('Rule 7: history.runsPlayed increments by exactly 1 per run end', () => {
  const meta = baseMetaState({ history: { runsPlayed: 5, bestScoreRun: 0 } });
  const run = baseRunState({ lucidityCoins: 10 });
  const banked = bankRunToMeta(run, meta, 'flatline');
  expect(banked.history.runsPlayed).toBe(6);
});
