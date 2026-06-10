// Free spin state is managed here, not scattered across the codebase.
// The "no chaining" rule is enforced structurally in evaluate.ts; these helpers
// manage the counter that feeds into SpinInput.

export interface FreeSpinState {
  readonly remaining: number;
  readonly max: number;
}

export function createFreeSpinState(max: number): FreeSpinState {
  return { remaining: 0, max };
}

// Called when player buys a "free spin max increase" upgrade
export function setFreeSpinMax(state: FreeSpinState, newMax: number): FreeSpinState {
  return {
    max: newMax,
    remaining: Math.min(state.remaining, newMax),
  };
}

export function hasFreeSpin(state: FreeSpinState): boolean {
  return state.remaining > 0;
}
