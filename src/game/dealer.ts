// Pure, deterministic dealer logic — extracted from the runState store so it can
// be exercised headlessly and pinned as golden parity vectors for the Godot port.
//
// The store still owns scene/phase gating (dealerIncoming / dealerPending /
// runPhase) and supplies the seeds; everything that decides WHETHER the dealer
// triggers and WHICH two items are offered lives here as side-effect-free
// functions of (state numbers, seed).
//
// Parity seam note: offer selection previously used `[...].sort(() => rng() - 0.5)`,
// an engine-dependent (and statistically biased) shuffle whose result depends on
// V8's sort implementation — impossible to reproduce bit-exactly in GDScript.
// It is replaced here with a portable Fisher-Yates shuffle driven by the same
// Mulberry32 RNG. Because the seed was already derived from Date.now(), the
// observable behavior (a random pair of distinct offers) is unchanged; only the
// exact pair for a given seed differs, which no gameplay rule or test depends on.

import { createRNG } from './rng';
import { IN_RUN_ITEMS } from '../content/inRunItems';

export const DEALER_THRESHOLD_HIGH = 0.65;
export const DEALER_THRESHOLD_LOW  = 0.35;
export const DEALER_PROC_CHANCE    = 0.15;
export const DEALER_MAX_COUNT      = 3;
export const DEALER_MIN_SPIN_GAP   = 3;

export const DEALER_ITEM_IDS: ReadonlyArray<string> = IN_RUN_ITEMS.map(item => item.id);

// Portable Fisher-Yates: identical output in TS and GDScript for the same RNG
// stream. Mutates and returns `arr`.
export function shuffleInPlace<T>(arr: T[], rng: () => number): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

// Choose the two distinct items the dealer offers, deterministically from `seed`.
export function pickDealerItems(seed: number): [string, string] | null {
  const candidates = [...DEALER_ITEM_IDS];
  if (candidates.length < 2) return null;
  const rng = createRNG(seed >>> 0);
  shuffleInPlace(candidates, rng);
  return [candidates[0], candidates[1]];
}

export interface DealerTriggerInput {
  readonly neurons: number;
  readonly startingNeurons: number;
  readonly spinCount: number;
  readonly dealerCount: number;
  readonly dealerLastSpinCount: number;
  readonly dealer65SafetyFired: boolean;
  readonly dealer35SafetyFired: boolean;
  readonly procSeed: number; // seed for the 15% random-proc roll
}

export interface DealerTriggerResult {
  readonly shouldTrigger: boolean;
  readonly dealer65SafetyFired: boolean;
  readonly dealer35SafetyFired: boolean;
}

// Decide whether the dealer should appear this check, plus the updated safety
// flags. Pure: same inputs → same outputs. Hard preconditions (no starting
// neurons, dealer cap reached, min-spin-gap not met) short-circuit to no-trigger
// with the safety flags left untouched — matching the store's early returns.
export function evaluateDealerTrigger(input: DealerTriggerInput): DealerTriggerResult {
  const {
    neurons, startingNeurons, spinCount, dealerCount, dealerLastSpinCount,
    dealer65SafetyFired, dealer35SafetyFired, procSeed,
  } = input;

  if (
    startingNeurons <= 0 ||
    dealerCount >= DEALER_MAX_COUNT ||
    spinCount - dealerLastSpinCount < DEALER_MIN_SPIN_GAP
  ) {
    return { shouldTrigger: false, dealer65SafetyFired, dealer35SafetyFired };
  }

  const ratio = neurons / startingNeurons;
  let shouldTrigger = false;
  let new65Fired = dealer65SafetyFired;
  let new35Fired = dealer35SafetyFired;

  if (!dealer65SafetyFired && ratio <= DEALER_THRESHOLD_HIGH) {
    new65Fired = true;
    if (dealerCount === 0) shouldTrigger = true;
  }

  if (!dealer35SafetyFired && ratio <= DEALER_THRESHOLD_LOW) {
    new35Fired = true;
    if (dealerCount === 1) shouldTrigger = true;
  }

  if (!shouldTrigger) {
    const rng = createRNG(procSeed >>> 0);
    if (rng() < DEALER_PROC_CHANCE) shouldTrigger = true;
  }

  return { shouldTrigger, dealer65SafetyFired: new65Fired, dealer35SafetyFired: new35Fired };
}
