// All economic constants. No magic numbers anywhere else — only here.
// Tune these against simulator output before shipping.

export const ECONOMY = {
  // Neurons
  STARTING_NEURONS:         100,
  NEURON_DECAY_PER_SPIN:    3,   // base cost per regular spin
  MIN_NEURONS_TO_SPIN:      3,   // spin disabled below this
  MAX_NEURONS:              100, // hard cap in Act I
  MAX_NEURONS_ACT2:         300, // cap with positive upgrades (Act II)
  MIN_NEURON_DECAY:         1,   // upgrades cannot reduce decay below 1

  // Free spins
  BASE_MAX_FREE_SPINS:      1,   // default cap; jackpot grants exactly this
  UPGRADED_MAX_FREE_SPINS:  3,   // max reachable with corrupted upgrades

  // Score multiplier baseline (bet × reward-amp on top of this)
  BASE_LUCIDITY_MULTIPLIER: 1.0,

  // Ending thresholds
  WEALTH_SCORE_THRESHOLD:   1000, // score needed to trigger the wealth ending
  EXIT_LUCIDITY_THRESHOLD:   750, // lucidity wallet needed for a voluntary exit

  // Every N lucidity coins earned in a run restores one randomly-chosen spent ability.
  // If no ability has been used at the threshold crossing the credit is lost.
  LUCIDITY_COINS_PER_RESTORE: 30,
} as const;
