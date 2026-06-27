import React, { useEffect, useRef, useState } from 'react';
import { Animated } from 'react-native';
import { useSettledLucidity } from '../state/useAnimatedLucidity';
import { COIN_ICON } from '../content/uiAssets';
import { COIN_FLIGHT_MS, COIN_STAGGER_MS } from '../content/timing';

// Regular Lucidity coins. The sequence is: burst OUT of the black cash tray
// first (pop up + scatter), THEN stream up to the goal bar/counter — they don't
// jump straight to the bar. Source-px positions on the 160×320 canvas; the parent
// scales by `f`. Visual only; power coins (every 30L) are handled separately by
// PowerCoinFlow so they can travel to the power they restore.
const TRAY   = { x: 80, y: 290 } as const; // black coin tray, bottom of cabinet
const TARGET = { x: 76, y: 75  } as const; // Lucidity bar centre (objective bar)
const COIN_SRC_SIZE = 11;                  // coin sprite size in source px
const BURST_RISE_SRC = 24;                 // how far coins pop up out of the tray
const BURST_SCATTER_SRC = 26;              // horizontal spread at the burst peak

// Cap the swarm so a huge win never spawns hundreds of sprites; the staggered
// pour still reads as "the total is being counted out".
const MAX_VISIBLE = 8;
const TOTAL_MS    = COIN_FLIGHT_MS;  // per coin: burst + collect (shared with the counter gate)
const BURST_FRAC  = 0.4;             // fraction of the flight spent bursting out of the tray
const STAGGER_MS  = COIN_STAGGER_MS; // gap between coins pouring out

interface Sprite {
  id: number;
  anim: Animated.Value;
  jitter: number; // -0.5..0.5 horizontal spread
}

interface Props {
  // Display px per source px (must match SlotMachine's `f`).
  f: number;
  // Fired when a flying coin reaches the counter, so the bar can shake.
  onArrive?: () => void;
  // Extra hold flag: keeps coins frozen during reroll visual animations.
  hold?: boolean;
}

export function CoinFlow({ f, onArrive, hold = false }: Props) {
  // Settled total: frozen while spinning OR while any visual hold is active
  // (e.g. a power reroll), so coins never launch before the final reel lands.
  const lucidityCoins = useSettledLucidity(hold);
  const prevCoins = useRef(lucidityCoins);
  const idRef = useRef(0);
  const [sprites, setSprites] = useState<Sprite[]>([]);

  useEffect(() => {
    const before = prevCoins.current;
    const after = lucidityCoins;
    prevCoins.current = after;
    if (after <= before) return; // only animate gains (resets/new runs are silent)

    const earned = after - before;
    const count = Math.max(1, Math.min(MAX_VISIBLE, earned));

    const batch: Sprite[] = Array.from({ length: count }, () => ({
      id: idRef.current++,
      anim: new Animated.Value(0),
      jitter: Math.random() - 0.5,
    }));

    setSprites(s => [...s, ...batch]);

    Animated.stagger(
      STAGGER_MS,
      batch.map(sp =>
        Animated.timing(sp.anim, { toValue: 1, duration: TOTAL_MS, useNativeDriver: true }),
      ),
    ).start();

    // onArrive when each coin reaches the bar; drop the batch once all landed.
    batch.forEach((sp, i) => {
      setTimeout(() => onArrive?.(), STAGGER_MS * i + TOTAL_MS);
    });
    const total = STAGGER_MS * (count - 1) + TOTAL_MS + 30;
    setTimeout(() => {
      setSprites(s => s.filter(x => !batch.includes(x)));
    }, total);
  }, [lucidityCoins]); // eslint-disable-line react-hooks/exhaustive-deps

  const size = COIN_SRC_SIZE * f;

  return (
    <>
      {sprites.map(sp => {
        const x0 = TRAY.x * f - size / 2;
        const y0 = TRAY.y * f - size / 2;
        const xBurst = (TRAY.x + sp.jitter * BURST_SCATTER_SRC) * f - size / 2;
        const yBurst = (TRAY.y - BURST_RISE_SRC) * f - size / 2;
        const x1 = TARGET.x * f - size / 2;
        const y1 = TARGET.y * f - size / 2;
        // Phase 1 (0 → BURST_FRAC): pop up + scatter out of the tray.
        // Phase 2 (BURST_FRAC → 1): stream up to the goal bar.
        const translateX = sp.anim.interpolate({
          inputRange: [0, BURST_FRAC, 1],
          outputRange: [x0, xBurst, x1],
        });
        const translateY = sp.anim.interpolate({
          inputRange: [0, BURST_FRAC, 1],
          outputRange: [y0, yBurst, y1],
        });
        const opacity = sp.anim.interpolate({
          inputRange: [0, 0.1, 0.85, 1],
          outputRange: [0, 1, 1, 0],
        });
        return (
          <Animated.Image
            key={sp.id}
            source={COIN_ICON}
            style={{
              position: 'absolute',
              left: 0,
              top: 0,
              width: size,
              height: size,
              opacity,
              transform: [{ translateX }, { translateY }],
            }}
            resizeMode="contain"
            fadeDuration={0}
          />
        );
      })}
    </>
  );
}
