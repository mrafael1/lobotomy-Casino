import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Image,
  Pressable,
  StyleSheet,
  useWindowDimensions,
  Animated,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { Text } from '../components/PixelText';
import { useMetaStore } from '../state/metaState';
import { useRunStore, canStoreRunConsumable } from '../state/runState';
import {
  CONSUMABLES, CONSUMABLE_MAP, MAX_CONSUMABLE_SLOTS,
  totalConsumableCopies, buildStashSlots,
} from '../content/consumables';
import { IN_RUN_ITEMS, IN_RUN_ITEM_MAP } from '../content/inRunItems';
import { ITEM_HINTS, FALLBACK_HINTS } from '../content/itemHints';
import {
  itemIcon, DEALER_SHOP_COUNTER, DEALER_SHOP_PORTRAIT, COIN_ICON,
} from '../content/uiAssets';
import { Stash } from '../components/Stash';
import { PanResponder } from 'react-native';

// ─── Scene geometry ───────────────────────────────────────────────────────────
// The bg + counter layers are baked on the full 1280×2560 canvas (logical
// 160×320 at 8×, matching the taller virtual game canvas — see content/layout.ts).
// Layout coords below are in that 1280×2560 pixel space; sx()/sy() convert a
// point and sw()/sh() convert a size into the aspect-fitted scene frame. The
// bg → dealer → counter layers all share that frame so the overlays line up.
const SRC_W = 1280;
const SRC_H = 2560;

// Counter circles — the "slots" consumables rest in. Centres measured from
// dealer_shop_counter.png (1280×2560): uniform 176px pitch, radius ≈29px,
// row at y≈1671.
const CIRCLE_CX = [124, 300, 476, 652, 820, 996] as const;
const CIRCLE_CY = 1671;
const CIRCLE_R  = 29;

// Consumable icon resting in a circle: base sits on the circle bottom, the
// circle peeking out beneath reads as the slot/shadow it rests in. Rendered at
// the art's native size (128×128), which clears the 176px circle pitch.
const CONS_ICON     = 128;
const RUN_CONS_ICON = 128;

// The big in-world TV (the black rounded screen in dealer_shop_bg.png, left of
// the dealer). Measured bounding box in the 1280×2560 scene. The dealer's
// explanation / instruction text and the selected item's effect render here —
// NOT on the small green dice panel up top.
const TV = { left: 16, top: 1008, width: 392, height: 208 } as const;

// Dealer portrait is a 2-frame horizontal sheet authored on the full 160×320
// scene canvas (2560×2560 = two 1280×2560 frames at 8×), so each frame is
// already calibrated to the scene like the bg/counter layers. It is drawn
// across the whole scene frame and slid one frame width to swap frames — no
// anchor offset or per-frame box (those were needed only by the old, shorter
// 160×240 art).

// One item shown resting on the counter — works for both the meta shop's
// pre-run consumables and the in-run dealer's run consumables.
type Offering = { id: string; name: string; description: string };

// Items that can occupy the RUN stash (pre-run consumables carried in + in-run
// items handed over by the dealer), for labelling the run-mode stash tray.
const RUN_STASH_ITEMS = [...CONSUMABLES, ...IN_RUN_ITEMS];

// ─── Component ───────────────────────────────────────────────────────────────
export function DealerShopScreen() {
  const router = useRouter();
  const { width: screenW, height: screenH } = useWindowDimensions();

  // Mode flag — the same scene serves the normal out-of-run shop AND the in-run
  // dealer event. 'run_consumables' is set by GameScreen's COME handler; absent
  // (or anything else) means the normal meta shop.
  const params = useLocalSearchParams<{ mode?: string }>();
  const runMode = params.mode === 'run_consumables';

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

  // Source → screen conversion (into the fitted scene frame). sx/sy map a point
  // (include the letterbox offset); sw/sh map a size (no offset).
  const sx = (v: number) => fitX + (v / SRC_W) * fitW;
  const sy = (v: number) => fitY + (v / SRC_H) * fitH;
  const sw = (v: number) => (v / SRC_W) * fitW;
  const sh = (v: number) => (v / SRC_H) * fitH;

  // ── Meta shop (normal mode) ──
  const lucidityWallet      = useMetaStore(s => s.lucidityWallet);
  const pendingConsumables  = useMetaStore(s => s.pendingConsumables);
  const buyConsumableCharge = useMetaStore(s => s.buyConsumableCharge);

  // ── In-run dealer visit (run_consumables mode) ──
  const dealerOfferIds     = useRunStore(s => s.dealerOfferIds);
  const runConsumables     = useRunStore(s => s.runConsumables);
  const acceptDealerOffer  = useRunStore(s => s.acceptDealerOffer);
  const declineDealerOffer = useRunStore(s => s.declineDealerOffer);
  const discardRunConsumable = useRunStore(s => s.discardRunConsumable);

  const [selected, setSelected]   = useState<Offering | null>(null);
  const [dealerFrame, setDealerFrame] = useState(0);
  // Transient dealer one-liner shown in the speech bubble after a rejected
  // purchase (not enough Lucidity / stash full). Cleared on the next selection.
  const [dealerMessage, setDealerMessage] = useState<string | null>(null);

  // Shake driver for the stash tray + dealer on a rejected purchase.
  const shake = useRef(new Animated.Value(0)).current;
  function runShake() {
    shake.setValue(0);
    Animated.sequence([
      Animated.timing(shake, { toValue: 1,  duration: 50, useNativeDriver: true }),
      Animated.timing(shake, { toValue: -1, duration: 50, useNativeDriver: true }),
      Animated.timing(shake, { toValue: 1,  duration: 50, useNativeDriver: true }),
      Animated.timing(shake, { toValue: -1, duration: 50, useNativeDriver: true }),
      Animated.timing(shake, { toValue: 0,  duration: 50, useNativeDriver: true }),
    ]).start();
  }
  const shakeX = shake.interpolate({ inputRange: [-1, 1], outputRange: [-6, 6] });

  // Safety net: if the player leaves the run-mode dealer scene by any path
  // (hardware back included) without our take/leave handler clearing it, close
  // the in-run dealer visit so the machine isn't left locked (runBusy).
  useEffect(() => {
    if (!runMode) return;
    return () => {
      const s = useRunStore.getState();
      if (s.dealerPending) s.declineDealerOffer();
    };
  }, [runMode]);

  // The offerings resting on the counter. Run mode shows ONLY the in-run
  // consumables the dealer is offering this visit — no permanent/meta items.
  const offerings: Offering[] = runMode
    ? (dealerOfferIds ?? [])
        .map(id => IN_RUN_ITEM_MAP[id])
        .filter((i): i is NonNullable<typeof i> => Boolean(i))
        .map(i => ({ id: i.id, name: i.name, description: i.description }))
    : CONSUMABLES.map(c => ({ id: c.id, name: c.name, description: c.description }));

  // Stash tray (bottom-left). Normal mode mirrors supplies queued for the next
  // run; run mode mirrors the supplies already in the current run. Duplicates
  // occupy separate slots (expanded by buildStashSlots).
  const stashSlots = buildStashSlots(
    runMode ? runConsumables : pendingConsumables,
    runMode ? RUN_STASH_ITEMS : CONSUMABLES,
  );

  function consumableStatus(id: string) {
    const c = CONSUMABLE_MAP[id];
    if (!c) return 'buyable';
    if (lucidityWallet < c.shopCost) return 'tooPoor';
    // Duplicates allowed: the only block is a full stash.
    if (totalConsumableCopies(pendingConsumables) >= MAX_CONSUMABLE_SLOTS) return 'slotsFull';
    return 'buyable';
  }

  // In-character dealer lines for a rejected purchase.
  const MSG_TOO_POOR   = '"Come back richer."';
  const MSG_STASH_FULL = '"Your pockets are full."';
  const MSG_MAXED      = '"No room for that."';

  // Tapping a counter item selects it (TV explains it) and makes the dealer react.
  function handleSelect(o: Offering) {
    setSelected(prev => (prev?.id === o.id ? prev : o));
    setDealerFrame(f => (f === 0 ? 1 : 0));
    setDealerMessage(null);
  }

  // Acquire an offering by dragging it onto the dealer/counter (and, pre-run,
  // onto the stash). Buying never ACTIVATES a consumable — it only stores/takes
  // it. On failure the dealer shakes and says why. Works in both modes (#5/#8).
  function attemptAcquire(o: Offering) {
    setSelected(o);
    if (runMode) {
      // No room? Reject with shake + message; the player can throw a stash item
      // onto the dealer to free a slot, then take again, or just leave.
      if (!canStoreRunConsumable(runConsumables, o.id)) {
        setDealerMessage(MSG_STASH_FULL);
        runShake();
        return;
      }
      // Take one, apply it to the CURRENT run, then return to the machine.
      acceptDealerOffer(o.id);
      router.back();
      return;
    }
    const status = consumableStatus(o.id);
    if (status === 'buyable') {
      buyConsumableCharge(o.id);
      setDealerMessage(null);
      return;
    }
    setDealerMessage(
      status === 'tooPoor'   ? MSG_TOO_POOR :
      status === 'slotsFull' ? MSG_STASH_FULL :
                               MSG_MAXED,
    );
    runShake();
  }

  // Drop zones. The dealer/counter is anywhere above the counter surface; the
  // stash tray sits bottom-left. An offering can be dropped on either to buy/take.
  function isOnDealer(_absX: number, absY: number): boolean {
    return absY < sy(CIRCLE_CY - CIRCLE_R);
  }
  function isOnStash(absX: number, absY: number): boolean {
    return absX < 140 && absY > screenH - 96;
  }
  function isOnAcquireZone(absX: number, absY: number): boolean {
    return isOnDealer(absX, absY) || isOnStash(absX, absY);
  }

  // Throw a stash item onto the dealer to free its slot — gives nothing back.
  function handleThrow(id: string) {
    discardRunConsumable(id);
    setDealerMessage(null);
    setDealerFrame(f => (f === 0 ? 1 : 0));
  }

  // Leave without buying — run mode dismisses the dealer offer and returns to
  // the machine; normal mode just pops back to wherever the shop was opened.
  function handleLeave() {
    if (runMode) declineDealerOffer();
    router.back();
  }

  // ── TV overlay ───────────────────────────────────────────────────────────
  // The big TV shows ONLY the compact green (+) / red (−) hints for the
  // selected item (no name, no description, no numbers) — in BOTH the in-run
  // dealer and the pre-run shop. When nothing is selected, run mode shows the
  // instruction; the pre-run shop leaves the screen blank.
  const tvBox = {
    position: 'absolute',
    left:   sx(TV.left),
    top:    sy(TV.top),
    width:  sw(TV.width),
    height: sh(TV.height),
    paddingHorizontal: sw(20),
    paddingVertical: sh(16),
    justifyContent: 'center',
  } as const;

  function renderTV() {
    if (selected) {
      const hints = ITEM_HINTS[selected.id] ?? FALLBACK_HINTS;
      return (
        <View style={[tvBox, { alignItems: 'flex-start' }]} pointerEvents="none">
          {/* Fixed size, single line, left-anchored to the TV edge — NO
              adjustsFontSizeToFit and NO centering, so the + and − lines are
              always the same size and start at the same x (never shift). */}
          <Text style={styles.tvHintPos} numberOfLines={1}>
            + {hints.positiveHint}
          </Text>
          <Text style={styles.tvHintNeg} numberOfLines={1}>
            - {hints.negativeHint}
          </Text>
        </View>
      );
    }

    if (!runMode) return null;
    return (
      <View style={tvBox} pointerEvents="none">
        <Text style={styles.tvDesc} numberOfLines={5} adjustsFontSizeToFit minimumFontScale={0.6}>
          {'Drag one to me.\nThen back to the machine.'}
        </Text>
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

      {/* ── LAYER 2: Dealer (2-frame sheet, slide to reveal one frame). Each
             frame is a full 160×320 scene canvas, so it fills the whole scene
             frame; sliding left by one frame width (fitW) swaps frames. ─── */}
      <Animated.View
        style={{ position: 'absolute', ...sceneFrame, overflow: 'hidden', transform: [{ translateX: shakeX }] }}
        pointerEvents="none"
      >
        <Image
          source={DEALER_SHOP_PORTRAIT}
          style={{
            position: 'absolute',
            top:  0,
            left: -dealerFrame * fitW,
            width:  fitW * 2,
            height: fitH,
          }}
          resizeMode="stretch"
        />
      </Animated.View>

      {/* ── LAYER 3: Counter (drawn over the dealer's lower body) ───────── */}
      <Image
        source={DEALER_SHOP_COUNTER}
        style={{ position: 'absolute', ...sceneFrame }}
        resizeMode="contain"
      />

      {/* ── TV — drawn after the counter art (the TV graphic lives there). ── */}
      {renderTV()}

      {/* ── Dealer speech bubble — a rejected-purchase line (both modes) takes
             priority; otherwise the selected item's flavor/mood. All dealer
             feedback lives here now (no bottom text box). ── */}
      {(dealerMessage || selected) && (
        <SafeAreaView style={styles.bubbleAnchor} pointerEvents="none">
          <Animated.View style={[styles.dealerBubble, { transform: [{ translateX: shakeX }] }]}>
            <Text style={styles.dealerBubbleText}>
              {dealerMessage
                ? dealerMessage
                : `"${(ITEM_HINTS[selected!.id] ?? FALLBACK_HINTS).flavorText}"`}
            </Text>
          </Animated.View>
        </SafeAreaView>
      )}

      {/* ── Consumables resting in the counter circles ─────────────────── */}
      {offerings.map((o, idx) => {
        const cx = CIRCLE_CX[idx];
        if (cx === undefined) return null;
        const isSelected = selected?.id === o.id;
        const iconBox = runMode ? RUN_CONS_ICON : CONS_ICON;
        const left = cx - iconBox / 2;
        const top  = (CIRCLE_CY + CIRCLE_R) - iconBox;
        const itemBox = {
          position: 'absolute' as const,
          left:   sx(left),
          top:    sy(top),
          width:  sw(iconBox),
          height: sh(iconBox),
          alignItems: 'center' as const,
          justifyContent: 'flex-end' as const,
        };
        const shopCost = CONSUMABLE_MAP[o.id]?.shopCost ?? 0;
        return (
          <React.Fragment key={o.id}>
            {/* PRICE + coin icon, ABOVE the consumable (pre-run shop only). */}
            {!runMode && (
              <View
                style={{
                  position: 'absolute',
                  left:  sx(cx - 70),
                  top:   sy(top - 46),
                  width: sw(140),
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
                pointerEvents="none"
              >
                <Text style={styles.priceText}>{shopCost}</Text>
                <Image source={COIN_ICON} style={styles.priceCoin} resizeMode="contain" />
              </View>
            )}

            {/* Tap selects; drag onto the dealer (or the stash, pre-run) buys/
                takes it. Drag-to-acquire works in BOTH dealer modes. */}
            <DraggableCounterItem
              boxStyle={itemBox}
              iconId={o.id}
              onTap={() => handleSelect(o)}
              onDrop={() => attemptAcquire(o)}
              dropTest={isOnAcquireZone}
            />

            {/* NAME — only for the SELECTED item, directly UNDER it. Unselected
                items show just the asset (+ price above), no name. */}
            {isSelected && (
              <View
                style={{
                  position: 'absolute',
                  left:  sx(cx - 110),
                  top:   sy(CIRCLE_CY + CIRCLE_R + 8),
                  width: sw(220),
                  alignItems: 'center',
                }}
                pointerEvents="none"
              >
                <Text
                  style={styles.itemName}
                  numberOfLines={1}
                  adjustsFontSizeToFit
                  minimumFontScale={0.6}
                >
                  {o.name.toUpperCase()}
                </Text>
              </View>
            )}
          </React.Fragment>
        );
      })}

      {/* ── Stash tray (bottom-left) — purchased / carried supplies land here.
             In run mode the items are draggable: drop one on the dealer to throw
             it out and free a slot. Pre-run, offerings can be dropped onto this
             tray to buy them (see isOnStash). ── */}
      <SafeAreaView style={styles.stashAnchor} pointerEvents="box-none">
        <Text style={styles.stashLabel}>STASH</Text>
        <Animated.View style={{ transform: [{ translateX: shakeX }] }}>
          <Stash
            items={stashSlots}
            disabled={!runMode}
            draggable={runMode}
            onThrow={handleThrow}
            dropTest={isOnDealer}
            width={104}
          />
        </Animated.View>
      </SafeAreaView>

      {/* ── HUD ────────────────────────────────────────────────────────── */}
      <SafeAreaView style={styles.hud} pointerEvents="box-none">
        <View style={styles.hudRow}>
          <Pressable style={styles.backBtn} onPress={handleLeave}>
            <Text style={styles.backText}>← {runMode ? 'LEAVE' : 'BACK'}</Text>
          </Pressable>
          {/* Run mode: the instruction copy lives on the big TV (renderTV), not
              up here. Normal shop keeps its wallet readout (Lucidity + coin). */}
          {!runMode && (
            <View style={styles.walletPill}>
              <Image source={COIN_ICON} style={styles.walletCoin} resizeMode="contain" />
              <Text style={styles.wallet}>{lucidityWallet}</Text>
            </View>
          )}
        </View>
      </SafeAreaView>
    </View>
  );
}

// ─── Draggable counter item (pre-run shop) ──────────────────────────────────
// A counter offering you can either tap (select) or drag onto the dealer to buy.
// Drag visual follows the finger; on release, a tiny move is treated as a tap, a
// drop over a valid zone fires onDrop, and any other drop springs the
// icon back to its resting circle. No physics — just a follow + snap-back.
interface DraggableCounterItemProps {
  boxStyle: object;
  iconId: string;
  onTap: () => void;
  onDrop: () => void;
  dropTest: (absX: number, absY: number) => boolean;
}

function DraggableCounterItem({
  boxStyle, iconId, onTap, onDrop, dropTest,
}: DraggableCounterItemProps) {
  const pan = useRef(new Animated.ValueXY({ x: 0, y: 0 })).current;
  const TAP_SLOP = 6;

  const responder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: (_e, g) => Math.hypot(g.dx, g.dy) > 4,
      onPanResponderGrant: () => pan.setValue({ x: 0, y: 0 }),
      onPanResponderMove: Animated.event([null, { dx: pan.x, dy: pan.y }], {
        useNativeDriver: false,
      }),
      onPanResponderRelease: (_e, g) => {
        const moved = Math.hypot(g.dx, g.dy) > TAP_SLOP;
        if (!moved) {
          onTap();
          return;
        }
        if (dropTest(g.moveX, g.moveY)) {
          onDrop();
        }
        Animated.spring(pan, { toValue: { x: 0, y: 0 }, useNativeDriver: false }).start();
      },
      onPanResponderTerminate: () => {
        Animated.spring(pan, { toValue: { x: 0, y: 0 }, useNativeDriver: false }).start();
      },
    }),
  ).current;

  return (
    <Animated.View
      {...responder.panHandlers}
      style={[boxStyle, { transform: pan.getTranslateTransform() }]}
    >
      <Image source={itemIcon(iconId)} style={styles.consIcon} resizeMode="contain" />
    </Animated.View>
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

  // TV explanation text (normal shop description / run instruction).
  tvDesc: {
    color: '#e2e8f0',
    fontSize: 19,
    lineHeight: 23,
  },

  // TV mechanical hints (run mode): compact, big, green = good / red = bad.
  // No fontWeight — DTM-Sans ships a single weight, so asking for 900 makes
  // Android drop the pixel font for the system sans. The face is already bold.
  tvHintPos: {
    color: '#22c55e',
    fontSize: 17,
    textAlign: 'left',
    marginBottom: 8,
  },
  tvHintNeg: {
    color: '#ef4444',
    fontSize: 17,
    textAlign: 'left',
  },

  // Dealer speech bubble — short flavor text, anchored near the top, clear of
  // the back button and the dice/TV/item row.
  bubbleAnchor: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    alignItems: 'center',
    paddingTop: 44,
    paddingHorizontal: 24,
  },
  dealerBubble: {
    backgroundColor: '#13091f',
    borderColor: '#a855f7',
    borderWidth: 1,
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 16,
    maxWidth: '88%',
  },
  dealerBubbleText: {
    color: '#e2e8f0',
    fontSize: 13,
    fontStyle: 'italic',
    textAlign: 'center',
    lineHeight: 17,
  },

  // Item name, shown directly under its icon on the counter. No fontWeight so
  // the DTM pixel font isn't dropped on Android (single-weight face).
  itemName: {
    color: '#00e5ff',
    fontSize: 13,
    letterSpacing: 1,
    textAlign: 'center',
    textShadowColor: '#000',
    textShadowRadius: 3,
  },
  // Price above the consumable (pre-run): big number + Lucidity coin. No
  // fontWeight (keep the DTM pixel font on Android).
  priceText: {
    color: '#fbbf24',
    fontSize: 15,
    letterSpacing: 1,
    textShadowColor: '#000',
    textShadowRadius: 3,
    marginRight: 4,
  },
  priceCoin: {
    width: 16,
    height: 16,
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
    letterSpacing: 3,
    marginBottom: 2,
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
    letterSpacing: 2,
  },
  walletPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(0,0,0,0.55)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
  walletCoin: {
    width: 14,
    height: 14,
  },
  wallet: {
    color: '#00e5ff',
    fontSize: 14,
    letterSpacing: 1,
  },
});
