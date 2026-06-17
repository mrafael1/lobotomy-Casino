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
import { CONSUMABLE_MAP, MAX_CONSUMABLE_SLOTS, MAX_CONSUMABLE_CHARGES_PER_SLOT } from '../content/consumables';
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
  discardConsumableForGift: (discardId: string) => void;
  dismissGift: () => void;
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
  pendingGiftConsumableId:    null,
  pendingGiftNeedsDiscard:    false,
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

function activeSlotIds(runConsumables: Partial<Record<string, number>>): string[] {
  return Object.keys(runConsumables).filter(k => (runConsumables[k] ?? 0) > 0);
}

function canStoreItem(runConsumables: Partial<Record<string, number>>, itemId: string): boolean {
  const currentCharges = runConsumables[itemId] ?? 0;
  if (currentCharges >= MAX_CONSUMABLE_CHARGES_PER_SLOT) return false;
  if (currentCharges > 0) return true;
  return activeSlotIds(runConsumables).length < MAX_CONSUMABLE_SLOTS;
}

function pickDealerItems(spinCount: number, runConsumables: Partial<Record<string, number>>): [string, string] | null {
  const rng = createRNG(((Date.now() ^ (spinCount * 0x6b43c7f)) >>> 0));
  const candidates = DEALER_ITEM_IDS.filter(id =>
    (runConsumables[id] ?? 0) < MAX_CONSUMABLE_CHARGES_PER_SLOT);
  if (candidates.length < 2) return null;
  const shuffled = [...candidates].sort(() => rng() - 0.5);
  return [shuffled[0], shuffled[1]];
}

// Attempt to restore a randomly-chosen spent ability.
// Called when a 30-coin threshold is crossed. If no ability has been used,
// the credit is lost ("lose it" semantics — no carry-over).
function tryRestoreAbility(
  abilitiesUsed: ReadonlyArray<AbilityId>,
  seed: number,
): ReadonlyArray<AbilityId> {
  if (abilitiesUsed.length === 0) return abilitiesUsed;
  const rng = createRNG((seed >>> 0));
  const idx = Math.floor(rng() * abilitiesUsed.length);
  return abilitiesUsed.filter((_, i) => i !== idx) as ReadonlyArray<AbilityId>;
}

export const useRunStore = create<RunStore>((set, get) => ({
  ...INITIAL_RUN_STATE,
  runPhase: 'idle',
  lastEnding: null,
  decaySkips: 0,

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

    // Lucidity coin accumulation + ability-restore check.
    // Every LUCIDITY_COINS_PER_RESTORE coins earned fires one restore attempt.
    // "Lose it" semantics: if no ability has been spent, the credit is forfeited.
    const prevCoins = state.lucidityCoins;
    const newCoins  = prevCoins + finalResult.coinsEarned;
    const prevGen   = Math.floor(prevCoins / ECONOMY.LUCIDITY_COINS_PER_RESTORE);
    const nextGen   = Math.floor(newCoins  / ECONOMY.LUCIDITY_COINS_PER_RESTORE);
    let abilitiesUsed = state.abilitiesUsed;
    for (let i = prevGen; i < nextGen; i++) {
      abilitiesUsed = tryRestoreAbility(abilitiesUsed, seed ^ (i * 0x517cc1b7));
    }

    set({
      neurons:                    finalResult.neuronsAfter,
      scoreEarned:                state.scoreEarned + finalResult.scoreEarned,
      lucidityCoins:              newCoins,
      abilitiesUsed,
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

        case 'addLucidity':
          // Water (dealer item): grants coins directly to the run wallet drip
          set({
            runConsumables: newRunConsumables,
            lucidityCoins: state.lucidityCoins + effect.amount,
          });
          return true;

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

    const freeSpinsAfter = Math.min(
      state.freeSpinsRemaining + outcome.freeSpinsGranted, state.maxFreeSpins);
    set({
      abilitiesUsed: [...state.abilitiesUsed, 'reroll'],
      scoreEarned:   Math.max(0, state.scoreEarned + outcome.scoreDelta),
      lucidityCoins: Math.max(0, state.lucidityCoins + outcome.coinsDelta),
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
    const freeSpinsAfter = Math.min(
      state.freeSpinsRemaining + outcome.freeSpinsGranted, state.maxFreeSpins);
    set({
      abilitiesUsed: [...state.abilitiesUsed, 'shift'],
      scoreEarned:   Math.max(0, state.scoreEarned + outcome.scoreDelta),
      lucidityCoins: Math.max(0, state.lucidityCoins + outcome.coinsDelta),
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

    const freeSpinsAfter = Math.min(
      state.freeSpinsRemaining + outcome.freeSpinsGranted, state.maxFreeSpins);
    set({
      runConsumables: newRunConsumables,
      neurons: neuronsAfter,
      scoreEarned:   Math.max(0, state.scoreEarned + outcome.scoreDelta),
      lucidityCoins: Math.max(0, state.lucidityCoins + outcome.coinsDelta),
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
      const offerIds = pickDealerItems(state.spinCount, state.runConsumables);
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

    const existingCharges = state.runConsumables[itemId] ?? 0;
    if (canStoreItem(state.runConsumables, itemId)) {
      set({
        dealerPending: false,
        dealerOfferIds: null,
        runConsumables: { ...state.runConsumables, [itemId]: existingCharges + 1 },
        pendingGiftConsumableId: null,
        pendingGiftNeedsDiscard: false,
      });
      return;
    }

    set({
      dealerPending: false,
      dealerOfferIds: null,
      pendingGiftConsumableId: itemId,
      pendingGiftNeedsDiscard: true,
    });
  },

  declineDealerOffer(): void {
    set({ dealerPending: false, dealerOfferIds: null });
  },

  discardConsumableForGift(discardId: string): void {
    const state = get();
    const giftId = state.pendingGiftConsumableId;
    if (!giftId) return;
    if ((state.runConsumables[discardId] ?? 0) <= 0) return;

    const next = { ...state.runConsumables };
    delete next[discardId];
    next[giftId] = Math.min((next[giftId] ?? 0) + 1, MAX_CONSUMABLE_CHARGES_PER_SLOT);
    set({ runConsumables: next, pendingGiftConsumableId: null, pendingGiftNeedsDiscard: false });
  },

  dismissGift(): void {
    set({ pendingGiftConsumableId: null, pendingGiftNeedsDiscard: false });
  },
}));
