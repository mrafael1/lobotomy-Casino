import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useRunStore } from '../state/runState';
import { ECONOMY } from '../content/economy';

interface Props {
  // Display size of the TV screen area (px). Drives font/bar scaling.
  width: number;
  height: number;
}

// App-rendered overlay for the cabinet's TV screen: money objective (score
// toward the wealth ending) and spins-left (neurons / per-spin cost). The art
// keeps the screen blank so this text is never baked into the PNG.
export function MachineScreenMeters({ width, height }: Props) {
  const scoreEarned    = useRunStore(s => s.scoreEarned);
  const neurons        = useRunStore(s => s.neurons);
  const startingN      = useRunStore(s => s.startingNeurons);

  const goal = ECONOMY.WEALTH_SCORE_THRESHOLD;
  const wealthRatio = Math.max(0, Math.min(1, scoreEarned / goal));

  // Spins remaining before flatline, measured at the BASE per-spin cost — kept
  // independent of the selected bet so changing the multiplier doesn't yank the
  // number around (a worse-feeling signal than the neuron meter itself). This is
  // a readable estimate, not the spin rule.
  const spinsLeft = Math.max(0, Math.ceil(neurons / ECONOMY.NEURON_DECAY_PER_SPIN));
  const mindRatio = startingN > 0 ? Math.max(0, Math.min(1, neurons / startingN)) : 0;

  const fontSize = Math.max(6, Math.round(width * 0.085));
  const barH = Math.max(3, Math.round(height * 0.11));
  const mindColor = mindRatio > 0.6 ? '#00e5ff' : mindRatio > 0.3 ? '#f97316' : '#ef4444';

  return (
    <View style={[styles.root, { width, height, padding: Math.round(width * 0.06) }]} pointerEvents="none">
      <View style={styles.block}>
        <Text style={[styles.label, { fontSize }]} numberOfLines={1}>
          €{scoreEarned} / €{goal}
        </Text>
        <View style={[styles.barTrack, { height: barH }]}>
          <View style={[styles.barFill, { width: `${wealthRatio * 100}%` as `${number}%`, backgroundColor: '#fbbf24' }]} />
        </View>
      </View>

      <View style={styles.block}>
        <Text style={[styles.label, { fontSize }]} numberOfLines={1}>
          SPINS LEFT: {spinsLeft}
        </Text>
        <View style={[styles.barTrack, { height: barH }]}>
          <View style={[styles.barFill, { width: `${mindRatio * 100}%` as `${number}%`, backgroundColor: mindColor }]} />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    justifyContent: 'center',
    gap: 4,
  },
  block: {
    gap: 2,
  },
  label: {
    color: '#7df9c6',
    fontWeight: '900',
    letterSpacing: 0.5,
    textShadowColor: 'rgba(0,0,0,0.8)',
    textShadowRadius: 2,
  },
  barTrack: {
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderRadius: 2,
    overflow: 'hidden',
  },
  barFill: {
    height: '100%',
    borderRadius: 2,
  },
});
