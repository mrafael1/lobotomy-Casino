import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { Text } from './PixelText';

// Flatline retention readout. The player's full run Lucidity (their "score") shows
// first, then — after a short beat so they can read it — the number drains down to
// the 10% they keep, the lost amount climbing in red as it falls. Purely visual:
// the bank already kept the real 10% when the run ended; this only dramatises the
// loss. Lives on the screen-space run-over overlay (outside PixelScene), so sizes
// are plain px like the rest of that overlay.
const HOLD_MS  = 700;   // let the player read their full score before it drains
const DRAIN_MS = 1600;  // duration of the count-down to the kept amount

interface Props {
  // Lucidity accumulated this run — the score shown, and what 10% is taken from.
  total: number;
  // Fraction kept on flatline (ECONOMY.END_OF_RUN_LUCIDITY_KEPT, e.g. 0.10).
  keptFraction: number;
}

export function FlatlineKeptCountdown({ total, keptFraction }: Props) {
  const kept = Math.floor(total * keptFraction);
  const keptPct = Math.round(keptFraction * 100);
  const [display, setDisplay] = useState(total);
  const rafRef = useRef<ReturnType<typeof requestAnimationFrame> | null>(null);
  const holdRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    setDisplay(total);
    if (kept >= total) return; // nothing to lose (e.g. ran with 0 Lucidity)

    holdRef.current = setTimeout(() => {
      const t0 = Date.now();
      const tick = () => {
        const p = Math.min(1, (Date.now() - t0) / DRAIN_MS);
        const eased = 1 - (1 - p) * (1 - p); // easeOutQuad — quick drop, gentle settle
        setDisplay(p >= 1 ? kept : Math.round(total - (total - kept) * eased));
        if (p < 1) rafRef.current = requestAnimationFrame(tick);
      };
      rafRef.current = requestAnimationFrame(tick);
    }, HOLD_MS);

    return () => {
      if (holdRef.current) clearTimeout(holdRef.current);
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
    };
  }, [total, kept]);

  const lost = total - display;

  return (
    <View style={styles.wrap}>
      <Text style={styles.score}>{display}</Text>
      <Text style={styles.keptLabel}>LUCIDITY · {keptPct}% KEPT</Text>
      {lost > 0 && <Text style={styles.lost}>−{lost} lost</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    alignItems: 'center',
    gap: 4,
  },
  score: {
    color: '#f8fafc',
    fontSize: 40,
    letterSpacing: 3,
  },
  keptLabel: {
    color: '#94a3b8',
    fontSize: 13,
    letterSpacing: 2,
  },
  lost: {
    color: '#ef4444',
    fontSize: 15,
    letterSpacing: 1,
  },
});
