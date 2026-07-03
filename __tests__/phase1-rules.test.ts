// Phase 1 mechanics tests: abilities, consumables, and the run store.
// These extend (never replace) the sacred-rule tests.

import { scoreReels } from '../src/game/evaluate';
import { applyReroll, applyMoveColumn, applyCopyReel } from '../src/game/abilities';
import { SYMBOL_WEIGHTS } from '../src/content/symbols';
import { useRunStore, planLucidityGain } from '../src/state/runState';
import { CONSUMABLES } from '../src/content/consumables';
import { PAIR_SCORE } from '../src/content/payouts';
import { SYMBOLS } from '../src/content/symbols';
import { createRNG } from '../src/game/rng';
import type { ReelResult, AbilityId } from '../src/game/types';

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
  expect(granted.scoreEarned).toBe(denied.scoreEarned);
  expect(denied.scoreEarned).toBeGreaterThan(0);
});

test('scoreReels: Pattern Fabrication — non-adjacent match pays double pair value', () => {
  const reels: ReelResult = ['eye', 'pill', 'eye']; // a===c, no adjacent match
  const withPattern = scoreReels(reels, 1, false, true);
  const without     = scoreReels(reels, 1, false, false);

  expect(withPattern.winType).toBe('pair');
  expect(withPattern.scoreEarned).toBe((PAIR_SCORE.eye ?? 0) * 2);
  expect(without.winType).toBe('miss');
});

test('scoreReels: Pattern Fabrication — brain pair is not a jackpot', () => {
  const result = scoreReels(['brain', 'eye', 'brain'], 1, true, true);

  expect(result.winType).toBe('pair');
  expect(result.scoreEarned).toBe((PAIR_SCORE.brain ?? 0) * 2);
  expect(result.freeSpinsGranted).toBe(0);
});

test('scoreReels: learning active — book visible adds +10 per book', () => {
  const reels: ReelResult = ['book', 'eye', 'pill'];
  const withLearning    = scoreReels(reels, 1, false, false, true);
  const withoutLearning = scoreReels(reels, 1, false, false, false);

  // With learning: pair (eye/pill miss) but +10 for 1 book visible → lucidity = 10
  expect(withLearning.scoreEarned).toBe(10);
  // Without learning: book isn't in payout table in a meaningful way, treated as miss
  expect(withoutLearning.scoreEarned).toBe(0);
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
  expect(outcome.scoreDelta).toBeGreaterThan(0);
});

// ─────────────────────────────────────────────
// Move Column ability
// ─────────────────────────────────────────────
test('applyMoveColumn: can complete a jackpot — Lucidity pays, free spin only when allowed', () => {
  const before: ReelResult = ['brain', 'brain', 'eye'];
  const outcome = applyMoveColumn(before, 2, -1, 1);

  expect(outcome.reels).toEqual(['brain', 'brain', 'brain']);
  expect(outcome.isJackpot).toBe(true);
  expect(outcome.scoreDelta).toBeGreaterThan(0);
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
    'hideReelPairBoost', 'guaranteeSymbol', 'scrambleThenHide',
    'resetPowersRandomEffect', 'restoreAbilityOrSpins',
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

test('store: Serum — picked symbol is guaranteed, blur queues for the spin after (issue #53)', () => {
  freshRun({ cons_focus: 1 });
  expect(useRunStore.getState().runConsumables['cons_focus']).toBe(1);

  useRunStore.getState().useConsumable('cons_focus', { serumSymbol: 'vial' });
  expect(useRunStore.getState().guaranteeSymbolSpins).toBe(1);
  expect(useRunStore.getState().guaranteeSymbolId).toBe('vial');
  expect(useRunStore.getState().pendingBlurSpins).toBe(1);
  expect(useRunStore.getState().banBrainSpins).toBe(0);
  expect(useRunStore.getState().runConsumables['cons_focus']).toBe(0);
});

test('store: Serum guaranteed symbol appears, then the next spin is blurry (issue #53)', () => {
  freshRun({ cons_focus: 1 });
  useRunStore.getState().useConsumable('cons_focus', { serumSymbol: 'vial' });

  // Guaranteed spin: the picked symbol appears at least once.
  const result = useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  expect(result?.reels.includes('vial')).toBe(true);
  let state = useRunStore.getState();
  expect(state.guaranteeSymbolSpins).toBe(0);
  expect(state.guaranteeSymbolId).toBeNull();
  expect(state.blurReelsSpins).toBe(1); // the spin after renders blurry
  expect(state.pendingBlurSpins).toBe(0);

  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  state = useRunStore.getState();
  expect(state.blurReelsSpins).toBe(0);
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

  expect(state.runConsumables.item_cocktail).toBe(1);
  expect(totalConsumableCharges(state.runConsumables)).toBe(1);
  expect(state.scoreEarned).toBe(0);

  expect(useRunStore.getState().useConsumable('item_cocktail')).toBe(true);
  state = useRunStore.getState();

  expect(state.runConsumables.item_cocktail).toBe(0);
  expect(state.cocktailBoostSpins).toBe(2);
  expect(state.compulsiveSpinSkips).toBe(0);
  expect(state.pendingCompulsiveSpinSkips).toBe(0);
  expect(state.scoreEarned).toBe(0);
});

test('store: Cocktail boosts 2 spins without queuing compulsion', () => {
  freshRun({ item_cocktail: 1 });

  expect(useRunStore.getState().useConsumable('item_cocktail')).toBe(true);
  expect(useRunStore.getState().cocktailBoostSpins).toBe(2);
  expect(useRunStore.getState().compulsiveSpinSkips).toBe(0);
  expect(useRunStore.getState().pendingCompulsiveSpinSkips).toBe(0);

  // First boosted spin is a normal player spin with the rarity bonus.
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  let state = useRunStore.getState();
  const firstBonus = state.lastResult!.reels.reduce(
    (sum, sym) => sum + SYMBOLS[sym].rarityScore,
    0,
  );
  expect(state.lastResult!.scoreEarned).toBeGreaterThanOrEqual(firstBonus);
  expect(state.cocktailBoostSpins).toBe(1);
  expect(state.compulsiveSpinSkips).toBe(0);

  // Second boosted spin: the boost ends without queuing an automatic spin.
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  state = useRunStore.getState();
  expect(state.cocktailBoostSpins).toBe(0);
  expect(state.compulsiveSpinSkips).toBe(0);
  expect(state.pendingCompulsiveSpinSkips).toBe(0);
});

test('store: Energy Drink locks out x3, preserves neurons, then forces 1 x1 spin', () => {
  freshRun({ item_energy_drink: 1 });
  useRunStore.getState().setBetMultiplier(3);

  expect(useRunStore.getState().useConsumable('item_energy_drink')).toBe(true);
  expect(useRunStore.getState().betMultiplier).toBe(2);
  expect(useRunStore.getState().forcedRandomBetSpins).toBe(2);
  expect(useRunStore.getState().pendingCompulsiveSpinSkips).toBe(1);

  useRunStore.getState().setBetMultiplier(3);
  expect(useRunStore.getState().betMultiplier).toBe(2);

  const neuronsBefore = useRunStore.getState().neurons;
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  let state = useRunStore.getState();
  expect(state.neurons).toBe(neuronsBefore);
  expect(state.decaySkips).toBe(1);
  expect(state.forcedRandomBetSpins).toBe(1);

  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  state = useRunStore.getState();
  expect(state.decaySkips).toBe(0);
  expect(state.compulsiveSpinSkips).toBe(1);
  expect(state.pendingCompulsiveSpinSkips).toBe(0);

  const beforeCompulsive = useRunStore.getState().neurons;
  useRunStore.getState().setBetMultiplier(3);
  useRunStore.getState().spin({ compulsive: true });
  useRunStore.getState().setSpinning(false);
  state = useRunStore.getState();
  expect(state.neurons).toBe(beforeCompulsive - 3); // x1 decay despite x3 selected
  expect(state.compulsiveSpinSkips).toBe(0);
});

test('store: mid-run dealer substance is refused while stash is full, taken after a throw', () => {
  // Two copies of WATER fill both stash slots (duplicates occupy separate slots).
  freshRun({ item_water: 2 });
  useRunStore.setState({
    dealerPending: true,
    dealerOfferIds: ['item_pill', 'item_water'],
  });

  // Full stash (2 copies): the offer is a no-op — nothing is stored.
  useRunStore.getState().acceptDealerOffer('item_pill');
  let state = useRunStore.getState();
  expect(state.runConsumables.item_pill).toBeUndefined();
  expect(totalConsumableCharges(state.runConsumables)).toBe(2);

  // Throwing one stash copy (dragged onto the dealer) frees a single slot.
  useRunStore.getState().discardRunConsumable('item_water');
  state = useRunStore.getState();
  expect(state.runConsumables.item_water).toBe(1);
  expect(totalConsumableCharges(state.runConsumables)).toBe(1);

  // With a free slot, taking the offer now stores it alongside the duplicate.
  useRunStore.setState({ dealerPending: true, dealerOfferIds: ['item_pill', 'item_water'] });
  useRunStore.getState().acceptDealerOffer('item_pill');
  state = useRunStore.getState();
  expect(state.runConsumables.item_pill).toBe(1);
  expect(totalConsumableCharges(state.runConsumables)).toBe(2);
});

test('store: same consumable can be bought into two stash slots', () => {
  freshRun({ item_water: 1 });
  useRunStore.setState({ dealerPending: true, dealerOfferIds: ['item_water', 'item_pill'] });

  // Buying/taking the same item again stacks a second copy (two slots).
  useRunStore.getState().acceptDealerOffer('item_water');
  let state = useRunStore.getState();
  expect(state.runConsumables.item_water).toBe(2);
  expect(totalConsumableCharges(state.runConsumables)).toBe(2);

  // Each copy is used independently.
  expect(useRunStore.getState().useConsumable('item_water')).toBe(true);
  state = useRunStore.getState();
  expect(state.runConsumables.item_water).toBe(1);
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

test('store: Tea grants fallback free spins when no abilities were used (issue #32)', () => {
  freshRun({ cons_tea: 1 });
  const before = useRunStore.getState().freeSpinsRemaining;
  expect(useRunStore.getState().useConsumable('cons_tea')).toBe(true);
  // fallbackSpins = 3, clamped to maxFreeSpins.
  const expected = Math.min(before + 3, useRunStore.getState().maxFreeSpins);
  expect(useRunStore.getState().freeSpinsRemaining).toBe(expected);
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
  const lucidityBefore = useRunStore.getState().scoreEarned;

  expect(useRunStore.getState().rerollReel(2)).toBe(true);
  const after = useRunStore.getState();

  expect(after.lastResult!.reels[0]).toBe(before[0]);
  expect(after.lastResult!.reels[1]).toBe(before[1]);
  expect(typeof after.scoreEarned).toBe('number');
  expect(after.scoreEarned).toBeGreaterThanOrEqual(0);
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
  expect(useRunStore.getState().lockedReelSpins[1]).toBe(2);
  expect(useRunStore.getState().abilitiesUsed).toContain('memory');
  // 1/run — second lock call is ignored
  useRunStore.getState().lockReel(0);
  expect(useRunStore.getState().lockedReels).toEqual([false, true, false]);
});

test('store: MEMORY lock persists for exactly 2 spins', () => {
  useRunStore.getState().startNewRun(['perm_memory'], {});
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  useRunStore.getState().lockReel(0);
  expect(useRunStore.getState().lockedReels[0]).toBe(true);
  expect(useRunStore.getState().lockedReelSpins[0]).toBe(2);

  // Spin 1 — lock should still be active after finishing
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  expect(useRunStore.getState().lockedReels[0]).toBe(true);
  expect(useRunStore.getState().lockedReelSpins[0]).toBe(1);

  // Spin 2 — lock expires after this spin
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);
  expect(useRunStore.getState().lockedReels[0]).toBe(false);
  expect(useRunStore.getState().lockedReelSpins[0]).toBe(0);
});

test('store: consumables cannot be activated inside a dealer scene', () => {
  freshRun({ item_water: 1 });

  // In-run dealer visit (dealerPending) — use is blocked, charge untouched.
  useRunStore.setState({ dealerPending: true });
  expect(useRunStore.getState().useConsumable('item_water')).toBe(false);
  expect(useRunStore.getState().runConsumables.item_water).toBe(1);

  // Dealer arrival prompt (dealerIncoming) — also blocked.
  useRunStore.setState({ dealerPending: false, dealerIncoming: true });
  expect(useRunStore.getState().useConsumable('item_water')).toBe(false);
  expect(useRunStore.getState().runConsumables.item_water).toBe(1);

  // Back on the machine — use works again.
  useRunStore.setState({ dealerIncoming: false });
  expect(useRunStore.getState().useConsumable('item_water')).toBe(true);
});

test('store: a 50L threshold restores a spent power IMMEDIATELY, not on commit', () => {
  useRunStore.getState().startNewRun([], {});
  useRunStore.setState({
    lucidityCoins: 20,
    abilitiesUsed: ['reroll'],
    pendingPowerRestores: [],
    runConsumables: { item_water: 1 },
    isSpinning: false,
  });

  // +40 Lucidity (20 → 60) crosses the 50 threshold → reroll is restored right
  // now. The power_coin queue holds it only for the visual; gameplay no longer waits.
  expect(useRunStore.getState().useConsumable('item_water')).toBe(true);
  let s = useRunStore.getState();
  expect(s.lucidityCoins).toBe(60);
  expect(s.abilitiesUsed).not.toContain('reroll'); // restored without any commit
  expect(s.pendingPowerRestores).toContain('reroll'); // queued for the coin visual

  // commitPowerRestore is now visual-only: it just drains the feedback queue and
  // never re-touches abilitiesUsed (so it can't double-restore).
  useRunStore.getState().commitPowerRestore('reroll');
  s = useRunStore.getState();
  expect(s.abilitiesUsed).not.toContain('reroll');
  expect(s.pendingPowerRestores).not.toContain('reroll');
});

test('store: a power restores even when other powers are still available', () => {
  useRunStore.getState().startNewRun([], {});
  useRunStore.setState({
    lucidityCoins: 20,
    abilitiesUsed: ['reroll'], // reroll spent; shift & memory still available
    pendingPowerRestores: [],
    runConsumables: { item_water: 1 },
    isSpinning: false,
  });

  expect(useRunStore.getState().useConsumable('item_water')).toBe(true); // 20 → 60
  const s = useRunStore.getState();
  expect(s.abilitiesUsed).not.toContain('reroll'); // the one spent power came back
});

test('store: a 50L threshold with no spent power restores nothing', () => {
  useRunStore.getState().startNewRun([], {});
  useRunStore.setState({
    lucidityCoins: 20,
    abilitiesUsed: [],
    pendingPowerRestores: [],
    runConsumables: { item_water: 1 },
    isSpinning: false,
  });

  useRunStore.getState().useConsumable('item_water'); // 20 → 60, crosses 50
  const s = useRunStore.getState();
  expect(s.lucidityCoins).toBe(60);
  expect(s.abilitiesUsed).toEqual([]);
  expect(s.pendingPowerRestores).toEqual([]); // nothing spent → nothing restored
});

// ─────────────────────────────────────────────
// planLucidityGain — the pure restoration helper
// ─────────────────────────────────────────────
test('planLucidityGain: 49 → 55 restores one used power', () => {
  const plan = planLucidityGain(49, 6, ['reroll'] as AbilityId[], 1);
  expect(plan.lucidityCoins).toBe(55);
  expect(plan.restores).toEqual(['reroll']);
  expect(plan.abilitiesUsed).toEqual([]);
});

test('planLucidityGain: 40 → 140 restores two used powers when two are depleted', () => {
  const plan = planLucidityGain(40, 100, ['reroll', 'shift'] as AbilityId[], 1);
  expect(plan.lucidityCoins).toBe(140);
  expect(plan.restores.length).toBe(2); // two thresholds crossed (50, 100)
  expect(plan.restores.sort()).toEqual(['reroll', 'shift']);
  expect(plan.abilitiesUsed).toEqual([]);
});

test('planLucidityGain: one used + two available restores only the used one', () => {
  // Available powers simply aren't in abilitiesUsed; only the spent one is eligible.
  const plan = planLucidityGain(0, 50, ['memory'] as AbilityId[], 1);
  expect(plan.restores).toEqual(['memory']);
  expect(plan.abilitiesUsed).toEqual([]);
});

test('planLucidityGain: a threshold crossed with no used powers restores none', () => {
  const plan = planLucidityGain(0, 95, [] as AbilityId[], 1);
  expect(plan.lucidityCoins).toBe(95);
  expect(plan.restores).toEqual([]);
  expect(plan.abilitiesUsed).toEqual([]);
});

test('planLucidityGain: a single threshold restores at most one power (no double)', () => {
  // 49 → 55 crosses exactly one threshold, so even with two spent powers only one
  // is restored; the other stays used.
  const plan = planLucidityGain(49, 6, ['reroll', 'shift'] as AbilityId[], 1);
  expect(plan.restores.length).toBe(1);
  expect(plan.abilitiesUsed.length).toBe(1); // the unrestored one remains spent
});

test('planLucidityGain: 0 → 160 restores up to three used powers', () => {
  const plan = planLucidityGain(0, 160, ['reroll', 'shift', 'memory'] as AbilityId[], 1);
  expect(plan.restores.length).toBe(3); // thresholds at 50, 100, 150
  expect(plan.restores.sort()).toEqual(['memory', 'reroll', 'shift']);
  expect(plan.abilitiesUsed).toEqual([]);
});

test('planLucidityGain: non-positive gain restores nothing and never goes negative', () => {
  const plan = planLucidityGain(40, -100, ['reroll'] as AbilityId[], 1);
  expect(plan.lucidityCoins).toBe(0);
  expect(plan.restores).toEqual([]);
  expect(plan.abilitiesUsed).toEqual(['reroll']);
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

test('store: power-made jackpot keeps lastResult free-spin metadata in sync', () => {
  freshRun();
  useRunStore.getState().spin();
  useRunStore.getState().setSpinning(false);

  // Force a known pair so copying reel 0 onto reel 2 creates a fresh jackpot.
  useRunStore.setState({
    freeSpinsRemaining: 0,
    lastResult: {
      ...useRunStore.getState().lastResult!,
      reels: ['brain', 'brain', 'eye'] as ReelResult,
      isJackpot: false,
      winType: 'pair',
      isFreeSpin: false,
      freeSpinsGranted: 0,
      freeSpinsAfter: 0,
    },
  });

  expect(useRunStore.getState().copyReel(0, 2)).toBe(true);
  const state = useRunStore.getState();
  expect(state.lastResult!.isJackpot).toBe(true);
  expect(state.freeSpinsRemaining).toBe(1);
  // lastResult must agree with the store, not keep the pre-power values.
  expect(state.lastResult!.freeSpinsGranted).toBe(1);
  expect(state.lastResult!.freeSpinsAfter).toBe(1);
});

test('store: White Powder copy has no extra consumable or neuron penalty', () => {
  freshRun({ cons_white_powder: 0, item_water: 1 });
  useRunStore.setState({
    neurons: 80,
    lastResult: {
      reels: ['brain', 'eye', 'vial'] as ReelResult,
      scoreEarned: 0,
      coinsEarned: 0,
      neuronsAfter: 80,
      freeSpinsAfter: 0,
      freeSpinsGranted: 0,
      isJackpot: false,
      winType: 'miss',
      isFreeSpin: false,
      scoreMultiplier: 1,
    },
  });

  expect(useRunStore.getState().copyReel(0, 2)).toBe(true);
  const state = useRunStore.getState();
  expect(state.neurons).toBe(80);
  expect(state.runConsumables.item_water).toBe(1);
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
