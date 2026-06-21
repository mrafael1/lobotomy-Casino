import React, { useEffect, useRef, useState } from 'react';
import { View, Image, Pressable, Text, Animated, StyleSheet, useWindowDimensions } from 'react-native';
import { Reel } from './Reel';
import { SpriteSheetFrame } from './SpriteSheetFrame';
import { MachineScreenMeters } from './MachineScreenMeters';
import { MOVE_ORDER } from '../game/abilities';
import { SYMBOLS } from '../content/symbols';
import { useRunStore } from '../state/runState';
import type { SymbolId } from '../game/types';
import {
  MACHINE_V3, REEL_BG_V3, MULTIPLIER_V3, LEVER_V3, JACKPOT_V3,
  MACHINE_SRC_W, MACHINE_ASPECT,
  REEL_WINDOW, REEL_CELL_CENTERS, REEL_CELL_WIDTH, TV_SCREEN,
  MULT_STRIP, MULT_BADGE_CENTERS, LEVER_HIT,
  LEVER_FRAME_COUNT, MULTIPLIER_FRAME_COUNT, JACKPOT_FRAME_COUNT,
} from '../content/machineAssets';

const FALLBACK_SYMBOL: SymbolId = 'brain';

// Lever pull plays frames 0 → 5 quickly, fires the spin, then snaps back to idle.
const LEVER_FRAME_MS = 42;

// Centre y of the reel holes (source px).
const HOLE_CENTER_Y = REEL_WINDOW.top + REEL_WINDOW.height / 2;

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
  // Bet multiplier selection via the on-machine top-panel buttons.
  onSelectMultiplier?: (m: 1 | 2 | 3) => void;
  isMultiplierLocked?: (m: 1 | 2 | 3) => boolean;
  multiplierInteractive?: boolean;
  // Pull lever to spin. onLeverPull fires after the pull animation lands.
  onLeverPull?: () => void;
  leverEnabled?: boolean;
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
  onLeverPull,
  leverEnabled = false,
}: Props) {
  const { width: screenWidth, height: screenHeight } = useWindowDimensions();

  const isSpinning    = useRunStore(s => s.isSpinning);
  const lastResult    = useRunStore(s => s.lastResult);
  const lockedReels   = useRunStore(s => s.lockedReels);
  const betMultiplier = useRunStore(s => s.betMultiplier) as 1 | 2 | 3;
  const lockedReelSpinsRemaining = useRunStore(s => s.lockedReelSpinsRemaining);

  // ── Lever animation (idle 0 → pulled 5) ──
  const [leverFrame, setLeverFrame] = useState(0);
  const leverTimers = useRef<Array<ReturnType<typeof setTimeout>>>([]);

  function pullLever() {
    if (!leverEnabled || !onLeverPull) return;
    // Ignore repeated triggers while a pull (or spin) is already running.
    if (leverTimers.current.length > 0 || isSpinning) return;
    for (let f = 1; f <= LEVER_FRAME_COUNT - 1; f++) {
      leverTimers.current.push(setTimeout(() => setLeverFrame(f), LEVER_FRAME_MS * f));
    }
    leverTimers.current.push(setTimeout(() => { onLeverPull(); }, LEVER_FRAME_MS * (LEVER_FRAME_COUNT - 1)));
    leverTimers.current.push(setTimeout(() => {
      setLeverFrame(0);
      leverTimers.current = [];
    }, LEVER_FRAME_MS * LEVER_FRAME_COUNT));
  }

  useEffect(() => () => { leverTimers.current.forEach(clearTimeout); }, []);

  // Lever glow — breathing neon ring when a spin is ready.
  const leverGlowOpacity = useRef(new Animated.Value(0)).current;
  const leverGlowScale   = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (!leverEnabled) {
      leverGlowOpacity.stopAnimation(() => leverGlowOpacity.setValue(0));
      return;
    }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.parallel([
          Animated.timing(leverGlowOpacity, { toValue: 0.9, duration: 550, useNativeDriver: true }),
          Animated.timing(leverGlowScale,   { toValue: 1.1, duration: 550, useNativeDriver: true }),
        ]),
        Animated.parallel([
          Animated.timing(leverGlowOpacity, { toValue: 0.15, duration: 650, useNativeDriver: true }),
          Animated.timing(leverGlowScale,   { toValue: 0.92, duration: 650, useNativeDriver: true }),
        ]),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [leverEnabled]);

  // ── Jackpot flash (2-frame banner) ──
  const [jackpotFlash, setJackpotFlash] = useState(false);
  const [jackpotFrame, setJackpotFrame] = useState(0);
  const flashTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const flashBlink = useRef<ReturnType<typeof setInterval> | null>(null);

  // Waits for the reroll animation too — a power-made jackpot should flash
  // when the reel lands, not while it is still spinning.
  useEffect(() => {
    if (lastResult?.isJackpot && !isSpinning && rerollingReelIndex === null) {
      setJackpotFlash(true);
      flashBlink.current = setInterval(
        () => setJackpotFrame(f => (f + 1) % JACKPOT_FRAME_COUNT),
        140,
      );
      flashTimer.current = setTimeout(() => {
        setJackpotFlash(false);
        if (flashBlink.current) clearInterval(flashBlink.current);
      }, 1800);
    }
    return () => {
      if (flashTimer.current) clearTimeout(flashTimer.current);
      if (flashBlink.current) clearInterval(flashBlink.current);
    };
  }, [lastResult, isSpinning, rerollingReelIndex]);

  // ── Sizing — largest integer scale of the 96×144 cabinet that fits portrait. ──
  const maxW = screenWidth * 0.94;
  const maxH = screenHeight * 0.52;
  const rawScale = Math.min(maxW / MACHINE_SRC_W, maxH / (MACHINE_SRC_W * MACHINE_ASPECT));
  const scale = Math.max(2, Math.min(4, Math.floor(rawScale)));
  const machineWidth  = MACHINE_SRC_W * scale;
  const machineHeight = Math.round(machineWidth * MACHINE_ASPECT);
  const f = machineWidth / MACHINE_SRC_W; // display px per source px (== scale)

  const symbolSize = Math.round(REEL_CELL_WIDTH * f);

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

  // Adjacent symbols for the shift buttons.
  // Book is not in MOVE_ORDER — clamp to 0 (brain's position), matching applyMoveColumn,
  // so the direction buttons still appear even when the reel shows a book.
  const shiftCurrentSym = shiftTargetReel != null ? reels[shiftTargetReel] : null;
  const rawShiftIdx = shiftCurrentSym ? MOVE_ORDER.indexOf(shiftCurrentSym) : -1;
  const shiftIdx = rawShiftIdx < 0 && shiftCurrentSym !== null ? 0 : rawShiftIdx;
  const shiftUpSym   = shiftIdx >= 0 ? MOVE_ORDER[(shiftIdx - 1 + MOVE_ORDER.length) % MOVE_ORDER.length] : null;
  const shiftDownSym = shiftIdx >= 0 ? MOVE_ORDER[(shiftIdx + 1) % MOVE_ORDER.length] : null;

  // Cell tap-target geometry (source px → display px). A touch of vertical
  // padding makes the small reel windows comfortably tappable.
  const cellTapW = 17 * f;
  const cellTapTop = (REEL_WINDOW.top - 4) * f;
  const cellTapH = (REEL_WINDOW.height + 8) * f;

  return (
    <View style={[styles.machine, { width: machineWidth, height: machineHeight }]}>
      {/* 1 — Reel backing (white cells) behind the cabinet windows */}
      <Image source={REEL_BG_V3} style={styles.fill} resizeMode="stretch" fadeDuration={0} />

      {/* 2 — Reel symbol columns (masked by the cabinet's holes, drawn next) */}
      <View style={styles.fill} pointerEvents="none">
        {([0, 1, 2] as const).map(i => {
          const isRerolling = rerollingReelIndex === i;
          return (
            <View
              key={i}
              style={{
                position: 'absolute',
                left: (REEL_CELL_CENTERS[i] - REEL_CELL_WIDTH / 2) * f,
                top: HOLE_CENTER_Y * f - (symbolSize * 3) / 2,
                width: symbolSize,
                height: symbolSize * 3,
              }}
            >
              <Reel
                finalSymbol={reels[i]}
                spinning={isSpinning || isRerolling}
                locked={lockedReels[i]}
                reelIndex={i}
                onComplete={isRerolling ? onRerollDone : handleReelComplete}
                overrideStopMs={isRerolling ? 600 : undefined}
                size={symbolSize}
                tile={false}
              />
            </View>
          );
        })}
      </View>

      {/* 3 — Cabinet (its transparent windows reveal the reels above) */}
      <Image source={MACHINE_V3} style={styles.fill} resizeMode="stretch" fadeDuration={0} />

      {/* 4 — TV screen meters (app-rendered) */}
      <View
        style={{
          position: 'absolute',
          left: TV_SCREEN.left * f,
          top: TV_SCREEN.top * f,
          width: TV_SCREEN.width * f,
          height: TV_SCREEN.height * f,
        }}
        pointerEvents="none"
      >
        <MachineScreenMeters width={TV_SCREEN.width * f} height={TV_SCREEN.height * f} />
      </View>

      {/* 5 — Multiplier readout (frame = current bet) */}
      <SpriteSheetFrame
        source={MULTIPLIER_V3}
        frameIndex={betMultiplier - 1}
        frameCount={MULTIPLIER_FRAME_COUNT}
        width={machineWidth}
        height={machineHeight}
        style={styles.fill}
      />

      {/* 6 — Lever (current frame) */}
      <SpriteSheetFrame
        source={LEVER_V3}
        frameIndex={leverFrame}
        frameCount={LEVER_FRAME_COUNT}
        width={machineWidth}
        height={machineHeight}
        style={styles.fill}
      />

      {/* 7 — Jackpot banner flash */}
      {jackpotFlash && (
        <SpriteSheetFrame
          source={JACKPOT_V3}
          frameIndex={jackpotFrame}
          frameCount={JACKPOT_FRAME_COUNT}
          width={machineWidth}
          height={machineHeight}
          style={styles.fill}
        />
      )}

      {/* 8 — Reel cell overlays: targeting + lock/selection display (above cabinet) */}
      <View style={styles.fill} pointerEvents="box-none">
        {([0, 1, 2] as const).map(i => {
          const left = REEL_CELL_CENTERS[i] * f - cellTapW / 2;
          const selected = selectedReels.includes(i);
          const locked = lockedReels[i];
          const tappable = !!onReelPress && !isSpinning && rerollingReelIndex === null;
          return (
            <View
              key={i}
              style={{ position: 'absolute', left, top: cellTapTop, width: cellTapW, height: cellTapH }}
              pointerEvents="box-none"
            >
              {tappable && (
                <Pressable style={StyleSheet.absoluteFill} onPress={() => onReelPress!(i)} />
              )}
              {selected && <View style={[StyleSheet.absoluteFill, styles.reelSelected]} pointerEvents="none" />}
              {locked && (
                <View style={[StyleSheet.absoluteFill, styles.lockBadge]} pointerEvents="none">
                  <Text style={[styles.lockIcon, { fontSize: Math.round(7 * f) }]}>🔒</Text>
                  <Text style={[styles.lockCount, { fontSize: Math.round(3.5 * f) }]}>
                    {lockedReelSpinsRemaining}
                  </Text>
                </View>
              )}
            </View>
          );
        })}
      </View>

      {/* 9 — Multiplier tap targets (above cabinet) + lock overlay */}
      <View style={styles.fill} pointerEvents="box-none">
        {([1, 2, 3] as const).map(m => {
          const locked = isMultiplierLocked ? isMultiplierLocked(m) : false;
          const canTap = multiplierInteractive && !!onSelectMultiplier && !locked;
          const cx = MULT_BADGE_CENTERS[m - 1];
          const w = 16 * f;
          return (
            <View
              key={m}
              style={{
                position: 'absolute',
                left: cx * f - w / 2,
                top: MULT_STRIP.top * f,
                width: w,
                height: MULT_STRIP.height * f,
              }}
              pointerEvents="box-none"
            >
              {canTap && (
                <Pressable style={StyleSheet.absoluteFill} onPress={() => onSelectMultiplier!(m)} />
              )}
              {locked && (
                <View style={[StyleSheet.absoluteFill, styles.multLockOverlay]} pointerEvents="none">
                  <Text style={{ fontSize: Math.round(MULT_STRIP.height * f * 0.7) }}>🔒</Text>
                </View>
              )}
            </View>
          );
        })}
      </View>

      {/* 10 — Shift direction buttons — above and below the selected reel column */}
      {shiftTargetReel != null && onShiftDirection && shiftUpSym && shiftDownSym && (
        <>
          <Pressable
            style={[
              styles.shiftBtn,
              styles.shiftBtnTop,
              {
                left: REEL_CELL_CENTERS[shiftTargetReel] * f - cellTapW / 2,
                width: cellTapW,
                top: TV_SCREEN.top * f,
                height: (REEL_WINDOW.top - TV_SCREEN.top - 2) * f,
              },
            ]}
            onPress={() => onShiftDirection(1)}
          >
            <Text style={styles.shiftSymbolLabel}>{SYMBOLS[shiftDownSym].name.toUpperCase()}</Text>
            <Text style={styles.shiftArrow}>▲</Text>
          </Pressable>

          <Pressable
            style={[
              styles.shiftBtn,
              styles.shiftBtnBottom,
              {
                left: REEL_CELL_CENTERS[shiftTargetReel] * f - cellTapW / 2,
                width: cellTapW,
                top: (REEL_WINDOW.top + REEL_WINDOW.height + 2) * f,
                height: 24 * f,
              },
            ]}
            onPress={() => onShiftDirection(-1)}
          >
            <Text style={styles.shiftArrow}>▼</Text>
            <Text style={styles.shiftSymbolLabel}>{SYMBOLS[shiftUpSym].name.toUpperCase()}</Text>
          </Pressable>
        </>
      )}

      {/* 11 — Lever glow ring — breathes when a spin is ready. */}
      <Animated.View
        pointerEvents="none"
        style={{
          position: 'absolute',
          top:    LEVER_HIT.top * f - 4,
          left:   LEVER_HIT.left * f - 4,
          width:  LEVER_HIT.width * f + 8,
          height: LEVER_HIT.height * f + 8,
          borderRadius: 8,
          borderWidth: 2,
          borderColor: '#ff2d78',
          opacity: leverGlowOpacity,
          transform: [{ scale: leverGlowScale }],
        }}
      />

      {/* 12 — Lever pull hit target (rendered last so it wins the touch contest). */}
      {onLeverPull && (
        <Pressable
          style={{
            position: 'absolute',
            top:    LEVER_HIT.top * f,
            left:   LEVER_HIT.left * f,
            width:  LEVER_HIT.width * f,
            height: LEVER_HIT.height * f,
          }}
          onPress={pullLever}
          disabled={!leverEnabled}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  machine: {
    position: 'relative',
  },
  fill: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
  },
  reelSelected: {
    borderWidth: 2,
    borderColor: '#00e5ff',
    borderRadius: 4,
  },
  lockBadge: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  lockIcon: {
    lineHeight: undefined,
  },
  lockCount: {
    color: '#fbbf24',
    fontWeight: '900',
  },
  multLockOverlay: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  shiftBtn: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,229,255,0.16)',
    borderColor: 'rgba(0,229,255,0.5)',
    borderWidth: 1,
    borderRadius: 6,
  },
  shiftBtnTop: {
    justifyContent: 'flex-end',
    paddingBottom: 2,
  },
  shiftBtnBottom: {
    justifyContent: 'flex-start',
    paddingTop: 2,
  },
  shiftArrow: {
    color: '#00e5ff',
    fontSize: 16,
    fontWeight: '900',
    lineHeight: 18,
  },
  shiftSymbolLabel: {
    color: '#00e5ff',
    fontSize: 8,
    fontWeight: '800',
    letterSpacing: 1,
    opacity: 0.9,
  },
});
