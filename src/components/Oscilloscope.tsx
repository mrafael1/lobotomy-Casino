import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet, useWindowDimensions } from 'react-native';
import { useRunStore } from '../state/runState';

// Number of sample points — more = smoother trace, but more Views to render.
const N = 38;
// Height of the waveform drawable area (px).
const WAVE_H = 44;
// Update interval (ms). 50 ms ≈ 20 fps.
const TICK_MS = 50;
// How many phase units advance per tick. Controls scroll speed.
const PHASE_STEP = 0.011;

// Deterministic pseudo-noise in [-1, 1] based on column index and a seed.
function pnoise(i: number, seed: number): number {
  const v = Math.sin(i * 127.1453 + seed * 311.7231) * 43758.5453;
  return (v - Math.floor(v)) * 2 - 1;
}

// Normalised EKG waveform at position t in [0, 1). Returns a value in [-1, 1].
// P–QRS–T complex with baseline silence, roughly matching a real EKG shape.
function ekgAt(t: number): number {
  const u = ((t % 1) + 1) % 1;
  // R spike (dominant, Gaussian shaped)
  const R = Math.exp(-((u - 0.28) * (u - 0.28)) / 0.0014);
  // Q dip (just before R)
  const Q = u > 0.23 && u < 0.28 ? -Math.sin((u - 0.23) / 0.05 * Math.PI) * 0.2 : 0;
  // S dip (just after R)
  const S = u > 0.3 && u < 0.38 ? -Math.sin((u - 0.3) / 0.08 * Math.PI) * 0.25 : 0;
  // T wave
  const T = u > 0.44 && u < 0.68 ? Math.sin((u - 0.44) / 0.24 * Math.PI) * 0.28 : 0;
  // P wave
  const P = u > 0.07 && u < 0.21 ? Math.sin((u - 0.07) / 0.14 * Math.PI) * 0.18 : 0;
  return R + Q + S + T + P;
}

interface Segment {
  len: number;
  angle: number;
  cx: number;
  cy: number;
}

export function Oscilloscope() {
  const neurons          = useRunStore(s => s.neurons);
  const startingNeurons  = useRunStore(s => s.startingNeurons);
  const hideNeuronsSpins = useRunStore(s => s.hideNeuronsSpins);

  const { width: screenW } = useWindowDimensions();

  // Mutable refs so the setInterval closure always reads fresh values without
  // being included in the dependency array (avoids re-creating the interval
  // every time neurons change).
  const phaseRef  = useRef(0);
  const healthRef = useRef(1);
  const hideRef   = useRef(0);

  healthRef.current = startingNeurons > 0
    ? Math.max(0, Math.min(1, neurons / startingNeurons))
    : 1;
  hideRef.current = hideNeuronsSpins;

  // Segment layout dimensions derived from screen width + fixed padding.
  const containerW = screenW - 40; // 20 px horizontal padding each side
  const segW       = containerW / (N - 1);
  const halfH      = WAVE_H / 2;
  const maxAmp     = halfH * 0.88;

  const [segments, setSegments] = useState<Segment[]>([]);

  useEffect(() => {
    const id = setInterval(() => {
      phaseRef.current = (phaseRef.current + PHASE_STEP) % 1;

      const ph     = phaseRef.current;
      const hr     = healthRef.current;
      const hidden = hideRef.current > 0;

      // Mix of noise and EKG signal — noisier as neurons drain.
      const noiseMix   = hidden ? 1.0 : Math.max(0, 1 - hr) * 0.85;
      const ekgStrength = hidden ? 0   : Math.min(1, hr / 0.08);  // fade EKG near death
      const amp        = hidden ? maxAmp * 0.25 : maxAmp * (0.18 + hr * 0.82);
      // Noise seed changes slowly so the distortion evolves visibly rather than
      // looking completely static.
      const noiseSeed  = Math.floor(ph * 18);

      const ys: number[] = [];
      for (let i = 0; i < N; i++) {
        const t    = i / (N - 1) + ph;
        const base = ekgAt(t) * ekgStrength;
        const n    = pnoise(i, noiseSeed) * noiseMix;
        ys.push(halfH - (base + n) * amp);
      }

      const segs: Segment[] = [];
      for (let i = 0; i < N - 1; i++) {
        const y1 = ys[i], y2 = ys[i + 1];
        const dy = y2 - y1;
        segs.push({
          len:   Math.sqrt(segW * segW + dy * dy),
          angle: Math.atan2(dy, segW) * (180 / Math.PI),
          cx:    i * segW + segW / 2,
          cy:    (y1 + y2) / 2,
        });
      }
      setSegments(segs);
    }, TICK_MS);

    return () => clearInterval(id);
    // Re-create the interval only when layout dimensions change (screen rotation).
  }, [segW, halfH, maxAmp]); // eslint-disable-line react-hooks/exhaustive-deps

  const hr = healthRef.current;
  const lineColor =
    hideNeuronsSpins > 0 ? '#a855f7'
    : hr > 0.6           ? '#00e5ff'
    : hr > 0.3           ? '#f97316'
    :                       '#ef4444';

  return (
    <View style={styles.root}>
      <View style={[styles.waveArea, { height: WAVE_H }]}>
        {segments.map((seg, i) => (
          <View
            key={i}
            style={[
              styles.seg,
              {
                width:           seg.len,
                left:            seg.cx - seg.len / 2,
                top:             seg.cy - 1,
                backgroundColor: lineColor,
                transform:       [{ rotate: `${seg.angle}deg` }],
              },
            ]}
          />
        ))}
      </View>

      {hideNeuronsSpins > 0 ? (
        <Text style={styles.countBlinded}>
          ?? / ??  ({hideNeuronsSpins} spins)
        </Text>
      ) : (
        <Text style={styles.count}>{neurons} / {startingNeurons}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    paddingHorizontal: 20,
    paddingVertical:   6,
    gap:               2,
  },
  waveArea: {
    position: 'relative',
    overflow: 'hidden',
  },
  seg: {
    position:     'absolute',
    height:       2,
    borderRadius: 1,
  },
  count: {
    color:      '#e2e8f0',
    fontSize:   12,
    fontWeight: '600',
    textAlign:  'right',
  },
  countBlinded: {
    color:         '#a855f7',
    fontSize:      12,
    fontWeight:    '700',
    textAlign:     'right',
    letterSpacing: 1,
  },
});
