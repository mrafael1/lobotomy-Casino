import { useEffect, useRef, useState } from 'react';
import { useRunStore } from './runState';
import { COIN_FIRST_ARRIVAL_MS } from '../content/timing';

// The "settled" Lucidity total: the real total, but FROZEN while a spin's reels
// are still turning (isSpinning), released only once they all stop. spin() banks
// the coins immediately (gameplay isn't blocked), but the visual feedback — coins
// flying from the tray, the counter climbing, the bar filling — should wait for
// the final reel (incl. the 3rd-reel pair tension) to land. Non-spin gains (dealer
// water, power re-scores) happen while not spinning, so they release at once.
export function useSettledLucidity(hold = false): number {
  const coins = useRunStore(s => s.lucidityCoins);
  const isSpinning = useRunStore(s => s.isSpinning);
  const [settled, setSettled] = useState(coins);

  useEffect(() => {
    // Hold during the spin or any external visual-hold (e.g. reroll animation).
    if (!isSpinning && !hold) setSettled(coins);
  }, [coins, isSpinning, hold]);

  return settled;
}

// The "coin-arrival gated" total: the settled total, but its INCREASES are held
// back until the first flying coin would reach the goal bar (COIN_FIRST_ARRIVAL_MS
// after the gain settles). This is what makes the counter + objective bar wait —
// they only start climbing when coins ARRIVE at the bar, not while coins are still
// leaving the tray. Decreases/resets snap (we only ever count up). If the coin
// animation is skipped, the same delay acts as a short fallback so the displayed
// total still reconciles to the real Lucidity.
function useCoinArrivalGatedLucidity(): number {
  const settled = useSettledLucidity();
  const [gated, setGated] = useState(settled);
  const gatedRef = useRef(settled);

  useEffect(() => {
    // Decrease/reset: snap immediately (mirrors CoinFlow, which ignores decreases).
    if (settled <= gatedRef.current) {
      gatedRef.current = settled;
      setGated(settled);
      return;
    }
    // Increase: defer until the first coin reaches the goal bar.
    const timer = setTimeout(() => {
      gatedRef.current = settled;
      setGated(settled);
    }, COIN_FIRST_ARRIVAL_MS);
    return () => clearTimeout(timer);
  }, [settled]);

  return gated;
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
  // Follow the coin-arrival gated total so the counter/bar start climbing only
  // once the first coin reaches the goal bar — not while coins are still leaving
  // the tray (and never before the reels stop, which the settled total enforces).
  const target = useCoinArrivalGatedLucidity();
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
