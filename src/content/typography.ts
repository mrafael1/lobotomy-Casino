// ── Central pixel-art typography ─────────────────────────────────────────────
// "Determination Sans" (Undertale-style pixel font) lives at
// assets/font/DTM-Sans.otf and is loaded via expo-font's useFonts() in
// app/_layout.tsx. PIXEL_FONT MUST equal the font's internal family name AND the
// useFonts() key — "Determination Sans", NOT the filename "DTM-Sans" (a filename
// key makes iOS silently fall back to the system font). It is applied app-wide
// via the <Text> wrapper in components/PixelText.tsx (RN 0.81's Text is a
// function component, so a global monkey-patch can't work). DTM-Mono.otf
// ("Determination Mono") is also bundled if a monospace variant is wanted later.
export const PIXEL_FONT = 'Determination Sans';
