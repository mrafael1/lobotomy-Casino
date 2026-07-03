import { ECONOMY } from '../content/economy';
import type { RunState, MetaState, EndingType } from './types';

export function checkEnding(run: RunState, meta: MetaState): EndingType | null {
  if (run.scoreEarned >= ECONOMY.WEALTH_SCORE_THRESHOLD) return 'wealth';
  if (run.neurons <= 0) return 'flatline';
  return null;
}

// The Exit Route requires no corruption AND enough lucidity coins banked this run.
export function checkExitEligibility(run: RunState, meta: MetaState): boolean {
  return (
    !meta.corruptionEverUsed &&
    run.lucidityCoins >= ECONOMY.EXIT_LUCIDITY_THRESHOLD
  );
}

export function lucidityKeptFraction(meta: MetaState): number {
  return meta.ownedPermanents.includes(ECONOMY.SMART_SAVE_UPGRADE_ID)
    ? ECONOMY.SMART_SAVE_LUCIDITY_KEPT
    : ECONOMY.END_OF_RUN_LUCIDITY_KEPT;
}

// The single transition point where run state crosses into meta.
// lucidityCoins bank to the wallet; scoreEarned tracks the personal best.
//
// Retention: the player keeps only END_OF_RUN_LUCIDITY_KEPT (10%) of the Lucidity
// accumulated this run — e.g. 150 accumulated → 15 banked. Floor so the kept
// amount is a whole coin and never rounds up past what was earned.
export function bankRunToMeta(
  run: RunState,
  meta: MetaState,
  ending: EndingType,
): MetaState {
  const endingsReached = meta.endingsReached.includes(ending)
    ? meta.endingsReached
    : ([...meta.endingsReached, ending] as MetaState['endingsReached']);

  const keptLucidity = Math.floor(run.lucidityCoins * lucidityKeptFraction(meta));

  return {
    ...meta,
    lucidityWallet: meta.lucidityWallet + keptLucidity,
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
