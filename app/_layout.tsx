import { Stack } from 'expo-router';
import { useFonts } from 'expo-font';
import { useEffect } from 'react';
import { preloadGameImages } from '../src/perf/preloadAssets';

export default function RootLayout() {
  // Load the DTM-Sans (Undertale-style) pixel font. The family key here MUST
  // match PIXEL_FONT in typography.ts. Gate rendering until it's ready so no
  // text flashes in a fallback face first.
  // Key MUST match the font's internal family name ("Determination Sans") and
  // PIXEL_FONT — using the filename ("DTM-Sans") makes iOS silently fall back to
  // the system font.
  const [fontsLoaded] = useFonts({
    'Determination Sans': require('../assets/font/DTM-Sans.otf'),
    'Determination Mono': require('../assets/font/DTM-Mono.otf'),
  });

  useEffect(() => {
    if (fontsLoaded) preloadGameImages();
  }, [fontsLoaded]);

  if (!fontsLoaded) return null;

  // Cross-fade between screens rather than a hard cut (animation: 'none').
  // Mounting a screen (decoding its art, first layout) costs a few frames, and
  // with no transition that shows up as a frozen snap — it reads as a stutter.
  // A short fade gives immediate, deliberate motion that masks the mount hitch.
  // Kept short (120ms) so the switch feels near-immediate; the mount hitch it
  // used to mask is now largely gone because the machine sprite sheets are
  // decoded once into the persistent Skia cache (see skiaImageCache) instead of
  // re-decoding on every remount.
  //
  // freezeOnBlur: false — react-native-screens freezes a blurred screen (react-
  // freeze suspends its renders) and, on return, replays a single full re-render
  // of the whole subtree. For the machine that means every Skia <Canvas> (3 reels,
  // lever, multiplier/jackpot/shift/lock/reel-select sheets, TV bars) re-rasterizes
  // in one burst — a long freeze (~1s on mid-tier Android) when coming back from
  // the dealer or scores. The machine is idle while covered, so keeping it live
  // costs nothing and makes the return instant.
  return (
    <Stack
      screenOptions={{ headerShown: false, animation: 'fade', animationDuration: 120, freezeOnBlur: false }}
    />
  );
}
