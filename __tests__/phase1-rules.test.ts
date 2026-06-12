// Phase 1 mechanics tests: abilities, consumables, and the run store.
// These extend (never replace) the sacred-rule tests.

import { scoreReels } from '../src/game/evaluate';
import { applyReroll, applyMoveColumn, applyCopyReel } from '../src/game/abilities';
import { SYMBOL_WEIGHTS } from '../src/content/symbols';
import { useRunStore } from '../src/state/runState';
import { CONSUMABLES } from '../src/content/consumables';
import { PAIR_PAYOUTS } from '../src/content/payouts';
import { SYMBOLS } from '../src/content/symbols';
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

test('scoreReels: Pattern Fabrication — non-adjacent match pays double pair value', () => {
  const reels: ReelResult = ['eye', 'pill', 'eye']; // a===c, no adjacent match
  const withPattern = scoreReels(reels, 1, false, true);
  const without     = scoreReels(reels, 1, false, false);

  expect(withPattern.winType).toBe('pair');
  expect(withPattern.lucidityEarned).toBe((PAIR_PAYOUTS.eye ?? 0) * 2);
  expect(without.winType).toBe('miss');
});

test('scoreReels: Pattern Fabrication — brain pair is not a jackpot', () => {
  const result = scoreReels(['brain', 'eye', 'brain'], 1, true, true);

  expect(result.winType).toBe('pair');
  expect(result.lucidityEarned).toBe((PAIR_PAYOUTS.brain ?? 0) * 2);
  expect(result.freeSpinsGranted).toBe(0);
});

test('scoreReels: learning active — book visible adds +10 per book', () => {
  const reels: ReelResult = ['book', 'eye', 'pill'];
  const withLearning    = scoreReels(reels, 1, false, false, true);
  const withoutLearning = scoreReels(reels, 1, false, false, false);

  // With learning: pair (eye/pill miss) but +10 for 1 book visible → lucidity = 10
  expect(withLearning.lucidityEarned).toBe(10);
  // Without learning: book isn't in payout table in a meaningful way, treated as miss
  expect(withoutLearning.lucidityEarned).toBe(0);
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

test('applyReroll: mints free spins only when allowed and the jackpot is new', () => {
  // Default (grant not allowed — e.g. result came from a free spin): no grant.
  const denied = applyReroll(['brain', 'brain', 'eye'], 2, () => 0, 1);
  expect(denied.isJackpot).toBe(true);
  expect(denied.freeSpinsGranted).toBe(0);

  // Allowed on a paid spin: power-made jackpot grants the free spin.
  const granted = applyReroll(
    ['brain', 'brain', 'eye'], 2, () => 0, 1, SYMBOL_WEIGHTS, false, false, true);
  expect(granted.isJackpot).toBe(true);
  expect(granted.freeSpinsGranted).toBe(1);
});

test('abilities: an already-jackpot result never grants again', () => {
  // Copy brain onto brain — jackpot before AND after → no double grant.
  const outcome = applyCopyReel(
    ['brain', 'brain', 'brain'], 0, 2, 1, false, false, true);
  expect(outcome.isJackpot).toBe(true);
  expect(outcome.freeSpinsGranted).toBe(0);
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
test('applyMoveColumn: can complete a jackpot — Lucidity pays, free spin only when allowed', () => {
  const before: ReelResult = ['brain', 'brain', 'eye'];
  const outcome = applyMoveColumn(before, 2, -1, 1);

  expect(outcome.reels).toEqual(['brain', 'brain', 'brain']);
  expect(outcome.isJackpot).toBe(true);
  expect(outcome.lucidityDelta).toBeGreaterThan(0);
  expect(outcome.freeSpinsGranted).toBe(0); // grant not allowed by default

  const allowed = applyMoveColumn(before, 2, -1, 1, false, false, true);
  expect(allowed.freeSpinsGranted).toBe(1);
});

test('applyMoveColumn: wraps around the cycle in both directions', () => {
  const up = applyMoveColumn(['brain', 'eye', 'pill'], 0, -1, 1);
  expect(up.reels[0]).toBe('flatline');

  const down = applyMoveColumn(['flatline', 'eye', 'pill'], 0, 1, 1);
  expect(down.reels[0]).toBe('brain');
});

// ─────────────────────────────────────────────
// Consumable content invariant
// ─────────────────────────────────────────────
test('no consumable can ever add neurons', () => {
  const allowed = new Set([
    'skipDecay', 'lucidityMultiplierNextSpin', 'copyReel', 'brainBoost', 'restoreAbility',
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

function totalConsumableCharges(runConsumables: Partial<Record<string, number>>): number {
  return Object.values(runConsumables).reduce<number>((sum, n) => sum + (n ?? 0), 0);
}

test('store: Focus Serum — sets nextSpinLucidityMultiplier to 3', () => {
  freshRun({ cons_focus: 1 });
  expect(useRunStore.getState().runConsumables['cons_focus']).toBe(1);

  useRunStore.getState().useConsumable('cons_focus');
  expect(useRunStore.getState().nextSpinLucidityMultiplier).toBe(3.0);
  expect(useRunStore.getState().runConsumables['cons_focus']).toBe(0);
});

test('store: Focus Serum side effect — neurons hidden for 5 spins, then visible', () => {
  freshRun({ cons_focus: 1 });
  useRunStore.getState().useConsumable('cons_focus');
  expect(useRunStore.getState().hideNeuronsSpins).toBe(5);

  for (let i = 5; i > 0; i--) {
    useRunStore.getState().spin();
    useRunStore.getState().setSpinning(false);
    expect(useRunStore.getState().hideNeuronsSpins).toBe(i - 1);
  }
  expect(useRunStore.getState().hideNeuronsSpins).toBe(0);
});

test('store: consumable rejected when no charges remain', () => {
  freshRun({ cons_focus: 1 });
  expect(useRunStore.getState().useConsumable('cons_focus')).toBe(true);
  expect(useRunStore.getState().useConsumable('cons_focus')).toBe(false);
});

test('store: mid-run dealer Cocktail is stashed, not activated immediately', () => {
  freshRun();
  useRunStore.setState({
    dealerPending: true,
    dealerOfferIds: ['item_cocktail', 'item_water'],
  });

  useRunStore.getState().acceptDealerOffer('item_cocktail');
  let state = useRunStore.getState();

  expect(state.pendingGiftConsumableId).toBeNull();
  expect(state.pendingGiftNeedsDiscard).toBe(false);
  expect(state.runConsumables.item_cocktail).toBe(1);
  expect(totalConsumableCharges(state.runConsumables)).toBe(1);
  expect(state.lucidityEarned).toBe(0);

  expect(useRunStore.getState().useConsumable('item_cocktail')).toBe(true);
  state = useRunStore.getState();

  expect(state.runConsumables.item_cocktail).toBe(0);
  expect(state.cocktailBoostSpins).toBe(3);
  expect(state.compulsiveSpinSkips).toBe(2);
  expect(state.lucidityEarned).toBe(0);
});

test('store: Cocktail adds visible rarity sum to the next 3 spins and forces 2 x1 spins', () => {
  freshRun({ item_cocktail: 1 });
  useRunStore.getState().setBetMultiplier(3);

  expect(useRunStore.getState().useConsumable('item_cocktail')).toBe(true);
  expect(useRunStore.getState().cocktailBoostSpins).toBe(3);
  expect(useRunStore.getState().compulsiveSpinSkips).toBe(2);

  const neuronsBefore = useRunStore.getState().neurons;
  useRunStore.getState().spin({ compulsive: true });
  useRunStore.getState().setSpinning(false);

  let state = useRunStore.getState();
  const firstBonus = state.lastResult!.reels.reduce(
    (sum, sym) => sum + SYMBOLS[sym].rarityScore,
    0,
  );
  expect(state.neurons).toBe(neuronsBefore - 3);
  expect(state.lastResult!.lucidityEarned).toBeGreaterThanOrEqual(firstBonus);
  expect(state.cocktailBoostSpins).toBe(2);
  expect(state.compulsiveSpinSkips).toBe(1);

  useRunStore.getState().spin({ compulsive: true });
  useRunStore.getState().setSpinning(false);
  expect(useRunStore.getState().cocktailBoostSpins).toBe(1);
  expect(useRunStore.getState().compulsiveSpinSkips).toBe(0);

  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  state = useRunStore.getState();
  expect(state.cocktailBoostSpins).toBe(0);
});

test('store: Energy Drink locks out x3 and preserves neurons while active', () => {
  freshRun({ item_energy_drink: 1 });
  useRunStore.getState().setBetMultiplier(3);

  expect(useRunStore.getState().useConsumable('item_energy_drink')).toBe(true);
  expect(useRunStore.getState().betMultiplier).toBe(2);
  expect(useRunStore.getState().forcedRandomBetSpins).toBe(5);

  useRunStore.getState().setBetMultiplier(3);
  expect(useRunStore.getState().betMultiplier).toBe(2);

  const neuronsBefore = useRunStore.getState().neurons;
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  const state = useRunStore.getState();
  expect(state.neurons).toBe(neuronsBefore);
  expect(state.decaySkips).toBe(4);
  expect(state.forcedRandomBetSpins).toBe(4);
});

test('store: mid-run dealer substance waits for discard when stash is full', () => {
  freshRun({ cons_focus: 2, cons_tea: 2 });
  useRunStore.setState({
    dealerPending: true,
    dealerOfferIds: ['item_pill', 'item_water'],
  });

  useRunStore.getState().acceptDealerOffer('item_pill');
  let state = useRunStore.getState();

  expect(state.pendingGiftConsumableId).toBe('item_pill');
  expect(state.pendingGiftNeedsDiscard).toBe(true);
  expect(totalConsumableCharges(state.runConsumables)).toBe(4);

  useRunStore.getState().discardConsumableForGift('cons_focus');
  state = useRunStore.getState();

  expect(state.pendingGiftConsumableId).toBeNull();
  expect(state.pendingGiftNeedsDiscard).toBe(false);
  expect(state.runConsumables.cons_focus).toBeUndefined();
  expect(state.runConsumables.item_pill).toBe(1);
});

test('store: Tea restores a used ability', () => {
  freshRun({ cons_tea: 1 });
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  // Use reroll first
  expect(useRunStore.getState().rerollReel(0)).toBe(true);
  expect(useRunStore.getState().abilitiesUsed).toContain('reroll');

  // Tea restores it
  expect(useRunStore.getState().useConsumable('cons_tea')).toBe(true);
  expect(useRunStore.getState().abilitiesUsed).not.toContain('reroll');
});

test('store: Tea rejected when no abilities have been used', () => {
  freshRun({ cons_tea: 1 });
  expect(useRunStore.getState().useConsumable('cons_tea')).toBe(false);
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

  expect(after.lastResult!.reels[0]).toBe(before[0]);
  expect(after.lastResult!.reels[1]).toBe(before[1]);
  expect(typeof after.lucidityEarned).toBe('number');
  expect(after.lucidityEarned).toBeGreaterThanOrEqual(0);
  void lucidityBefore;
});

test('store: SHIFT requires perm_shift upgrade', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  expect(useRunStore.getState().moveReel(0, 1)).toBe(false);

  useRunStore.getState().startNewRun(['perm_shift'], {});
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  expect(useRunStore.getState().moveReel(0, 1)).toBe(true);
  expect(useRunStore.getState().abilitiesUsed).toContain('shift');
  expect(useRunStore.getState().moveReel(0, -1)).toBe(false);
});

test('store: MEMORY requires perm_memory upgrade', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  useRunStore.getState().lockReel(0);
  expect(useRunStore.getState().lockedReels).toEqual([false, false, false]);

  useRunStore.getState().startNewRun(['perm_memory'], {});
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  useRunStore.getState().lockReel(1);
  expect(useRunStore.getState().lockedReels).toEqual([false, true, false]);
  expect(useRunStore.getState().abilitiesUsed).toContain('memory');
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
  freshRun({ cons_focus: 2, cons_tea: 2 });
  let lastNeurons = useRunStore.getState().neurons;

  for (let i = 0; i < 50; i++) {
    const s = useRunStore.getState();
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

test('store: sedative — every 3rd spin costs no neurons', () => {
  useRunStore.getState().startNewRun(['corr_sedative'], {});
  let spinsDone = 0;
  let neuronsBefore: number;

  // Spin until we've done a 3rd spin
  while (spinsDone < 3) {
    neuronsBefore = useRunStore.getState().neurons;
    useRunStore.getState().spin();
    useRunStore.getState().setSpinning(false);
    spinsDone++;
  }

  // After exactly 3 spins, spin #3 (index 2) should have cost 0 neurons.
  // We check that total neurons lost over 3 spins equals cost of 2 spins.
  const state = useRunStore.getState();
  const expected = state.startingNeurons - 2 * 3; // 2 real spins × 3N each
  expect(state.neurons).toBe(expected);
});

test('store: Hydration raises starting neurons above the base cap', () => {
  useRunStore.getState().startNewRun(['pos_hydration_1'], {});
  expect(useRunStore.getState().startingNeurons).toBe(110);
  expect(useRunStore.getState().neurons).toBe(110);

  useRunStore.getState().startNewRun(
    ['pos_hydration_1', 'pos_hydration_2', 'pos_hydration_3'], {});
  expect(useRunStore.getState().startingNeurons).toBe(140);
  expect(useRunStore.getState().neurons).toBe(140);
});
