import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { SymbolCanvas, SYMBOL_SIZE } from './SymbolCanvas';
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
  reelIndex: 0 | 1 | 2;
  onComplete?: () => void;
  size?: number;
}

export function Reel({ finalSymbol, spinning, reelIndex, onComplete, size = SYMBOL_SIZE }: Props) {
  // midIndex is the index in CYCLE_ORDER for the main (result) row
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
    }, STOP_TIMES_MS[reelIndex]);

    return clearTimers;
  }, [spinning, finalSymbol, reelIndex]);

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
          <SymbolCanvas symbol={sym} size={size} />
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
