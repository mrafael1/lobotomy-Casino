import React from 'react';
import { View } from 'react-native';
import type { ImageSourcePropType, StyleProp, ViewStyle } from 'react-native';
import {
  Canvas,
  Image as SkiaImage,
  FilterMode,
  MipmapMode,
  useImage,
} from '@shopify/react-native-skia';

interface Props {
  source: ImageSourcePropType;
  frameIndex: number;
  frameCount: number;
  orientation?: 'horizontal' | 'vertical';
  // Grid sheets: number of columns. When set, frames are laid out row-major
  // (left→right, top→bottom) across ceil(frameCount / columns) rows, and
  // `orientation` is ignored.
  columns?: number;
  // Display size of a SINGLE frame (px). The source sheet is scaled to match.
  width: number;
  height: number;
  style?: StyleProp<ViewStyle>;
}

// Renders one frame of a sprite sheet via a Skia canvas. The whole sheet is
// scaled so a single frame is exactly (width × height), then shifted so the
// requested frame sits inside the canvas (Skia clips to the canvas bounds).
//
// Why Skia instead of RN <Image>: RN's Image always samples with bilinear
// filtering when scaling, which softens nearest-neighbour pixel art and lands
// differently per texture size (so some sheets looked crisp while others
// blurred). Skia lets us pin the sampler to FilterMode.Nearest, keeping every
// sheet crisp regardless of dimensions.
// Memoized: each frame is a Skia <Canvas> (its own GPU surface). Without memo,
// every parent re-render (jackpot blink, lever frames, lock countdowns, a coin
// count-up) re-renders all of these canvases even when their frame/size is
// unchanged. Props are primitives + a stable `source`, so a shallow compare is a
// safe, cheap gate that keeps unchanged layers off the render path.
function SpriteSheetFrameImpl({
  source,
  frameIndex,
  frameCount,
  orientation = 'horizontal',
  columns,
  width,
  height,
  style,
}: Props) {
  // useImage caches by source, so repeats of the same sheet share one decode
  // and frame changes never reload. Returns null until the first decode lands.
  const image = useImage(source as Parameters<typeof useImage>[0]);

  const idx = Math.max(0, Math.min(frameCount - 1, frameIndex));

  const cols = columns && columns > 0 ? columns : 0;
  const grid = cols > 0;
  const rows = grid ? Math.ceil(frameCount / cols) : 0;
  const horizontal = orientation === 'horizontal';

  // Full sheet size (display px) and the frame's top-left offset within it.
  let sheetW: number;
  let sheetH: number;
  let ox: number;
  let oy: number;
  if (grid) {
    sheetW = width * cols;
    sheetH = height * rows;
    ox = (idx % cols) * width;
    oy = Math.floor(idx / cols) * height;
  } else if (horizontal) {
    sheetW = width * frameCount;
    sheetH = height;
    ox = idx * width;
    oy = 0;
  } else {
    sheetW = width;
    sheetH = height * frameCount;
    ox = 0;
    oy = idx * height;
  }

  return (
    <Canvas style={[{ width, height }, style]} pointerEvents="none">
      {image && (
        <SkiaImage
          image={image}
          x={-ox}
          y={-oy}
          width={sheetW}
          height={sheetH}
          fit="fill"
          sampling={{ filter: FilterMode.Nearest, mipmap: MipmapMode.None }}
        />
      )}
    </Canvas>
  );
}

export const SpriteSheetFrame = React.memo(SpriteSheetFrameImpl);
