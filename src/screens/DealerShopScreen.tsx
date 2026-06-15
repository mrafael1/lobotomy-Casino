import React, { useState } from 'react';
import {
  View,
  Image,
  Pressable,
  Text,
  StyleSheet,
  SafeAreaView,
  Modal,
  ScrollView,
  useWindowDimensions,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useMetaStore } from '../state/metaState';
import { ABILITY_UPGRADES, CORRUPTED_UPGRADES, POSITIVE_UPGRADES, ALL_UPGRADES } from '../content/upgrades';
import { CONSUMABLES } from '../content/consumables';
import { itemIcon } from '../content/uiAssets';
import type { Upgrade } from '../content/upgrades';
import type { Consumable } from '../content/consumables';

// ─── Scene layout constants ───────────────────────────────────────────────────
// Source canvas: 320×480 → 2× runtime → 640×960.
// All coords below are in source (320×480) space; multiply by (sceneW/320) and
// (sceneH/480) to get screen pixels at runtime.
const SRC_W = 320;
const SRC_H = 480;

// Item slot size (source px)
const SLOT_W  = 44;
const SLOT_H  = 22;
const SLOT_GAP = 4;
const SLOT_X_START = 18;

// Shelf rows: { y, accent, items[] }
const SHELF_ROWS = [
  {
    key: 'powers',
    label: 'POWERS',
    accent: '#a855f7',
    y: 28,
    items: ABILITY_UPGRADES as ReadonlyArray<Upgrade>,
    type: 'upgrade' as const,
  },
  {
    key: 'positive',
    label: 'POSITIVE',
    accent: '#22c55e',
    y: 68,
    items: POSITIVE_UPGRADES as ReadonlyArray<Upgrade>,
    type: 'upgrade' as const,
  },
  {
    key: 'corrupted',
    label: 'CORRUPTED',
    accent: '#ef4444',
    y: 108,
    items: CORRUPTED_UPGRADES as ReadonlyArray<Upgrade>,
    type: 'upgrade' as const,
  },
] as const;

// Consumable slots on counter (source px)
const CONS_SLOT_W = 60;
const CONS_SLOT_X_START = 18;
const CONS_SLOT_GAP = 12;
const CONS_Y = 184;

// Dealer drag-target area (source px) — reserved for future drag-to-buy gesture
const DEALER_AREA = { x: 118, y: 136, w: 84, h: 80 };

// ─── Selected item union ──────────────────────────────────────────────────────
type ShopItem =
  | { kind: 'upgrade';    item: Upgrade }
  | { kind: 'consumable'; item: Consumable };

// ─── Component ───────────────────────────────────────────────────────────────
export function DealerShopScreen() {
  const router   = useRouter();
  const { width: screenW } = useWindowDimensions();

  // Scene fills screen width; height proportional.
  const sceneW = screenW;
  const sceneH = sceneW * (SRC_H / SRC_W);
  const sx = (v: number) => (v / SRC_W) * sceneW;  // source-x → screen-x
  const sy = (v: number) => (v / SRC_H) * sceneH;  // source-y → screen-y

  const lucidityWallet      = useMetaStore(s => s.lucidityWallet);
  const ownedPermanents     = useMetaStore(s => s.ownedPermanents);
  const pendingConsumables  = useMetaStore(s => s.pendingConsumables);
  const buyUpgrade          = useMetaStore(s => s.buyUpgrade);
  const buyConsumableCharge = useMetaStore(s => s.buyConsumableCharge);

  const [selected, setSelected] = useState<ShopItem | null>(null);

  // ── Status helpers ────────────────────────────────────────────────────────
  function upgradeStatus(u: Upgrade) {
    if (ownedPermanents.includes(u.id))                                return 'owned';
    if (u.requiresId && !ownedPermanents.includes(u.requiresId))       return 'locked';
    if (lucidityWallet < u.cost)                                       return 'tooPoor';
    return 'buyable';
  }

  function consumableStatus(c: Consumable) {
    const charges = pendingConsumables[c.id] ?? 0;
    if (charges >= 2)  return 'maxed';
    if (lucidityWallet < c.shopCost) return 'tooPoor';
    const slots = Object.values(pendingConsumables).filter(n => (n ?? 0) > 0).length;
    if (charges === 0 && slots >= 2) return 'slotsFull';
    return 'buyable';
  }

  // ── Buy dispatch ─────────────────────────────────────────────────────────
  function handleBuy() {
    if (!selected) return;
    if (selected.kind === 'upgrade') {
      buyUpgrade(selected.item.id);
    } else {
      buyConsumableCharge(selected.item.id);
    }
    setSelected(null);
  }

  // ── Slot icon helper ─────────────────────────────────────────────────────
  function ItemSlot({
    item, accent, slotX, slotY, w, h,
  }: {
    item: Upgrade | Consumable | null;
    accent: string;
    slotX: number; slotY: number; w: number; h: number;
  }) {
    if (!item) return null;

    const isUpgrade    = 'cost' in item;
    const shopItem: ShopItem = isUpgrade
      ? { kind: 'upgrade',    item: item as Upgrade }
      : { kind: 'consumable', item: item as Consumable };

    const isSelected = selected?.item.id === item.id;
    const owned = isUpgrade && ownedPermanents.includes((item as Upgrade).id);

    return (
      <Pressable
        style={[
          styles.slot,
          {
            left: sx(slotX), top: sy(slotY),
            width: sx(w), height: sy(h),
            borderColor: isSelected ? accent : accent + '55',
          },
          owned && styles.slotOwned,
        ]}
        onPress={() => setSelected(isSelected ? null : shopItem)}
      >
        <Image
          source={itemIcon(item.id)}
          style={styles.slotIcon}
          resizeMode="contain"
        />
        {owned && <View style={[styles.ownedDot, { backgroundColor: accent }]} />}
      </Pressable>
    );
  }

  // ── Description modal ─────────────────────────────────────────────────────
  function renderDescription() {
    if (!selected) return null;
    const { item, kind } = selected;
    const isUpgrade = kind === 'upgrade';
    const u = isUpgrade ? (item as Upgrade) : null;
    const c = !isUpgrade ? (item as Consumable) : null;

    const cost     = isUpgrade ? u!.cost : c!.shopCost;
    const status   = isUpgrade ? upgradeStatus(u!) : consumableStatus(c!);
    const accent   = isUpgrade
      ? (u!.category === 'corrupted' ? '#ef4444' : u!.category === 'positive' ? '#22c55e' : '#a855f7')
      : '#00e5ff';
    const canBuy   = status === 'buyable';

    return (
      <View style={styles.descPanel}>
        <Text style={[styles.descName, { color: accent }]}>{item.name}</Text>
        <Text style={styles.descText}>{item.description}</Text>
        {status === 'locked'    && <Text style={styles.descWarn}>Requires previous tier</Text>}
        {status === 'tooPoor'   && <Text style={styles.descWarn}>Not enough Lucidity</Text>}
        {status === 'maxed'     && <Text style={styles.descWarn}>Slots maxed</Text>}
        {status === 'slotsFull' && <Text style={styles.descWarn}>Supply slots full</Text>}
        <View style={styles.descActions}>
          <Text style={[styles.descCost, { color: accent }]}>
            {status === 'owned' ? 'OWNED' : `${cost} L`}
          </Text>
          {canBuy && (
            <Pressable
              style={[styles.buyBtn, { backgroundColor: accent }]}
              onPress={handleBuy}
            >
              <Text style={styles.buyBtnText}>TAKE IT</Text>
            </Pressable>
          )}
          <Pressable style={styles.closeBtn} onPress={() => setSelected(null)}>
            <Text style={styles.closeBtnText}>✕</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <View style={[styles.scene, { width: sceneW, height: sceneH }]}>
        {/* Background scene */}
        <Image
          source={require('../../assets/images/dealer_shop_bg.png')}
          style={StyleSheet.absoluteFill}
          resizeMode="stretch"
        />

        {/* ── Powers shelf ─────────────────────────────────────────────── */}
        {SHELF_ROWS.map(shelf =>
          shelf.items.map((item, idx) => (
            <ItemSlot
              key={item.id}
              item={item}
              accent={shelf.accent}
              slotX={SLOT_X_START + idx * (SLOT_W + SLOT_GAP)}
              slotY={shelf.y}
              w={SLOT_W}
              h={SLOT_H}
            />
          ))
        )}

        {/* ── Consumables on counter ───────────────────────────────────── */}
        {CONSUMABLES.map((c, idx) => (
          <ItemSlot
            key={c.id}
            item={c}
            accent="#00e5ff"
            slotX={CONS_SLOT_X_START + idx * (CONS_SLOT_W + CONS_SLOT_GAP)}
            slotY={CONS_Y}
            w={CONS_SLOT_W}
            h={26}
          />
        ))}

        {/* ── Description panel (anchored bottom of scene) ─────────────── */}
        <View style={[styles.descAnchor, { top: sy(310) }]}>
          {renderDescription()}
        </View>
      </View>

      {/* HUD — wallet + back — outside scene so it sits above on safe area */}
      <SafeAreaView style={styles.hud} pointerEvents="box-none">
        <View style={styles.hudRow}>
          <Pressable style={styles.backBtn} onPress={() => router.back()}>
            <Text style={styles.backText}>← BACK</Text>
          </Pressable>
          <Text style={styles.wallet}>{lucidityWallet} L</Text>
        </View>
      </SafeAreaView>
    </View>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#08040e',
  },
  scene: {
    position: 'relative',
    overflow: 'hidden',
  },

  // ── Slot icons ────────────────────────────────────────────────────────────
  slot: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderRadius: 2,
    backgroundColor: 'rgba(8,4,20,0.7)',
  },
  slotOwned: {
    opacity: 0.55,
  },
  slotIcon: {
    width: '80%',
    height: '80%',
  },
  ownedDot: {
    position: 'absolute',
    top: 2,
    right: 2,
    width: 4,
    height: 4,
    borderRadius: 2,
  },

  // ── Description panel ────────────────────────────────────────────────────
  descAnchor: {
    position: 'absolute',
    left: 0,
    right: 0,
    paddingHorizontal: 12,
  },
  descPanel: {
    backgroundColor: 'rgba(10,4,22,0.94)',
    borderColor: '#a855f733',
    borderWidth: 1,
    borderRadius: 10,
    padding: 14,
    gap: 8,
  },
  descName: {
    fontSize: 15,
    fontWeight: '900',
    letterSpacing: 2,
  },
  descText: {
    color: '#94a3b8',
    fontSize: 12,
    lineHeight: 18,
  },
  descWarn: {
    color: '#f97316',
    fontSize: 11,
    fontWeight: '700',
  },
  descActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingTop: 4,
  },
  descCost: {
    fontSize: 14,
    fontWeight: '900',
    flex: 1,
  },
  buyBtn: {
    borderRadius: 6,
    paddingVertical: 8,
    paddingHorizontal: 16,
  },
  buyBtnText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 1,
  },
  closeBtn: {
    padding: 8,
  },
  closeBtnText: {
    color: '#64748b',
    fontSize: 16,
    fontWeight: '700',
  },

  // ── HUD ──────────────────────────────────────────────────────────────────
  hud: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
  },
  hudRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 10,
  },
  backBtn: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 6,
    backgroundColor: 'rgba(0,0,0,0.5)',
    borderWidth: 1,
    borderColor: '#00e5ff44',
  },
  backText: {
    color: '#00e5ff',
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 2,
  },
  wallet: {
    color: '#00e5ff',
    fontSize: 14,
    fontWeight: '900',
    letterSpacing: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
});
