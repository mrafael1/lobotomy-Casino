class_name LobRNG
extends RefCounted

## Mulberry32 — bit-exact RNG plus weightedPick.
##
## GDScript int is 64-bit signed with no native uint32 or Math.imul, so every step
## is masked to 32 bits and imul is reimplemented. The product inside _imul
## (a&M32)*(b&M32) overflows int64 and wraps mod 2^64; keeping only the low 32 bits
## recovers the correct result. This logic is proven bit-exact against the JS
## createRNG in __tests__/rng-gdscript-mirror.test.ts — DO NOT "simplify" it.

const M32 := 0xFFFFFFFF

var _s: int

func _init(seed: int) -> void:
	_s = seed & M32

# 32-bit signed multiply mirroring JS Math.imul.
static func imul(a: int, b: int) -> int:
	var r := (a & M32) * (b & M32) # may overflow int64 and wrap — intentional
	r = r & M32                    # keep low 32 bits (0 .. 2^32-1)
	if r >= 0x80000000:
		r -= 0x100000000           # to signed, mirroring JS for the XORs
	return r

func _next_u32() -> int:
	_s = (_s + 0x6d2b79f5) & M32
	var t := _s
	t = imul(t ^ ((t & M32) >> 15), t | 1)
	t = t ^ (t + imul((t & M32) ^ ((t & M32) >> 7), t | 61))
	return ((t & M32) ^ ((t & M32) >> 14)) & M32

# Float in [0, 1), matching JS `((t ^ (t >>> 14)) >>> 0) / 4294967296`.
func next() -> float:
	return float(_next_u32()) / 4294967296.0

# The raw uint32 (used by the RNG parity vectors). float = u32 / 4294967296.0.
func next_u32() -> int:
	return _next_u32()

# Weighted random selection. `items` is an Array of { "weight": int/float, "value": String }
# in a STABLE order. Mirrors weightedPick(): cumulative subtraction with a final
# floating-point guard returning the last item.
static func weighted_pick(items: Array, rng: LobRNG) -> String:
	var total := 0.0
	for it in items:
		total += float(it["weight"])
	var roll := rng.next() * total
	for it in items:
		roll -= float(it["weight"])
		if roll < 0.0:
			return String(it["value"])
	return String(items[items.size() - 1]["value"])
