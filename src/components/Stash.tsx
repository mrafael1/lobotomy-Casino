import React, { useRef } from 'react';
import { View, Image, Pressable, StyleSheet, Animated, PanResponder } from 'react-native';
import { Text } from './PixelText';
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
  // Drag-to-throw: when `draggable`, filled slots can be dragged. On release the
  // absolute drop point is passed to `dropTest`; if it returns true, `onThrow`
  // fires with the item id (otherwise the icon springs back to its slot).
  draggable?: boolean;
  onThrow?: (id: string) => void;
  dropTest?: (absX: number, absY: number) => boolean;
}

export function Stash({
  items, onUse, disabled = false, width = 132,
  draggable = false, onThrow, dropTest,
}: Props) {
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

        if (item && draggable && !disabled) {
          return (
            <DraggableSlot
              key={i}
              item={item}
              left={sx}
              top={sy}
              width={sw}
              height={sh}
              onThrow={onThrow}
              dropTest={dropTest}
            />
          );
        }

        return (
          <Pressable
            key={i}
            style={({ pressed }) => [
              styles.slot,
              { left: sx, top: sy, width: sw, height: sh },
              pressed && item && !disabled ? styles.slotPressed : null,
            ]}
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

interface DraggableSlotProps {
  item: StashSlotItem;
  left: number;
  top: number;
  width: number;
  height: number;
  onThrow?: (id: string) => void;
  dropTest?: (absX: number, absY: number) => boolean;
}

function DraggableSlot({ item, left, top, width, height, onThrow, dropTest }: DraggableSlotProps) {
  const pan = useRef(new Animated.ValueXY({ x: 0, y: 0 })).current;
  const dragging = useRef(false);

  // The responder is created once; read the latest item/callbacks through a ref
  // so a thrown slot resolves against the current item, not the mount-time one.
  const cb = useRef({ item, onThrow, dropTest });
  cb.current = { item, onThrow, dropTest };

  const responder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        dragging.current = true;
        pan.setValue({ x: 0, y: 0 });
      },
      onPanResponderMove: Animated.event([null, { dx: pan.x, dy: pan.y }], {
        useNativeDriver: false,
      }),
      onPanResponderRelease: (_evt, gesture) => {
        dragging.current = false;
        if (cb.current.dropTest?.(gesture.moveX, gesture.moveY)) {
          cb.current.onThrow?.(cb.current.item.id);
          return;
        }
        Animated.spring(pan, {
          toValue: { x: 0, y: 0 },
          useNativeDriver: false,
        }).start();
      },
      onPanResponderTerminate: () => {
        dragging.current = false;
        Animated.spring(pan, {
          toValue: { x: 0, y: 0 },
          useNativeDriver: false,
        }).start();
      },
    }),
  ).current;

  return (
    <Animated.View
      {...responder.panHandlers}
      style={[
        styles.slot,
        styles.draggable,
        { left, top, width, height, transform: pan.getTranslateTransform() },
      ]}
    >
      <Image source={itemIcon(item.id)} style={styles.icon} resizeMode="contain" />
      {item.charges > 1 && <Text style={styles.charge}>×{item.charges}</Text>}
    </Animated.View>
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
  slotPressed: {
    opacity: 0.65,
    transform: [{ scale: 0.94 }],
  },
  // Dragged icons float above neighbouring UI (buy bar, etc.).
  draggable: {
    zIndex: 50,
    elevation: 50,
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
