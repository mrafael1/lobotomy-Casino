import React, { useEffect, useRef, useState } from 'react';
import { View, Image, Pressable, Text, StyleSheet, useWindowDimensions } from 'react-native';
import { Reel } from './Reel';
import { SYMBOL_SIZE } from './SymbolCanvas';
import { MOVE_ORDER } from '../game/abilities';
import { SYMBOLS } from '../content/symbols';
import { useRunStore } from '../state/runState';
import type { SymbolId } from '../game/types';

// Runtime PNG is a 3x nearest-neighbor upscale of the 200x300 source art.
const MACHINE_ASPECT = 900 / 600;

// Exact reel window from the Aseprite source:
// x=25, y=82, width=150, height=100 on a 200x300 cabinet.
const WIN_TOP   = 82 / 300;
const WIN_LEFT  = 25 / 200;
const WIN_W     = 150 / 200;
const WIN_H     = 100 / 300;

// Multiplier panel: transparent overlays baked by the asset pipeline
// (scripts/generate-machine-overlays.js -> compose-runtime-assets.js).
// One PNG per bet state; the app swaps the source by betMultiplier.
const MULTIPLIER_PNGS: Record<1 | 2 | 3, number> = {
  1: require('../../assets/images/machine_multiplier_x1.png'),
  2: require('../../assets/images/machine_multiplier_x2.png'),
  3: require('../../assets/images/machine_multiplier_x3.png'),
};

// Tap targets over the three on-machine multiplier slots, as fractions of the
// cabinet. These mirror the slot geometry in generate-machine-overlays.js
// (panel x=33..167, y=190..246; slots width 39 at x=37/80/123, y=196..240).
const MULT_SLOT_TOP = 196 / 300;
const MULT_SLOT_H   = 44 / 300;
const MULT_SLOTS: ReadonlyArray<{ left: number; width: number }> = [
  { left: 37 / 200,  width: 39 / 200 },
  { left: 80 / 200,  width: 39 / 200 },
  { left: 123 / 200, width: 39 / 200 },
];

const FALLBACK_SYMBOL: SymbolId = 'brain';

interface Props {
  onAllReelsDone: () => void;
  // When set, reels are tappable (ability/lock targeting) and highlight on press.
  onReelPress?: (reelIndex: number) => void;
  selectedReels?: ReadonlyArray<number>;
  // When set, renders ▲/▼ shift buttons above/below that reel column.
  shiftTargetReel?: number | null;
  onShiftDirection?: (direction: -1 | 1) => void;
  // Single-reel reroll animation: spins only that reel, fires when done.
  rerollingReelIndex?: number | null;
  onRerollDone?: () => void;
  // Bet multiplier selection via the on-machine panel (replaces the old buttons).
  onSelectMultiplier?: (m: 1 | 2 | 3) => void;
  isMultiplierLocked?: (m: 1 | 2 | 3) => boolean;
  multiplierInteractive?: boolean;
}

export function SlotMachine({
  onAllReelsDone,
  onReelPress,
  selectedReels = [],
  shiftTargetReel,
  onShiftDirection,
  rerollingReelIndex = null,
  onRerollDone,
  onSelectMultiplier,
  isMultiplierLocked,
  multiplierInteractive = false,
}: Props) {
  const { width: screenWidth, height: screenHeight } = useWindowDimensions();

  const isSpinning    = useRunStore(s => s.isSpinning);
  const lastResult    = useRunStore(s => s.lastResult);
  const lockedReels   = useRunStore(s => s.lockedReels);
  const neurons       = useRunStore(s => s.neurons);
  const startingN     = useRunStore(s => s.startingNeurons);
  const runPhase      = useRunStore(s => s.runPhase);
  const betMultiplier = useRunStore(s => s.betMultiplier) as 1 | 2 | 3;

  // Jackpot flash
  const [jackpotFlash, setJackpotFlash] = useState(false);
  const flashTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Waits for the reroll animation too — a power-made jackpot should flash
  // when the reel lands, not while it is still spinning.
  useEffect(() => {
    if (lastResult?.isJackpot && !isSpinning && rerollingReelIndex === null) {
      setJackpotFlash(true);
      flashTimer.current = setTimeout(() => setJackpotFlash(false), 1800);
    }
    return () => { if (flashTimer.current) clearTimeout(flashTimer.current); };
  }, [lastResult, isSpinning, rerollingReelIndex]);

  const machineWidth  = Math.floor(Math.min(
    screenWidth * 0.9,
    (screenHeight * 0.56) / MACHINE_ASPECT,
  ));
  const machineHeight = machineWidth * MACHINE_ASPECT;
  const symbolSize    = Math.min(
    Math.floor((machineWidth * WIN_W) / 3) - 4,
    Math.floor((machineHeight * WIN_H) / 3) - 2,
    SYMBOL_SIZE,
  );

  const neuronRatio = startingN > 0 ? neurons / startingN : 1;
  const decayOpacity = runPhase === 'running'
    ? Math.pow(Math.max(0, Math.min(1, 1 - neuronRatio)), 0.7)
    : 0;

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

  // Reset completed counter when a new spin starts. Locked reels fire their
  // onComplete before this effect runs (child effects before parent), so
  // pre-seed with the number of locked reels to avoid a missed completion.
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
  const reelW   = winW / 3;

  const lockedReelSpinsRemaining = useRunStore(s => s.lockedReelSpinsRemaining);

  // Adjacent symbols for the shift buttons.
  // Book is not in MOVE_ORDER — clamp to 0 (brain's position), matching applyMoveColumn,
  // so the direction buttons still appear even when the reel shows a book.
  const shiftCurrentSym =
    shiftTargetReel != null ? reels[shiftTargetReel] : null;
  const rawShiftIdx = shiftCurrentSym ? MOVE_ORDER.indexOf(shiftCurrentSym) : -1;
  const shiftIdx = rawShiftIdx < 0 && shiftCurrentSym !== null ? 0 : rawShiftIdx;
  const shiftUpSym   = shiftIdx >= 0
    ? MOVE_ORDER[(shiftIdx - 1 + MOVE_ORDER.length) % MOVE_ORDER.length]
    : null;
  const shiftDownSym = shiftIdx >= 0
    ? MOVE_ORDER[(shiftIdx + 1) % MOVE_ORDER.length]
    : null;

  return (
    <View style={[styles.machine, { width: machineWidth, height: machineHeight }]}>
      <Image
        source={require('../../assets/images/machine_normal.png')}
        style={styles.machineImg}
        resizeMode="contain"
      />
      <Image
        source={require('../../assets/images/machine_decay.png')}
        style={[styles.machineImg, styles.machineOverlay, { opacity: decayOpacity }]}
        resizeMode="contain"
      />
      {/* Multiplier panel — drawn on top of decay so the active bet stays
          readable; under the jackpot flash. */}
      <Image
        source={MULTIPLIER_PNGS[betMultiplier]}
        style={[styles.machineImg, styles.machineOverlay]}
        resizeMode="contain"
      />
      {jackpotFlash && (
        <Image
          source={require('../../assets/images/machine_jackpot.png')}
          style={[styles.machineImg, styles.machineOverlay]}
          resizeMode="contain"
        />
      )}

      {/* Tappable multiplier slots over the on-machine panel */}
      {multiplierInteractive && onSelectMultiplier &&
        ([1, 2, 3] as const).map((m, i) => (
          <Pressable
            key={m}
            style={{
              position: 'absolute',
              top:    machineHeight * MULT_SLOT_TOP,
              left:   machineWidth  * MULT_SLOTS[i].left,
              width:  machineWidth  * MULT_SLOTS[i].width,
              height: machineHeight * MULT_SLOT_H,
            }}
            onPress={() => onSelectMultiplier(m)}
            disabled={isMultiplierLocked ? isMultiplierLocked(m) : false}
          />
        ))}

      {/* Reels overlay */}
      <View
        style={[
          styles.reelWindow,
          { top: winTop, left: winLeft, width: winW, height: winH },
        ]}
      >
        {([0, 1, 2] as const).map(i => {
          const isRerolling = rerollingReelIndex === i;
          return (
            <Pressable
              key={i}
              style={[
                styles.reelSlot,
                { width: reelW, height: symbolSize * 3 },
                selectedReels.includes(i) && styles.reelSelected,
              ]}
              onPress={onReelPress ? () => onReelPress(i) : undefined}
              disabled={!onReelPress || isSpinning || rerollingReelIndex !== null}
            >
              <Reel
                finalSymbol={reels[i]}
                spinning={isSpinning || isRerolling}
                locked={lockedReels[i]}
                reelIndex={i}
                onComplete={isRerolling ? onRerollDone : handleReelComplete}
                overrideStopMs={isRerolling ? 600 : undefined}
                size={symbolSize}
              />
              {lockedReels[i] && (
                <Text style={styles.lockBadge}>
                  LOCK {lockedReelSpinsRemaining}
                </Text>
              )}
            </Pressable>
          );
        })}
      </View>

      {/* Shift direction buttons — above and below the selected reel column */}
      {shiftTargetReel != null && onShiftDirection && shiftUpSym && shiftDownSym && (
        <>
          <Pressable
            style={[
              styles.shiftBtn,
              styles.shiftBtnTop,
              {
                left: winLeft + reelW * shiftTargetReel,
                width: reelW,
                top: 0,
                height: winTop - 4,
              },
            ]}
            onPress={() => onShiftDirection(1)}
          >
            <Text style={styles.shiftSymbolLabel}>
              {SYMBOLS[shiftDownSym].name.toUpperCase()}
            </Text>
            <Text style={styles.shiftArrow}>▲</Text>
          </Pressable>

          <Pressable
            style={[
              styles.shiftBtn,
              styles.shiftBtnBottom,
              {
                left: winLeft + reelW * shiftTargetReel,
                width: reelW,
                top: winTop + winH + 4,
                bottom: 0,
              },
            ]}
            onPress={() => onShiftDirection(-1)}
          >
            <Text style={styles.shiftArrow}>▼</Text>
            <Text style={styles.shiftSymbolLabel}>
              {SYMBOLS[shiftUpSym].name.toUpperCase()}
            </Text>
          </Pressable>
        </>
      )}
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
  machineOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
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
  shiftBtn: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,229,255,0.12)',
    borderColor: 'rgba(0,229,255,0.45)',
    borderWidth: 1,
  },
  shiftBtnTop: {
    borderRadius: 8,
    justifyContent: 'flex-end',
    paddingBottom: 4,
  },
  shiftBtnBottom: {
    borderRadius: 8,
    justifyContent: 'flex-start',
    paddingTop: 4,
  },
  shiftArrow: {
    color: '#00e5ff',
    fontSize: 18,
    fontWeight: '900',
    lineHeight: 20,
  },
  shiftSymbolLabel: {
    color: '#00e5ff',
    fontSize: 8,
    fontWeight: '800',
    letterSpacing: 1,
    opacity: 0.85,
  },
});
