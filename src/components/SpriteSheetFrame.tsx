import React from 'react';
import { View, Image, StyleSheet } from 'react-native';
import type { ImageSourcePropType, StyleProp, ViewStyle } from 'react-native';

interface Props {
  source: ImageSourcePropType;
  frameIndex: number;
  frameCount: number;
  orientation?: 'horizontal' | 'vertical';
  // Grid sheets: number of columns. When set, frames are laid out row-major
  // (left→right, top→bottom) across ceil(frameCount / columns) rows, and
  // `orientation` is ignored. Used to keep wide sheets under the GPU's max
  // texture size (a long 1D strip can exceed it and get downsampled/blurred).
  columns?: number;
  // Display size of a SINGLE frame (px). The source sheet is scaled to match.
  width: number;
  height: number;
  style?: StyleProp<ViewStyle>;
}

// Renders one frame of a sprite sheet by clipping to a single frame and shifting
// the full sheet behind the clip window. Works at any source resolution — the
// sheet is stretched so the displayed frame is exactly (width × height),
// regardless of how large the authored PNG is.
export function SpriteSheetFrame({
  source,
  frameIndex,
  frameCount,
  orientation = 'horizontal',
  columns,
  width,
  height,
  style,
}: Props) {
  const idx = Math.max(0, Math.min(frameCount - 1, frameIndex));

  // Grid mode: stretch the sheet to (cols × rows) frames and offset on both axes.
  const cols = columns && columns > 0 ? columns : 0;
  const grid = cols > 0;
  const rows = grid ? Math.ceil(frameCount / cols) : 0;
  const horizontal = orientation === 'horizontal';

  const sheetStyle = grid
    ? {
        width: width * cols,
        height: height * rows,
        transform: [
          { translateX: -(idx % cols) * width },
          { translateY: -Math.floor(idx / cols) * height },
        ],
      }
    : {
        width: horizontal ? width * frameCount : width,
        height: horizontal ? height : height * frameCount,
        transform: [
          horizontal
            ? { translateX: -idx * width }
            : { translateY: -idx * height },
        ],
      };

  return (
    <View style={[styles.clip, { width, height }, style]} pointerEvents="none">
      <Image source={source} fadeDuration={0} resizeMode="stretch" style={sheetStyle} />
    </View>
  );
}

const styles = StyleSheet.create({
  clip: {
    overflow: 'hidden',
  },
});
