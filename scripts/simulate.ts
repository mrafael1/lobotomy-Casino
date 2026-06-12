// Headless simulator: runs N complete runs headlessly and reports balance metrics.
// Usage:  npx ts-node scripts/simulate.ts
// Tune src/content/economy.ts and src/content/payouts.ts until the numbers feel right.

import { createRNG } from '../src/game/rng';
import { evaluate } from '../src/game/evaluate';
import { checkEnding } from '../src/game/endings';
import { computeNeuronDecay, computeStartingNeurons } from '../src/game/economy';
import { ECONOMY } from '../src/content/economy';
import type { RunState, MetaState } from '../src/game/types';

const RUNS       = 100_000;
const SEED_BASE  = 0xDEADBEEF;

const EMPTY_META: MetaState = {
  schemaVersion:      1,
  lucidityWallet:     0,
  ownedPermanents:    [],
  corruptionEverUsed: false,
  endingsReached:     [],
  pendingConsumables: {},
  history: { runsPlayed: 0, bestLucidityRun: 0 },
};

let totalSpins       = 0;
let totalLucidity    = 0;
let jackpots         = 0;
let triples          = 0;
let pairs            = 0;
let flatlinesCount   = 0;
let longestRun       = 0;
let shortestRun      = Infinity;

for (let r = 0; r < RUNS; r++) {
  const rng = createRNG(SEED_BASE + r);
  const startingNeurons = computeStartingNeurons([]);
  const neuronDecay     = computeNeuronDecay([]);

  let run: RunState = {
    neurons:                   startingNeurons,
    startingNeurons,
    lucidityEarned:            0,
    freeSpinsRemaining:        0,
    maxFreeSpins:              ECONOMY.BASE_MAX_FREE_SPINS,
    lucidityMultiplier:        ECONOMY.BASE_LUCIDITY_MULTIPLIER,
    nextSpinLucidityMultiplier: 1,
    isSpinning:                false,
    lastResult:                null,
    lockedReels:               [false, false, false],
    runConsumables:            {},
    abilitiesUsed:             [],
    ownedUpgrades:             [],
    spinCount:                 0,
    isFreeSpin:                false,
    betMultiplier:             1,
    dealerCount:               0,
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
    decaySkips:                0,
  };

  while (run.neurons > 0) {
    const isFreeSpin = run.freeSpinsRemaining > 0;
    const result = evaluate({
      neurons:            run.neurons,
      neuronDecayAmount:  neuronDecay,
      freeSpinsRemaining: run.freeSpinsRemaining,
      maxFreeSpins:       run.maxFreeSpins,
      lucidityMultiplier: run.lucidityMultiplier,
      isFreeSpin,
      lockedReels:        [false, false, false],
      previousReels:      null,
      rng,
      bookWeight:         0,
      brainWeightBonus:   0,
      guaranteedWin:      false,
      pattern23Triple:    false,
      learningActive:     false,
    });

    run = {
      ...run,
      neurons:            result.neuronsAfter,
      lucidityEarned:     run.lucidityEarned + result.lucidityEarned,
      freeSpinsRemaining: result.freeSpinsAfter,
      lastResult:         result,
      spinCount:          run.spinCount + 1,
      isFreeSpin,
    };

    if (result.isJackpot) jackpots++;
    if (result.winType === 'triple' && !result.isJackpot) triples++;
    if (result.winType === 'pair') pairs++;

    // Safety: bail if something has gone wrong and run won't end naturally
    if (run.spinCount > 10_000) break;
  }

  const ending = checkEnding(run, EMPTY_META);
  if (ending === 'flatline') flatlinesCount++;

  totalSpins    += run.spinCount;
  totalLucidity += run.lucidityEarned;
  if (run.spinCount > longestRun)  longestRun  = run.spinCount;
  if (run.spinCount < shortestRun) shortestRun = run.spinCount;
}

const avgSpins    = totalSpins    / RUNS;
const avgLucidity = totalLucidity / RUNS;
const jackpotRate = totalSpins / (jackpots || 1);

console.log('\n=== LOBOTOMY Headless Simulator ===');
console.log(`Runs simulated:      ${RUNS.toLocaleString()}`);
console.log(`Total spins:         ${totalSpins.toLocaleString()}`);
console.log('');
console.log(`Avg spins / run:     ${avgSpins.toFixed(1)}`);
console.log(`Shortest run:        ${shortestRun} spins`);
console.log(`Longest run:         ${longestRun} spins`);
console.log('');
console.log(`Avg Lucidity / run:  ${avgLucidity.toFixed(1)}`);
console.log(`Total Lucidity:      ${totalLucidity.toLocaleString()}`);
console.log('');
console.log(`Jackpots:            ${jackpots.toLocaleString()}  (1 in ${jackpotRate.toFixed(0)} spins)`);
console.log(`Triples (non-jack):  ${triples.toLocaleString()}`);
console.log(`Pairs:               ${pairs.toLocaleString()}`);
console.log(`Flatline endings:    ${flatlinesCount.toLocaleString()} / ${RUNS.toLocaleString()}`);
console.log('');
console.log(`Wealth threshold:    ${ECONOMY.WEALTH_LUCIDITY_THRESHOLD} Lucidity`);
console.log(`Runs to wealth:      ~${Math.ceil(ECONOMY.WEALTH_LUCIDITY_THRESHOLD / avgLucidity)} runs avg`);
console.log('');
