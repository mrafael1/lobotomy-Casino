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

  // Lucidity
  BASE_LUCIDITY_MULTIPLIER: 1.0,

  // Ending thresholds (tune via simulator)
  WEALTH_LUCIDITY_THRESHOLD: 1000, // corrupted builds can reach ~1200–1500 L/run
  EXIT_LUCIDITY_THRESHOLD:    750, // pure positive ceiling ~850–950 L/run — hard but achievable
} as const;
