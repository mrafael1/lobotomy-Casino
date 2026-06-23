import React from 'react';
import { Text as RNText, type TextProps } from 'react-native';
import { PIXEL_FONT } from '../content/typography';

// Drop-in replacement for react-native's <Text> that applies the shared pixel
// font (DTM-Sans). Imported in place of RN's Text across the app.
//
// Why a wrapper instead of a global patch: in RN 0.81 `Text` is a plain function
// component (the new `component(...)` syntax — no forwardRef.render), so the
// usual global monkey-patch silently no-ops. Putting the font first in the style
// array keeps any explicit per-style fontFamily overriding it.
export function Text({ style, ...rest }: TextProps) {
  return <RNText {...rest} style={[{ fontFamily: PIXEL_FONT }, style]} />;
}
