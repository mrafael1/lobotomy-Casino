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
  // A short fade gives immediate, deliberate motion that masks the mount hitch,
  // so navigation feels smooth even though the underlying work is unchanged.
  return (
    <Stack
      screenOptions={{ headerShown: false, animation: 'fade', animationDuration: 220 }}
    />
  );
}
