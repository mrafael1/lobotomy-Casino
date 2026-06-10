import { ECONOMY } from '../content/economy';
import type { RunState, MetaState, EndingType } from './types';

// Check if the current run has triggered an ending condition.
// Returns null if the run should continue.
export function checkEnding(run: RunState, meta: MetaState): EndingType | null {
  if (run.neurons <= 0) return 'flatline';
  if (run.lucidityEarned >= ECONOMY.WEALTH_LUCIDITY_THRESHOLD) return 'wealth';
  return null;
}

// The Exit Route requires no corruption AND a Lucidity threshold.
// corruptionEverUsed is permanent per slot — there is no undo path here.
export function checkExitEligibility(run: RunState, meta: MetaState): boolean {
  return (
    !meta.corruptionEverUsed &&
    run.lucidityEarned >= ECONOMY.EXIT_LUCIDITY_THRESHOLD
  );
}

// The single transition point where run state crosses into meta.
// ONLY Lucidity crosses — neurons, free spins, spin count, all die with the run.
export function bankRunToMeta(
  run: RunState,
  meta: MetaState,
  ending: EndingType,
): MetaState {
  const endingsReached = meta.endingsReached.includes(ending)
    ? meta.endingsReached
    : ([...meta.endingsReached, ending] as MetaState['endingsReached']);

  return {
    ...meta,
    lucidityWallet: meta.lucidityWallet + run.lucidityEarned,
    endingsReached,
    history: {
      runsPlayed: meta.history.runsPlayed + 1,
      bestLucidityRun: Math.max(meta.history.bestLucidityRun, run.lucidityEarned),
      wealthEndingReachedAt:
        ending === 'wealth' && !meta.history.wealthEndingReachedAt
          ? Date.now()
          : meta.history.wealthEndingReachedAt,
      exitEndingReachedAt:
        ending === 'exit' && !meta.history.exitEndingReachedAt
          ? Date.now()
          : meta.history.exitEndingReachedAt,
    },
  };
}
