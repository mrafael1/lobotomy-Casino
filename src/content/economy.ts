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

  // The main Lucidity objective shown by the machine TV bar (progress, no reset).
  // This is the default/current tier goal; a later tier system can override it.
  LUCIDITY_OBJECTIVE: 1000,

  // Every N lucidity coins earned in a run resets (restores) one randomly-chosen
  // spent power. The Nth coin (50, 100, 150, …) is the "power coin" that fires it.
  // This is SEPARATE from the TV objective bar (which tracks LUCIDITY_OBJECTIVE
  // and never resets). If no power has been used at a crossing the credit is lost.
  LUCIDITY_COINS_PER_RESTORE: 50,

  // End-of-run retention: the player keeps this fraction of the Lucidity they
  // accumulated during the run (banked to the wallet). The rest is burned off.
  END_OF_RUN_LUCIDITY_KEPT: 0.10,
} as const;

// The Nth coin (50, 100, 150, …) is a "power coin": when it reaches the counter it
// resets one power. Pass the running total AFTER the coin has been counted.
export function isPowerCoin(totalLucidityAfterCoin: number): boolean {
  return (
    totalLucidityAfterCoin > 0 &&
    totalLucidityAfterCoin % ECONOMY.LUCIDITY_COINS_PER_RESTORE === 0
  );
}
