import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  withTiming,
  useAnimatedStyle,
  interpolateColor,
} from 'react-native-reanimated';
import { useRunStore } from '../state/runState';
import { ECONOMY } from '../content/economy';

export function NeuronBar() {
  const neurons          = useRunStore(s => s.neurons);
  const startingNeurons  = useRunStore(s => s.startingNeurons);
  const hideNeuronsSpins = useRunStore(s => s.hideNeuronsSpins);

  const blinded = hideNeuronsSpins > 0;

  const progress = useSharedValue(1); // 1 = full, 0 = empty

  useEffect(() => {
    const ratio = startingNeurons > 0 ? neurons / startingNeurons : 0;
    progress.value = withTiming(ratio, { duration: 400 });
  }, [neurons, startingNeurons]);

  const barStyle = useAnimatedStyle(() => ({
    width: `${progress.value * 100}%` as `${number}%`,
    backgroundColor: interpolateColor(
      progress.value,
      [0, 0.3, 0.6, 1],
      ['#ef4444', '#f97316', '#eab308', '#00e5ff'],
    ),
  }));

  if (blinded) {
    return (
      <View style={styles.root}>
        <Text style={styles.label}>NEURONS</Text>
        <View style={styles.track}>
          <View style={styles.fillBlinded} />
        </View>
        <Text style={styles.countBlinded}>?? / ??  ({hideNeuronsSpins} spins)</Text>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <Text style={styles.label}>NEURONS</Text>
      <View style={styles.track}>
        <Animated.View style={[styles.fill, barStyle]} />
      </View>
      <Text style={styles.count}>{neurons} / {startingNeurons}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    paddingHorizontal: 20,
    paddingVertical: 8,
    gap: 4,
  },
  label: {
    color: '#94a3b8',
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 3,
  },
  track: {
    height: 6,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 3,
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    borderRadius: 3,
  },
  fillBlinded: {
    height: '100%',
    width: '100%',
    borderRadius: 3,
    backgroundColor: 'rgba(168,85,247,0.35)',
  },
  count: {
    color: '#e2e8f0',
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'right',
  },
  countBlinded: {
    color: '#a855f7',
    fontSize: 12,
    fontWeight: '700',
    textAlign: 'right',
    letterSpacing: 1,
  },
});
