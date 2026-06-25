import { useEffect, useRef, useState } from 'react';
import { useRunStore } from './runState';

// The "settled" Lucidity total: the real total, but FROZEN while a spin's reels
// are still turning (isSpinning), released only once they all stop. spin() banks
// the coins immediately (gameplay isn't blocked), but the visual feedback — coins
// flying from the tray, the counter climbing, the bar filling — should wait for
// the final reel (incl. the 3rd-reel pair tension) to land. Non-spin gains (dealer
// water, power re-scores) happen while not spinning, so they release at once.
export function useSettledLucidity(): number {
  const coins = useRunStore(s => s.lucidityCoins);
  const isSpinning = useRunStore(s => s.isSpinning);
  const [settled, setSettled] = useState(coins);

  useEffect(() => {
    // Hold during the spin; snap to the real total the moment the reels stop.
    if (!isSpinning) setSettled(coins);
  }, [coins, isSpinning]);

  return settled;
}

// A displayed Lucidity value that climbs smoothly toward the real total. Gameplay
// state (lucidityCoins) updates immediately; only this UI number lags and counts
// up, so the goal counter (MachineScreenMeters) and the TV objective bar
// (SlotMachine) share one synced animation.
//
// Behaviour:
//   - increases animate (count up); larger gains climb faster but visibly,
//     capped at MAX_MS so a huge gain never crawls.
//   - decreases (a power that lowers the score, or a new run resetting to 0)
//     snap instantly — we only ever count UP.
//   - a new gain mid-climb just re-targets and keeps climbing.
const MS_PER_UNIT = 26;   // ms per Lucidity point — slower so small/medium gains read
const MIN_MS = 300;       // floor so tiny gains still read as a climb
const MAX_MS = 1500;      // ceiling so big gains stay fast enough (cap the wait)

export function useAnimatedLucidity(): number {
  // Follow the settled total so the counter/bar climb only after the reels stop,
  // in sync with the flying coins.
  const target = useSettledLucidity();
  const [display, setDisplay] = useState(target);
  const displayRef = useRef(target);
  const rafRef = useRef<ReturnType<typeof requestAnimationFrame> | null>(null);

  useEffect(() => {
    const from = displayRef.current;
    const to = target;

    // Only ever count up; snap on any decrease (incl. run reset to 0).
    if (to <= from) {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
      displayRef.current = to;
      setDisplay(to);
      return;
    }

    const dur = Math.min(MAX_MS, Math.max(MIN_MS, (to - from) * MS_PER_UNIT));
    const t0 = Date.now();

    const tick = () => {
      const p = Math.min(1, (Date.now() - t0) / dur);
      // easeOutQuad — quick start, gentle settle onto the exact value.
      const eased = 1 - (1 - p) * (1 - p);
      const value = p >= 1 ? to : Math.round(from + (to - from) * eased);
      displayRef.current = value;
      setDisplay(value);
      if (p < 1) {
        rafRef.current = requestAnimationFrame(tick);
      } else {
        rafRef.current = null;
      }
    };

    if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(tick);

    return () => {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    };
  }, [target]);

  return display;
}
