import React from 'react';
import { View, Image, StyleSheet } from 'react-native';
import type { ImageSourcePropType, StyleProp, ViewStyle } from 'react-native';

interface Props {
  source: ImageSourcePropType;
  frameIndex: number;
  frameCount: number;
  orientation?: 'horizontal' | 'vertical';
  // Display size of a SINGLE frame (px). The source sheet is scaled to match.
  width: number;
  height: number;
  style?: StyleProp<ViewStyle>;
}

// Renders one frame of a sprite sheet by clipping to a single frame and shifting
// the full sheet behind the clip window. Works at any source resolution — the
// sheet is stretched to (width × frameCount) so the displayed frame is exactly
// (width × height), regardless of how large the authored PNG is.
export function SpriteSheetFrame({
  source,
  frameIndex,
  frameCount,
  orientation = 'horizontal',
  width,
  height,
  style,
}: Props) {
  const horizontal = orientation === 'horizontal';
  const idx = Math.max(0, Math.min(frameCount - 1, frameIndex));

  return (
    <View style={[styles.clip, { width, height }, style]} pointerEvents="none">
      <Image
        source={source}
        fadeDuration={0}
        resizeMode="stretch"
        style={{
          width: horizontal ? width * frameCount : width,
          height: horizontal ? height : height * frameCount,
          transform: [
            horizontal
              ? { translateX: -idx * width }
              : { translateY: -idx * height },
          ],
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  clip: {
    overflow: 'hidden',
  },
});
