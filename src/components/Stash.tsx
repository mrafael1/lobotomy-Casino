import React from 'react';
import { View, Image, Pressable, Text, StyleSheet } from 'react-native';
import { STASH_TRAY, itemIcon } from '../content/uiAssets';

// Stash tray art is 66x34 with two 24x24 slot depressions.
// Slot geometry from stash_tray.lua (source px), expressed as fractions.
const TRAY_W = 66;
const TRAY_H = 34;
const SLOTS = [
  { left: 4 / TRAY_W,  top: 5 / TRAY_H, w: 24 / TRAY_W, h: 24 / TRAY_H },
  { left: 38 / TRAY_W, top: 5 / TRAY_H, w: 24 / TRAY_W, h: 24 / TRAY_H },
] as const;

export interface StashSlotItem {
  id: string;
  name: string;
  charges: number;
}

interface Props {
  // Up to 2 items; index maps to physical slot. Empty slots show as receptacles.
  items: ReadonlyArray<StashSlotItem | null>;
  onUse?: (id: string) => void;
  disabled?: boolean;
  width?: number;
}

export function Stash({ items, onUse, disabled = false, width = 132 }: Props) {
  const height = width * (TRAY_H / TRAY_W);

  return (
    <View style={{ width, height }}>
      <Image source={STASH_TRAY} style={styles.tray} resizeMode="contain" />
      {SLOTS.map((slot, i) => {
        const item = items[i] ?? null;
        const sx = width * slot.left;
        const sy = height * slot.top;
        const sw = width * slot.w;
        const sh = height * slot.h;
        return (
          <Pressable
            key={i}
            style={[styles.slot, { left: sx, top: sy, width: sw, height: sh }]}
            onPress={item && onUse && !disabled ? () => onUse(item.id) : undefined}
            disabled={!item || !onUse || disabled}
          >
            {item ? (
              <>
                <Image source={itemIcon(item.id)} style={styles.icon} resizeMode="contain" />
                {item.charges > 1 && (
                  <Text style={styles.charge}>×{item.charges}</Text>
                )}
              </>
            ) : null}
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  tray: {
    width: '100%',
    height: '100%',
  },
  slot: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
  },
  icon: {
    width: '88%',
    height: '88%',
  },
  charge: {
    position: 'absolute',
    right: -1,
    bottom: -1,
    color: '#00e5ff',
    fontSize: 9,
    fontWeight: '900',
    textShadowColor: '#000',
    textShadowRadius: 3,
  },
});
