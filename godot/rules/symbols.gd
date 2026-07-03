class_name Symbols
extends RefCounted

## Symbol definitions. Symbol ids are preserved verbatim as Strings
## so they match the parity JSON vectors exactly.

const IDS := ["brain", "eye", "pill", "syringe", "vial", "flatline", "book"]

const WEIGHT := {
	"brain": 6, "eye": 8, "pill": 9, "syringe": 9, "vial": 10, "flatline": 10, "book": 0,
}

const RARITY := {
	"brain": 10, "eye": 8, "pill": 6, "syringe": 6, "vial": 4, "flatline": 4, "book": 9,
}

# Canonical visible reel cycle (book sits outside the strip). Abilities step along this.
const BASE_SYMBOL_CYCLE := ["brain", "eye", "pill", "syringe", "vial", "flatline"]

# Book weight when the Learning upgrade is owned.
const BOOK_SYMBOL_WEIGHT := 7

# Mirrors SYMBOL_WEIGHTS — STABLE order is load-bearing for weightedPick parity.
static func symbol_weights() -> Array:
	return [
		{ "weight": 6, "value": "brain" },
		{ "weight": 8, "value": "eye" },
		{ "weight": 9, "value": "pill" },
		{ "weight": 9, "value": "syringe" },
		{ "weight": 10, "value": "vial" },
		{ "weight": 10, "value": "flatline" },
	]
