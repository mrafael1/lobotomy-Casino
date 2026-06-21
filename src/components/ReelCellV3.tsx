import React, { useEffect, useRef, useState } from 'react';
import { View, Image } from 'react-native';
import { Symbol } from './Symbol';
import { SYMBOLS_SHEET_V3, SYMBOL_FRAME_COUNT } from '../content/machineAssets';
import type { SymbolId } from '../game/types';

const SYMBOLS_SHEET_NATIVE = Image.resolveAssetSource(SYMBOLS_SHEET_V3);
const SYMBOLS_SHEET_WIDTH = SYMBOLS_SHEET_NATIVE.width;
const SYMBOLS_SHEET_HEIGHT = SYMBOLS_SHEET_NATIVE.height;
const SYMBOL_FRAME_WIDTH = SYMBOLS_SHEET_WIDTH / SYMBOL_FRAME_COUNT;

// Spin-blur cadence and per-reel stop times (ms) — matches the previous reel.
const CYCLE_INTERVAL_MS = 60;
const STOP_TIMES_MS = [600, 850, 1100];

// Visual neighbour order for the landed reel strip (book sits outside it).
const STRIP_ORDER: SymbolId[] = ['brain', 'eye', 'pill', 'syringe', 'scalpel', 'flatline'];

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
  // Display geometry (px).
  machineWidth: number;
  machineHeight: number;
  hole: { left: number; top: number; width: number; height: number };
  symbolSize: number;        // size of the landed sprite
}

// One reel cell for the v3 machine. While spinning it cycles symbols.png, which
// is already authored at the x5 runtime size. On stop it shows the exact
// resolved symbol via its per-symbol sprite — covering all 7 symbols, including
// scalpel/book which the sheet doesn't contain.
export function ReelCellV3({
  finalSymbol,
  spinning,
  locked = false,
  reelIndex,
  onComplete,
  overrideStopMs,
  machineWidth,
  machineHeight,
  hole,
  symbolSize,
}: Props) {
  const adjacentSymbolSize = Math.round(symbolSize * 0.9);
  const landedStripHeight = symbolSize + adjacentSymbolSize * 2;

  // null = show the resolved sprite; number = show that sheet frame (blurring).
  const [blurFrame, setBlurFrame] = useState<number | null>(null);
  const frameRef = useRef(reelIndex); // staggered start so reels look independent
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const stopTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function clearTimers() {
    if (intervalRef.current) clearInterval(intervalRef.current);
    if (stopTimerRef.current) clearTimeout(stopTimerRef.current);
    intervalRef.current = null;
    stopTimerRef.current = null;
  }

  useEffect(() => {
    if (!spinning) {
      clearTimers();
      setBlurFrame(null);
      return;
    }

    // Locked reels keep their symbol — finish immediately, no blur.
    if (locked) {
      setBlurFrame(null);
      onComplete?.();
      return;
    }

    setBlurFrame(frameRef.current % SYMBOL_FRAME_COUNT);
    intervalRef.current = setInterval(() => {
      frameRef.current += 1;
      setBlurFrame(frameRef.current % SYMBOL_FRAME_COUNT);
    }, CYCLE_INTERVAL_MS);

    stopTimerRef.current = setTimeout(() => {
      clearTimers();
      setBlurFrame(null);
      onComplete?.();
    }, overrideStopMs ?? STOP_TIMES_MS[reelIndex]);

    return clearTimers;
  }, [spinning, finalSymbol, reelIndex, locked, overrideStopMs]);

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
      {blurFrame === null ? (
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
        // Full-canvas x5 sheet, shifted so frame `blurFrame` lands at canvas
        // origin. The cell's hole offset is already in x5 display pixels.
        <Image
          source={SYMBOLS_SHEET_V3}
          fadeDuration={0}
          style={{
            position: 'absolute',
            width: SYMBOLS_SHEET_WIDTH,
            height: SYMBOLS_SHEET_HEIGHT,
            left: -hole.left - blurFrame * SYMBOL_FRAME_WIDTH,
            top: -hole.top,
          }}
        />
      )}
    </View>
  );
}
