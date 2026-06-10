// Phase 1 mechanics tests: abilities, consumables, and the run store.
// These extend (never replace) the sacred-rule tests.

import { scoreReels } from '../src/game/evaluate';
import { applySwap, applyMoveColumn } from '../src/game/abilities';
import { useRunStore } from '../src/state/runState';
import { CONSUMABLES } from '../src/content/consumables';
import { ECONOMY } from '../src/content/economy';
import { ABILITIES } from '../src/content/abilities';
import type { ReelResult } from '../src/game/types';

// ─────────────────────────────────────────────
// scoreReels — the shared scoring primitive
// ─────────────────────────────────────────────
test('scoreReels: brain triple grants a free spin only when allowed', () => {
  const reels: ReelResult = ['brain', 'brain', 'brain'];
  const granted = scoreReels(reels, 1, true);
  const denied  = scoreReels(reels, 1, false);

  expect(granted.winType).toBe('jackpot');
  expect(granted.freeSpinsGranted).toBe(1);
  expect(denied.winType).toBe('jackpot');
  expect(denied.freeSpinsGranted).toBe(0);
  // Lucidity pays either way
  expect(granted.lucidityEarned).toBe(denied.lucidityEarned);
  expect(denied.lucidityEarned).toBeGreaterThan(0);
});

// ─────────────────────────────────────────────
// Swap ability
// ─────────────────────────────────────────────
test('applySwap: converts a split pair into an adjacent pair, delta positive', () => {
  // [eye, brain, eye] is a miss (a===c does not count); swapping 0,1 makes
  // [brain, eye, eye] — an adjacent eye pair.
  const before: ReelResult = ['eye', 'brain', 'eye'];
  const outcome = applySwap(before, 0, 1, 1);

  expect(outcome.reels).toEqual(['brain', 'eye', 'eye']);
  expect(outcome.lucidityDelta).toBeGreaterThan(0);
});

test('applySwap: never mints free spins — outcome has no free-spin channel', () => {
  // Structural check: AbilityOutcome carries reels + lucidityDelta + isJackpot only.
  const outcome = applySwap(['brain', 'brain', 'brain'], 0, 1, 1);
  expect('freeSpinsGranted' in outcome).toBe(false);
  expect('freeSpinsAfter' in outcome).toBe(false);
});

test('applySwap: swapping a win away gives a negative delta (player choice)', () => {
  const before: ReelResult = ['eye', 'eye', 'scalpel'];
  const outcome = applySwap(before, 1, 2, 1); // [eye, scalpel, eye] — miss
  expect(outcome.lucidityDelta).toBeLessThan(0);
});

// ─────────────────────────────────────────────
// Move Column ability
// ─────────────────────────────────────────────
test('applyMoveColumn: can complete a jackpot — Lucidity pays, no free spin exists', () => {
  // [brain, brain, eye]: shifting reel 2 up (eye → brain) completes the triple.
  const before: ReelResult = ['brain', 'brain', 'eye'];
  const outcome = applyMoveColumn(before, 2, -1, 1);

  expect(outcome.reels).toEqual(['brain', 'brain', 'brain']);
  expect(outcome.isJackpot).toBe(true);
  expect(outcome.lucidityDelta).toBeGreaterThan(0);
  expect('freeSpinsGranted' in outcome).toBe(false);
});

test('applyMoveColumn: wraps around the cycle in both directions', () => {
  const up = applyMoveColumn(['brain', 'eye', 'pill'], 0, -1, 1);
  expect(up.reels[0]).toBe('flatline'); // brain is first; up wraps to last

  const down = applyMoveColumn(['flatline', 'eye', 'pill'], 0, 1, 1);
  expect(down.reels[0]).toBe('brain'); // flatline is last; down wraps to first
});

// ─────────────────────────────────────────────
// Consumable content invariant (Sacred Rule 1 adjacency)
// ─────────────────────────────────────────────
test('no consumable can ever add neurons', () => {
  const allowed = new Set([
    'skipDecay', 'grantFreeSpins', 'lucidityMultiplierNextSpin', 'lockReelNextSpin',
  ]);
  for (const c of CONSUMABLES) {
    expect(allowed.has(c.effect.type)).toBe(true);
  }
});

// ─────────────────────────────────────────────
// Run store integration
// ─────────────────────────────────────────────
function freshRun(lucidity = 1000): void {
  useRunStore.getState().startNewRun([]);
  useRunStore.setState({ lucidityEarned: lucidity });
}

test('store: Stasis Patch — spins cost 0 neurons while skips remain, never add any', () => {
  freshRun();
  useRunStore.getState().buyConsumable('cons_stasis');
  expect(useRunStore.getState().decaySkips).toBe(3);

  const before = useRunStore.getState().neurons;
  useRunStore.getState().spin();
  const after = useRunStore.getState();

  expect(after.neurons).toBe(before);     // no decay consumed
  expect(after.decaySkips).toBe(2);       // one skip used
});

test('store: free-spin consumable clamps to max and rejects at cap', () => {
  freshRun();
  const max = useRunStore.getState().maxFreeSpins; // base = 1

  expect(useRunStore.getState().buyConsumable('cons_free_spin')).toBe('applied');
  expect(useRunStore.getState().freeSpinsRemaining).toBe(max);

  const lucidityBefore = useRunStore.getState().lucidityEarned;
  expect(useRunStore.getState().buyConsumable('cons_free_spin')).toBe('rejected');
  expect(useRunStore.getState().lucidityEarned).toBe(lucidityBefore); // not charged
});

test('store: reel lock is single-use — cleared after the next spin', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  expect(useRunStore.getState().buyConsumable('cons_reel_lock')).toBe('needsReelPick');
  useRunStore.getState().lockReel(1);
  expect(useRunStore.getState().lockedReels).toEqual([false, true, false]);

  const lockedSymbol = useRunStore.getState().lastResult!.reels[1];
  useRunStore.getState().spin();
  const after = useRunStore.getState();

  expect(after.lastResult!.reels[1]).toBe(lockedSymbol); // lock held
  expect(after.lockedReels).toEqual([false, false, false]); // then cleared
});

test('store: swap charges its cost and applies the Lucidity delta', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  // Force a known result so the delta is predictable
  const state = useRunStore.getState();
  useRunStore.setState({
    lastResult: { ...state.lastResult!, reels: ['eye', 'brain', 'eye'] },
    lucidityEarned: 100,
  });

  expect(useRunStore.getState().swapReels(0, 1)).toBe(true);
  const after = useRunStore.getState();

  expect(after.lastResult!.reels).toEqual(['brain', 'eye', 'eye']);
  // 100 - swap cost + eye pair payout (delta from miss → pair)
  expect(after.lucidityEarned).toBeGreaterThan(100 - ABILITIES.swap.cost);
});

test('store: Override rejects when free spins are at cap', () => {
  freshRun();
  useRunStore.getState().buyConsumable('cons_free_spin'); // now at base max (1)
  const lucidityBefore = useRunStore.getState().lucidityEarned;

  expect(useRunStore.getState().buyOverrideFreeSpin()).toBe(false);
  expect(useRunStore.getState().lucidityEarned).toBe(lucidityBefore);
});

test('store: abilities and consumables are blocked while spinning', () => {
  freshRun();
  useRunStore.getState().spin(); // isSpinning is now true

  expect(useRunStore.getState().buyConsumable('cons_stasis')).toBe('rejected');
  expect(useRunStore.getState().swapReels(0, 1)).toBe(false);
  expect(useRunStore.getState().buyOverrideFreeSpin()).toBe(false);
});

test('store: neurons never increase across any sequence of actions (Sacred Rule 1)', () => {
  freshRun();
  let lastNeurons = useRunStore.getState().neurons;

  for (let i = 0; i < 50; i++) {
    const s = useRunStore.getState();
    // Interleave consumables, abilities, spins
    if (i % 7 === 0) s.buyConsumable('cons_stasis');
    if (i % 5 === 0) s.buyConsumable('cons_lucidity_boost');
    if (i % 3 === 0 && s.lastResult) s.swapReels(0, 2);
    s.spin();
    s.setSpinning(false);
    useRunStore.setState({ lucidityEarned: 1000 }); // keep affordable

    const now = useRunStore.getState().neurons;
    expect(now).toBeLessThanOrEqual(lastNeurons);
    lastNeurons = now;
    if (now <= 0) break;
  }
});
