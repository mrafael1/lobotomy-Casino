import { InteractionManager } from 'react-native';

export const DEBUG_PERF_TIMING = false;

export function logTiming(label: string): void {
  if (DEBUG_PERF_TIMING) console.log(label, Date.now());
}

export function afterPress(action: () => void): void {
  requestAnimationFrame(() => {
    action();
  });
}

export function afterInteractions(action: () => void): void {
  InteractionManager.runAfterInteractions(action);
}

export function logFirstFrameAfter(label: string): void {
  if (!DEBUG_PERF_TIMING) return;
  const start = Date.now();
  console.log(`${label} start`, start);
  requestAnimationFrame(() => {
    console.log(`${label} first frame`, Date.now(), Date.now() - start);
  });
}
