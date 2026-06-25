import React from 'react';
import {
  StyleSheet,
  View,
  useWindowDimensions,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import {
  ASSET_SCALE,
  VIRTUAL_HEIGHT,
  VIRTUAL_WIDTH,
} from '../content/layout';

type PixelSceneProps = {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
};

// Centers the 160×320 virtual game canvas and fit-scales it to the phone
// (aspect-preserving "contain" — never stretched). Children are positioned in
// asset-space (virtual × ASSET_SCALE) via vpx() and drawn at their native ×8
// resolution; the single transform here scales the whole composited canvas down
// to fit. Because the art is authored ×8 (higher than the on-screen size), that
// scale is a DOWNSCALE (supersample) which keeps the pixel art crisp.
export function PixelScene({ children, style }: PixelSceneProps) {
  const { width, height } = useWindowDimensions();
  const scale = Math.min(
    width / VIRTUAL_WIDTH,
    height / VIRTUAL_HEIGHT,
  );

  return (
    <View
      style={[StyleSheet.absoluteFill, styles.root, style]}
      pointerEvents="box-none"
    >
      <View
        style={{
          width: VIRTUAL_WIDTH * ASSET_SCALE,
          height: VIRTUAL_HEIGHT * ASSET_SCALE,
          transform: [{ scale: scale / ASSET_SCALE }],
        }}
        pointerEvents="box-none"
      >
        {children}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
