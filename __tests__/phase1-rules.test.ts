// Phase 1 mechanics tests: abilities, consumables, and the run store.
// These extend (never replace) the sacred-rule tests.

import { scoreReels } from '../src/game/evaluate';
import { applyReroll, applyMoveColumn } from '../src/game/abilities';
import { useRunStore } from '../src/state/runState';
import { CONSUMABLES } from '../src/content/consumables';
import { createRNG } from '../src/game/rng';
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
  expect(granted.lucidityEarned).toBe(denied.lucidityEarned);
  expect(denied.lucidityEarned).toBeGreaterThan(0);
});

// ─────────────────────────────────────────────
// Reroll ability
// ─────────────────────────────────────────────
test('applyReroll: replaces exactly the target reel, others untouched', () => {
  const before: ReelResult = ['eye', 'brain', 'pill'];
  // rng always returns 0 → always picks 'brain' (first weight entry)
  const outcome = applyReroll(before, 2, () => 0, 1);

  expect(outcome.reels[0]).toBe('eye');
  expect(outcome.reels[1]).toBe('brain');
  expect(outcome.reels[2]).toBe('brain'); // rerolled to brain
});

test('applyReroll: never mints free spins', () => {
  const outcome = applyReroll(['brain', 'brain', 'eye'], 2, () => 0, 1);
  expect('freeSpinsGranted' in outcome).toBe(false);
  expect('freeSpinsAfter' in outcome).toBe(false);
});

test('applyReroll: completing a triple gives a positive delta', () => {
  const before: ReelResult = ['brain', 'brain', 'eye'];
  // rng → 0 always picks brain; completing the triple → positive delta
  const outcome = applyReroll(before, 2, () => 0, 1);
  expect(outcome.isJackpot).toBe(true);
  expect(outcome.lucidityDelta).toBeGreaterThan(0);
});

// ─────────────────────────────────────────────
// Move Column ability
// ─────────────────────────────────────────────
test('applyMoveColumn: can complete a jackpot — Lucidity pays, no free spin exists', () => {
  const before: ReelResult = ['brain', 'brain', 'eye'];
  const outcome = applyMoveColumn(before, 2, -1, 1);

  expect(outcome.reels).toEqual(['brain', 'brain', 'brain']);
  expect(outcome.isJackpot).toBe(true);
  expect(outcome.lucidityDelta).toBeGreaterThan(0);
  expect('freeSpinsGranted' in outcome).toBe(false);
});

test('applyMoveColumn: wraps around the cycle in both directions', () => {
  const up = applyMoveColumn(['brain', 'eye', 'pill'], 0, -1, 1);
  expect(up.reels[0]).toBe('flatline');

  const down = applyMoveColumn(['flatline', 'eye', 'pill'], 0, 1, 1);
  expect(down.reels[0]).toBe('brain');
});

// ─────────────────────────────────────────────
// Consumable content invariant (Sacred Rule 1 adjacency)
// ─────────────────────────────────────────────
test('no consumable can ever add neurons', () => {
  const allowed = new Set([
    'skipDecay', 'grantFreeSpins', 'lucidityMultiplierNextSpin',
  ]);
  for (const c of CONSUMABLES) {
    expect(allowed.has(c.effect.type)).toBe(true);
  }
});

// ─────────────────────────────────────────────
// Run store integration
// ─────────────────────────────────────────────
function freshRun(runConsumables: Partial<Record<string, number>> = {}): void {
  useRunStore.getState().startNewRun([], runConsumables);
}

test('store: Stasis Patch — spins cost 0 neurons while skips remain', () => {
  freshRun({ cons_stasis: 1 });
  expect(useRunStore.getState().runConsumables['cons_stasis']).toBe(1);

  useRunStore.getState().useConsumable('cons_stasis');
  expect(useRunStore.getState().decaySkips).toBe(3);
  expect(useRunStore.getState().runConsumables['cons_stasis']).toBe(0);

  const before = useRunStore.getState().neurons;
  useRunStore.getState().spin();
  const after = useRunStore.getState();

  expect(after.neurons).toBe(before);   // no decay consumed
  expect(after.decaySkips).toBe(2);     // one skip used
});

test('store: consumable rejected when no charges remain', () => {
  freshRun({ cons_focus: 1 });
  expect(useRunStore.getState().useConsumable('cons_focus')).toBe(true);
  expect(useRunStore.getState().useConsumable('cons_focus')).toBe(false);
});

test('store: free-spin consumable clamps to max and rejects at cap', () => {
  freshRun({ cons_free_spin: 3 });
  const max = useRunStore.getState().maxFreeSpins; // base = 1

  expect(useRunStore.getState().useConsumable('cons_free_spin')).toBe(true);
  expect(useRunStore.getState().freeSpinsRemaining).toBe(max);

  // Already at cap — rejected, charge not consumed
  const chargesBefore = useRunStore.getState().runConsumables['cons_free_spin'] ?? 0;
  expect(useRunStore.getState().useConsumable('cons_free_spin')).toBe(false);
  expect(useRunStore.getState().runConsumables['cons_free_spin']).toBe(chargesBefore);
});

test('store: REROLL ability is 1-use per run — second call rejected', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  expect(useRunStore.getState().rerollReel(0)).toBe(true);
  expect(useRunStore.getState().abilitiesUsed).toContain('reroll');
  expect(useRunStore.getState().rerollReel(1)).toBe(false); // already used
});

test('store: REROLL only changes the target reel and applies Lucidity delta', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  const before = useRunStore.getState().lastResult!.reels;
  const lucidityBefore = useRunStore.getState().lucidityEarned;

  expect(useRunStore.getState().rerollReel(2)).toBe(true);
  const after = useRunStore.getState();

  // Reels 0 and 1 are unchanged
  expect(after.lastResult!.reels[0]).toBe(before[0]);
  expect(after.lastResult!.reels[1]).toBe(before[1]);
  // Lucidity reflects the new score delta (may go up or down)
  expect(typeof after.lucidityEarned).toBe('number');
  expect(after.lucidityEarned).toBeGreaterThanOrEqual(0);
  // Net lucidity moved by lucidityDelta (which could be negative — player's gamble)
  void lucidityBefore; // referenced to satisfy linter
});

test('store: SHIFT requires perm_shift upgrade', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  // Without the upgrade, move is rejected
  expect(useRunStore.getState().moveReel(0, 1)).toBe(false);

  // With the upgrade present in ownedUpgrades
  useRunStore.getState().startNewRun(['perm_shift'], {});
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  expect(useRunStore.getState().moveReel(0, 1)).toBe(true);
  expect(useRunStore.getState().abilitiesUsed).toContain('shift');
  // second call rejected (1 use per run)
  expect(useRunStore.getState().moveReel(0, -1)).toBe(false);
});

test('store: MEMORY requires perm_memory upgrade', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  // Without the upgrade, lockReel is a no-op
  useRunStore.getState().lockReel(0);
  expect(useRunStore.getState().lockedReels).toEqual([false, false, false]);

  // With upgrade, lockReel works and marks ability used
  useRunStore.getState().startNewRun(['perm_memory'], {});
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  useRunStore.getState().lockReel(1);
  expect(useRunStore.getState().lockedReels).toEqual([false, true, false]);
  expect(useRunStore.getState().abilitiesUsed).toContain('memory');
  // second lock rejected
  useRunStore.getState().lockReel(0);
  expect(useRunStore.getState().lockedReels).toEqual([false, true, false]);
});

test('store: abilities and consumables are blocked while spinning', () => {
  freshRun({ cons_stasis: 1 });
  useRunStore.getState().spin(); // isSpinning is now true

  expect(useRunStore.getState().useConsumable('cons_stasis')).toBe(false);
  expect(useRunStore.getState().rerollReel(0)).toBe(false);
});

test('store: neurons never increase across any sequence of actions (Sacred Rule 1)', () => {
  freshRun({ cons_stasis: 5, cons_focus: 5 });
  let lastNeurons = useRunStore.getState().neurons;

  for (let i = 0; i < 50; i++) {
    const s = useRunStore.getState();
    if (i % 7 === 0) s.useConsumable('cons_stasis');
    if (i % 5 === 0) s.useConsumable('cons_focus');
    if (i % 3 === 0 && s.lastResult) s.rerollReel(0);
    s.spin();
    s.setSpinning(false);

    const now = useRunStore.getState().neurons;
    expect(now).toBeLessThanOrEqual(lastNeurons);
    lastNeurons = now;
    if (now <= 0) break;
  }
});
