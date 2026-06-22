import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useRunStore } from '../state/runState';
import { ECONOMY } from '../content/economy';

interface Props {
  // Display size of the TV screen area (px). Drives font scaling.
  width: number;
  height: number;
}

// App-rendered numbers for the cabinet's TV screen: money objective (score toward
// the wealth ending) and spins-left. The fill bars themselves are now art
// (Health.png / Wealth.png drawn by SlotMachine); this only adds the readouts.
export function MachineScreenMeters({ width, height }: Props) {
  const scoreEarned = useRunStore(s => s.scoreEarned);
  const neurons     = useRunStore(s => s.neurons);

  const goal = ECONOMY.WEALTH_SCORE_THRESHOLD;

  // Spins remaining at the BASE per-spin cost — independent of the selected bet
  // so changing the multiplier doesn't yank the number around.
  const spinsLeft = Math.max(0, Math.ceil(neurons / ECONOMY.NEURON_DECAY_PER_SPIN));

  const fontSize = Math.max(5, Math.round(width * 0.07));
  const screenPadding = Math.round(width * 0.06);
  const contentLeft = Math.round(width * 0.25);
  const contentRight = Math.round(width * 0.08);

  const labelStyle = [
    styles.label,
    { fontSize, marginLeft: contentLeft, marginRight: contentRight },
  ];

  // space-between puts the two readouts at the top and bottom of the screen so
  // they sit clear of the two art fill bars in the middle band.
  return (
    <View style={[styles.root, { width, height, padding: screenPadding }]} pointerEvents="none">
      <Text style={labelStyle} numberOfLines={1}>€{scoreEarned} / €{goal}</Text>
      <Text style={labelStyle} numberOfLines={1}>SPINS LEFT: {spinsLeft}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    justifyContent: 'space-between',
  },
  label: {
    color: '#7df9c6',
    fontWeight: '900',
    letterSpacing: 0.5,
    textShadowColor: 'rgba(0,0,0,0.8)',
    textShadowRadius: 2,
  },
});
