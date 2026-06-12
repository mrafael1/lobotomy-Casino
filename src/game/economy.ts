import { ECONOMY } from '../content/economy';
import { UPGRADE_MAP } from '../content/upgrades';
import { BOOK_SYMBOL_WEIGHT } from '../content/symbols';
import type { UpgradeId } from './types';

export function computeNeuronDecay(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  let decay = ECONOMY.NEURON_DECAY_PER_SPIN;
  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'neuronDecayReduction') {
      decay -= upgrade.effect.amount;
    }
  }
  return Math.max(ECONOMY.MIN_NEURON_DECAY, decay);
}

export function computeStartingNeurons(ownedPermanents: ReadonlyArray<UpgradeId>): number {
  let neurons = ECONOMY.STARTING_NEURONS;
  for (const id of ownedPermanents) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'startingNeuronBonus') {
      neurons += upgrade.effect.amount;
    }
  }
  return Math.min(neurons, computeNeuronCap(ownedPermanents));
}

export function computeNeuronCap(ownedPermanents: ReadonlyArray<UpgradeId>): number {
  return ECONOMY.MAX_NEURONS;
}

// Combined Lucidity multiplier: multiplicative clean upgrades × (1 + additive reward amp bonus).
export function computeLucidityMultiplier(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  let multiplicative = ECONOMY.BASE_LUCIDITY_MULTIPLIER;
  let rewardAmpBonus = 0;

  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (!upgrade) continue;
    if (upgrade.effect.type === 'lucidityMultiplier') {
      multiplicative *= upgrade.effect.multiplier;
    } else if (upgrade.effect.type === 'rewardAmpBonus') {
      rewardAmpBonus += upgrade.effect.bonus;
    }
  }
  return multiplicative * (1 + rewardAmpBonus);
}

export function computeJackpotMultiplier(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  let multiplier = 1.0;
  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'jackpotLucidityMultiplier') {
      multiplier *= upgrade.effect.multiplier;
    }
  }
  return multiplier;
}

export function computeMaxFreeSpins(_ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  return ECONOMY.BASE_MAX_FREE_SPINS;
}

export function computePassiveLucidity(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  let passive = 0;
  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'passiveLucidityPerSpin') {
      passive += upgrade.effect.amount;
    }
  }
  return passive;
}

// Returns > 0 if the Learning upgrade is owned (the book symbol weight to use).
export function computeBookWeight(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'bookSymbol') {
      return upgrade.effect.weight;
    }
  }
  return 0;
}

// Returns the extra brain weight from Pattern Recognition upgrade.
// Does NOT include Syringe boost — that's tracked separately in RunState.
export function computeBrainWeightBonus(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  let bonus = 0;
  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'brainWeightBonus') {
      bonus += upgrade.effect.amount;
    }
  }
  return bonus;
}

// True if the Sedative Protocol corrupted upgrade is owned.
export function hasSedative(ownedUpgrades: ReadonlyArray<UpgradeId>): boolean {
  return ownedUpgrades.some(id => UPGRADE_MAP[id]?.effect.type === 'sedativeBonusSpin');
}

// True if Pattern Fabrication (2/3 doubled pair) is owned.
export function hasPattern23Triple(ownedUpgrades: ReadonlyArray<UpgradeId>): boolean {
  return ownedUpgrades.some(id => UPGRADE_MAP[id]?.effect.type === 'pattern23Triple');
}
