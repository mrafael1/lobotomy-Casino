import React from 'react';
import { View, Image, StyleSheet } from 'react-native';
import type { ImageSourcePropType } from 'react-native';

interface Props {
  track: ImageSourcePropType;   // empty bar (full-canvas frame)
  fill: ImageSourcePropType;    // full bar (full-canvas frame)
  ratio: number;                // 0..1 fill amount
  machineWidth: number;
  machineHeight: number;
  fillLeft: number;             // display px — left edge of the fill region
  fillWidth: number;            // display px — full width of the fill region
}

// Renders a TV bar as a static track plus a fill revealed left→right by ratio.
// Both art frames are full-canvas; the fill is clipped to [fillLeft, +ratio·width]
// so it lines up with the cabinet exactly. Avoids the giant 36-frame sheets.
function TvFillBarImpl({ track, fill, ratio, machineWidth, machineHeight, fillLeft, fillWidth }: Props) {
  const r = Math.max(0, Math.min(1, ratio));
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <Image source={track} style={StyleSheet.absoluteFill} resizeMode="stretch" fadeDuration={0} />
      <View
        style={{ position: 'absolute', left: fillLeft, top: 0, width: fillWidth * r, height: '100%', overflow: 'hidden' }}
      >
        <Image
          source={fill}
          style={{ position: 'absolute', left: -fillLeft, top: 0, width: machineWidth, height: machineHeight }}
          resizeMode="stretch"
          fadeDuration={0}
        />
      </View>
    </View>
  );
}

// Props are primitives + stable sources — memoized so it only re-renders when the
// fill ratio (or geometry) actually changes, not on every parent re-render.
export const TvFillBar = React.memo(TvFillBarImpl);
