import React, { useEffect, useRef, useState } from 'react';
import { View, Image } from 'react-native';
import { Symbol } from './Symbol';
import { SYMBOLS_SHEET_V3, SYMBOL_FRAME_COUNT } from '../content/machineAssets';
import type { SymbolId } from '../game/types';

// Spin-blur cadence and per-reel stop times (ms) — matches the previous reel.
const CYCLE_INTERVAL_MS = 60;
const STOP_TIMES_MS = [600, 850, 1100];

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

// One reel cell for the v3 machine. While spinning it cycles the 5-frame
// symbols.png sheet (authored on the machine's own canvas, so clipping the cell
// to its hole shows the symbol in place) for a smooth blur. On stop it shows the
// exact resolved symbol via its per-symbol sprite — covering all 7 symbols,
// including scalpel/book which the sheet doesn't contain.
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
        <Symbol symbol={finalSymbol} size={symbolSize} tile={false} />
      ) : (
        // Full-canvas sheet, shifted so frame `blurFrame` lands at canvas origin
        // and the cell's hole offset is subtracted — the clip shows just this cell.
        <Image
          source={SYMBOLS_SHEET_V3}
          fadeDuration={0}
          resizeMode="stretch"
          style={{
            position: 'absolute',
            width: machineWidth * SYMBOL_FRAME_COUNT,
            height: machineHeight,
            left: -hole.left - blurFrame * machineWidth,
            top: -hole.top,
          }}
        />
      )}
    </View>
  );
}
