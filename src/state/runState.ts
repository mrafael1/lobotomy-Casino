import { create } from 'zustand';
import type { RunState, SpinResult, UpgradeId, EndingType, AbilityId } from '../game/types';
import { evaluate } from '../game/evaluate';
import { applyReroll, applyMoveColumn, applyCopyReel } from '../game/abilities';
import { createRNG } from '../game/rng';
import {
  computeNeuronDecay,
  computeStartingNeurons,
  computeLucidityMultiplier,
  computeMaxFreeSpins,
  computeBookWeight,
  computeBrainWeightBonus,
  hasSedative,
  hasPattern23Triple,
} from '../game/economy';
import { ECONOMY } from '../content/economy';
import { CONSUMABLE_MAP, MAX_CONSUMABLE_SLOTS, totalConsumableCopies } from '../content/consumables';
import { IN_RUN_ITEMS, IN_RUN_ITEM_MAP } from '../content/inRunItems';
import { SYMBOLS } from '../content/symbols';
import { SYMBOL_WEIGHTS } from '../content/symbols';
import type { ReelResult } from '../game/types';

export type RunPhase = 'idle' | 'running' | 'over';
export type SpinOptions = { readonly compulsive?: boolean };

// Dealer appearance config
const DEALER_THRESHOLD_HIGH = 0.65;
const DEALER_THRESHOLD_LOW  = 0.35;
const DEALER_PROC_CHANCE    = 0.15;
const DEALER_MAX_COUNT      = 3;
const DEALER_MIN_SPIN_GAP   = 3;

const DEALER_ITEM_IDS = IN_RUN_ITEMS.map(item => item.id);

export interface RunStore extends RunState {
  runPhase: RunPhase;
  lastEnding: EndingType | null;
  decaySkips: number;

  // Powers that a 30L-threshold restore already gave back, queued ONLY so the
  // power_coin animation can fly a coin toward each as feedback. The gameplay
  // restore (removal from abilitiesUsed) has ALREADY happened at the Lucidity
  // gain — this queue owns no state. commitPowerRestore clears one when its coin
  // lands (or the flight is interrupted). Not persisted; purely visual.
  pendingPowerRestores: ReadonlyArray<AbilityId>;
  commitPowerRestore: (powerId: AbilityId) => void;

  spin: (options?: SpinOptions) => SpinResult | null;
  setSpinning: (v: boolean) => void;
  setBetMultiplier: (m: 1 | 2 | 3) => void;
  startNewRun: (
    ownedPermanents: ReadonlyArray<UpgradeId>,
    pendingConsumables: Partial<Record<string, number>>,
  ) => void;
  endRun: (ending: EndingType) => void;

  useConsumable: (consumableId: string) => boolean;
  lockReel: (reelIndex: number) => void;
  rerollReel: (reelIndex: number) => boolean;
  moveReel: (reelIndex: number, direction: -1 | 1) => boolean;
  copyReel: (sourceReel: number, targetReel: number) => boolean;

  // Dealer interactions
  checkDealerTrigger: () => void;
  revealDealer: () => void;
  declineDealerVisit: () => void;
  acceptDealerOffer: (itemId: string) => void;
  declineDealerOffer: () => void;
  discardRunConsumable: (discardId: string) => void;
}

const INITIAL_RUN_STATE: RunState = {
  neurons:                    0,
  startingNeurons:            0,
  scoreEarned:                0,
  lucidityCoins:              0,
  freeSpinsRemaining:         0,
  maxFreeSpins:               ECONOMY.BASE_MAX_FREE_SPINS,
  lucidityMultiplier:         ECONOMY.BASE_LUCIDITY_MULTIPLIER,
  nextSpinLucidityMultiplier: 1.0,
  isSpinning:                 false,
  lastResult:                 null,
  lockedReels:                [false, false, false],
  lockedReelSpinsRemaining:   0,
  runConsumables:             {},
  abilitiesUsed:              [],
  ownedUpgrades:              [],
  spinCount:                  0,
  isFreeSpin:                 false,
  betMultiplier:              1,
  dealerCount:                0,
  dealerLastSpinCount:        0,
  dealer65SafetyFired:        false,
  dealer35SafetyFired:        false,
  dealerIncoming:             false,
  dealerPending:              false,
  dealerOfferIds:             null,
  brainBoostSpins:            0,
  forcedRandomBetSpins:       0,
  guaranteedWinSpins:         0,
  blockPowersSpins:           0,
  hideNeuronsSpins:           0,
  cocktailBoostSpins:         0,
  compulsiveSpinSkips:        0,
  pendingCompulsiveSpinSkips: 0,
  decaySkips:                 0,
};

function canAct(state: RunStore): boolean {
  return state.runPhase === 'running' && !state.isSpinning;
}

function canUseAbility(state: RunStore): boolean {
  return canAct(state) && state.lastResult !== null && state.blockPowersSpins <= 0;
}

// A copy can be stored whenever the stash isn't full. Duplicates are allowed —
// the same item may occupy more than one slot — so there is no per-item cap;
// only the total-copies cap matters. (itemId kept for call-site clarity.)
export function canStoreRunConsumable(runConsumables: Partial<Record<string, number>>, itemId: string): boolean {
  void itemId;
  return totalConsumableCopies(runConsumables) < MAX_CONSUMABLE_SLOTS;
}

function pickDealerItems(spinCount: number): [string, string] | null {
  const rng = createRNG(((Date.now() ^ (spinCount * 0x6b43c7f)) >>> 0));
  // Duplicates are allowed in the stash now, so offer any two distinct items
  // for variety regardless of what's already held (a full stash is rejected on
  // take, with a dealer message).
  const candidates = DEALER_ITEM_IDS;
  if (candidates.length < 2) return null;
  const shuffled = [...candidates].sort(() => rng() - 0.5);
  return [shuffled[0], shuffled[1]];
}

// Apply a Lucidity gain and IMMEDIATELY restore one random spent power per 30-coin
// threshold crossed (Math.floor(total / 30) index increases). Threshold counting
// is on the run's cumulative Lucidity, so it triggers from any coin gain (spins,
// dealer water, power re-scores) — not just at end of run.
//
// The restore is part of THIS gameplay state change: the chosen powers are removed
// from abilitiesUsed and the shrunken list is returned. It never waits on an
// animation. The picks are also returned in `restores` purely so the optional
// power_coin animation can fly a coin toward each restored power as feedback.
//
// Eligibility = ANY spent power (an entry in abilitiesUsed); other powers still
// being available does not matter. One instance is removed per crossing, and the
// shrinking list is re-checked each crossing, so the same spent instance is never
// restored twice and multiple crossings restore multiple powers when possible.
// Non-positive gains, or no spent power, restore nothing. Independent of the TV
// objective bar (which tracks LUCIDITY_OBJECTIVE and never resets).
export function planLucidityGain(
  prevCoins: number,
  gain: number,
  abilitiesUsed: ReadonlyArray<AbilityId>,
  seed: number,
): { lucidityCoins: number; abilitiesUsed: ReadonlyArray<AbilityId>; restores: AbilityId[] } {
  const newCoins = Math.max(0, prevCoins + gain);
  if (gain <= 0) return { lucidityCoins: newCoins, abilitiesUsed, restores: [] };

  const per = ECONOMY.LUCIDITY_COINS_PER_RESTORE;
  const prevIndex = Math.floor(prevCoins / per);
  const nextIndex = Math.floor(newCoins / per);

  const restores: AbilityId[] = [];
  let remaining = [...abilitiesUsed];
  for (let i = prevIndex; i < nextIndex; i++) {
    if (remaining.length === 0) break; // nothing spent left → remaining credits lost
    const rng = createRNG((seed ^ (i * 0x517cc1b7)) >>> 0);
    const idx = Math.min(remaining.length - 1, Math.floor(rng() * remaining.length));
    restores.push(remaining[idx]);
    remaining = remaining.filter((_, j) => j !== idx); // remove exactly one instance
  }
  return { lucidityCoins: newCoins, abilitiesUsed: remaining, restores };
}

export const useRunStore = create<RunStore>((set, get) => ({
  ...INITIAL_RUN_STATE,
  runPhase: 'idle',
  lastEnding: null,
  decaySkips: 0,
  pendingPowerRestores: [],

  // Called by the power_coin animation when its coin reaches the power (or the
  // flight is interrupted). The restore itself ALREADY happened at the Lucidity
  // gain, so this only clears the power from the visual queue, letting the next
  // queued coin play. A no-op if the id isn't queued.
  commitPowerRestore(powerId: AbilityId): void {
    const state = get();
    const queueIdx = state.pendingPowerRestores.indexOf(powerId);
    if (queueIdx < 0) return;
    set({
      pendingPowerRestores: state.pendingPowerRestores.filter((_, i) => i !== queueIdx),
    });
  },

  spin(options?: SpinOptions): SpinResult | null {
    const state = get();
    if (state.runPhase !== 'running' || state.isSpinning) return null;

    const isCompulsive = options?.compulsive === true && state.compulsiveSpinSkips > 0;
    const isFreeSpin = !isCompulsive && state.freeSpinsRemaining > 0;
    if (!isFreeSpin && state.neurons < 1) return null;

    const seed = ((Date.now() ^ (state.spinCount * 0x9e3779b9)) >>> 0);
    const rng = createRNG(seed);

    const stasisActive = !isCompulsive && !isFreeSpin && state.decaySkips > 0;
    const sedativeActive = !isCompulsive && !isFreeSpin && hasSedative(state.ownedUpgrades) &&
      (state.spinCount + 1) % 3 === 0;

    let effectiveBetMultiplier: 1 | 2 | 3 = state.betMultiplier;
    if (isCompulsive) {
      effectiveBetMultiplier = 1;
    } else if (state.forcedRandomBetSpins > 0 && effectiveBetMultiplier === 3) {
      effectiveBetMultiplier = 2;
    }

    // When the spin costs neurons, you can't bet more spins-worth than you have
    // left: clamp to the affordable budget so scoring matches the multiplier
    // badge (which demotes a locked selection in SlotMachine). Free/stasis/
    // sedative spins cost nothing, so the full selected multiplier stands.
    if (!stasisActive && !sedativeActive && !isFreeSpin) {
      const spinsBudget = Math.max(1, Math.ceil(state.neurons / ECONOMY.NEURON_DECAY_PER_SPIN));
      effectiveBetMultiplier = Math.min(effectiveBetMultiplier, spinsBudget) as 1 | 2 | 3;
    }

    const baseDecay = computeNeuronDecay(state.ownedUpgrades);
    const neuronDecayAmount = (stasisActive || sedativeActive || isFreeSpin)
      ? 0
      : Math.min(effectiveBetMultiplier * baseDecay, state.neurons);

    const upgradesBrainBonus = computeBrainWeightBonus(state.ownedUpgrades);
    const syringeBrainBonus = state.brainBoostSpins > 0 ? SYMBOLS.brain.weight * 3 : 0;
    const brainWeightBonus = upgradesBrainBonus + syringeBrainBonus;

    // Score multiplier applies to score only, never to coins
    const baseMultiplier = state.lucidityMultiplier * state.nextSpinLucidityMultiplier * effectiveBetMultiplier;
    const effectiveMultiplier = state.brainBoostSpins > 0 ? baseMultiplier * 0.5 : baseMultiplier;

    const bookWeight  = computeBookWeight(state.ownedUpgrades);
    const pattern23   = hasPattern23Triple(state.ownedUpgrades);
    const learningOn  = bookWeight > 0;
    const guaranteedWin = state.guaranteedWinSpins > 0;

    const result = evaluate({
      neurons:            state.neurons,
      neuronDecayAmount,
      freeSpinsRemaining: state.freeSpinsRemaining,
      maxFreeSpins:       state.maxFreeSpins,
      lucidityMultiplier: effectiveMultiplier,
      isFreeSpin,
      lockedReels:        state.lockedReels,
      previousReels:      state.lastResult?.reels ?? null,
      rng,
      bookWeight,
      brainWeightBonus,
      guaranteedWin,
      pattern23Triple:    pattern23,
      learningActive:     learningOn,
    });

    // Cocktail rarity bonus goes to score only (it's already a multiplied variable)
    const cocktailBonus = state.cocktailBoostSpins > 0
      ? result.reels.reduce((sum, sym) => sum + (SYMBOLS[sym]?.rarityScore ?? 0), 0)
      : 0;
    const finalResult: SpinResult = cocktailBonus > 0
      ? { ...result, scoreEarned: result.scoreEarned + cocktailBonus }
      : result;

    // Lucidity gained is 1:1 with the score shown this spin (cocktail rarity
    // bonus included), so the coin count matches the win label exactly. Each
    // 30-coin threshold restores one spent power immediately (abilitiesUsed
    // shrinks now); the picks are queued only for the power_coin feedback.
    const plan = planLucidityGain(
      state.lucidityCoins, finalResult.scoreEarned, state.abilitiesUsed, seed,
    );

    set({
      neurons:                    finalResult.neuronsAfter,
      scoreEarned:                state.scoreEarned + finalResult.scoreEarned,
      lucidityCoins:              plan.lucidityCoins,
      abilitiesUsed:              plan.abilitiesUsed,
      pendingPowerRestores:       [...state.pendingPowerRestores, ...plan.restores],
      freeSpinsRemaining:         finalResult.freeSpinsAfter,
      isFreeSpin:                 finalResult.isFreeSpin,
      isSpinning:                 true,
      lastResult:                 finalResult,
      spinCount:                  state.spinCount + 1,
      nextSpinLucidityMultiplier: 1.0,
      decaySkips:                 stasisActive ? state.decaySkips - 1 : state.decaySkips,
      brainBoostSpins:            Math.max(0, state.brainBoostSpins - 1),
      forcedRandomBetSpins:       Math.max(0, state.forcedRandomBetSpins - 1),
      guaranteedWinSpins:         Math.max(0, state.guaranteedWinSpins - 1),
      blockPowersSpins:           Math.max(0, state.blockPowersSpins - 1),
      hideNeuronsSpins:           Math.max(0, state.hideNeuronsSpins - 1),
      cocktailBoostSpins:         Math.max(0, state.cocktailBoostSpins - 1),
      compulsiveSpinSkips:
        (isCompulsive ? Math.max(0, state.compulsiveSpinSkips - 1) : state.compulsiveSpinSkips) +
        (state.cocktailBoostSpins === 1 ? state.pendingCompulsiveSpinSkips : 0),
      pendingCompulsiveSpinSkips: state.cocktailBoostSpins === 1 ? 0 : state.pendingCompulsiveSpinSkips,
    });

    return finalResult;
  },

  setSpinning(v: boolean): void {
    if (v) {
      set({ isSpinning: true });
    } else {
      const state = get();
      const remaining = Math.max(0, state.lockedReelSpinsRemaining - 1);
      set({
        isSpinning: false,
        lockedReels: remaining > 0 ? state.lockedReels : [false, false, false],
        lockedReelSpinsRemaining: remaining,
      });
    }
  },

  setBetMultiplier(m: 1 | 2 | 3): void {
    if (m === 3 && get().forcedRandomBetSpins > 0) return;
    set({ betMultiplier: m });
  },

  startNewRun(
    ownedPermanents: ReadonlyArray<UpgradeId>,
    pendingConsumables: Partial<Record<string, number>>,
  ): void {
    const startingNeurons    = computeStartingNeurons(ownedPermanents);
    const lucidityMultiplier = computeLucidityMultiplier(ownedPermanents);
    const maxFreeSpins       = computeMaxFreeSpins(ownedPermanents);

    set({
      ...INITIAL_RUN_STATE,
      neurons:          startingNeurons,
      startingNeurons:  startingNeurons,
      lucidityMultiplier,
      maxFreeSpins,
      ownedUpgrades:  ownedPermanents,
      runConsumables: pendingConsumables,
      abilitiesUsed:  [],
      pendingPowerRestores: [],
      runPhase:       'running',
      lastEnding:     null,
      decaySkips:     0,
    });
  },

  endRun(ending: EndingType): void {
    set({ runPhase: 'over', lastEnding: ending });
  },

  useConsumable(consumableId: string): boolean {
    const state = get();
    if (!canAct(state)) return false;
    // Consumables can never be activated while a dealer scene is up (the
    // invitation prompt or the in-run dealer visit). Shopping/selecting is fine;
    // activating an effect is machine-only. This is a hard state-level block on
    // top of the UI hiding the use affordance in those scenes.
    if (state.dealerIncoming || state.dealerPending) return false;

    const consumable = CONSUMABLE_MAP[consumableId];
    const inRunItem = IN_RUN_ITEM_MAP[consumableId];
    if (!consumable && !inRunItem) return false;

    const charges = state.runConsumables[consumableId] ?? 0;
    if (charges < 1) return false;

    const newRunConsumables = { ...state.runConsumables, [consumableId]: charges - 1 };

    if (inRunItem) {
      const effect = inRunItem.effect;

      switch (effect.type) {
        case 'skipDecay':
          set({
            runConsumables: newRunConsumables,
            decaySkips: state.decaySkips + effect.spins,
            forcedRandomBetSpins: state.forcedRandomBetSpins + effect.forcedRandomBetSpins,
            betMultiplier: state.betMultiplier === 3 ? 2 : state.betMultiplier,
          });
          return true;

        case 'addLucidity': {
          // Water (dealer item): grants coins directly — and, like any Lucidity
          // gain, can cross 30-coin thresholds to restore spent powers immediately.
          const plan = planLucidityGain(
            state.lucidityCoins, effect.amount, state.abilitiesUsed,
            ((Date.now() ^ (state.spinCount * 0x2545f491)) >>> 0),
          );
          set({
            runConsumables: newRunConsumables,
            lucidityCoins: plan.lucidityCoins,
            abilitiesUsed: plan.abilitiesUsed,
            pendingPowerRestores: [...state.pendingPowerRestores, ...plan.restores],
          });
          return true;
        }

        case 'cocktailBoost':
          set({
            runConsumables: newRunConsumables,
            cocktailBoostSpins: state.cocktailBoostSpins + effect.spins,
            pendingCompulsiveSpinSkips: state.pendingCompulsiveSpinSkips + effect.compulsiveSpins,
          });
          return true;

        case 'guaranteedWin':
          set({
            runConsumables: newRunConsumables,
            guaranteedWinSpins: state.guaranteedWinSpins + effect.spins,
            blockPowersSpins: state.blockPowersSpins + effect.blockPowersSpins,
          });
          return true;
      }
    }

    const effect = consumable!.effect;

    switch (effect.type) {
      case 'skipDecay':
        set({ runConsumables: newRunConsumables, decaySkips: state.decaySkips + effect.spins });
        return true;

      case 'lucidityMultiplierNextSpin':
        set({
          runConsumables: newRunConsumables,
          nextSpinLucidityMultiplier: effect.multiplier,
          hideNeuronsSpins: state.hideNeuronsSpins + (effect.hideNeuronsSpins ?? 0),
        });
        return true;

      case 'restoreAbility': {
        if (state.abilitiesUsed.length === 0) return false;
        const rng = createRNG(((Date.now() ^ (state.spinCount * 0xdeadbeef)) >>> 0));
        const idx = Math.floor(rng() * state.abilitiesUsed.length);
        const newUsed = state.abilitiesUsed.filter((_, i) => i !== idx);
        set({ runConsumables: newRunConsumables, abilitiesUsed: newUsed as ReadonlyArray<AbilityId> });
        return true;
      }

      case 'brainBoost': {
        const allAbilities: AbilityId[] = ['reroll', 'shift', 'memory'];
        const available = allAbilities.filter(a => !state.abilitiesUsed.includes(a));
        const toBlock: AbilityId[] = available.length > 0
          ? (() => {
              const rng = createRNG(((Date.now() ^ state.spinCount) >>> 0));
              const pick = available[Math.floor(rng() * available.length)];
              return [pick];
            })()
          : [];

        set({
          runConsumables: newRunConsumables,
          brainBoostSpins: effect.spins,
          abilitiesUsed: [...state.abilitiesUsed, ...toBlock] as ReadonlyArray<AbilityId>,
        });
        return true;
      }

      case 'copyReel':
        set({ runConsumables: newRunConsumables });
        return true;
    }
  },

  lockReel(reelIndex: number): void {
    const state = get();
    if (!canUseAbility(state)) return;
    if (!state.ownedUpgrades.includes('perm_memory')) return;
    if (state.abilitiesUsed.includes('memory')) return;

    const locks: [boolean, boolean, boolean] = [false, false, false];
    locks[reelIndex] = true;
    set({
      lockedReels:              locks,
      lockedReelSpinsRemaining: 3,
      abilitiesUsed:            [...state.abilitiesUsed, 'memory'],
    });
  },

  rerollReel(reelIndex: number): boolean {
    const state = get();
    if (!canUseAbility(state) || !state.lastResult) return false;
    if (state.abilitiesUsed.includes('reroll')) return false;

    const seed = ((Date.now() ^ (state.spinCount * 0x5bd1e995 + reelIndex)) >>> 0);
    const rng = createRNG(seed);

    const upgradesBrainBonus = computeBrainWeightBonus(state.ownedUpgrades);
    const syringeBrainBonus = state.brainBoostSpins > 0 ? SYMBOLS.brain.weight * 4 : 0;
    const brainWeightBonus = upgradesBrainBonus + syringeBrainBonus;
    const bookWeight = computeBookWeight(state.ownedUpgrades);
    const pattern23 = hasPattern23Triple(state.ownedUpgrades);
    const learningOn = bookWeight > 0;

    let weights = SYMBOL_WEIGHTS;
    if (brainWeightBonus > 0) {
      weights = weights.map(w =>
        w.value === 'brain' ? { ...w, weight: w.weight + brainWeightBonus } : w,
      );
    }
    if (bookWeight > 0) {
      weights = [...weights, { weight: bookWeight, value: 'book' as const }];
    }

    const outcome = applyReroll(
      state.lastResult.reels, reelIndex, rng, state.lucidityMultiplier,
      weights, pattern23, learningOn, !state.lastResult.isFreeSpin,
    );

    // Plan restores on the list that INCLUDES this reroll: if using it to make
    // the pair/triple crosses a 30L threshold, reroll itself is eligible to be
    // restored (so a power used to trigger a reset can be the one given back).
    const markedUsed = [...state.abilitiesUsed, 'reroll'] as ReadonlyArray<AbilityId>;
    const plan = planLucidityGain(
      state.lucidityCoins, outcome.coinsDelta, markedUsed, seed,
    );
    const freeSpinsAfter = Math.min(
      state.freeSpinsRemaining + outcome.freeSpinsGranted, state.maxFreeSpins);
    set({
      abilitiesUsed: plan.abilitiesUsed,
      scoreEarned:   Math.max(0, state.scoreEarned + outcome.scoreDelta),
      lucidityCoins: plan.lucidityCoins,
      pendingPowerRestores: [...state.pendingPowerRestores, ...plan.restores],
      freeSpinsRemaining: freeSpinsAfter,
      lastResult: {
        ...state.lastResult,
        reels:            outcome.reels,
        isJackpot:        outcome.isJackpot,
        winType:          outcome.winType,
        scoreEarned:      Math.max(0, state.lastResult.scoreEarned + outcome.scoreDelta),
        coinsEarned:      Math.max(0, state.lastResult.coinsEarned + outcome.coinsDelta),
        freeSpinsGranted: state.lastResult.freeSpinsGranted + (freeSpinsAfter - state.freeSpinsRemaining),
        freeSpinsAfter,
      },
    });
    return true;
  },

  moveReel(reelIndex: number, direction: -1 | 1): boolean {
    const state = get();
    if (!canUseAbility(state) || !state.lastResult) return false;
    if (!state.ownedUpgrades.includes('perm_shift')) return false;
    if (state.abilitiesUsed.includes('shift')) return false;

    const pattern23 = hasPattern23Triple(state.ownedUpgrades);
    const learningOn = computeBookWeight(state.ownedUpgrades) > 0;

    const outcome = applyMoveColumn(
      state.lastResult.reels, reelIndex, direction, state.lucidityMultiplier,
      pattern23, learningOn, !state.lastResult.isFreeSpin,
    );
    const moveSeed = ((Date.now() ^ (state.spinCount * 0x27d4eb2f + reelIndex)) >>> 0);
    // Include this shift so, like reroll, a power used to make the gain that
    // crosses a 30L threshold can itself be the restored one.
    const markedUsed = [...state.abilitiesUsed, 'shift'] as ReadonlyArray<AbilityId>;
    const plan = planLucidityGain(
      state.lucidityCoins, outcome.coinsDelta, markedUsed, moveSeed,
    );
    const freeSpinsAfter = Math.min(
      state.freeSpinsRemaining + outcome.freeSpinsGranted, state.maxFreeSpins);
    set({
      abilitiesUsed: plan.abilitiesUsed,
      scoreEarned:   Math.max(0, state.scoreEarned + outcome.scoreDelta),
      lucidityCoins: plan.lucidityCoins,
      pendingPowerRestores: [...state.pendingPowerRestores, ...plan.restores],
      freeSpinsRemaining: freeSpinsAfter,
      lastResult: {
        ...state.lastResult,
        reels:            outcome.reels,
        isJackpot:        outcome.isJackpot,
        winType:          outcome.winType,
        scoreEarned:      Math.max(0, state.lastResult.scoreEarned + outcome.scoreDelta),
        coinsEarned:      Math.max(0, state.lastResult.coinsEarned + outcome.coinsDelta),
        freeSpinsGranted: state.lastResult.freeSpinsGranted + (freeSpinsAfter - state.freeSpinsRemaining),
        freeSpinsAfter,
      },
    });
    return true;
  },

  copyReel(sourceReel: number, targetReel: number): boolean {
    const state = get();
    if (!canAct(state) || !state.lastResult) return false;

    const pattern23 = hasPattern23Triple(state.ownedUpgrades);
    const learningOn = computeBookWeight(state.ownedUpgrades) > 0;

    const outcome = applyCopyReel(
      state.lastResult.reels, sourceReel, targetReel, state.lucidityMultiplier,
      pattern23, learningOn, !state.lastResult.isFreeSpin,
    );

    const otherConsumables = Object.entries(state.runConsumables)
      .filter(([id, charges]) => id !== 'cons_white_powder' && (charges ?? 0) > 0);

    let newRunConsumables = { ...state.runConsumables };
    let neuronsAfter = state.neurons;

    if (otherConsumables.length > 0) {
      const rng = createRNG(((Date.now() ^ state.spinCount) >>> 0));
      const [victimId, victimCharges] = otherConsumables[Math.floor(rng() * otherConsumables.length)];
      newRunConsumables = { ...newRunConsumables, [victimId]: (victimCharges ?? 1) - 1 };
    } else {
      neuronsAfter = Math.max(0, state.neurons - 20);
    }

    const copySeed = ((Date.now() ^ (state.spinCount * 0x165667b1)) >>> 0);
    const plan = planLucidityGain(
      state.lucidityCoins, outcome.coinsDelta, state.abilitiesUsed, copySeed,
    );
    const freeSpinsAfter = Math.min(
      state.freeSpinsRemaining + outcome.freeSpinsGranted, state.maxFreeSpins);
    set({
      runConsumables: newRunConsumables,
      neurons: neuronsAfter,
      abilitiesUsed: plan.abilitiesUsed,
      scoreEarned:   Math.max(0, state.scoreEarned + outcome.scoreDelta),
      lucidityCoins: plan.lucidityCoins,
      pendingPowerRestores: [...state.pendingPowerRestores, ...plan.restores],
      freeSpinsRemaining: freeSpinsAfter,
      lastResult: {
        ...state.lastResult,
        reels:            outcome.reels,
        isJackpot:        outcome.isJackpot,
        winType:          outcome.winType,
        scoreEarned:      Math.max(0, state.lastResult.scoreEarned + outcome.scoreDelta),
        coinsEarned:      Math.max(0, state.lastResult.coinsEarned + outcome.coinsDelta),
        freeSpinsGranted: state.lastResult.freeSpinsGranted + (freeSpinsAfter - state.freeSpinsRemaining),
        freeSpinsAfter,
      },
    });
    return true;
  },

  checkDealerTrigger(): void {
    const state = get();
    if (state.runPhase !== 'running' || state.dealerPending || state.dealerIncoming) return;
    if (state.startingNeurons <= 0) return;
    if (state.dealerCount >= DEALER_MAX_COUNT) return;
    if (state.spinCount - state.dealerLastSpinCount < DEALER_MIN_SPIN_GAP) return;

    const ratio = state.neurons / state.startingNeurons;
    let shouldTrigger = false;
    let new65Fired = state.dealer65SafetyFired;
    let new35Fired = state.dealer35SafetyFired;

    if (!state.dealer65SafetyFired && ratio <= DEALER_THRESHOLD_HIGH) {
      new65Fired = true;
      if (state.dealerCount === 0) shouldTrigger = true;
    }

    if (!state.dealer35SafetyFired && ratio <= DEALER_THRESHOLD_LOW) {
      new35Fired = true;
      if (state.dealerCount === 1) shouldTrigger = true;
    }

    if (!shouldTrigger) {
      const rng = createRNG(((Date.now() ^ (state.spinCount * 0x9e3779b9 + 0xdeadbeef)) >>> 0));
      if (rng() < DEALER_PROC_CHANCE) shouldTrigger = true;
    }

    if (shouldTrigger) {
      const offerIds = pickDealerItems(state.spinCount);
      if (!offerIds) {
        set({ dealer65SafetyFired: new65Fired, dealer35SafetyFired: new35Fired });
        return;
      }
      set({
        dealerCount:         state.dealerCount + 1,
        dealerLastSpinCount: state.spinCount,
        dealer65SafetyFired: new65Fired,
        dealer35SafetyFired: new35Fired,
        dealerIncoming:      true,
        dealerOfferIds:      offerIds,
      });
    } else if (new65Fired !== state.dealer65SafetyFired || new35Fired !== state.dealer35SafetyFired) {
      set({ dealer65SafetyFired: new65Fired, dealer35SafetyFired: new35Fired });
    }
  },

  revealDealer(): void {
    const state = get();
    if (!state.dealerIncoming || state.runPhase !== 'running') return;
    set({ dealerIncoming: false, dealerPending: true });
  },

  declineDealerVisit(): void {
    set({ dealerIncoming: false, dealerPending: false, dealerOfferIds: null });
  },

  acceptDealerOffer(itemId: string): void {
    const state = get();
    if (!state.dealerPending || !state.dealerOfferIds) return;
    if (!state.dealerOfferIds.includes(itemId)) return;

    const item = IN_RUN_ITEM_MAP[itemId];
    if (!item) {
      set({ dealerPending: false, dealerOfferIds: null });
      return;
    }

    // Stash-full case is handled on the dealer screen (drag an item onto the
    // dealer to throw one out, then take again), so this only stores when there
    // is room — full is a defensive no-op.
    const existingCharges = state.runConsumables[itemId] ?? 0;
    if (!canStoreRunConsumable(state.runConsumables, itemId)) {
      set({ dealerPending: false, dealerOfferIds: null });
      return;
    }
    set({
      dealerPending: false,
      dealerOfferIds: null,
      runConsumables: { ...state.runConsumables, [itemId]: existingCharges + 1 },
    });
  },

  declineDealerOffer(): void {
    set({ dealerPending: false, dealerOfferIds: null });
  },

  // Throw ONE stash copy away to free its slot — gives nothing back. With
  // duplicates allowed, this removes a single copy (decrement), clearing the
  // entry only when the last copy is thrown.
  discardRunConsumable(discardId: string): void {
    const state = get();
    const current = state.runConsumables[discardId] ?? 0;
    if (current <= 0) return;
    const next = { ...state.runConsumables };
    if (current <= 1) delete next[discardId];
    else next[discardId] = current - 1;
    set({ runConsumables: next });
  },
}));
