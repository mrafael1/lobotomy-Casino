import React, { useEffect, useRef, useState } from 'react';
import { Animated } from 'react-native';
import { useRunStore } from '../state/runState';
import { POWER_COIN_ICON } from '../content/uiAssets';
import { POWER_HITS } from '../content/machineAssets';
import type { AbilityId } from '../game/types';

// Power coin: at each 30L threshold runState ALREADY restored one spent power and
// queued it in pendingPowerRestores purely as a visual cue. This plays that cue: a
// power_coin pops out of the tray, flies to the (already-restored) power's button,
// then pulses it. It waits for the reels to stop (isSpinning) and handles the queue
// one coin at a time, so multiple crossed thresholds animate sequentially. This
// component owns NO gameplay state — if it never runs, the restore still stands.
const TRAY = { x: 80, y: 290 } as const; // black coin tray, bottom of cabinet
const COIN_SRC_SIZE = 13;
const FLIGHT_MS = 640;
const FLASH_MS = 360;

// AbilityId → POWER_HITS key (memory uses the lock art/position).
const POWER_HIT_KEY: Record<AbilityId, keyof typeof POWER_HITS> = {
  reroll: 'reroll',
  shift:  'shift',
  memory: 'lock',
};

function powerCenter(power: AbilityId): { cx: number; cy: number } {
  const hit = POWER_HITS[POWER_HIT_KEY[power]];
  return { cx: hit.left + hit.width / 2, cy: hit.top + hit.height / 2 };
}

interface Props {
  f: number; // display px per source px (must match SlotMachine's `f`)
  // Extra hold flag: keeps the power-coin animation frozen during reroll visuals.
  hold?: boolean;
}

export function PowerCoinFlow({ f, hold = false }: Props) {
  const queue = useRunStore(s => s.pendingPowerRestores);
  const isSpinning = useRunStore(s => s.isSpinning);
  const commitPowerRestore = useRunStore(s => s.commitPowerRestore);

  const [active, setActive] = useState<AbilityId | null>(null);
  const [flashPower, setFlashPower] = useState<AbilityId | null>(null);
  const fly = useRef(new Animated.Value(0)).current;
  const flash = useRef(new Animated.Value(0)).current;

  // Start the next coin once reels have stopped and no visual hold is active.
  useEffect(() => {
    if (active !== null || isSpinning || hold || queue.length === 0) return;
    const power = queue[0];
    setActive(power);
    fly.setValue(0);
    Animated.timing(fly, { toValue: 1, duration: FLIGHT_MS, useNativeDriver: true }).start(({ finished }) => {
      // The restore already happened at the Lucidity gain; this coin is feedback
      // only. Clear it from the visual queue (whether or not the flight finished)
      // so the next queued coin can play and the queue never stalls.
      commitPowerRestore(power);
      setActive(null);
      if (!finished) return; // interrupted (unmount/reset) → skip the pulse
      // Coin reached the power → pulse the button.
      setFlashPower(power);
      flash.setValue(0);
      Animated.sequence([
        Animated.timing(flash, { toValue: 1, duration: 90, useNativeDriver: true }),
        Animated.timing(flash, { toValue: 0, duration: FLASH_MS - 90, useNativeDriver: true }),
      ]).start(() => setFlashPower(null));
    });
  }, [active, isSpinning, hold, queue, commitPowerRestore, fly, flash]);

  const size = COIN_SRC_SIZE * f;

  return (
    <>
      {active !== null && (() => {
        const { cx, cy } = powerCenter(active);
        const x0 = TRAY.x * f - size / 2;
        const y0 = TRAY.y * f - size / 2;
        const x1 = cx * f - size / 2;
        const y1 = cy * f - size / 2;
        const translateX = fly.interpolate({ inputRange: [0, 1], outputRange: [x0, x1] });
        const translateY = fly.interpolate({ inputRange: [0, 0.35, 1], outputRange: [y0, y0 - 26 * f, y1] });
        const scale = fly.interpolate({ inputRange: [0, 0.18, 1], outputRange: [0.4, 1.15, 0.9] });
        const opacity = fly.interpolate({ inputRange: [0, 0.12, 0.9, 1], outputRange: [0, 1, 1, 0] });
        return (
          <Animated.Image
            source={POWER_COIN_ICON}
            style={{
              position: 'absolute',
              left: 0,
              top: 0,
              width: size,
              height: size,
              opacity,
              transform: [{ translateX }, { translateY }, { scale }],
            }}
            resizeMode="contain"
            fadeDuration={0}
          />
        );
      })()}

      {/* Restore feedback: a quick glow pulse on the power that was just restored. */}
      {flashPower !== null && (() => {
        const { cx, cy } = powerCenter(flashPower);
        const ringSize = 22 * f;
        return (
          <Animated.View
            pointerEvents="none"
            style={{
              position: 'absolute',
              left: cx * f - ringSize / 2,
              top: cy * f - ringSize / 2,
              width: ringSize,
              height: ringSize,
              borderRadius: ringSize / 2,
              borderWidth: Math.max(1, 1.5 * f),
              borderColor: '#fde047',
              opacity: flash,
              transform: [{ scale: flash.interpolate({ inputRange: [0, 1], outputRange: [0.6, 1.3] }) }],
            }}
          />
        );
      })()}
    </>
  );
}
