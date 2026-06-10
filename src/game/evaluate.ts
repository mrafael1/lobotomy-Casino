import { SYMBOL_WEIGHTS } from '../content/symbols';
import {
  JACKPOT_LUCIDITY,
  JACKPOT_FREE_SPIN_GRANT,
  TRIPLE_PAYOUTS,
  PAIR_PAYOUTS,
} from '../content/payouts';
import { weightedPick } from './rng';
import type { SpinInput, SpinResult, ReelResult, SymbolId, WinType } from './types';

function spinReel(rng: SpinInput['rng']): SymbolId {
  return weightedPick(SYMBOL_WEIGHTS, rng);
}

// evaluate() is the single source of truth for a spin's outcome.
// Call it synchronously BEFORE starting any animation. The animation plays
// toward the already-decided result — it can never change the outcome.
export function evaluate(input: SpinInput): SpinResult {
  const {
    neurons,
    neuronDecayAmount,
    freeSpinsRemaining,
    maxFreeSpins,
    lucidityMultiplier,
    isFreeSpin,
    lockedReels,
    previousReels,
    rng,
  } = input;

  // Spin each reel; locked reels keep the previous symbol (reel-lock consumable)
  const reels: ReelResult = [
    lockedReels[0] && previousReels ? previousReels[0] : spinReel(rng),
    lockedReels[1] && previousReels ? previousReels[1] : spinReel(rng),
    lockedReels[2] && previousReels ? previousReels[2] : spinReel(rng),
  ];
  const [a, b, c] = reels;

  // Neurons: free spins cost nothing
  const neuronsAfter = isFreeSpin
    ? neurons
    : Math.max(0, neurons - neuronDecayAmount);

  // Determine win type
  let winType: WinType = 'miss';
  let lucidityEarned = 0;
  let freeSpinsGranted = 0;

  if (a === b && b === c) {
    if (a === 'brain') {
      winType = 'jackpot';
      lucidityEarned = Math.round(JACKPOT_LUCIDITY * lucidityMultiplier);
      // Structural enforcement: free spins NEVER generate free spins (§4 of arch doc)
      if (!isFreeSpin) {
        freeSpinsGranted = JACKPOT_FREE_SPIN_GRANT;
      }
    } else {
      winType = 'triple';
      lucidityEarned = Math.round((TRIPLE_PAYOUTS[a] ?? 0) * lucidityMultiplier);
    }
  } else if (a === b || b === c) {
    // Only adjacent pairs count (left-to-right read; a===c without matching b is a miss)
    const matchSymbol: SymbolId = a === b ? a : b;
    winType = 'pair';
    lucidityEarned = Math.round((PAIR_PAYOUTS[matchSymbol] ?? 0) * lucidityMultiplier);
  }

  // Free spin accounting
  const freeSpinsAfter = isFreeSpin
    ? Math.max(0, freeSpinsRemaining - 1)                           // consumed one
    : Math.min(freeSpinsRemaining + freeSpinsGranted, maxFreeSpins); // may gain one

  return {
    reels,
    lucidityEarned,
    neuronsAfter,
    freeSpinsGranted,
    freeSpinsAfter,
    isJackpot: winType === 'jackpot',
    isFreeSpin,
    winType,
  };
}
