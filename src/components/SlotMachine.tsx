import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { View, Image, Pressable, StyleSheet, Animated } from 'react-native';
import { Text } from './PixelText';
import { ReelCellV3 } from './ReelCellV3';
import { SpriteSheetFrame } from './SpriteSheetFrame';
import { LeverSprite } from './LeverSprite';
import { MachineScreenMeters } from './MachineScreenMeters';
import { CoinFlow } from './CoinFlow';
import { PowerCoinFlow } from './PowerCoinFlow';
import { ScoreBurst } from './ScoreBurst';
import { useRunStore } from '../state/runState';
import { useAnimatedLucidity } from '../state/useAnimatedLucidity';
import { useRenderCount } from '../perf/useRenderCount';
import type { SymbolId } from '../game/types';
import { TvFillBar } from './TvFillBar';
import { ECONOMY } from '../content/economy';
import {
  MACHINE_V3, REEL_BG_V3, MULTIPLIER_V3, JACKPOT_V3,
  REROLL_V3, SHIFT_V3, LOCK_V3, SHIFT_POWER_V3, LOCK_POWER_V3, REEL_SELECT_V3,
  WEALTH_TRACK_V3, WEALTH_FILL_V3, HEALTH_TRACK_V3, HEALTH_FILL_V3,
  MACHINE_SRC_W, MACHINE_ASPECT,
  REEL_WINDOW, REEL_CELL_CENTERS, REEL_HOLES, TV_SCREEN, BAR_FILL,
  MULT_STRIP, MULT_BADGE_CENTERS, LEVER_HIT, POWER_HITS, SHIFT_ARROW_HITS,
  MULTIPLIER_FRAME_COUNT, JACKPOT_FRAME_COUNT, POWER_FRAME_COUNT,
  SHIFT_POWER_FRAME_COUNT, SHIFT_POWER_COLUMNS, LOCK_POWER_FRAME_COUNT,
  REEL_SELECT_FRAME_COUNT, REEL_SELECT_COLUMNS,
} from '../content/machineAssets';

const FALLBACK_SYMBOL: SymbolId = 'brain';

const RESULT_REVEAL_DELAY_MS = 150;

// Tension: when the first two reels already match, the 3rd reel holds a touch
// longer before stopping (a possible triple). Animation timing only — the result
// is already resolved and unchanged. Tune 200–500ms.
const THIRD_REEL_PAIR_TENSION_DELAY_MS = 250;

interface PowerControl {
  visible: boolean;
  frame: 0 | 1 | 2;
  onPress?: () => void;
}

type PowerKey = 'reroll' | 'shift' | 'memory';

type PowerDef = {
  key: PowerKey;
  hit: typeof POWER_HITS[keyof typeof POWER_HITS];
  state?: PowerControl;
};

interface Props {
  onAllReelsDone: () => void;
  // When set, reels are tappable (ability/lock targeting) and highlight on press.
  onReelPress?: (reelIndex: number) => void;
  selectedReels?: ReadonlyArray<number>;
  // When true, the shift power is active: draws the shift_power overlay (up/down
  // arrows on every reel) and makes each arrow tappable to shift that reel.
  shiftActive?: boolean;
  onShiftReel?: (reelIndex: number, direction: -1 | 1) => void;
  onShiftCancel?: () => void;
  // When true, a reroll/lock power is choosing a reel: draws the reel_selection
  // overlay (one arrow per reel), with the pressed reel's arrow lit on touch.
  reelSelectActive?: boolean;
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
  // Explicit reel the score announcement should emerge from when a power changed a
  // reel (reroll/shift/copy). `null`/omitted means a normal spin — ScoreBurst then
  // derives the reel from the result (pair on the first two reels → 2nd reel).
  scoreSourceReelIndex?: 0 | 1 | 2 | null;
  // Compulsion: while a forced spin runs the machine bets for itself —
  // show this multiplier (1 or 2 only, never 3) on the readout instead of the
  // player's selection. `null` = normal (use the player's bet).
  forcedMultiplier?: 1 | 2 | null;
  // Bumped (incrementing number) to make the lever self-pull as a VISUAL cue for a
  // forced Compulsion spin. Plays the lever animation only — it never calls
  // onLeverPull, so it cannot cause a second/duplicate spin.
  compulsionPullSignal?: number;
}

export const SlotMachine = React.memo(function SlotMachine({
  onAllReelsDone,
  onReelPress,
  selectedReels = [],
  shiftActive = false,
  onShiftReel,
  onShiftCancel,
  reelSelectActive = false,
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
  scoreSourceReelIndex = null,
  forcedMultiplier = null,
  compulsionPullSignal = 0,
}: Props) {
  useRenderCount('SlotMachine');
  const isSpinning    = useRunStore(s => s.isSpinning);
  const lastResult    = useRunStore(s => s.lastResult);
  const lockedReels   = useRunStore(s => s.lockedReels);
  const betMultiplier = useRunStore(s => s.betMultiplier) as 1 | 2 | 3;
  const lockedReelSpins = useRunStore(s => s.lockedReelSpins);
  // NOTE: the animated Lucidity total is deliberately NOT read here. It climbs
  // ~60fps for up to 1.5s after every gain; reading it in this (large) component
  // would re-render the whole machine each frame. It lives in the isolated leaf
  // <AnimatedLucidityFill> (below) and in <MachineScreenMeters>, so only those
  // tiny nodes update per frame — the rest of the cabinet stays still.
  const neurons       = useRunStore(s => s.neurons);
  const startingN     = useRunStore(s => s.startingNeurons);
  const freeSpins     = useRunStore(s => s.freeSpinsRemaining);

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

  // ── Lever pull ──
  // The animation itself lives in <LeverSprite> (below) so its per-frame state
  // churn never re-renders this heavy tree. Here we only fire the SIGNAL: a tap
  // bumps manualPullSignal, which the sprite turns into a pull that also fires the
  // spin at the bottom. (The Compulsion self-pull rides compulsionPullSignal,
  // passed straight through to the sprite — visual only, no spin.)
  const [manualPullSignal, setManualPullSignal] = useState(0);
  function pullLever() {
    if (!leverEnabled || !onLeverPull) return;
    setManualPullSignal(n => n + 1);
  }

  // ── Arrow press feedback ──
  // The shift + reel-selection overlays draw their pressed state from sheet
  // frames; tapping an arrow has to swap to that frame INSTANTLY (on press-in,
  // before the shift/reroll executes). Both default to frame 0 (idle, all arrows
  // shown). A single setState on press is far below per-frame cost, so plain
  // state is fine here. They're reset whenever their mode turns off, in case a
  // press-out is missed (e.g. the selection is cancelled mid-press).
  //
  // Shift sheet frame = 1 + reel*2 + (up ? 1 : 0); 0 = nothing held.
  const [shiftPressFrame, setShiftPressFrame] = useState(0);
  // Reel-selection sheet frame = pressedReel + 1; 0 = nothing held.
  const [reelSelectPressFrame, setReelSelectPressFrame] = useState(0);

  useEffect(() => { if (!shiftActive) setShiftPressFrame(0); }, [shiftActive]);
  useEffect(() => { if (!reelSelectActive) setReelSelectPressFrame(0); }, [reelSelectActive]);

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

  // Reel hole rects in display px. Memoized on the scale so each reel gets a
  // STABLE object reference — otherwise the inline literal would break ReelCellV3's
  // memo on every render.
  const reelHoles = useMemo(
    () => ([0, 1, 2] as const).map(i => ({
      left:   REEL_HOLES[i].left * f,
      top:    REEL_HOLES[i].top * f,
      width:  REEL_HOLES[i].width * f,
      height: REEL_HOLES[i].height * f,
    })),
    [f],
  );

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
  const baseEffectiveMult = Math.min(betMultiplier, affordableMult);
  // During Compulsion the machine forces its own bet (x1/x2 only — never x3): show
  // it on the readout and use it for the win-burst colour, overriding the player's
  // selection. forcedMultiplier is null at all other times.
  const effectiveMult = forcedMultiplier ?? baseEffectiveMult;
  const multFrame =
    forcedMultiplier != null
      ? forcedMultiplier - 1                  // 0:×1  1:×2 (plain frame, no lock art)
      : affordableMult === 1 ? 4
        : affordableMult === 2 ? (baseEffectiveMult === 2 ? 5 : 3)
        :                        baseEffectiveMult - 1;

  // TV bars: the top bar is the Lucidity OBJECTIVE bar — it tracks progress
  // toward the current Lucidity goal (LUCIDITY_OBJECTIVE, default 1000 L) and
  // never resets. Its animated fill lives in <AnimatedLucidityFill> so the per-
  // frame count-up doesn't re-render this whole component. The 30-coin power-
  // restore threshold is separate: it only shakes/flashes the bar (see
  // runLucidityShake). The lower bar follows total spins left: base neuron-funded
  // spins plus banked free spins, capped at a full bar.
  const startingSpins = Math.max(1, Math.ceil(startingN / ECONOMY.NEURON_DECAY_PER_SPIN));
  const baseSpinsLeft = neurons > 0 ? Math.max(1, Math.ceil(neurons / ECONOMY.NEURON_DECAY_PER_SPIN)) : 0;
  const healthRatio = Math.max(0, Math.min(1, (baseSpinsLeft + freeSpins) / startingSpins));

  const reels: [SymbolId, SymbolId, SymbolId] = lastResult
    ? lastResult.reels
    : [FALLBACK_SYMBOL, FALLBACK_SYMBOL, FALLBACK_SYMBOL];

  const completedRef = useRef(0);
  const resultRevealTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Stable across renders (deps are stable) so ReelCellV3's memo isn't broken by a
  // fresh onComplete identity every render.
  const scheduleReveal = useCallback(() => {
    if (resultRevealTimer.current) clearTimeout(resultRevealTimer.current);
    resultRevealTimer.current = setTimeout(() => {
      resultRevealTimer.current = null;
      onAllReelsDone();
    }, RESULT_REVEAL_DELAY_MS);
  }, [onAllReelsDone]);

  const handleReelComplete = useCallback(() => {
    completedRef.current += 1;
    if (completedRef.current === 3) {
      completedRef.current = 0;
      scheduleReveal();
    }
  }, [scheduleReveal]);

  // Reset completed counter when a new spin starts. Locked reels fire their
  // onComplete before this effect runs (child effects before parent), so
  // pre-seed with the number of locked reels to avoid a missed completion.
  useEffect(() => {
    if (isSpinning) {
      if (resultRevealTimer.current) {
        clearTimeout(resultRevealTimer.current);
        resultRevealTimer.current = null;
      }
      const lockedCount = lockedReels.filter(Boolean).length;
      completedRef.current = lockedCount;
      // All three reels locked → none of them will call handleReelComplete after
      // this reset (locked reels finish instantly, in their child effect, before
      // this parent effect runs — and we just cleared the timer they scheduled).
      // Nothing would ever fire the reveal, so the machine would spin forever.
      // Schedule it directly for that case.
      if (lockedCount === 3) {
        completedRef.current = 0;
        scheduleReveal();
      }
    }
  }, [isSpinning]);

  useEffect(() => () => {
    if (resultRevealTimer.current) clearTimeout(resultRevealTimer.current);
  }, []);

  // Machine-mounted power buttons: each art sheet + its on-canvas hit rect, paired
  // with the display state GameScreen passes in. "memory" ability uses the lock art.
  // Memoized on `powers` so the array identity is stable across unrelated re-renders
  // — otherwise it would re-break MachineTouchOverlay's React.memo every time.
  const powerDefs = useMemo(() => [
    { key: 'reroll', source: REROLL_V3, hit: POWER_HITS.reroll, state: powers?.reroll },
    { key: 'shift',  source: SHIFT_V3,  hit: POWER_HITS.shift,  state: powers?.shift  },
    { key: 'memory', source: LOCK_V3,   hit: POWER_HITS.lock,   state: powers?.memory },
  ] as const, [powers]);

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
              hole={reelHoles[i]}
              symbolSize={symbolSize}
            />
          );
        })}
      </View>

      {/* 3 — Lever (animates on its own isolated component), behind the cabinet. */}
      <LeverSprite
        manualPullSignal={manualPullSignal}
        compulsionPullSignal={compulsionPullSignal}
        isSpinning={isSpinning}
        onLeverPull={onLeverPull}
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
        <AnimatedLucidityFill
          machineWidth={machineWidth}
          machineHeight={machineHeight}
          f={f}
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

      {/* 7d — Result announcement: PAIR / TRIPLE / JACKPOT + amount bursts out of
              the reel that produced the final scoring action (3rd reel for a
              normal spin; the changed reel for a power), floats up toward the goal
              bar and fades. Coloured by the bet multiplier. Visual only. */}
      <View style={styles.fill} pointerEvents="none">
        <ScoreBurst
          f={f}
          sourceReelIndex={scoreSourceReelIndex}
          multiplier={Math.max(1, Math.min(3, effectiveMult)) as 1 | 2 | 3}
          holdReveal={rerollingReelIndex !== null}
        />
      </View>

      {/* 7e — Reel-selection arrows (reroll / lock targeting): full-canvas overlay,
              one arrow per reel. Kept MOUNTED and shown/hidden by opacity rather
              than conditionally mounted: Skia's useImage has no cache, so a fresh
              mount on each power press would decode the sheet on press and make the
              arrows pop in late. Mounting once (at machine mount) decodes it ahead
              of time so toggling is instant. */}
      <View
        style={[styles.fill, reelSelectActive ? null : styles.hiddenOverlay]}
        pointerEvents="none"
      >
        <SpriteSheetFrame
          source={REEL_SELECT_V3}
          frameIndex={reelSelectPressFrame}
          frameCount={REEL_SELECT_FRAME_COUNT}
          columns={REEL_SELECT_COLUMNS}
          width={machineWidth}
          height={machineHeight}
          style={styles.fill}
        />
      </View>

      {/* Shift power arrow art (up/down arrows on every reel). Visual only — all
              touch input (incl. tap-to-cancel and the per-arrow hit zones) is
              owned by MachineTouchOverlay below. Same always-mounted + opacity
              treatment as the reel-selection arrows so it never decodes on press. */}
      <View
        style={[styles.fill, shiftActive && onShiftReel ? null : styles.hiddenOverlay]}
        pointerEvents="none"
      >
        <SpriteSheetFrame
          source={SHIFT_POWER_V3}
          frameIndex={shiftPressFrame}
          frameCount={SHIFT_POWER_FRAME_COUNT}
          columns={SHIFT_POWER_COLUMNS}
          width={machineWidth}
          height={machineHeight}
          style={styles.fill}
        />
      </View>

      <MachineTouchOverlay
        f={f}
        isSpinning={isSpinning}
        rerollingReelIndex={rerollingReelIndex}
        onReelPress={onReelPress}
        shiftActive={shiftActive}
        onShiftReel={onShiftReel}
        onShiftCancel={onShiftCancel}
        multiplierInteractive={multiplierInteractive}
        onSelectMultiplier={onSelectMultiplier}
        isMultiplierLocked={isMultiplierLocked}
        powerDefs={powerDefs}
        onLeverPull={onLeverPull ? pullLever : undefined}
        onShiftPressFrame={setShiftPressFrame}
        onReelSelectPressFrame={setReelSelectPressFrame}
      />
    </View>
  );
});

// Isolated Lucidity objective fill. Calls useAnimatedLucidity() HERE (not in
// SlotMachine) so the ~60fps count-up re-renders only this leaf — a single
// clipped <Image> — instead of the entire cabinet. Memoized: its props (size +
// scale) change only on an art/scale swap, so the parent re-rendering for any
// other reason never touches it; only its own internal count-up does.
const AnimatedLucidityFill = React.memo(function AnimatedLucidityFill({
  machineWidth,
  machineHeight,
  f,
}: {
  machineWidth: number;
  machineHeight: number;
  f: number;
}) {
  useRenderCount('AnimatedLucidityFill');
  const lucidityCoins = useAnimatedLucidity();
  const ratio = Math.max(0, Math.min(1, lucidityCoins / ECONOMY.LUCIDITY_OBJECTIVE));
  return (
    <TvFillBar
      track={WEALTH_TRACK_V3}
      fill={WEALTH_FILL_V3}
      ratio={ratio}
      machineWidth={machineWidth}
      machineHeight={machineHeight}
      fillLeft={BAR_FILL.left * f}
      fillWidth={BAR_FILL.width * f}
    />
  );
});

interface MachineTouchOverlayProps {
  f: number;
  isSpinning: boolean;
  rerollingReelIndex: number | null;
  onReelPress?: (reelIndex: number) => void;
  shiftActive: boolean;
  onShiftReel?: (reelIndex: number, direction: -1 | 1) => void;
  onShiftCancel?: () => void;
  multiplierInteractive: boolean;
  onSelectMultiplier?: (m: 1 | 2 | 3) => void;
  isMultiplierLocked?: (m: 1 | 2 | 3) => boolean;
  powerDefs: ReadonlyArray<PowerDef>;
  onLeverPull?: () => void;
  // Press feedback drivers: report the sheet frame to show on press-in (a value
  // computed from the reel + direction) and 0 on release. Stable setState
  // setters, so passing them keeps this component's memo intact.
  onShiftPressFrame?: (frame: number) => void;
  onReelSelectPressFrame?: (frame: number) => void;
}

// Touch layer for the cabinet — the single owner of all machine input (reels,
// multiplier, powers, shift arrows + tap-to-cancel, lever). Pressables only, with
// no visible overlay: press/selection feedback comes from the machine art itself
// (power frames, lever animation, the shifted reel result). Memoized so unrelated
// re-renders don't rebuild the hit zones.
const MachineTouchOverlay = React.memo(function MachineTouchOverlay({
  f,
  isSpinning,
  rerollingReelIndex,
  onReelPress,
  shiftActive,
  onShiftReel,
  onShiftCancel,
  multiplierInteractive,
  onSelectMultiplier,
  isMultiplierLocked,
  powerDefs,
  onLeverPull,
  onShiftPressFrame,
  onReelSelectPressFrame,
}: MachineTouchOverlayProps) {
  useRenderCount('MachineTouchOverlay');

  const cellTapW = 17 * f;
  const cellTapTop = (REEL_WINDOW.top - 4) * f;
  const cellTapH = (REEL_WINDOW.height + 8) * f;

  return (
    <View style={styles.fill} pointerEvents="box-none">
      {shiftActive && onShiftCancel && (
        <Pressable style={styles.fill} onPress={onShiftCancel} />
      )}

      {([0, 1, 2] as const).map(i => {
        const tappable = !!onReelPress && !isSpinning && rerollingReelIndex === null;
        if (!tappable) return null;
        const left = REEL_CELL_CENTERS[i] * f - cellTapW / 2;
        return (
          <Pressable
            key={i}
            style={{ position: 'absolute', left, top: cellTapTop, width: cellTapW, height: cellTapH }}
            onPressIn={() => onReelSelectPressFrame?.(i + 1)}
            onPressOut={() => onReelSelectPressFrame?.(0)}
            onPress={() => onReelPress(i)}
          />
        );
      })}

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
            onPress={() => onSelectMultiplier(m)}
          />
        );
      })}

      {powerDefs.map(p =>
        p.state && p.state.visible && p.state.onPress ? (
          <Pressable
            key={p.key}
            style={{
              position: 'absolute',
              left: p.hit.left * f,
              top: p.hit.top * f,
              width: p.hit.width * f,
              height: p.hit.height * f,
            }}
            onPress={() => {
              if (p.state?.frame !== 2) p.state?.onPress?.();
            }}
          />
        ) : null,
      )}

      {shiftActive && onShiftReel && SHIFT_ARROW_HITS.map((arrows, i) =>
        (['up', 'down'] as const).map(dir => {
          const r = arrows[dir];
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
              onPressIn={() => onShiftPressFrame?.(1 + i * 2 + (dir === 'up' ? 1 : 0))}
              onPressOut={() => onShiftPressFrame?.(0)}
              onPress={() => onShiftReel(i, dir === 'up' ? 1 : -1)}
            />
          );
        }),
      )}

      {onLeverPull && (
        <Pressable
          style={{
            position: 'absolute',
            top: LEVER_HIT.top * f,
            left: LEVER_HIT.left * f,
            width: LEVER_HIT.width * f,
            height: LEVER_HIT.height * f,
          }}
          onPress={onLeverPull}
        />
      )}
    </View>
  );
});

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
  hiddenOverlay: {
    opacity: 0,
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
