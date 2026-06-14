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

// Generic consumable/in-run-item icon. Per-item art is a later pass; until then
// every stash item and dealer offer renders this placeholder vial.
export const CONSUMABLE_ICON_FALLBACK = require('../../assets/images/ui/consumable_placeholder.png');

// Per-item icon registry. Add entries here as bespoke icons are authored;
// anything missing falls back to CONSUMABLE_ICON_FALLBACK.
export const ITEM_ICONS: Record<string, ImageSourcePropType> = {};

export function itemIcon(id: string): ImageSourcePropType {
  return ITEM_ICONS[id] ?? CONSUMABLE_ICON_FALLBACK;
}
