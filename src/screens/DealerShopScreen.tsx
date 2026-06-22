import React, { useState } from 'react';
import {
  View,
  Image,
  Pressable,
  Text,
  StyleSheet,
  useWindowDimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useMetaStore } from '../state/metaState';
import { CONSUMABLES } from '../content/consumables';
import { itemIcon, DEALER_SHOP_COUNTER, DEALER_SHOP_PORTRAIT } from '../content/uiAssets';
import { Stash } from '../components/Stash';
import type { Consumable } from '../content/consumables';

// ─── Scene geometry ───────────────────────────────────────────────────────────
// All scene art is baked on the same 800×1200 canvas (logical 160×240 at 5×).
// Layout coords below are in that 800×1200 pixel space; sx()/sy() convert to
// screen pixels at runtime. The three full-screen layers (bg → dealer → counter)
// are each stretched to fill the screen, so the overlays line up with the art.
const SRC_W = 800;
const SRC_H = 1200;

// Counter circles — the "slots" consumables rest in. Centres measured from
// dealer_shop_counter.png (uniform 110px pitch, radius ≈18px, row at y≈847).
const CIRCLE_CX = [77, 187, 297, 407, 517, 627] as const;
const CIRCLE_CY = 847;
const CIRCLE_R  = 18;

// Consumable icon resting in a circle: base sits on the circle bottom, the
// circle peeking out beneath reads as the slot/shadow it rests in.
const CONS_ICON = 56;

// TV screen (baked into dealer_shop_bg.png, far left). The selected item's
// explanation is rendered onto this dark panel. Inner safe area is inset from
// the bezel/rounded corners.
const TV = { left: 24, top: 446, width: 168, height: 104 } as const;

// Dealer portrait is a 2-frame horizontal sheet (1600×1200). Each frame is a
// full 800×1200 canvas with the dealer already positioned, so we just stretch
// the whole sheet to 2× screen width and slide it to reveal one frame.

// ─── Component ───────────────────────────────────────────────────────────────
export function DealerShopScreen() {
  const router = useRouter();
  const { width: screenW, height: screenH } = useWindowDimensions();

  // The scene art is aspect-fitted (contain) into the screen rather than
  // stretched, so the pixel art is never distorted on non-2:3 displays. The
  // wall-coloured root fills any letterbox bars. This mirrors how the game
  // scene fits its background (see Background.tsx). All three layers and every
  // overlay share this same fitted frame so the coords line up.
  const SRC_AR    = SRC_W / SRC_H;
  const screenAR  = screenH > 0 ? screenW / screenH : SRC_AR;
  const fitW = screenAR > SRC_AR ? screenH * SRC_AR : screenW;
  const fitH = screenAR > SRC_AR ? screenH          : screenW / SRC_AR;
  const fitX = (screenW - fitW) / 2;
  const fitY = (screenH - fitH) / 2;
  const sceneFrame = { left: fitX, top: fitY, width: fitW, height: fitH } as const;

  // Source → screen coordinate conversion (into the fitted scene frame).
  const sx = (v: number) => fitX + (v / SRC_W) * fitW;
  const sy = (v: number) => fitY + (v / SRC_H) * fitH;

  const lucidityWallet      = useMetaStore(s => s.lucidityWallet);
  const pendingConsumables  = useMetaStore(s => s.pendingConsumables);
  const buyConsumableCharge = useMetaStore(s => s.buyConsumableCharge);

  const [selected, setSelected]   = useState<Consumable | null>(null);
  const [dealerFrame, setDealerFrame] = useState(0);

  // Stash tray (bottom-left) — mirrors the supplies queued for the next run.
  // Buying a supply drops it straight in here. Max 2 distinct types.
  const stashSlots = [0, 1].map(i => {
    const queued = CONSUMABLES.filter(c => (pendingConsumables[c.id] ?? 0) > 0);
    const c = queued[i];
    return c ? { id: c.id, name: c.name, charges: pendingConsumables[c.id] ?? 0 } : null;
  });

  function consumableStatus(c: Consumable) {
    const charges = pendingConsumables[c.id] ?? 0;
    if (charges >= 2)                      return 'maxed';
    if (lucidityWallet < c.shopCost)       return 'tooPoor';
    const slots = Object.values(pendingConsumables).filter(n => (n ?? 0) > 0).length;
    if (charges === 0 && slots >= 2)       return 'slotsFull';
    return 'buyable';
  }

  // Tapping a counter item selects it (TV explains it) and makes the dealer react.
  function handleSelect(c: Consumable) {
    setSelected(prev => (prev?.id === c.id ? prev : c));
    setDealerFrame(f => (f === 0 ? 1 : 0));
  }

  function handleBuy() {
    if (!selected) return;
    buyConsumableCharge(selected.id);
    setSelected(null);
  }

  // ── TV explanation overlay ───────────────────────────────────────────────
  function renderTV() {
    if (!selected) return null;
    return (
      <View
        style={{
          position: 'absolute',
          left:   sx(TV.left),
          top:    sy(TV.top),
          width:  sx(TV.width),
          height: sy(TV.height),
          padding: 4,
          justifyContent: 'flex-start',
        }}
        pointerEvents="none"
      >
        <Text style={styles.tvName} numberOfLines={2} adjustsFontSizeToFit minimumFontScale={0.6}>
          {selected.name}
        </Text>
        <Text style={styles.tvDesc} numberOfLines={6} adjustsFontSizeToFit minimumFontScale={0.5}>
          {selected.description}
        </Text>
      </View>
    );
  }

  // ── Buy bar (bottom, right of the stash tray) ────────────────────────────
  function renderBuyBar() {
    if (!selected) return null;
    const status = consumableStatus(selected);
    return (
      <View style={styles.buyPanel}>
        <Text style={styles.buyName}>{selected.name}</Text>
        <View style={styles.buyRow}>
          <Text style={styles.buyCost}>{selected.shopCost} L</Text>
          {status === 'buyable' && (
            <Pressable style={styles.buyBtn} onPress={handleBuy}>
              <Text style={styles.buyText}>TAKE IT</Text>
            </Pressable>
          )}
          {status === 'tooPoor'   && <Text style={styles.buyWarn}>Not enough Lucidity</Text>}
          {status === 'maxed'     && <Text style={styles.buyWarn}>Charges maxed</Text>}
          {status === 'slotsFull' && <Text style={styles.buyWarn}>Supply slots full</Text>}
          <Pressable style={styles.closeBtn} onPress={() => setSelected(null)}>
            <Text style={styles.closeText}>✕</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.root}>

      {/* ── LAYER 1: Background wall, shelves, TV ──────────────────────── */}
      <Image
        source={require('../../assets/images/dealer_shop_bg.png')}
        style={{ position: 'absolute', ...sceneFrame }}
        resizeMode="contain"
      />

      {/* ── TV explanation (drawn on the bg's TV screen) ───────────────── */}
      {renderTV()}

      {/* ── LAYER 2: Dealer (2-frame sheet, slide to reveal one frame) ─── */}
      <View
        style={{ position: 'absolute', ...sceneFrame, overflow: 'hidden' }}
        pointerEvents="none"
      >
        <Image
          source={DEALER_SHOP_PORTRAIT}
          style={{
            position: 'absolute', top: 0,
            left: -dealerFrame * fitW,
            width: fitW * 2, height: fitH,
          }}
          resizeMode="contain"
        />
      </View>

      {/* ── LAYER 3: Counter (drawn over the dealer's lower body) ───────── */}
      <Image
        source={DEALER_SHOP_COUNTER}
        style={{ position: 'absolute', ...sceneFrame }}
        resizeMode="contain"
      />

      {/* ── Consumables resting in the counter circles ─────────────────── */}
      {CONSUMABLES.map((c, idx) => {
        const cx = CIRCLE_CX[idx];
        if (cx === undefined) return null;
        const isSelected = selected?.id === c.id;
        const left = cx - CONS_ICON / 2;
        const top  = (CIRCLE_CY + CIRCLE_R) - CONS_ICON;
        return (
          <Pressable
            key={c.id}
            style={{
              position: 'absolute',
              left:   sx(left),
              top:    sy(top),
              width:  sx(CONS_ICON),
              height: sy(CONS_ICON),
              alignItems: 'center',
              justifyContent: 'flex-end',
            }}
            onPress={() => handleSelect(c)}
          >
            <Image source={itemIcon(c.id)} style={styles.consIcon} resizeMode="contain" />
            {isSelected && <View style={styles.selectedRing} />}
          </Pressable>
        );
      })}

      {/* ── Stash tray (bottom-left) — purchased supplies land here ─────── */}
      <SafeAreaView style={styles.stashAnchor} pointerEvents="box-none">
        <Text style={styles.stashLabel}>STASH</Text>
        <Stash items={stashSlots} disabled width={104} />
      </SafeAreaView>

      {/* ── Buy bar (bottom, right of the stash tray) ──────────────────── */}
      {selected && (
        <SafeAreaView style={styles.buyAnchor} pointerEvents="box-none">
          {renderBuyBar()}
        </SafeAreaView>
      )}

      {/* ── HUD ────────────────────────────────────────────────────────── */}
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
    // Wall colour, so any sub-pixel rounding gap shows the wall, never black.
    backgroundColor: '#0e081c',
  },

  consIcon: {
    width: '100%',
    height: '100%',
  },
  selectedRing: {
    position: 'absolute',
    inset: -2,
    borderWidth: 2,
    borderRadius: 6,
    borderColor: '#00e5ff',
  },

  // TV explanation text (on the in-world screen)
  tvName: {
    color: '#00e5ff',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 1,
    marginBottom: 3,
  },
  tvDesc: {
    color: '#cbd5e1',
    fontSize: 10,
    lineHeight: 13,
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

  // Buy bar anchored bottom, to the right of the stash tray
  buyAnchor: {
    position: 'absolute',
    left: 128,
    right: 12,
    bottom: 12,
  },
  buyPanel: {
    backgroundColor: 'rgba(8,4,20,0.95)',
    borderColor: 'rgba(0,229,255,0.3)',
    borderWidth: 1,
    borderRadius: 12,
    padding: 12,
    gap: 8,
  },
  buyName: {
    color: '#00e5ff',
    fontSize: 14,
    fontWeight: '900',
    letterSpacing: 1,
  },
  buyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  buyCost: {
    color: '#00e5ff',
    fontSize: 14,
    fontWeight: '900',
  },
  buyWarn: {
    color: '#f97316',
    fontSize: 11,
    fontWeight: '700',
    flex: 1,
  },
  buyBtn: {
    backgroundColor: '#00e5ff',
    borderRadius: 6,
    paddingVertical: 8,
    paddingHorizontal: 16,
    flex: 1,
  },
  buyText: {
    color: '#08020e',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 1,
    textAlign: 'center',
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
