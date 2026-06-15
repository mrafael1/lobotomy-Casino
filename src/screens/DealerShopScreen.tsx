import React, { useState } from 'react';
import {
  View,
  Image,
  Pressable,
  Text,
  StyleSheet,
  SafeAreaView,
  useWindowDimensions,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useMetaStore } from '../state/metaState';
import { ABILITY_UPGRADES, CORRUPTED_UPGRADES, POSITIVE_UPGRADES } from '../content/upgrades';
import { CONSUMABLES } from '../content/consumables';
import { itemIcon, DEALER_PORTRAIT, DEALER_SHOP_COUNTER } from '../content/uiAssets';
import { Stash } from '../components/Stash';
import type { Upgrade } from '../content/upgrades';
import type { Consumable } from '../content/consumables';

// ─── Scene geometry (source 320×480) ─────────────────────────────────────────
// Background stretches to fill the whole screen. All layout coords are in
// source (320×480) space; sx()/sy() convert to screen pixels at runtime.
const SRC_W = 320;
const SRC_H = 480;

// Icon size on shelves (source px). No cell border — icons float directly
// on the shelf surface. Tap target is the icon itself.
const ICON_W = 44;
const ICON_H = 44;
const ICON_GAP = 4;
const ICON_X0 = 18;

// Shelf rows — y is the centre of the icon, board is 2px below y+ICON_H/2.
const SHELF_ROWS = [
  { key: 'powers',    accent: '#a855f7', iconY: 12, items: ABILITY_UPGRADES   as ReadonlyArray<Upgrade> },
  { key: 'positive',  accent: '#22c55e', iconY: 66, items: POSITIVE_UPGRADES  as ReadonlyArray<Upgrade> },
  { key: 'corrupted', accent: '#ef4444', iconY: 120, items: CORRUPTED_UPGRADES as ReadonlyArray<Upgrade> },
] as const;

// Consumable icons sit ON the counter top (behind the counter PNG layer but
// visually resting on the bar surface). The counter PNG is transparent above
// CTOP=358 except for a subtle shadow stripe.
const CONS_ICON_W = 52;
const CONS_ICON_H = 52;
const CONS_ICON_X0 = 22;
const CONS_ICON_GAP = 16;
const CONS_ICON_Y = 295;          // centre of icon above counter (source y)

// Dealer portrait — aspect-correct, base sits at the counter top.
const DEALER_AR     = 192 / 288;  // width / height of dealer_portrait.png
const DEALER_BASE_Y = 358;        // source y where counter top begins
const DEALER_VIS_H  = 190;        // visible height of dealer in source px

// ─── Types ───────────────────────────────────────────────────────────────────
type ShopItem =
  | { kind: 'upgrade';    item: Upgrade }
  | { kind: 'consumable'; item: Consumable };

// ─── Component ───────────────────────────────────────────────────────────────
export function DealerShopScreen() {
  const router = useRouter();
  const { width: screenW, height: screenH } = useWindowDimensions();

  // Source → screen coordinate conversion (background stretches to fill screen)
  const sx = (v: number) => (v / SRC_W) * screenW;
  const sy = (v: number) => (v / SRC_H) * screenH;

  // Dealer portrait dimensions in screen space
  const dealerH    = sy(DEALER_VIS_H);
  const dealerW    = dealerH * DEALER_AR;
  const dealerLeft = (screenW - dealerW) / 2;
  const dealerTop  = sy(DEALER_BASE_Y) - dealerH;

  const lucidityWallet      = useMetaStore(s => s.lucidityWallet);
  const ownedPermanents     = useMetaStore(s => s.ownedPermanents);
  const pendingConsumables  = useMetaStore(s => s.pendingConsumables);
  const buyUpgrade          = useMetaStore(s => s.buyUpgrade);
  const buyConsumableCharge = useMetaStore(s => s.buyConsumableCharge);

  const [selected, setSelected] = useState<ShopItem | null>(null);

  // Stash tray (bottom-left) — mirrors the supplies queued for the next run.
  // Buying a supply drops it straight in here. Max 2 distinct types.
  const stashSlots = [0, 1].map(i => {
    const queued = CONSUMABLES.filter(c => (pendingConsumables[c.id] ?? 0) > 0);
    const c = queued[i];
    return c ? { id: c.id, name: c.name, charges: pendingConsumables[c.id] ?? 0 } : null;
  });

  // ── Status helpers ─────────────────────────────────────────────────────────
  function upgradeStatus(u: Upgrade) {
    if (ownedPermanents.includes(u.id))                          return 'owned';
    if (u.requiresId && !ownedPermanents.includes(u.requiresId)) return 'locked';
    if (lucidityWallet < u.cost)                                 return 'tooPoor';
    return 'buyable';
  }
  function consumableStatus(c: Consumable) {
    const charges = pendingConsumables[c.id] ?? 0;
    if (charges >= 2)                      return 'maxed';
    if (lucidityWallet < c.shopCost)       return 'tooPoor';
    const slots = Object.values(pendingConsumables).filter(n => (n ?? 0) > 0).length;
    if (charges === 0 && slots >= 2)       return 'slotsFull';
    return 'buyable';
  }

  function handleBuy() {
    if (!selected) return;
    if (selected.kind === 'upgrade') buyUpgrade(selected.item.id);
    else buyConsumableCharge(selected.item.id);
    setSelected(null);
  }

  // ── Icon slot — no cell border, just the icon ──────────────────────────────
  function IconSlot({
    item, accent, slotX, slotY, w, h,
  }: {
    item: Upgrade | Consumable;
    accent: string;
    slotX: number; slotY: number; w: number; h: number;
  }) {
    const isUpgrade = 'cost' in item;
    const shopItem: ShopItem = isUpgrade
      ? { kind: 'upgrade',    item: item as Upgrade }
      : { kind: 'consumable', item: item as Consumable };
    const isSelected = selected?.item.id === item.id;
    const owned = isUpgrade && ownedPermanents.includes((item as Upgrade).id);

    return (
      <Pressable
        style={{
          position: 'absolute',
          left: sx(slotX),
          top:  sy(slotY),
          width:  sx(w),
          height: sy(h),
          opacity: owned ? 0.45 : 1,
          alignItems: 'center',
          justifyContent: 'center',
        }}
        onPress={() => setSelected(isSelected ? null : shopItem)}
      >
        <Image
          source={itemIcon(item.id)}
          style={[
            styles.icon,
            isSelected && { tintColor: undefined, borderColor: accent, borderWidth: 2, borderRadius: 4 },
          ]}
          resizeMode="contain"
        />
        {isSelected && (
          <View style={[styles.selectedRing, { borderColor: accent }]} />
        )}
      </Pressable>
    );
  }

  // ── Description panel ──────────────────────────────────────────────────────
  function renderDescription() {
    if (!selected) return null;
    const { item, kind } = selected;
    const isUpgrade = kind === 'upgrade';
    const u = isUpgrade ? (item as Upgrade) : null;
    const c = !isUpgrade ? (item as Consumable) : null;
    const cost   = isUpgrade ? u!.cost : c!.shopCost;
    const status = isUpgrade ? upgradeStatus(u!) : consumableStatus(c!);
    const accent = isUpgrade
      ? (u!.category === 'corrupted' ? '#ef4444' : u!.category === 'positive' ? '#22c55e' : '#a855f7')
      : '#00e5ff';
    return (
      <View style={styles.descPanel}>
        <Text style={[styles.descName, { color: accent }]}>{item.name}</Text>
        <Text style={styles.descText}>{item.description}</Text>
        {status === 'locked'    && <Text style={styles.descWarn}>Requires previous tier</Text>}
        {status === 'tooPoor'   && <Text style={styles.descWarn}>Not enough Lucidity</Text>}
        {status === 'maxed'     && <Text style={styles.descWarn}>Slots maxed</Text>}
        {status === 'slotsFull' && <Text style={styles.descWarn}>Supply slots full</Text>}
        <View style={styles.descRow}>
          <Text style={[styles.descCost, { color: accent }]}>
            {status === 'owned' ? 'OWNED' : `${cost} L`}
          </Text>
          {status === 'buyable' && (
            <Pressable style={[styles.buyBtn, { backgroundColor: accent }]} onPress={handleBuy}>
              <Text style={styles.buyText}>TAKE IT</Text>
            </Pressable>
          )}
          <Pressable style={styles.closeBtn} onPress={() => setSelected(null)}>
            <Text style={styles.closeText}>✕</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.root}>

      {/* ── LAYER 1: Background wall + shelves ─────────────────────── */}
      <Image
        source={require('../../assets/images/dealer_shop_bg.png')}
        style={StyleSheet.absoluteFill}
        resizeMode="stretch"
      />

      {/* ── LAYER 2: Dealer portrait (aspect-correct) ──────────────── */}
      <Image
        source={DEALER_PORTRAIT}
        style={{
          position: 'absolute',
          left: dealerLeft,
          top:  dealerTop,
          width: dealerW,
          height: dealerH,
        }}
        resizeMode="contain"
      />

      {/* ── LAYER 3: Counter (transparent above bar, hides dealer legs) */}
      <Image
        source={DEALER_SHOP_COUNTER}
        style={StyleSheet.absoluteFill}
        resizeMode="stretch"
      />

      {/* ── Icon overlays (rendered after counter so consumables appear
           on the bar surface, shelf icons appear on the wall) ─────── */}

      {/* Shelf icons */}
      {SHELF_ROWS.map(shelf =>
        shelf.items.map((item, idx) => (
          <IconSlot
            key={item.id}
            item={item}
            accent={shelf.accent}
            slotX={ICON_X0 + idx * (ICON_W + ICON_GAP)}
            slotY={shelf.iconY}
            w={ICON_W}
            h={ICON_H}
          />
        ))
      )}

      {/* Consumable icons on the bar */}
      {CONSUMABLES.map((c, idx) => (
        <IconSlot
          key={c.id}
          item={c}
          accent="#00e5ff"
          slotX={CONS_ICON_X0 + idx * (CONS_ICON_W + CONS_ICON_GAP)}
          slotY={CONS_ICON_Y}
          w={CONS_ICON_W}
          h={CONS_ICON_H}
        />
      ))}

      {/* ── Stash tray (bottom-left) — purchased supplies land here ─── */}
      <SafeAreaView style={styles.stashAnchor} pointerEvents="box-none">
        <Text style={styles.stashLabel}>STASH</Text>
        <Stash items={stashSlots} disabled width={104} />
      </SafeAreaView>

      {/* ── Description panel (bottom, right of the stash tray) ─────── */}
      {selected && (
        <SafeAreaView style={styles.descAnchor} pointerEvents="box-none">
          {renderDescription()}
        </SafeAreaView>
      )}

      {/* ── HUD ────────────────────────────────────────────────────── */}
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

  // Icon — no cell, just the image
  icon: {
    width: '100%',
    height: '100%',
  },
  selectedRing: {
    position: 'absolute',
    inset: -2,
    borderWidth: 2,
    borderRadius: 4,
  },

  // Stash tray pinned bottom-left
  stashAnchor: {
    position: 'absolute',
    left: 12,
    bottom: 12,
    alignItems: 'center',
  },
  stashLabel: {
    color: '#00e5ff',
    fontSize: 9,
    fontWeight: '900',
    letterSpacing: 3,
    marginBottom: 2,
  },
  // Description panel anchored bottom, to the right of the stash tray
  descAnchor: {
    position: 'absolute',
    left: 128,
    right: 12,
    bottom: 12,
  },
  descPanel: {
    backgroundColor: 'rgba(8,4,20,0.95)',
    borderColor: 'rgba(168,85,247,0.25)',
    borderWidth: 1,
    borderRadius: 12,
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
  descRow: {
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
  buyText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 1,
  },
  closeBtn: {
    padding: 8,
  },
  closeText: {
    color: '#64748b',
    fontSize: 16,
    fontWeight: '700',
  },

  // HUD
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
    backgroundColor: 'rgba(0,0,0,0.55)',
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
    backgroundColor: 'rgba(0,0,0,0.55)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
});
