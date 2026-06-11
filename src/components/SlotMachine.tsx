import React, { useEffect, useRef, useState } from 'react';
import { View, Image, Pressable, Text, StyleSheet, useWindowDimensions } from 'react-native';
import { Reel } from './Reel';
import { SYMBOL_SIZE } from './SymbolCanvas';
import { useRunStore } from '../state/runState';
import type { SymbolId } from '../game/types';

// Machine PNG aspect ratio (height / width). Measured from provided assets.
const MACHINE_ASPECT = 1.337;

// Reel window position as fractions of the machine image dimensions.
// Tune these if the overlay drifts on the actual assets.
const WIN_TOP   = 0.162;
const WIN_LEFT  = 0.125;
const WIN_W     = 0.750;
const WIN_H     = 0.380;

const FALLBACK_SYMBOL: SymbolId = 'brain';

interface Props {
  onAllReelsDone: () => void;
  // When set, reels are tappable (ability/lock targeting) and highlight on press.
  onReelPress?: (reelIndex: number) => void;
  selectedReels?: ReadonlyArray<number>;
}

export function SlotMachine({ onAllReelsDone, onReelPress, selectedReels = [] }: Props) {
  const { width: screenWidth } = useWindowDimensions();

  const isSpinning  = useRunStore(s => s.isSpinning);
  const lastResult  = useRunStore(s => s.lastResult);
  const lockedReels = useRunStore(s => s.lockedReels);
  const neurons     = useRunStore(s => s.neurons);
  const startingN   = useRunStore(s => s.startingNeurons);
  const runPhase    = useRunStore(s => s.runPhase);

  // Jackpot flash
  const [jackpotFlash, setJackpotFlash] = useState(false);
  const flashTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (lastResult?.isJackpot && !isSpinning) {
      setJackpotFlash(true);
      flashTimer.current = setTimeout(() => setJackpotFlash(false), 1800);
    }
    return () => { if (flashTimer.current) clearTimeout(flashTimer.current); };
  }, [lastResult, isSpinning]);

  const machineWidth  = screenWidth * 0.9;
  const machineHeight = machineWidth * MACHINE_ASPECT;
  // Symbol fits into one of 3 rows within the reel window
  const symbolSize    = Math.min(
    Math.floor((machineWidth * WIN_W) / 3) - 4,
    Math.floor((machineHeight * WIN_H) / 3) - 2,
    SYMBOL_SIZE,
  );

  const neuronRatio = startingN > 0 ? neurons / startingN : 0;
  const isDecay     = neuronRatio <= 0.5 && runPhase === 'running';
  const machineImg  = jackpotFlash
    ? require('../../assets/images/machine_jackpot.png')
    : isDecay
      ? require('../../assets/images/machine_decay.png')
      : require('../../assets/images/machine_normal.png');

  const reels: [SymbolId, SymbolId, SymbolId] = lastResult
    ? lastResult.reels
    : [FALLBACK_SYMBOL, FALLBACK_SYMBOL, FALLBACK_SYMBOL];

  const completedRef = useRef(0);

  function handleReelComplete() {
    completedRef.current += 1;
    if (completedRef.current === 3) {
      completedRef.current = 0;
      onAllReelsDone();
    }
  }

  // Reset completed counter when a new spin starts.
  // Locked reels fire onComplete immediately without animating, so pre-count them.
  useEffect(() => {
    if (isSpinning) {
      completedRef.current = lockedReels.filter(Boolean).length;
    }
  }, [isSpinning]);

  // Reel window absolute coords over the machine image
  const winTop  = machineHeight * WIN_TOP;
  const winLeft = machineWidth  * WIN_LEFT;
  const winW    = machineWidth  * WIN_W;
  const winH    = machineHeight * WIN_H;

  return (
    <View style={[styles.machine, { width: machineWidth, height: machineHeight }]}>
      <Image source={machineImg} style={styles.machineImg} resizeMode="contain" />

      {/* Reels overlay */}
      <View
        style={[
          styles.reelWindow,
          { top: winTop, left: winLeft, width: winW, height: winH },
        ]}
      >
        {([0, 1, 2] as const).map(i => (
          <Pressable
            key={i}
            style={[
              styles.reelSlot,
              { width: winW / 3, height: symbolSize * 3 },
              selectedReels.includes(i) && styles.reelSelected,
            ]}
            onPress={onReelPress ? () => onReelPress(i) : undefined}
            disabled={!onReelPress || isSpinning}
          >
            <Reel
              finalSymbol={reels[i]}
              spinning={isSpinning}
              locked={lockedReels[i]}
              reelIndex={i}
              onComplete={handleReelComplete}
              size={symbolSize}
            />
            {lockedReels[i] && <Text style={styles.lockBadge}>LOCKED</Text>}
          </Pressable>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  machine: {
    position: 'relative',
  },
  machineImg: {
    width: '100%',
    height: '100%',
  },
  reelWindow: {
    position: 'absolute',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-evenly',
  },
  reelSlot: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  reelSelected: {
    borderWidth: 2,
    borderColor: '#00e5ff',
    borderRadius: 8,
  },
  lockBadge: {
    position: 'absolute',
    bottom: 2,
    color: '#fbbf24',
    fontSize: 8,
    fontWeight: '900',
    letterSpacing: 1,
  },
});
