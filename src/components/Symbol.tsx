import React from 'react';
import { View, Image, StyleSheet } from 'react-native';
import { SymbolCanvas, SYMBOL_SIZE } from './SymbolCanvas';
import { SYMBOL_SPRITES } from '../content/symbolAssets';
import type { SymbolId } from '../game/types';

export { SYMBOL_SIZE };

interface Props {
  symbol: SymbolId;
  size?: number;
}

// Single swap point between the placeholder vector art and the final pixel-art
// sprites. If a PNG is registered in SYMBOL_SPRITES it renders that over the
// standard dark reel tile; otherwise it falls back to the Skia vector drawing,
// which paints its own tile. Sprites are authored transparent — the tile here is
// the shared backing so every symbol reads against the same field.
export function Symbol({ symbol, size = SYMBOL_SIZE }: Props) {
  const sprite = SYMBOL_SPRITES[symbol];

  if (!sprite) {
    return <SymbolCanvas symbol={symbol} size={size} />;
  }

  return (
    <View style={[styles.tile, { width: size, height: size, borderRadius: size * 0.08 }]}>
      <Image
        source={sprite}
        style={{ width: size, height: size }}
        resizeMode="contain"
        fadeDuration={0}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  tile: {
    backgroundColor: '#0d0d1e',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
});
