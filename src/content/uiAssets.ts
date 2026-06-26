import type { ImageSourcePropType } from 'react-native';

export const STASH_TRAY = require('../../assets/images/ui/stash_tray.png');

// The single coin currency: Lucidity. coin.png is the normal coin; power_coin.png
// is the every-50th "power coin" that resets a power when it reaches the counter.
export const COIN_ICON = require('../../assets/images/ui/coin.png');
export const POWER_COIN_ICON = require('../../assets/images/ui/power_coin.png');
export const DEALER_PORTRAIT = require('../../assets/images/ui/dealer_portrait.png');
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
  item_energy_drink: require('../../assets/images/items/energy_drink.png'),  // Energy Drink
  item_cocktail:     require('../../assets/images/items/cocktail.png'),      // Cocktail
  cons_focus:        require('../../assets/images/items/focus_serum.png'),   // Focus Serum
  cons_tea:          require('../../assets/images/items/herbal_tea.png'),    // Herbal Tea
};

export function itemIcon(id: string): ImageSourcePropType {
  return ITEM_ICONS[id] ?? CONSUMABLE_ICON_FALLBACK;
}
