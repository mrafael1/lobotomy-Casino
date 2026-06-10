import { ECONOMY } from '../content/economy';
import { UPGRADE_MAP } from '../content/upgrades';
import type { UpgradeId } from './types';

// Compute the effective neuron decay for a spin given the current upgrade set.
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

// Compute starting neurons for a new run from owned permanents.
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

// Compute the neuron cap (hard ceiling) from owned permanents.
export function computeNeuronCap(ownedPermanents: ReadonlyArray<UpgradeId>): number {
  let cap: number = ECONOMY.MAX_NEURONS;
  for (const id of ownedPermanents) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'neuronCapIncrease') {
      cap = Math.max(cap, upgrade.effect.newCap);
    }
  }
  return Math.min(cap, ECONOMY.MAX_NEURONS_ACT2);
}

// Compute the combined Lucidity multiplier from all active upgrades.
export function computeLucidityMultiplier(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  let multiplier = ECONOMY.BASE_LUCIDITY_MULTIPLIER;
  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (
      upgrade?.effect.type === 'lucidityMultiplier' ||
      upgrade?.effect.type === 'cleanLucidityMultiplier'
    ) {
      multiplier *= upgrade.effect.multiplier;
    }
  }
  return multiplier;
}

// Compute the jackpot-specific multiplier from corrupted upgrades.
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

// The maximum free spin count allowed given current upgrades.
export function computeMaxFreeSpins(ownedUpgrades: ReadonlyArray<UpgradeId>): number {
  let max: number = ECONOMY.BASE_MAX_FREE_SPINS;
  for (const id of ownedUpgrades) {
    const upgrade = UPGRADE_MAP[id];
    if (upgrade?.effect.type === 'freeSpinMaxIncrease') {
      max = Math.max(max, upgrade.effect.newMax);
    }
  }
  return Math.min(max, ECONOMY.UPGRADED_MAX_FREE_SPINS);
}

// Passive Lucidity earned every spin regardless of result (positive upgrade).
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
