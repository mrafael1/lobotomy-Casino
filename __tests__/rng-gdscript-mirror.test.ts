// Day-1 gate: prove the GDScript Mulberry32 spec is BIT-EXACT with the canonical
// JS createRNG — without needing a Godot binary.
//
// GDScript `int` is 64-bit signed with no native uint32 / Math.imul, so the port
// masks every step to 32 bits and reimplements imul. The danger is that
// (a & M32) * (b & M32) overflows int64; the spec relies on that overflow wrapping
// mod 2^64 and then keeping only the low 32 bits. JS doubles can't represent that
// product, so this mirror models a Godot int64 with BigInt + explicit 64-bit
// two's-complement wrap, then runs the EXACT statements the GDScript rng.gd will
// run. If this matches createRNG for every seed/iteration, the GDScript spec is
// proven correct.
//
// rng.gd must mirror this logic line-for-line.

import { readFileSync } from 'fs';
import { join } from 'path';
import { createRNG } from '../src/game/rng';

const M32 = 0xFFFFFFFFn;
const TWO32 = 0x100000000n;
const TWO63 = 1n << 63n;
const TWO64 = 1n << 64n;
const MASK64 = TWO64 - 1n;

// Model a Godot int64: wrap a BigInt into signed 64-bit two's complement.
function wrap64(x: bigint): bigint {
  x &= MASK64;
  if (x >= TWO63) x -= TWO64;
  return x;
}

// Mirrors gdscript:  func _imul(a, b) -> int  (32-bit signed multiply == Math.imul)
function imul(a: bigint, b: bigint): bigint {
  let r = wrap64((a & M32) * (b & M32)); // int64 product, overflow wraps
  r = r & M32;                            // low 32 bits (0 .. 2^32-1)
  if (r >= 0x80000000n) r -= TWO32;       // to signed, mirroring JS for the XORs
  return r;
}

// Mirrors gdscript next(): operates entirely in Godot-int space.
function makeGodotRNG(seed: number): () => number {
  let s = BigInt(seed >>> 0) & M32;
  return (): number => {
    s = (s + 0x6d2b79f5n) & M32;            // mask each step (== JS accumulate then ToUint32)
    let t = s;
    t = imul(t ^ ((t & M32) >> 15n), t | 1n);
    t = t ^ (t + imul((t & M32) ^ ((t & M32) >> 7n), t | 61n));
    const out = ((t & M32) ^ ((t & M32) >> 14n)) & M32; // uint32
    return Number(out) / 4294967296;
  };
}

// Float -> exact uint32 (float === u32 / 2^32, exactly representable).
function toU32(f: number): number {
  return Math.round(f * 4294967296);
}

const SEEDS = [0, 1, 42, 7777, 123456, 0xDEADBEEF, 0xFFFFFFFF, 2654435769, 999999999];

describe('GDScript Mulberry32 spec parity (Day-1 gate)', () => {
  test('imul reproduces Math.imul across edge values', () => {
    const samples = [0, 1, -1, 2, 0x7fffffff, -0x80000000, 0xffffffff, 0x12345678, 0x9e3779b9, 3, 61];
    for (const a of samples) {
      for (const b of samples) {
        const expected = Math.imul(a, b);
        const got = Number(imul(BigInt(a), BigInt(b)));
        expect(got).toBe(expected);
      }
    }
  });

  test('GDScript-modeled RNG matches createRNG bit-exactly for 2000 iterations', () => {
    for (const seed of SEEDS) {
      const js = createRNG(seed);
      const gd = makeGodotRNG(seed);
      for (let i = 0; i < 2000; i++) {
        const a = toU32(js());
        const b = toU32(gd());
        if (a !== b) {
          throw new Error(`Divergence at seed ${seed >>> 0}, iter ${i}: js u32=${a}, gdscript u32=${b}`);
        }
      }
    }
  });

  test('GDScript-modeled RNG reproduces the committed rng.json vectors', () => {
    const rng = JSON.parse(
      readFileSync(join(__dirname, '..', 'parity', 'vectors', 'rng.json'), 'utf8'),
    ) as { seeds: number[]; count: number; vectors: Record<string, { u32: number[] }> };

    for (const seed of rng.seeds) {
      const gd = makeGodotRNG(seed);
      const expected = rng.vectors[String(seed >>> 0)].u32;
      for (let i = 0; i < expected.length; i++) {
        expect(toU32(gd())).toBe(expected[i]);
      }
    }
  });
});
