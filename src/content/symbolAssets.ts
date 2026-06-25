import type { ImageSourcePropType } from 'react-native';
import type { SymbolId } from '../game/types';

// Final pixel-art reel sprites. The slot reel renders main symbols at 32x32, so
// every sprite referenced here should be a 32x32 PNG for 1:1 pixel display.
// If a symbol's entry is null, <Symbol> falls back to the vector placeholder in
// SymbolCanvas so the game always renders.
export const SYMBOL_SPRITES: Record<SymbolId, ImageSourcePropType | null> = {
  brain:    require('../../assets/images/symbols/brain.png'),
  eye:      require('../../assets/images/symbols/eye.png'),
  pill:     require('../../assets/images/symbols/pill.png'),
  syringe:  require('../../assets/images/symbols/syringe.png'),
  vial:  require('../../assets/images/symbols/vial.png'),
  flatline: require('../../assets/images/symbols/flatline.png'),
  book:     require('../../assets/images/symbols/book_32.png'),
};
