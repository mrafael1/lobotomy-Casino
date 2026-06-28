import { Image } from 'react-native';
import {
  DEALER_SHOP_COUNTER,
  DEALER_SHOP_PORTRAIT,
  STASH_TRAY,
  COIN_ICON,
  POWER_COIN_ICON,
  CONSUMABLE_ICON_FALLBACK,
  ITEM_ICONS,
} from '../content/uiAssets';
import {
  MACHINE_V3,
  REEL_BG_V3,
  MULTIPLIER_V3,
  LEVER_V3,
  JACKPOT_V3,
  REROLL_V3,
  SHIFT_V3,
  LOCK_V3,
  SHIFT_POWER_V3,
  LOCK_POWER_V3,
  REEL_SELECT_V3,
  WEALTH_TRACK_V3,
  WEALTH_FILL_V3,
  HEALTH_TRACK_V3,
  HEALTH_FILL_V3,
  SYMBOLS_SHEET_V3,
} from '../content/machineAssets';
import { afterInteractions } from './interaction';
import { preloadSkiaImages } from './skiaImageCache';

let didPreload = false;

// Sprite sheets drawn through SpriteSheetFrame (Skia). Decoded once into the
// persistent Skia cache so they don't re-decode (and pop in late) every time the
// machine scene remounts — e.g. on the first lever pull or returning from the
// dealer. The plain RN <Image> layers (cabinet, reel bg, TV bars) are handled by
// Image.prefetch below.
const SKIA_SHEETS = [
  LEVER_V3,
  MULTIPLIER_V3,
  JACKPOT_V3,
  REROLL_V3,
  SHIFT_V3,
  LOCK_V3,
  SHIFT_POWER_V3,
  LOCK_POWER_V3,
  REEL_SELECT_V3,
] as const;

const ASSETS = [
  require('../../assets/images/bg_black.png'),
  require('../../assets/images/dealer_shop_bg.png'),
  DEALER_SHOP_COUNTER,
  DEALER_SHOP_PORTRAIT,
  STASH_TRAY,
  COIN_ICON,
  POWER_COIN_ICON,
  CONSUMABLE_ICON_FALLBACK,
  ...Object.values(ITEM_ICONS),
  MACHINE_V3,
  REEL_BG_V3,
  MULTIPLIER_V3,
  LEVER_V3,
  JACKPOT_V3,
  REROLL_V3,
  SHIFT_V3,
  LOCK_V3,
  SHIFT_POWER_V3,
  LOCK_POWER_V3,
  REEL_SELECT_V3,
  WEALTH_TRACK_V3,
  WEALTH_FILL_V3,
  HEALTH_TRACK_V3,
  HEALTH_FILL_V3,
  SYMBOLS_SHEET_V3,
] as const;

export function preloadGameImages(): void {
  if (didPreload) return;
  didPreload = true;

  afterInteractions(() => {
    ASSETS.forEach(source => {
      const resolved = Image.resolveAssetSource(source);
      if (resolved?.uri) Image.prefetch(resolved.uri).catch(() => undefined);
    });
    // Decode the Skia sprite sheets into the persistent cache too.
    preloadSkiaImages(SKIA_SHEETS).catch(() => undefined);
  });
}
