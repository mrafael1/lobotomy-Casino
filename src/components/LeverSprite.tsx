import React, { useEffect, useMemo, useRef } from 'react';
import type { StyleProp, ViewStyle } from 'react-native';
import {
  Canvas,
  Image as SkiaImage,
  useImage,
  FilterMode,
  MipmapMode,
} from '@shopify/react-native-skia';
import {
  useSharedValue,
  useDerivedValue,
  withSequence,
  withTiming,
  Easing,
  runOnJS,
} from 'react-native-reanimated';
import { getCachedSkiaImage } from '../perf/skiaImageCache';
import { LEVER_V3, LEVER_FRAME_COUNT } from '../content/machineAssets';

// Lever pull plays frames 0 → 5 quickly, fires the spin at the bottom, then snaps
// back to idle.
const LEVER_FRAME_MS = 42;

interface Props {
  // Bumped (incrementing) to request a MANUAL pull: animates AND fires the spin
  // (onLeverPull) once the lever bottoms out.
  manualPullSignal: number;
  // Bumped to request a visual-only Compulsion self-pull — animates the lever as
  // a cue but never calls onLeverPull, so it can't cause a second/duplicate spin.
  compulsionPullSignal: number;
  isSpinning: boolean;
  onLeverPull?: () => void;
  width: number;
  height: number;
  style?: StyleProp<ViewStyle>;
}

// The lever runs ENTIRELY on the UI thread.
//
// The frame is a Reanimated SharedValue; a derived value turns it into the Skia
// <Image>'s x offset, which Skia reads directly (no createAnimatedComponent, no
// useAnimatedProps). So a pull never triggers a React re-render and never touches
// the JS thread per frame — which is exactly why it used to "break" on returning
// from another scene: the old version stepped frames with React state + rAF, so
// the heavy re-render burst when the machine screen unfroze/remounted starved the
// callbacks and the pull collapsed to its last frame. A SharedValue-driven pull
// is immune to that: it plays start-to-finish regardless of JS-thread load.
//
// The sheet is read from the persistent Skia cache first, so a warm mount (every
// return from the dealer/scores) has the decoded image synchronously and the very
// first pull draws all frames. On a cold miss useImage decodes async; a pull that
// arrives before it lands is queued and replayed once ready (otherwise the early
// frames would draw nothing and only the last would show).
function LeverSpriteImpl({
  manualPullSignal,
  compulsionPullSignal,
  isSpinning,
  onLeverPull,
  width,
  height,
  style,
}: Props) {
  const cached = useMemo(() => getCachedSkiaImage(LEVER_V3), []);
  const loaded = useImage((cached ? null : LEVER_V3) as Parameters<typeof useImage>[0]);
  const image = cached ?? loaded;
  const ready = image !== null;

  const lastFrame = LEVER_FRAME_COUNT - 1;          // 5: fully pulled
  const sheetW = width * LEVER_FRAME_COUNT;          // horizontal strip of frames

  // Continuous frame position (0 → lastFrame) animated on the UI thread; the
  // derived x snaps it to whole frames so the pixel art stays crisp.
  const frame = useSharedValue(0);
  const imageX = useDerivedValue(() => {
    'worklet';
    const idx = Math.max(0, Math.min(lastFrame, Math.round(frame.value)));
    return -idx * width;
  }, [width, lastFrame]);

  // A pull in flight (JS side). Guards against overlapping triggers; cleared by
  // the animation's final callback.
  const pulling = useRef(false);
  // A pull requested before the sheet decoded; replayed once ready.
  const pendingPull = useRef<{ fireSpin: boolean } | null>(null);

  function clearPulling() { pulling.current = false; }

  function runLeverAnimation(fireSpin: boolean) {
    // Ignore repeated triggers while a pull (or spin) is already running.
    if (pulling.current || isSpinning) return;
    // Don't start against a not-yet-decoded sheet — queue and replay once ready.
    if (!ready) { pendingPull.current = { fireSpin }; return; }

    pulling.current = true;
    const pullMs = LEVER_FRAME_MS * lastFrame;       // time to reach the bottom
    const cb = onLeverPull;
    frame.value = 0;                                 // always start from idle
    frame.value = withSequence(
      // Pull down to the bottom; fire the spin (manual pulls only) when it lands.
      withTiming(lastFrame, { duration: pullMs, easing: Easing.linear }, finished => {
        'worklet';
        if (finished && fireSpin && cb) runOnJS(cb)();
      }),
      // Hold the bottom frame one beat.
      withTiming(lastFrame, { duration: LEVER_FRAME_MS }),
      // Snap back to idle and release the in-flight guard (short non-zero
      // duration so the completion callback always fires).
      withTiming(0, { duration: 60, easing: Easing.in(Easing.quad) }, finished => {
        'worklet';
        if (finished) runOnJS(clearPulling)();
      }),
    );
  }

  // Manual pull: animate + fire the spin at the bottom.
  const lastManualSignal = useRef(manualPullSignal);
  useEffect(() => {
    if (manualPullSignal === lastManualSignal.current) return;
    lastManualSignal.current = manualPullSignal;
    runLeverAnimation(true);
  }, [manualPullSignal]); // eslint-disable-line react-hooks/exhaustive-deps

  // Compulsion self-pull: animate only (the forced spin is fired by GameScreen).
  const lastCompulsionSignal = useRef(compulsionPullSignal);
  useEffect(() => {
    if (compulsionPullSignal === lastCompulsionSignal.current) return;
    lastCompulsionSignal.current = compulsionPullSignal;
    runLeverAnimation(false);
  }, [compulsionPullSignal]); // eslint-disable-line react-hooks/exhaustive-deps

  // Replay a queued pull as soon as the sheet decodes (cold-start first pull).
  useEffect(() => {
    if (!ready || !pendingPull.current) return;
    const { fireSpin } = pendingPull.current;
    pendingPull.current = null;
    runLeverAnimation(fireSpin);
  }, [ready]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <Canvas style={[{ width, height }, style]} pointerEvents="none">
      {image && (
        <SkiaImage
          image={image}
          x={imageX}
          y={0}
          width={sheetW}
          height={height}
          fit="fill"
          sampling={{ filter: FilterMode.Nearest, mipmap: MipmapMode.None }}
        />
      )}
    </Canvas>
  );
}

export const LeverSprite = React.memo(LeverSpriteImpl);
