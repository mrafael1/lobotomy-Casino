import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { Symbol, SYMBOL_SIZE } from './Symbol';
import type { SymbolId } from '../game/types';

const CYCLE_ORDER: SymbolId[] = ['brain', 'eye', 'pill', 'syringe', 'scalpel', 'flatline'];
const CYCLE_INTERVAL_MS = 70;
const STOP_TIMES_MS = [600, 850, 1100];

function cycleAt(index: number): SymbolId {
  return CYCLE_ORDER[((index % CYCLE_ORDER.length) + CYCLE_ORDER.length) % CYCLE_ORDER.length];
}

interface Props {
  finalSymbol: SymbolId;
  spinning: boolean;
  locked?: boolean;     // if true, skip animation and signal done immediately
  reelIndex: 0 | 1 | 2;
  onComplete?: () => void;
  size?: number;
  overrideStopMs?: number; // when set, used instead of STOP_TIMES_MS[reelIndex]
}

export function Reel({ finalSymbol, spinning, locked = false, reelIndex, onComplete, size = SYMBOL_SIZE, overrideStopMs }: Props) {
  const midIndexRef = useRef<number>(reelIndex);
  const [symbols, setSymbols] = useState<[SymbolId, SymbolId, SymbolId]>(() => [
    cycleAt(reelIndex - 1),
    cycleAt(reelIndex),
    cycleAt(reelIndex + 1),
  ]);

  const intervalRef  = useRef<ReturnType<typeof setInterval> | null>(null);
  const stopTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function clearTimers() {
    if (intervalRef.current)  clearInterval(intervalRef.current);
    if (stopTimerRef.current) clearTimeout(stopTimerRef.current);
    intervalRef.current  = null;
    stopTimerRef.current = null;
  }

  useEffect(() => {
    if (!spinning) {
      clearTimers();
      // Sync to finalSymbol so ability results (SHIFT/SWAP) are reflected immediately.
      const finalIdx = CYCLE_ORDER.indexOf(finalSymbol);
      midIndexRef.current = finalIdx;
      setSymbols([cycleAt(finalIdx - 1), finalSymbol, cycleAt(finalIdx + 1)]);
      return;
    }

    // Locked reels hold position — signal completion without animating.
    if (locked) {
      onComplete?.();
      return;
    }

    intervalRef.current = setInterval(() => {
      midIndexRef.current += 1;
      const mid = midIndexRef.current;
      setSymbols([cycleAt(mid - 1), cycleAt(mid), cycleAt(mid + 1)]);
    }, CYCLE_INTERVAL_MS);

    stopTimerRef.current = setTimeout(() => {
      clearTimers();
      const finalIdx = CYCLE_ORDER.indexOf(finalSymbol);
      midIndexRef.current = finalIdx;
      setSymbols([cycleAt(finalIdx - 1), finalSymbol, cycleAt(finalIdx + 1)]);
      onComplete?.();
    }, overrideStopMs ?? STOP_TIMES_MS[reelIndex]);

    return clearTimers;
  }, [spinning, finalSymbol, reelIndex, locked, overrideStopMs]);

  return (
    <View style={[styles.column, { width: size }]}>
      {symbols.map((sym, row) => (
        <View
          key={row}
          style={[
            styles.row,
            { width: size, height: size },
            row === 1 && styles.mainRow,
          ]}
        >
          <Symbol symbol={sym} size={size} />
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  column: {
    flexDirection: 'column',
    overflow: 'hidden',
  },
  row: {
    alignItems: 'center',
    justifyContent: 'center',
    opacity: 0.45,
  },
  mainRow: {
    opacity: 1,
  },
});
