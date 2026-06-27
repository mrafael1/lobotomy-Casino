import React, { useEffect, useRef, useState } from 'react';
import { View, Image, Animated, Easing } from 'react-native';
import { Symbol } from './Symbol';
import { SYMBOLS_SHEET_V3, SYMBOL_FRAME_COUNT } from '../content/machineAssets';
import { BASE_SYMBOL_CYCLE } from '../content/symbols';
import { DEBUG_SPIN_ANIM } from '../perf/useRenderCount';
import type { SymbolId } from '../game/types';

const SYMBOLS_SHEET_NATIVE = Image.resolveAssetSource(SYMBOLS_SHEET_V3);
const SYMBOLS_SHEET_WIDTH = SYMBOLS_SHEET_NATIVE.width;
const SYMBOLS_SHEET_HEIGHT = SYMBOLS_SHEET_NATIVE.height;
const SYMBOL_FRAME_WIDTH = SYMBOLS_SHEET_WIDTH / SYMBOL_FRAME_COUNT;

// Spin-blur cadence and per-reel stop times (ms) — matches the previous reel.
const CYCLE_INTERVAL_MS = 60;
const STOP_TIMES_MS = [650, 950, 1300];

// The blur is a DISCRETE flipbook — one full-canvas frame shown at a time, then a
// hard snap to the next. A continuous translateX scroll (the previous approach)
// slides two adjacent frames through the narrow reel window at once, which reads
// as doubled / ghosted "multiple" symbols. This staircase holds each frame for
// its whole 60ms step then snaps, and is driven natively (no per-frame re-render):
// a single driver value sweeps 0→SYMBOL_FRAME_COUNT and maps to stepped offsets.
const SPIN_STEP_INPUT: number[] = [];
const SPIN_STEP_OUTPUT: number[] = [];
for (let k = 0; k < SYMBOL_FRAME_COUNT; k++) {
  SPIN_STEP_INPUT.push(k, k + 0.999);
  SPIN_STEP_OUTPUT.push(-k * SYMBOL_FRAME_WIDTH, -k * SYMBOL_FRAME_WIDTH);
}
SPIN_STEP_INPUT.push(SYMBOL_FRAME_COUNT);
SPIN_STEP_OUTPUT.push(-(SYMBOL_FRAME_COUNT - 1) * SYMBOL_FRAME_WIDTH);

// Visual neighbour order for the landed reel strip (book sits outside it) —
// shares the canonical base-symbol cycle so reel visuals match SHIFT/ability logic.
const STRIP_ORDER = BASE_SYMBOL_CYCLE;

function neighbours(sym: SymbolId): { top: SymbolId; bottom: SymbolId } {
  const i = STRIP_ORDER.indexOf(sym);
  const n = STRIP_ORDER.length;
  if (i < 0) return { top: STRIP_ORDER[n - 1], bottom: STRIP_ORDER[0] };
  return { top: STRIP_ORDER[(i - 1 + n) % n], bottom: STRIP_ORDER[(i + 1) % n] };
}

interface Props {
  finalSymbol: SymbolId;
  spinning: boolean;
  locked?: boolean;          // locked reels hold position and finish instantly
  reelIndex: 0 | 1 | 2;
  onComplete?: () => void;
  overrideStopMs?: number;   // single-reel reroll uses its own stop time
  extraStopMs?: number;      // added to the stop time (e.g. 3rd-reel pair tension)
  // Display geometry (px).
  machineWidth: number;
  machineHeight: number;
  hole: { left: number; top: number; width: number; height: number };
  symbolSize: number;        // size of the landed sprite
}

// One reel cell for the v3 machine. While spinning it cycles symbols.png, which
// is already authored at the x5 runtime size. On stop it shows the exact
// resolved symbol via its per-symbol sprite — covering all 7 symbols, including
// vial/book which the sheet doesn't contain.
export function ReelCellV3({
  finalSymbol,
  spinning,
  locked = false,
  reelIndex,
  onComplete,
  overrideStopMs,
  extraStopMs = 0,
  machineWidth,
  machineHeight,
  hole,
  symbolSize,
}: Props) {
  const adjacentSymbolSize = Math.round(symbolSize * 0.9);
  const landedStripHeight = symbolSize + adjacentSymbolSize * 2;

  // false = show the resolved sprite; true = animate the spin-blur sheet natively.
  const [blurActive, setBlurActive] = useState(false);
  const spinX = useRef(new Animated.Value(0)).current;
  const spinLoopRef = useRef<Animated.CompositeAnimation | null>(null);
  const stopTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Single-owner guard: each spin start bumps this; a stop callback only acts if
  // it still owns the reel, so a previous spin's late timer can never finish a
  // newer spin.
  const animIdRef = useRef(0);

  function clearTimers() {
    spinLoopRef.current?.stop();
    if (stopTimerRef.current) clearTimeout(stopTimerRef.current);
    spinLoopRef.current = null;
    stopTimerRef.current = null;
  }

  useEffect(() => {
    if (!spinning) {
      animIdRef.current++; // invalidate any pending stop from the spin that ended
      clearTimers();
      setBlurActive(false);
      return;
    }

    // Locked reels keep their symbol — finish immediately, no blur.
    if (locked) {
      setBlurActive(false);
      onComplete?.();
      return;
    }

    // New spin owns this reel — cancel anything still running, then start once.
    const animId = ++animIdRef.current;
    clearTimers();
    if (__DEV__ && DEBUG_SPIN_ANIM) console.log('[SPIN_ANIM] start', animId, 'reel', reelIndex);

    spinX.setValue(0);
    setBlurActive(true);
    spinLoopRef.current = Animated.loop(
      Animated.timing(spinX, {
        toValue: SYMBOL_FRAME_COUNT,
        duration: CYCLE_INTERVAL_MS * SYMBOL_FRAME_COUNT,
        easing: Easing.linear,
        useNativeDriver: true,
      }),
    );
    spinLoopRef.current.start();

    stopTimerRef.current = setTimeout(() => {
      if (animId !== animIdRef.current) return; // a newer spin owns this reel now
      if (__DEV__ && DEBUG_SPIN_ANIM) console.log('[REEL] stop', reelIndex, animId);
      clearTimers();
      setBlurActive(false);
      onComplete?.();
    }, (overrideStopMs ?? STOP_TIMES_MS[reelIndex]) + extraStopMs);

    return clearTimers;
  }, [spinning, finalSymbol, reelIndex, locked, overrideStopMs, extraStopMs]);

  return (
    <View
      style={{
        position: 'absolute',
        left: hole.left,
        top: hole.top,
        width: hole.width,
        height: hole.height,
        overflow: 'hidden',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {!blurActive ? (
        // Landed reel strip: centre = result (full), neighbours peek above/below
        // and are clipped by the hole so only an edge of each shows.
        <View style={{ height: landedStripHeight, alignItems: 'center', justifyContent: 'center' }}>
          <View style={{ opacity: 0.5 }}>
            <Symbol symbol={neighbours(finalSymbol).top} size={adjacentSymbolSize} tile={false} />
          </View>
          <Symbol symbol={finalSymbol} size={symbolSize} tile={false} />
          <View style={{ opacity: 0.5 }}>
            <Symbol symbol={neighbours(finalSymbol).bottom} size={adjacentSymbolSize} tile={false} />
          </View>
        </View>
      ) : (
        // Full-canvas x5 sheet, shifted natively across its blur frames. The
        // cell's hole offset is already in x5 display pixels.
        <Animated.Image
          source={SYMBOLS_SHEET_V3}
          fadeDuration={0}
          style={{
            position: 'absolute',
            width: SYMBOLS_SHEET_WIDTH,
            height: SYMBOLS_SHEET_HEIGHT,
            left: -hole.left,
            top: -hole.top,
            transform: [{
              translateX: spinX.interpolate({
                inputRange: SPIN_STEP_INPUT,
                outputRange: SPIN_STEP_OUTPUT,
              }),
            }],
          }}
        />
      )}
    </View>
  );
}
