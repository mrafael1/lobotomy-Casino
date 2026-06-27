import { useRef } from 'react';

// Temporary render diagnostics. Flip DEBUG_RENDER_COUNTS to true to log how many
// times each instrumented component renders — useful for confirming that a single
// action (one arrow press, one spin, a coin animation) does NOT re-render the
// whole machine scene. Leave it false in committed builds; the calls compile away
// to a cheap ref bump when the flag is off.
export const DEBUG_RENDER_COUNTS = false;

// Spin-animation tracing — confirms exactly one animation starts per spin and no
// stale reel callbacks fire into a newer spin. Leave false in committed builds.
export const DEBUG_SPIN_ANIM = false;

// Power target-selection tracing — confirms the arrows' selection state flips the
// instant a power button is pressed.
export const DEBUG_POWER = false;

export function useRenderCount(name: string): void {
  const count = useRef(0);
  count.current += 1;
  if (__DEV__ && DEBUG_RENDER_COUNTS) {
    // eslint-disable-next-line no-console
    console.log(`[render] ${name}`, count.current);
  }
}
