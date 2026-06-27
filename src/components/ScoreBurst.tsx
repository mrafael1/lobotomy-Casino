import React, { useEffect, useRef, useState } from 'react';
import { Animated, StyleSheet } from 'react-native';
import { Text } from './PixelText';
import { useRunStore } from '../state/runState';
import type { SpinResult, ReelResult } from '../game/types';
import { REEL_CELL_CENTERS, REEL_WINDOW } from '../content/machineAssets';
import { SYMBOLS } from '../content/symbols';
import { DTM_SANS } from '../content/typography';

// Result-announcement colours, keyed by the bet multiplier the spin scored at.
// The win text (PAIR / TRIPLE / JACKPOT + amount) takes the multiplier's colour:
//   x1 = dark blue · x2 = the current orange/gold · x3 = red
// Visual only — no theme module exists yet, so these are the source of truth.
const CURRENT_ORANGE = '#fbbf24'; // the colour the result text used before this change
export const MULTIPLIER_RESULT_COLORS: Record<1 | 2 | 3, string> = {
  1: '#183A8C', // dark blue
  2: CURRENT_ORANGE,
  3: '#D62828', // red
};

// Lifetime of the burst (pop in → float up → fade out).
const BURST_MS = 1050;

// Cocktail per-reel score colour — matches the COCKTAIL status badge so the
// per-reel "+N" feedback reads as the cocktail's doing.
const COCKTAIL_COLOR = '#f0abfc';

// Reel a normal-spin win reads from when no power dictates the source: a pair on
// the first two reels reads from the 2nd reel (index 1); every other win (a pair
// on later reels, a triple/jackpot) reads from the 3rd reel (index 2).
function deriveSourceReel(reels: ReelResult): 0 | 1 | 2 {
  return reels[0] === reels[1] && reels[1] !== reels[2] ? 1 : 2;
}

// The lone unpaired reel of a pair (the symbol that shows once). Used to surface
// its Cocktail rarity gain, which is otherwise hidden inside the pair total.
// Returns null when there's no single odd reel (a triple, or no pair at all).
function soloReel(reels: ReelResult): 0 | 1 | 2 | null {
  if (reels[0] === reels[1] && reels[1] !== reels[2]) return 2;
  if (reels[1] === reels[2] && reels[0] !== reels[1]) return 0;
  if (reels[0] === reels[2] && reels[0] !== reels[1]) return 1;
  return null;
}

interface Burst {
  id: number;
  label?: string;    // PAIR / TRIPLE / JACKPOT / BONUS (omitted for per-reel cocktail)
  amount: number;    // Lucidity earned this result (or this reel, for cocktail)
  color: string;
  reel: 0 | 1 | 2;   // reel the score emerges from
}

interface Props {
  // Display px per source px (must match SlotMachine's `f`).
  f: number;
  // Explicit reel the score should emerge from when a power changed a reel
  // (reroll/shift/copy). `null` means "normal spin" — the reel is then derived
  // from the result (pair on the first two reels → 2nd reel, else 3rd reel).
  sourceReelIndex: 0 | 1 | 2 | null;
  // Bet multiplier this result scored at — picks the announcement colour.
  multiplier: 1 | 2 | 3;
  // True while the visual result is still landing (a power reroll animation
  // playing). Combined with isSpinning, the burst waits for this to clear so it
  // never appears before the 3rd reel (or the rerolled reel) stops.
  holdReveal: boolean;
}

// One-shot result announcement that pops out of the reel which produced the final
// scoring action, floats up toward the goal bar, and fades — then the coin flow
// (handled by CoinFlow) carries on. Reads the resolved result from the store and
// only fires once the reels have settled. Purely visual; owns no gameplay state.
export function ScoreBurst({ f, sourceReelIndex, multiplier, holdReveal }: Props) {
  const lastResult = useRunStore(s => s.lastResult);
  const isSpinning = useRunStore(s => s.isSpinning);
  const spinCount = useRunStore(s => s.spinCount);
  const settled = !isSpinning && !holdReveal;

  // The result we've already announced — start with whatever is on screen so a
  // remount never re-announces an old result. We also track the spin it belonged
  // to and the score it showed, so a power that re-scores the SAME spin only
  // re-pops when it actually adds score (see the gain check below).
  const announcedRef = useRef<SpinResult | null>(lastResult);
  const announcedSpinRef = useRef(spinCount);
  const prevScoreRef = useRef(lastResult?.scoreEarned ?? 0);
  const [bursts, setBursts] = useState<Burst[]>([]);
  const idRef = useRef(0);
  const anim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (!settled) return;
    if (!lastResult || lastResult === announcedRef.current) return;
    announcedRef.current = lastResult;

    // What did THIS action earn? A fresh spin earns its whole score; a power
    // re-scoring the same spin earns only the increase over the previous result.
    // A power used on a reel that doesn't improve the score (gain ≤ 0) must NOT
    // re-pop the announcement — that was the spurious repop.
    const isNewSpin = spinCount !== announcedSpinRef.current;
    const gain = isNewSpin
      ? lastResult.scoreEarned
      : lastResult.scoreEarned - prevScoreRef.current;
    announcedSpinRef.current = spinCount;
    prevScoreRef.current = lastResult.scoreEarned;

    let next: Burst[] | null = null;

    if (isNewSpin && lastResult.winType === 'miss' && lastResult.cocktailApplied) {
      // Cocktail, no pair/triple: the spin scored every visible symbol's rarity on
      // its own, so break it out — one "+N" floating from each reel.
      next = ([0, 1, 2] as const).map(i => ({
        id: idRef.current++,
        amount: SYMBOLS[lastResult.reels[i]]?.rarityScore ?? 0,
        color: COCKTAIL_COLOR,
        reel: i,
      }));
    } else if (gain > 0 && lastResult.winType !== 'miss') {
      const label =
        lastResult.winType === 'jackpot' ? 'JACKPOT'
        : lastResult.winType === 'triple' ? 'TRIPLE'
        : lastResult.winType === 'pair' ? 'PAIR'
        : 'BONUS';
      next = [{
        id: idRef.current++,
        label,
        amount: lastResult.scoreEarned,
        color: MULTIPLIER_RESULT_COLORS[multiplier],
        // Power override → that reel; otherwise read it from the result (a pair on
        // the first two reels pops on the 2nd reel, else the 3rd).
        reel: sourceReelIndex ?? deriveSourceReel(lastResult.reels),
      }];

      // Cocktail + pair: the unpaired symbol still scored its rarity, but that's
      // buried in the pair total. Float its solo gain from its own reel so the
      // player sees the cocktail paid for it too.
      const solo = isNewSpin && lastResult.cocktailApplied && lastResult.winType === 'pair'
        ? soloReel(lastResult.reels)
        : null;
      if (solo !== null) {
        next.push({
          id: idRef.current++,
          amount: SYMBOLS[lastResult.reels[solo]]?.rarityScore ?? 0,
          color: COCKTAIL_COLOR,
          reel: solo,
        });
      }
    }

    if (!next) return;
    setBursts(next);
    anim.setValue(0);
    Animated.timing(anim, { toValue: 1, duration: BURST_MS, useNativeDriver: true })
      .start(({ finished }) => { if (finished) setBursts([]); });
  }, [settled, lastResult, sourceReelIndex, multiplier, spinCount, anim]);

  if (bursts.length === 0) return null;

  // Spawn just above each reel's window, centred on the reel; pop a touch, then
  // float upward toward the goal bar while fading out. All active bursts share one
  // timeline so they rise together.
  const top = (REEL_WINDOW.top - 10) * f;
  const labelSize = Math.round(8 * f);
  const amountSize = Math.round(7 * f);

  const translateY = anim.interpolate({ inputRange: [0, 1], outputRange: [0, -28 * f] });
  const scale = anim.interpolate({ inputRange: [0, 0.18, 1], outputRange: [0.5, 1.1, 1] });
  const opacity = anim.interpolate({ inputRange: [0, 0.12, 0.7, 1], outputRange: [0, 1, 1, 0] });

  return (
    <>
      {bursts.map(b => {
        const cx = REEL_CELL_CENTERS[b.reel] * f;
        // Win labels need a wide box; per-reel cocktail "+N" sits narrow on its reel.
        const boxW = (b.label ? 64 : 28) * f;
        return (
          <Animated.View
            key={b.id}
            pointerEvents="none"
            style={{
              position: 'absolute',
              left: cx - boxW / 2,
              top,
              width: boxW,
              alignItems: 'center',
              opacity,
              transform: [{ translateY }, { scale }],
            }}
          >
            {b.label ? (
              <Text style={[styles.label, { color: b.color, fontSize: labelSize }]} numberOfLines={1}>
                {b.label}
              </Text>
            ) : null}
            <Text style={[styles.amount, { color: b.color, fontSize: amountSize }]} numberOfLines={1}>
              +{b.amount}
            </Text>
          </Animated.View>
        );
      })}
    </>
  );
}

const styles = StyleSheet.create({
  // Pixel font only (DTM ships a single weight — no fontWeight, or Android drops
  // the pixel face for the system sans). A dark shadow keeps it readable over the
  // reels.
  label: {
    fontFamily: DTM_SANS,
    letterSpacing: 1,
    textShadowColor: 'rgba(0,0,0,0.9)',
    textShadowRadius: 3,
  },
  amount: {
    fontFamily: DTM_SANS,
    letterSpacing: 0.5,
    textShadowColor: 'rgba(0,0,0,0.9)',
    textShadowRadius: 3,
  },
});
