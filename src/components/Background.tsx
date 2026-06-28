import React, { useEffect } from 'react';
import { StyleSheet, Image, View, useWindowDimensions } from 'react-native';
import Animated, { useSharedValue, withTiming, useAnimatedStyle } from 'react-native-reanimated';
import { useRunStore } from '../state/runState';

interface Props {
  children: React.ReactNode;
}

const BACKGROUND_WIDTH = 640;
const BACKGROUND_HEIGHT = 960;
const BACKGROUND_ASPECT = BACKGROUND_WIDTH / BACKGROUND_HEIGHT;

// Healthy and decay backgrounds cross-fade continuously as neurons drain.
// At 100% neurons: only healthy visible. At 0%: only decay visible.
export function Background({ children }: Props) {
  const { width: screenWidth, height: screenHeight } = useWindowDimensions();
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

  const screenAspect = screenHeight > 0 ? screenWidth / screenHeight : BACKGROUND_ASPECT;
  const fittedWidth = screenAspect > BACKGROUND_ASPECT
    ? screenWidth
    : screenHeight * BACKGROUND_ASPECT;
  const fittedHeight = screenAspect > BACKGROUND_ASPECT
    ? screenWidth / BACKGROUND_ASPECT
    : screenHeight;
  const backgroundFrame = {
    width: fittedWidth,
    height: fittedHeight,
    left: (screenWidth - fittedWidth) / 2,
    top: (screenHeight - fittedHeight) / 2,
  };

  return (
    <View style={styles.root}>
      <Image
        source={require('../../assets/images/bg_black.png')}
        style={[styles.backgroundImage, backgroundFrame]}
        resizeMode="stretch"
        fadeDuration={0}
      />
      <Animated.Image
        source={require('../../assets/images/bg_black.png')}
        style={[styles.backgroundImage, backgroundFrame, decayStyle]}
        resizeMode="stretch"
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
  backgroundImage: {
    position: 'absolute',
  },
});
