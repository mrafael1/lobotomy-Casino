import React, { useEffect } from 'react';
import { StyleSheet, Image, View } from 'react-native';
import Animated, { useSharedValue, withTiming, useAnimatedStyle } from 'react-native-reanimated';
import { useRunStore } from '../state/runState';

interface Props {
  children: React.ReactNode;
}

// Healthy and decay backgrounds cross-fade continuously as neurons drain.
// At 100% neurons: only healthy visible. At 0%: only decay visible.
export function Background({ children }: Props) {
  const neurons         = useRunStore(s => s.neurons);
  const startingNeurons = useRunStore(s => s.startingNeurons);

  const decayOpacity = useSharedValue(0);

  useEffect(() => {
    const rawRatio = startingNeurons > 0 ? neurons / startingNeurons : 1;
    const ratio = Math.max(0, Math.min(1, rawRatio));
    // Square-root curve: decay is visible from the first few spins rather
    // than requiring 40+ neurons to drain before anything is noticeable.
    decayOpacity.value = withTiming(Math.sqrt(1 - ratio), { duration: 600 });
  }, [neurons, startingNeurons]);

  const decayStyle = useAnimatedStyle(() => ({
    opacity: decayOpacity.value,
  }));

  return (
    <View style={styles.root}>
      <Image
        source={require('../../assets/images/background_healthy.png')}
        style={StyleSheet.absoluteFillObject}
        resizeMode="cover"
      />
      <Animated.Image
        source={require('../../assets/images/background_decay.png')}
        style={[StyleSheet.absoluteFillObject, decayStyle]}
        resizeMode="cover"
      />
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#030307',
  },
});
