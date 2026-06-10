import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { SymbolCanvas, SYMBOL_SIZE } from './SymbolCanvas';
import type { SymbolId } from '../game/types';

const CYCLE_ORDER: SymbolId[] = ['brain', 'eye', 'pill', 'syringe', 'scalpel', 'flatline'];
const CYCLE_INTERVAL_MS = 70;

// Stop times produce the cascade effect: left reel stops first, right last.
const STOP_TIMES_MS = [600, 850, 1100];

interface Props {
  finalSymbol: SymbolId;
  spinning: boolean;
  reelIndex: 0 | 1 | 2;
  onComplete?: () => void;
  size?: number;
}

export function Reel({ finalSymbol, spinning, reelIndex, onComplete, size = SYMBOL_SIZE }: Props) {
  const [displaySymbol, setDisplaySymbol] = useState<SymbolId>(CYCLE_ORDER[reelIndex]);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const stopTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const cycleIndexRef = useRef<number>(reelIndex); // start each reel at a different offset

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

    // Start cycling
    intervalRef.current = setInterval(() => {
      cycleIndexRef.current = (cycleIndexRef.current + 1) % CYCLE_ORDER.length;
      setDisplaySymbol(CYCLE_ORDER[cycleIndexRef.current]);
    }, CYCLE_INTERVAL_MS);

    // Stop after reel-specific duration and snap to result
    stopTimerRef.current = setTimeout(() => {
      clearTimers();
      setDisplaySymbol(finalSymbol);
      onComplete?.();
    }, STOP_TIMES_MS[reelIndex]);

    return clearTimers;
  }, [spinning, finalSymbol, reelIndex]);

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      <SymbolCanvas symbol={displaySymbol} size={size} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
  },
});
