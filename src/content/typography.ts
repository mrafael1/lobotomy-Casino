// ── Central pixel-art typography ─────────────────────────────────────────────
// The DTM (Undertale-style) pixel fonts live at assets/font/DTM-Sans.otf and
// DTM-Mono.otf, loaded via expo-font's useFonts() in app/_layout.tsx. These
// constants are the family keys — they MUST equal each font's internal family
// name AND the useFonts() key ("Determination Sans" / "Determination Mono"), NOT
// the filename (a filename key makes iOS silently fall back to the system font).
//
// All visible game text must resolve to one of these two ("dtm.sans" / "dtm.mono")
// — never a default RN font. They apply app-wide via the <Text> wrapper in
// components/PixelText.tsx (RN 0.81's Text is a function component, so a global
// monkey-patch can't work).
//
// IMPORTANT: DTM ships a SINGLE weight. Setting fontWeight (e.g. '900') makes
// Android drop the pixel font for the system sans — leave fontWeight unset on
// pixel-font text.
export const DTM_SANS = 'Determination Sans'; // dtm.sans
export const DTM_MONO = 'Determination Mono'; // dtm.mono

// Default game font. Resolves to dtm.sans.
export const PIXEL_FONT = DTM_SANS;
