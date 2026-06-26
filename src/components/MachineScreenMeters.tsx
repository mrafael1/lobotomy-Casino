import React from 'react';
import { View, Image, Text, StyleSheet } from 'react-native';
import { useRunStore } from '../state/runState';
import { useAnimatedLucidity } from '../state/useAnimatedLucidity';
import { ECONOMY } from '../content/economy';
import { TV_SCREEN, WEALTH_BAR, HEALTH_BAR } from '../content/machineAssets';
import { PIXEL_FONT } from '../content/typography';
import { COIN_ICON } from '../content/uiAssets';

interface Props {
  // Display size of the meter area (px) — the TV_SCREEN rect this is drawn into.
  width: number;
  height: number;
  // Display px per source px, so labels can be placed relative to the bars.
  f: number;
}

// Small gap (in source/virtual px) between a label and the bar beneath it.
const GAP_SRC = 3;

// App-rendered readouts for the cabinet TV. The top line is the Lucidity counter
// (coin icon + total) sitting just above the Lucidity bar; below it is spins-left
// above the health bar. All TV text uses PIXEL_FONT (the DTM font) to stay
// consistent with the rest of the app. The fill bars themselves are art drawn by
// SlotMachine; this only adds the text/icon.
export function MachineScreenMeters({ width, height, f }: Props) {
  // Displayed Lucidity climbs gradually toward the real total (gameplay state is
  // already updated); shared with the TV objective bar so they animate together.
  const lucidityCoins = useAnimatedLucidity();
  const neurons       = useRunStore(s => s.neurons);

  // Spins remaining at the BASE per-spin cost — independent of the selected bet
  // so changing the multiplier doesn't yank the number around.
  const spinsLeft = Math.max(0, Math.ceil(neurons / ECONOMY.NEURON_DECAY_PER_SPIN));

  const fontSize = Math.max(5, Math.round(width * 0.07));
  const coinSize = Math.round(fontSize * 1.15);

  // Labels are positioned relative to this container, which is the TV_SCREEN rect.
  const labelLeft = (WEALTH_BAR.left - TV_SCREEN.left) * f;
  // Text top so its bottom sits a small gap above the bar's top edge.
  const labelTop = (barTopSrc: number) =>
    (barTopSrc - TV_SCREEN.top) * f - GAP_SRC * f - fontSize;

  return (
    <View style={{ width, height }} pointerEvents="none">
      <View style={[styles.lucidityRow, { left: labelLeft, top: labelTop(WEALTH_BAR.top) }]}>
        <Image
          source={COIN_ICON}
          style={{ width: coinSize, height: coinSize, marginRight: Math.round(fontSize * 0.3) }}
          resizeMode="contain"
          fadeDuration={0}
        />
        <Text style={[styles.label, { fontSize }]} numberOfLines={1}>
          {lucidityCoins} / {ECONOMY.LUCIDITY_OBJECTIVE}
        </Text>
      </View>
      <Text
        style={[styles.label, styles.absolute, { fontSize, left: labelLeft, top: labelTop(HEALTH_BAR.top) }]}
        numberOfLines={1}
      >
        SPINS LEFT: {spinsLeft}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  absolute: {
    position: 'absolute',
  },
  lucidityRow: {
    position: 'absolute',
    flexDirection: 'row',
    alignItems: 'center',
  },
  // No fontWeight: DTM ships a single weight, so requesting 900 makes Android
  // drop the pixel font for the system sans (the SPINS LEFT regression). The
  // face already reads bold at this size.
  label: {
    color: '#7df9c6',
    fontFamily: PIXEL_FONT,
    letterSpacing: 0.5,
    textShadowColor: 'rgba(0,0,0,0.8)',
    textShadowRadius: 2,
  },
});
