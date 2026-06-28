import { Image } from 'react-native';
import type { ImageSourcePropType } from 'react-native';
import { Skia } from '@shopify/react-native-skia';
import type { SkImage } from '@shopify/react-native-skia';

// Persistent Skia image cache.
//
// Skia's `useImage` hook has NO cross-mount cache: every time a component mounts
// it starts from `null` and re-fetches/decodes the source asynchronously (see
// react-native-skia's useRawData → useLoading). So each time a screen that draws
// sprite sheets remounts (e.g. returning from the dealer scene), every sheet
// pops in a frame late, and the very first lever pull plays against a not-yet-
// decoded sheet (its early frames draw nothing).
//
// This module decodes each sheet ONCE into a long-lived SkImage and keeps it.
// SpriteSheetFrame reads from here first and only falls back to `useImage` on a
// miss, so a warm remount draws immediately and the machine art is never
// recreated on a scene switch.

const cache = new Map<string, SkImage>();
let didPreload = false;

function uriFor(source: ImageSourcePropType): string | null {
  const resolved = Image.resolveAssetSource(source as Parameters<typeof Image.resolveAssetSource>[0]);
  return resolved?.uri ?? null;
}

// Synchronous lookup for render — returns the decoded image or null on a miss.
export function getCachedSkiaImage(source: ImageSourcePropType): SkImage | null {
  const uri = uriFor(source);
  if (!uri) return null;
  return cache.get(uri) ?? null;
}

// Best-effort one-time preload. Safe to call more than once. Failures are
// swallowed — SpriteSheetFrame still works via its `useImage` fallback.
export async function preloadSkiaImages(sources: readonly ImageSourcePropType[]): Promise<void> {
  if (didPreload) return;
  didPreload = true;

  await Promise.all(
    sources.map(async source => {
      const uri = uriFor(source);
      if (!uri || cache.has(uri)) return;
      try {
        const data = await Skia.Data.fromURI(uri);
        const image = Skia.Image.MakeImageFromEncoded(data);
        if (image) cache.set(uri, image);
      } catch {
        // ignore — the consuming component falls back to useImage()
      }
    }),
  );
}
