import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useRunStore } from '../state/runState';
import { ECONOMY } from '../content/economy';
import { TV_SCREEN, WEALTH_BAR, HEALTH_BAR } from '../content/machineAssets';
import { PIXEL_FONT } from '../content/typography';

interface Props {
  // Display size of the meter area (px) — the TV_SCREEN rect this is drawn into.
  width: number;
  height: number;
  // Display px per source px, so labels can be placed relative to the bars.
  f: number;
}

// Small gap (in source/virtual px) between a label and the bar beneath it.
const GAP_SRC = 3;

// App-rendered readouts for the cabinet: the money/objective total (toward the
// wealth ending) and spins-left. Each label sits just ABOVE its own art fill bar
// (wealth/health) — in the meter area, not floating in the empty top of the TV.
// The fill bars themselves are art drawn by SlotMachine; this only adds the text.
export function MachineScreenMeters({ width, height, f }: Props) {
  const scoreEarned = useRunStore(s => s.scoreEarned);
  const neurons     = useRunStore(s => s.neurons);

  const goal = ECONOMY.WEALTH_SCORE_THRESHOLD;

  // Spins remaining at the BASE per-spin cost — independent of the selected bet
  // so changing the multiplier doesn't yank the number around.
  const spinsLeft = Math.max(0, Math.ceil(neurons / ECONOMY.NEURON_DECAY_PER_SPIN));

  const fontSize = Math.max(5, Math.round(width * 0.07));

  // Labels are positioned relative to this container, which is the TV_SCREEN rect.
  const labelLeft = (WEALTH_BAR.left - TV_SCREEN.left) * f;
  // Text top so its bottom sits a small gap above the bar's top edge.
  const labelTop = (barTopSrc: number) =>
    (barTopSrc - TV_SCREEN.top) * f - GAP_SRC * f - fontSize;

  return (
    <View style={{ width, height }} pointerEvents="none">
      <Text
        style={[styles.label, { fontSize, left: labelLeft, top: labelTop(WEALTH_BAR.top) }]}
        numberOfLines={1}
      >
        €{scoreEarned} / €{goal}
      </Text>
      <Text
        style={[styles.label, { fontSize, left: labelLeft, top: labelTop(HEALTH_BAR.top) }]}
        numberOfLines={1}
      >
        SPINS LEFT: {spinsLeft}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  label: {
    position: 'absolute',
    color: '#7df9c6',
    fontFamily: PIXEL_FONT,
    fontWeight: '900',
    letterSpacing: 0.5,
    textShadowColor: 'rgba(0,0,0,0.8)',
    textShadowRadius: 2,
  },
});
