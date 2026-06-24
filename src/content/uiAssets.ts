import type { ImageSourcePropType } from 'react-native';

// Power ability icon chips (reroll / shift / memory). Rendered as the bottom
// power row in place of the old text buttons.
export const POWER_ICONS: Record<'reroll' | 'shift' | 'memory', ImageSourcePropType> = {
  reroll: require('../../assets/images/ui/power_reroll.png'),
  shift:  require('../../assets/images/ui/power_shift.png'),
  memory: require('../../assets/images/ui/power_memory.png'),
};

export const STASH_TRAY = require('../../assets/images/ui/stash_tray.png');
export const DEALER_PORTRAIT = require('../../assets/images/ui/dealer_portrait.png');
export const DEALER_HANDS = require('../../assets/images/ui/dealer_hands.png');
export const DEALER_SHOP_COUNTER = require('../../assets/images/dealer_shop_counter.png');
// Dealer shop scene art (5×-baked, 800×1200 canvas). The portrait is a 2-frame
// horizontal sheet (1600×1200) — frame swaps each time a counter item is tapped.
export const DEALER_SHOP_PORTRAIT = require('../../assets/images/dealer_portrait.png');

// Generic consumable/in-run-item icon. Per-item art is a later pass; until then
// every stash item and dealer offer renders this placeholder vial.
export const CONSUMABLE_ICON_FALLBACK = require('../../assets/images/ui/consumable_placeholder.png');

// Per-item icon registry. Add entries here as bespoke icons are authored;
// anything missing falls back to CONSUMABLE_ICON_FALLBACK. Keys are the existing
// consumable/in-run-item IDs (content/consumables.ts, content/inRunItems.ts) —
// the new items/ art is mapped onto those IDs, no duplicate item logic.
export const ITEM_ICONS: Record<string, ImageSourcePropType> = {
  item_water:        require('../../assets/images/items/water.png'),         // Glass of Water
  item_pill:         require('../../assets/images/items/Tablet.png'),        // Red Pill (a tablet)
  cons_white_powder: require('../../assets/images/items/white_powder.png'),  // White Powder
};

// The items/ art is authored at 32×32 and is meant to be shown upscaled. Display
// at an integer multiple so the pixel art stays crisp (no fractional resample).
export const ITEM_NATIVE_PX = 32;
export const ITEM_DISPLAY_SCALE = 2;

export function itemIcon(id: string): ImageSourcePropType {
  return ITEM_ICONS[id] ?? CONSUMABLE_ICON_FALLBACK;
}
