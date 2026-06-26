import React, { useEffect, useRef, useState } from 'react';
import { View, Image, Pressable, StyleSheet, Animated } from 'react-native';
import { Text } from './PixelText';
import { ReelCellV3 } from './ReelCellV3';
import { SpriteSheetFrame } from './SpriteSheetFrame';
import { MachineScreenMeters } from './MachineScreenMeters';
import { CoinFlow } from './CoinFlow';
import { PowerCoinFlow } from './PowerCoinFlow';
import { useRunStore } from '../state/runState';
import { useAnimatedLucidity } from '../state/useAnimatedLucidity';
import type { SymbolId } from '../game/types';
import { TvFillBar } from './TvFillBar';
import { ECONOMY } from '../content/economy';
import {
  MACHINE_V3, REEL_BG_V3, MULTIPLIER_V3, LEVER_V3, JACKPOT_V3,
  REROLL_V3, SHIFT_V3, LOCK_V3, SHIFT_POWER_V3, LOCK_POWER_V3,
  WEALTH_TRACK_V3, WEALTH_FILL_V3, HEALTH_TRACK_V3, HEALTH_FILL_V3,
  MACHINE_SRC_W, MACHINE_ASPECT,
  REEL_WINDOW, REEL_CELL_CENTERS, REEL_HOLES, TV_SCREEN, BAR_FILL,
  MULT_STRIP, MULT_BADGE_CENTERS, LEVER_HIT, POWER_HITS, SHIFT_ARROW_HITS,
  LEVER_FRAME_COUNT, MULTIPLIER_FRAME_COUNT, JACKPOT_FRAME_COUNT, POWER_FRAME_COUNT,
  SHIFT_POWER_FRAME_COUNT, SHIFT_POWER_COLUMNS, LOCK_POWER_FRAME_COUNT,
} from '../content/machineAssets';

const FALLBACK_SYMBOL: SymbolId = 'brain';

// Lever pull plays frames 0 → 5 quickly, fires the spin, then snaps back to idle.
const LEVER_FRAME_MS = 42;

// Tension: when the first two reels already match, the 3rd reel holds a touch
// longer before stopping (a possible triple). Animation timing only — the result
// is already resolved and unchanged. Tune 200–500ms.
const THIRD_REEL_PAIR_TENSION_DELAY_MS = 250;

interface PowerControl {
  visible: boolean;
  frame: 0 | 1 | 2;
  onPress?: () => void;
}

interface Props {
  onAllReelsDone: () => void;
  // When set, reels are tappable (ability/lock targeting) and highlight on press.
  onReelPress?: (reelIndex: number) => void;
  selectedReels?: ReadonlyArray<number>;
  // When true, the shift power is active: draws the shift_power overlay (up/down
  // arrows on every reel) and makes each arrow tappable to shift that reel.
  shiftActive?: boolean;
  onShiftReel?: (reelIndex: number, direction: -1 | 1) => void;
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
  // Machine-mounted power buttons. GameScreen computes each power's display state;
  // SlotMachine just draws the right sheet frame and a hit zone. frame: 0 available,
  // 1 selected/pressed, 2 unavailable. "memory" uses the lock art.
  powers?: {
    reroll: PowerControl;
    shift: PowerControl;
    memory: PowerControl;
  };
  // Display scale: source px → display px. Must equal the runtime art's authored
  // scale (V3_SCALE) so the nearest-neighbour sheets draw 1:1 and crisp.
  scale?: number;
  // When true, holds coin/power-coin animations until the visual result has
  // fully landed (e.g. during a power reroll animation in GameScreen).
  rewardHold?: boolean;
}

export function SlotMachine({
  onAllReelsDone,
  onReelPress,
  selectedReels = [],
  shiftActive = false,
  onShiftReel,
  rerollingReelIndex = null,
  onRerollDone,
  onSelectMultiplier,
  isMultiplierLocked,
  multiplierInteractive = false,
  onLeverPull,
  leverEnabled = false,
  powers,
  scale = 5,
  rewardHold = false,
}: Props) {
  const isSpinning    = useRunStore(s => s.isSpinning);
  const lastResult    = useRunStore(s => s.lastResult);
  const lockedReels   = useRunStore(s => s.lockedReels);
  const betMultiplier = useRunStore(s => s.betMultiplier) as 1 | 2 | 3;
  const lockedReelSpins = useRunStore(s => s.lockedReelSpins);
  // Displayed Lucidity for the objective bar climbs gradually toward the real
  // total (state updates immediately) so big gains fill the bar smoothly. The
  // 30-coin shake/flash is driven separately by CoinFlow off the real total.
  const lucidityCoins = useAnimatedLucidity();
  const neurons       = useRunStore(s => s.neurons);
  const startingN     = useRunStore(s => s.startingNeurons);

  // Lucidity bar shake — nudged each time a flying coin lands on the counter; a
  // touch harder on a power coin. No colour wash over the bar (that used to span
  // the full width and read as a full bar) — threshold feedback now rides on the
  // power_coin → power-button animation instead.
  const lucidityShake = useRef(new Animated.Value(0)).current;
  const runLucidityShake = (strong: boolean) => {
    const amp = strong ? 4 : 2;
    lucidityShake.setValue(0);
    Animated.sequence([
      Animated.timing(lucidityShake, { toValue:  amp, duration: 40, useNativeDriver: true }),
      Animated.timing(lucidityShake, { toValue: -amp, duration: 40, useNativeDriver: true }),
      Animated.timing(lucidityShake, { toValue:  0,   duration: 40, useNativeDriver: true }),
    ]).start();
  };

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

  // ── Sizing — integer `scale` (the 96×144 cabinet → 96·scale × 144·scale).
  // Runtime art is nearest-neighbour pre-upscaled to this same scale, so every
  // source pixel aligns 1:1 to display pixels (no runtime bilinear blur). Every
  // layer — including the reel-blur sheet offsets in ReelCellV3 — derives from
  // `f`, so `scale` MUST match the art's authored V3_SCALE. ──
  const machineWidth  = MACHINE_SRC_W * scale;
  const machineHeight = Math.round(machineWidth * MACHINE_ASPECT);
  const f = machineWidth / MACHINE_SRC_W; // display px per source px

  // Landed symbol sprite size, scaled to the reel hole so it fills it like the
  // spin-blur frames do (~58% of the hole width, matching the previous look).
  const symbolSize = Math.round(REEL_HOLES[0].width * f * 0.58);

  // Multiplier frame encodes the EFFECTIVE bet + which bets are locked. Only
  // x3-locked and x2+x3-locked combos occur (cost/energy lock x3 before x2),
  // matching the art:
  //   0:×1  1:×2  2:×3  3:×1(×3 lock)  4:×1(×2+×3 lock)  5:×2(×3 lock)
  // The selected bet is clamped to the highest affordable level so a locked
  // selection shows the level it actually spins at (never a higher-than-shown
  // value) — see the matching clamp in runState's spin().
  const x2Locked = isMultiplierLocked ? isMultiplierLocked(2) : false;
  const x3Locked = isMultiplierLocked ? isMultiplierLocked(3) : false;
  const affordableMult = x2Locked ? 1 : x3Locked ? 2 : 3;
  const effectiveMult = Math.min(betMultiplier, affordableMult);
  const multFrame =
    affordableMult === 1 ? 4
    : affordableMult === 2 ? (effectiveMult === 2 ? 5 : 3)
    :                        effectiveMult - 1;

  // TV bars: the top bar is the Lucidity OBJECTIVE bar — it tracks progress
  // toward the current Lucidity goal (LUCIDITY_OBJECTIVE, default 1000 L) and
  // never resets. The 30-coin power-restore threshold is separate: it only
  // shakes/flashes this bar (see runLucidityShake), it does NOT reset it. It
  // reuses the wealth bar's art/slot until dedicated objective art exists. The
  // lower bar still follows remaining neurons.
  const lucidityRatio = Math.max(0, Math.min(1, lucidityCoins / ECONOMY.LUCIDITY_OBJECTIVE));
  const healthRatio = startingN > 0 ? Math.max(0, Math.min(1, neurons / startingN)) : 0;

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

  // Overlay frame for the shift arrows: 0 idle, else the held arrow's pressed
  // frame (1 + reel*2 + up). Reset to idle whenever shift deactivates.
  const [shiftFrame, setShiftFrame] = useState(0);
  useEffect(() => {
    if (!shiftActive) setShiftFrame(0);
  }, [shiftActive]);

  // Cell tap-target geometry (source px → display px). A touch of vertical
  // padding makes the small reel windows comfortably tappable.
  const cellTapW = 17 * f;
  const cellTapTop = (REEL_WINDOW.top - 4) * f;
  const cellTapH = (REEL_WINDOW.height + 8) * f;

  // Machine-mounted power buttons: each art sheet + its on-canvas hit rect, paired
  // with the display state GameScreen passes in. "memory" ability uses the lock art.
  const powerDefs = [
    { key: 'reroll', source: REROLL_V3, hit: POWER_HITS.reroll, state: powers?.reroll },
    { key: 'shift',  source: SHIFT_V3,  hit: POWER_HITS.shift,  state: powers?.shift  },
    { key: 'memory', source: LOCK_V3,   hit: POWER_HITS.lock,   state: powers?.memory },
  ] as const;

  return (
    <View style={[styles.machine, { width: machineWidth, height: machineHeight }]}>
      {/* 1 — Reel backing (white cells) behind the cabinet windows */}
      <Image source={REEL_BG_V3} style={styles.fill} resizeMode="stretch" fadeDuration={0} />

      {/* 2 — Reel cells: 5-frame spin blur (symbols.png), landing on the resolved
              sprite. Masked by the cabinet's holes, drawn next. */}
      <View style={styles.fill} pointerEvents="none">
        {([0, 1, 2] as const).map(i => {
          const isRerolling = rerollingReelIndex === i;
          // 3rd reel tension: only on a full spin (not a reroll) when reels 0 & 1
          // already match. Timing only — the resolved symbols are unchanged.
          const pairTension =
            i === 2 && !isRerolling && reels[0] === reels[1]
              ? THIRD_REEL_PAIR_TENSION_DELAY_MS
              : 0;
          return (
            <ReelCellV3
              key={i}
              finalSymbol={reels[i]}
              spinning={isSpinning || isRerolling}
              locked={lockedReels[i]}
              reelIndex={i}
              onComplete={isRerolling ? onRerollDone : handleReelComplete}
              overrideStopMs={isRerolling ? 600 : undefined}
              extraStopMs={pairTension}
              machineWidth={machineWidth}
              machineHeight={machineHeight}
              hole={{
                left: REEL_HOLES[i].left * f,
                top: REEL_HOLES[i].top * f,
                width: REEL_HOLES[i].width * f,
                height: REEL_HOLES[i].height * f,
              }}
              symbolSize={symbolSize}
            />
          );
        })}
      </View>

      {/* 3 — Lever (current frame), drawn behind the cabinet body. */}
      <SpriteSheetFrame
        source={LEVER_V3}
        frameIndex={leverFrame}
        frameCount={LEVER_FRAME_COUNT}
        width={machineWidth}
        height={machineHeight}
        style={styles.fill}
      />

      {/* 4 — Cabinet (its transparent windows reveal the reels above) */}
      <Image source={MACHINE_V3} style={styles.fill} resizeMode="stretch" fadeDuration={0} />

      {/* 4b — TV fill bars (Lucidity + health), drawn into the TV screen. The
              Lucidity bar shakes a touch each time a flying coin lands. */}
      <Animated.View
        style={[StyleSheet.absoluteFill, { transform: [{ translateX: lucidityShake }] }]}
        pointerEvents="none"
      >
        <TvFillBar
          track={WEALTH_TRACK_V3}
          fill={WEALTH_FILL_V3}
          ratio={lucidityRatio}
          machineWidth={machineWidth}
          machineHeight={machineHeight}
          fillLeft={BAR_FILL.left * f}
          fillWidth={BAR_FILL.width * f}
        />
      </Animated.View>
      <TvFillBar
        track={HEALTH_TRACK_V3}
        fill={HEALTH_FILL_V3}
        ratio={healthRatio}
        machineWidth={machineWidth}
        machineHeight={machineHeight}
        fillLeft={BAR_FILL.left * f}
        fillWidth={BAR_FILL.width * f}
      />

      {/* 5 — TV screen meters (app-rendered) */}
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
        <MachineScreenMeters width={TV_SCREEN.width * f} height={TV_SCREEN.height * f} f={f} />
      </View>

      {/* 6 — Multiplier readout (frame encodes selected bet + locks) */}
      <SpriteSheetFrame
        source={MULTIPLIER_V3}
        frameIndex={multFrame}
        frameCount={MULTIPLIER_FRAME_COUNT}
        width={machineWidth}
        height={machineHeight}
        style={styles.fill}
      />

      {/* 6b — Machine power button art (full-canvas layers; only the visible ones) */}
      {powerDefs.map(p => p.state && p.state.visible ? (
        <SpriteSheetFrame
          key={p.key}
          source={p.source}
          frameIndex={p.state.frame}
          frameCount={POWER_FRAME_COUNT}
          width={machineWidth}
          height={machineHeight}
          style={styles.fill}
        />
      ) : null)}

      {/* 7 — Jackpot lamp: frame 0 (unlit) at rest, cycling frames while flashing */}
      <SpriteSheetFrame
        source={JACKPOT_V3}
        frameIndex={jackpotFlash ? jackpotFrame : 0}
        frameCount={JACKPOT_FRAME_COUNT}
        width={machineWidth}
        height={machineHeight}
        style={styles.fill}
      />

      {/* 7b — Coin flow: Lucidity coins burst from the bottom tray, then stream
              up to the objective bar; each landing nudges the bar. Power coins
              (every 30L) are separate — they fly to the power they restore. */}
      <View style={styles.fill} pointerEvents="none">
        <CoinFlow f={f} onArrive={() => runLucidityShake(false)} hold={rewardHold} />
        <PowerCoinFlow f={f} hold={rewardHold} />
      </View>

      {/* 7c — Locked-reel indicators: a full-canvas lock box per locked reel
              (frame index == that reel; transparent elsewhere, so multiple stack
              cleanly). The spins-left count sits just below each box, clear of
              the symbol. */}
      {([0, 1, 2] as const).map(i => lockedReels[i] ? (
        <React.Fragment key={`lock-${i}`}>
          <SpriteSheetFrame
            source={LOCK_POWER_V3}
            frameIndex={i}
            frameCount={LOCK_POWER_FRAME_COUNT}
            width={machineWidth}
            height={machineHeight}
            style={styles.fill}
          />
          <Text
            style={[
              styles.lockCount,
              {
                position: 'absolute',
                left: (REEL_CELL_CENTERS[i] - 8) * f,
                top: 205 * f,
                width: 16 * f,
                fontSize: Math.round(5 * f),
                textAlign: 'center',
              },
            ]}
            pointerEvents="none"
          >
            {lockedReelSpins[i]}
          </Text>
        </React.Fragment>
      ) : null)}

      {/* 8 — Reel cell overlays: targeting + lock/selection display (above cabinet) */}
      <View style={styles.fill} pointerEvents="box-none">
        {([0, 1, 2] as const).map(i => {
          const left = REEL_CELL_CENTERS[i] * f - cellTapW / 2;
          const selected = selectedReels.includes(i);
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
            </View>
          );
        })}
      </View>

      {/* 9 — Multiplier tap targets (above cabinet). The lock state is baked into
             the multiplier art frames, so no overlay is drawn here. */}
      <View style={styles.fill} pointerEvents="box-none">
        {([1, 2, 3] as const).map(m => {
          const locked = isMultiplierLocked ? isMultiplierLocked(m) : false;
          const canTap = multiplierInteractive && !!onSelectMultiplier && !locked;
          if (!canTap) return null;
          const cx = MULT_BADGE_CENTERS[m - 1];
          const w = 16 * f;
          return (
            <Pressable
              key={m}
              style={{
                position: 'absolute',
                left: cx * f - w / 2,
                top: MULT_STRIP.top * f,
                width: w,
                height: MULT_STRIP.height * f,
              }}
              onPress={() => onSelectMultiplier!(m)}
            />
          );
        })}
      </View>

      {/* 9b — Machine power tap targets. Tappable only when visible and usable
             (frame 0/1); frame 2 (unavailable) renders no hit zone. */}
      <View style={styles.fill} pointerEvents="box-none">
        {powerDefs.map(p =>
          p.state && p.state.visible && p.state.frame !== 2 && p.state.onPress ? (
            <Pressable
              key={p.key}
              style={{
                position: 'absolute',
                left: p.hit.left * f,
                top: p.hit.top * f,
                width: p.hit.width * f,
                height: p.hit.height * f,
              }}
              onPress={p.state.onPress}
            />
          ) : null,
        )}
      </View>

      {/* 10 — Shift power: full-canvas up/down arrow overlay + per-reel hit zones.
              Tapping a reel's arrow shifts that reel; the overlay shows its pressed
              frame while any arrow is held. */}
      {shiftActive && onShiftReel && (
        <>
          <SpriteSheetFrame
            source={SHIFT_POWER_V3}
            frameIndex={shiftFrame}
            frameCount={SHIFT_POWER_FRAME_COUNT}
            columns={SHIFT_POWER_COLUMNS}
            width={machineWidth}
            height={machineHeight}
            style={styles.fill}
          />
          {SHIFT_ARROW_HITS.map((arrows, i) =>
            (['up', 'down'] as const).map(dir => {
              const r = arrows[dir];
              const frame = 1 + i * 2 + (dir === 'up' ? 1 : 0);
              return (
                <Pressable
                  key={`${i}-${dir}`}
                  style={{
                    position: 'absolute',
                    left: r.left * f,
                    top: r.top * f,
                    width: r.width * f,
                    height: r.height * f,
                  }}
                  onPressIn={() => setShiftFrame(frame)}
                  onPressOut={() => setShiftFrame(0)}
                  onPress={() => onShiftReel(i, dir === 'up' ? 1 : -1)}
                />
              );
            }),
          )}
        </>
      )}

      {/* 11 — Lever pull hit target (rendered last so it wins the touch contest). */}
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
  lockCount: {
    // Same blue as the lock art. No fontWeight: a custom pixel font has no bold
    // face, so requesting one makes RN fall back to a system font.
    color: '#00e5ff',
  },
  multLockOverlay: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
