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
import { CONSUMABLE_MAP } from '../content/consumables';
import { IN_RUN_ITEM_MAP } from '../content/inRunItems';
import { SYMBOLS } from '../content/symbols';
import { SYMBOL_WEIGHTS } from '../content/symbols';
import type { ReelResult } from '../game/types';

export type RunPhase = 'idle' | 'running' | 'over';

// Thresholds at which the Dealer appears (neuron ratio vs starting neurons).
const DEALER_THRESHOLD_HIGH = 0.65; // first appearance
const DEALER_THRESHOLD_LOW  = 0.35; // second appearance

// The 4 dealer item ids (rotated randomly when Dealer triggers).
const DEALER_ITEM_IDS = [
  'item_energy_drink',
  'item_cocktail',
  'item_water',
  'item_pill',
] as const;

export interface RunStore extends RunState {
  runPhase: RunPhase;
  lastEnding: EndingType | null;
  decaySkips: number;

  spin: () => SpinResult | null;
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
  acceptDealerOffer: () => void;
  declineDealerOffer: () => void;
}

const INITIAL_RUN_STATE: RunState = {
  neurons:                    0,
  startingNeurons:            0,
  lucidityEarned:             0,
  freeSpinsRemaining:         0,
  maxFreeSpins:               ECONOMY.BASE_MAX_FREE_SPINS,
  lucidityMultiplier:         ECONOMY.BASE_LUCIDITY_MULTIPLIER,
  nextSpinLucidityMultiplier: 1.0,
  isSpinning:                 false,
  lastResult:                 null,
  lockedReels:                [false, false, false],
  runConsumables:             {},
  abilitiesUsed:              [],
  ownedUpgrades:              [],
  spinCount:                  0,
  isFreeSpin:                 false,
  betMultiplier:              1,
  dealerPhase:                0,
  dealerPending:              false,
  dealerOfferId:              null,
  brainBoostSpins:            0,
  forcedRandomBetSpins:       0,
  guaranteedWinSpins:         0,
  blockPowersSpins:           0,
  decaySkips:                 0,
};

function canAct(state: RunStore): boolean {
  return state.runPhase === 'running' && !state.isSpinning;
}

function canUseAbility(state: RunStore): boolean {
  return canAct(state) && state.lastResult !== null && state.blockPowersSpins <= 0;
}

function pickDealerItem(spinCount: number): string {
  const idx = ((Date.now() ^ (spinCount * 0x6b43c7f)) >>> 0) % DEALER_ITEM_IDS.length;
  return DEALER_ITEM_IDS[idx];
}

export const useRunStore = create<RunStore>((set, get) => ({
  ...INITIAL_RUN_STATE,
  runPhase: 'idle',
  lastEnding: null,
  decaySkips: 0,

  spin(): SpinResult | null {
    const state = get();
    if (state.runPhase !== 'running' || state.isSpinning) return null;

    const isFreeSpin = state.freeSpinsRemaining > 0;
    if (!isFreeSpin && state.neurons < 1) return null;

    const seed = ((Date.now() ^ (state.spinCount * 0x9e3779b9)) >>> 0);
    const rng = createRNG(seed);

    // Stasis / sedative / forced random bet
    const stasisActive = !isFreeSpin && state.decaySkips > 0;
    const sedativeActive = !isFreeSpin && hasSedative(state.ownedUpgrades) &&
      (state.spinCount + 1) % 3 === 0;

    let effectiveBetMultiplier: 1 | 2 | 3 = state.betMultiplier;
    if (state.forcedRandomBetSpins > 0) {
      const choices: [1, 2, 3] = [1, 2, 3];
      effectiveBetMultiplier = choices[Math.floor(rng() * 3)] as 1 | 2 | 3;
    }

    const baseDecay = computeNeuronDecay(state.ownedUpgrades);
    const neuronDecayAmount = (stasisActive || sedativeActive || isFreeSpin)
      ? 0
      : Math.min(effectiveBetMultiplier * baseDecay, state.neurons);

    // Syringe brain boost: 5× brain weight
    const upgradesBrainBonus = computeBrainWeightBonus(state.ownedUpgrades);
    const syringeBrainBonus = state.brainBoostSpins > 0 ? SYMBOLS.brain.weight * 3 : 0; // 3 extra = 4× total
    const brainWeightBonus = upgradesBrainBonus + syringeBrainBonus;

    // Lucidity multiplier — reduced during Syringe boost
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

    set({
      neurons:                    result.neuronsAfter,
      lucidityEarned:             state.lucidityEarned + result.lucidityEarned,
      freeSpinsRemaining:         result.freeSpinsAfter,
      isFreeSpin:                 result.isFreeSpin,
      isSpinning:                 true,
      lastResult:                 result,
      spinCount:                  state.spinCount + 1,
      nextSpinLucidityMultiplier: 1.0,
      decaySkips:                 stasisActive ? state.decaySkips - 1 : state.decaySkips,
      brainBoostSpins:            Math.max(0, state.brainBoostSpins - 1),
      forcedRandomBetSpins:       Math.max(0, state.forcedRandomBetSpins - 1),
      guaranteedWinSpins:         Math.max(0, state.guaranteedWinSpins - 1),
      blockPowersSpins:           Math.max(0, state.blockPowersSpins - 1),
    });

    return result;
  },

  setSpinning(v: boolean): void {
    if (v) {
      set({ isSpinning: true });
    } else {
      set({ isSpinning: false, lockedReels: [false, false, false] });
    }
  },

  setBetMultiplier(m: 1 | 2 | 3): void {
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

    const consumable = CONSUMABLE_MAP[consumableId];
    if (!consumable) return false;

    const charges = state.runConsumables[consumableId] ?? 0;
    if (charges < 1) return false;

    const newRunConsumables = { ...state.runConsumables, [consumableId]: charges - 1 };
    const effect = consumable.effect;

    switch (effect.type) {
      case 'skipDecay':
        set({ runConsumables: newRunConsumables, decaySkips: state.decaySkips + effect.spins });
        return true;

      case 'lucidityMultiplierNextSpin':
        set({ runConsumables: newRunConsumables, nextSpinLucidityMultiplier: effect.multiplier });
        return true;

      case 'restoreAbility': {
        if (state.abilitiesUsed.length === 0) return false;
        // Randomly restore one used ability
        const rng = createRNG(((Date.now() ^ (state.spinCount * 0xdeadbeef)) >>> 0));
        const idx = Math.floor(rng() * state.abilitiesUsed.length);
        const restored = state.abilitiesUsed[idx];
        const newUsed = state.abilitiesUsed.filter((_, i) => i !== idx);
        set({ runConsumables: newRunConsumables, abilitiesUsed: newUsed as ReadonlyArray<AbilityId> });
        return true;
      }

      case 'brainBoost': {
        // Block a random unblocked ability for the rest of the run
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

      // copyReel is handled via the UI flow (copyReel store action), not useConsumable directly.
      // Calling useConsumable with copyReel just marks the charge as consumed — the UI
      // orchestrates source/target selection and calls store.copyReel() separately.
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
      lockedReels:   locks,
      abilitiesUsed: [...state.abilitiesUsed, 'memory'],
    });
  },

  rerollReel(reelIndex: number): boolean {
    const state = get();
    if (!canUseAbility(state) || !state.lastResult) return false;
    if (state.abilitiesUsed.includes('reroll')) return false;

    const seed = ((Date.now() ^ (state.spinCount * 0x5bd1e995 + reelIndex)) >>> 0);
    const rng = createRNG(seed);

    // Build effective weights (same as spin: includes brain bonus and book)
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
      weights, pattern23, learningOn,
    );

    set({
      abilitiesUsed: [...state.abilitiesUsed, 'reroll'],
      lucidityEarned: Math.max(0, state.lucidityEarned + outcome.lucidityDelta),
      lastResult: {
        ...state.lastResult,
        reels:          outcome.reels,
        isJackpot:      outcome.isJackpot,
        winType:        outcome.winType,
        lucidityEarned: Math.max(0, state.lastResult.lucidityEarned + outcome.lucidityDelta),
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
      pattern23, learningOn,
    );
    set({
      abilitiesUsed: [...state.abilitiesUsed, 'shift'],
      lucidityEarned: Math.max(0, state.lucidityEarned + outcome.lucidityDelta),
      lastResult: {
        ...state.lastResult,
        reels:          outcome.reels,
        isJackpot:      outcome.isJackpot,
        winType:        outcome.winType,
        lucidityEarned: Math.max(0, state.lastResult.lucidityEarned + outcome.lucidityDelta),
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
      pattern23, learningOn,
    );

    // Side effect: consume a random other consumable or lose 20 neurons
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

    set({
      runConsumables: newRunConsumables,
      neurons: neuronsAfter,
      lucidityEarned: Math.max(0, state.lucidityEarned + outcome.lucidityDelta),
      lastResult: {
        ...state.lastResult,
        reels:          outcome.reels,
        isJackpot:      outcome.isJackpot,
        winType:        outcome.winType,
        lucidityEarned: Math.max(0, state.lastResult.lucidityEarned + outcome.lucidityDelta),
      },
    });
    return true;
  },

  checkDealerTrigger(): void {
    const state = get();
    if (state.runPhase !== 'running' || state.dealerPending) return;
    if (state.startingNeurons <= 0) return;

    const ratio = state.neurons / state.startingNeurons;

    const shouldTriggerPhase1 = state.dealerPhase === 0 && ratio <= DEALER_THRESHOLD_HIGH;
    const shouldTriggerPhase2 = state.dealerPhase === 1 && ratio <= DEALER_THRESHOLD_LOW;

    if (shouldTriggerPhase1 || shouldTriggerPhase2) {
      const offerId = pickDealerItem(state.spinCount);
      set({
        dealerPhase:   state.dealerPhase + 1 as 1 | 2,
        dealerPending: true,
        dealerOfferId: offerId,
      });
    }
  },

  acceptDealerOffer(): void {
    const state = get();
    if (!state.dealerPending || !state.dealerOfferId) return;

    const item = IN_RUN_ITEM_MAP[state.dealerOfferId];
    if (!item) {
      set({ dealerPending: false, dealerOfferId: null });
      return;
    }

    const effect = item.effect;

    switch (effect.type) {
      case 'addNeurons':
        set({
          dealerPending: false,
          dealerOfferId: null,
          neurons: Math.min(state.neurons + effect.amount, ECONOMY.MAX_NEURONS),
          forcedRandomBetSpins: state.forcedRandomBetSpins + effect.forcedRandomBetSpins,
        });
        break;

      case 'addLucidity':
        set({
          dealerPending: false,
          dealerOfferId: null,
          lucidityEarned: state.lucidityEarned + effect.amount,
        });
        break;

      case 'cocktailBoost': {
        const raritySum = state.lastResult
          ? state.lastResult.reels.reduce((sum, sym) => sum + (SYMBOLS[sym]?.rarityScore ?? 0), 0)
          : 0;
        set({
          dealerPending: false,
          dealerOfferId: null,
          lucidityEarned: state.lucidityEarned + raritySum * 3,
        });
        break;
      }

      case 'guaranteedWin':
        set({
          dealerPending: false,
          dealerOfferId: null,
          guaranteedWinSpins: state.guaranteedWinSpins + effect.spins,
          blockPowersSpins: state.blockPowersSpins + effect.blockPowersSpins,
        });
        break;

      default:
        set({ dealerPending: false, dealerOfferId: null });
    }
  },

  declineDealerOffer(): void {
    set({ dealerPending: false, dealerOfferId: null });
  },
}));
