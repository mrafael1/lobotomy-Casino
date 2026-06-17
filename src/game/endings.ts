import { ECONOMY } from '../content/economy';
import type { RunState, MetaState, EndingType } from './types';

export function checkEnding(run: RunState, meta: MetaState): EndingType | null {
  if (run.neurons <= 0) return 'flatline';
  if (run.scoreEarned >= ECONOMY.WEALTH_SCORE_THRESHOLD) return 'wealth';
  return null;
}

// The Exit Route requires no corruption AND enough lucidity coins banked this run.
export function checkExitEligibility(run: RunState, meta: MetaState): boolean {
  return (
    !meta.corruptionEverUsed &&
    run.lucidityCoins >= ECONOMY.EXIT_LUCIDITY_THRESHOLD
  );
}

// The single transition point where run state crosses into meta.
// lucidityCoins bank to the wallet; scoreEarned tracks the personal best.
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
    lucidityWallet: meta.lucidityWallet + run.lucidityCoins,
    endingsReached,
    history: {
      runsPlayed: meta.history.runsPlayed + 1,
      bestScoreRun: Math.max(meta.history.bestScoreRun, run.scoreEarned),
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
