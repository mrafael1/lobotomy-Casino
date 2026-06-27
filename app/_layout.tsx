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

  return (
    <Stack screenOptions={{ headerShown: false, animation: 'none' }} />
  );
}
