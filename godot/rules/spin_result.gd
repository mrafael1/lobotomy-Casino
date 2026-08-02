class_name SpinResult
extends RefCounted

## The contract for the dictionary RunStateStore.spin() returns.
##
## This is the most-read value in the codebase — around 110 sites reach into it,
## and it is persisted verbatim into the run save, which is why it stays a
## Dictionary rather than becoming a class with typed fields. What it was missing
## was not a type but a definition: nothing said which keys exist, which are
## always present, or which only appear when a particular boost fired.
##
## So the names live here as constants, the store writes through them, and
## validate() checks the always-present set once per spin in debug builds. A
## mistyped key now fails where it is written instead of reading back as a silent
## null three screens later.
##
## Keys come from two places. The BASE group is produced by Evaluate, the
## parity-pinned pure module, and is present on every result. The store's own
## bonus stage layers the OPTIONAL group on top, and each of those appears only
## when its boost actually applied — callers must use get() with a default, never
## bare indexing.

# --- Always present. Written by Evaluate (or by the Heart branch, which fills
# --- the same shape by hand).
const REELS := "reels"
const WIN_TYPE := "winType"
const SCORE_EARNED := "scoreEarned"
const COINS_EARNED := "coinsEarned"
const SCORE_MULTIPLIER := "scoreMultiplier"
const NEURONS_AFTER := "neuronsAfter"
const FREE_SPINS_AFTER := "freeSpinsAfter"
const IS_FREE_SPIN := "isFreeSpin"

# --- Present on every Evaluate result, absent from a Heart spin (which does not
# --- run the weighted evaluation that produces them).
const IS_JACKPOT := "isJackpot"
const FREE_SPINS_GRANTED := "freeSpinsGranted"

# --- Optional. Each is written only when its boost fired; read with get().
const HIDDEN_REEL_COUNT := "hiddenReelCount"
const COCKTAIL_APPLIED := "cocktailApplied"
const COCKTAIL_BONUS := "cocktailBonus"
const COCKTAIL_MALUS_APPLIED := "cocktailMalusApplied"
const COCKTAIL_MALUS := "cocktailMalus"
const FLATLINE_BOOST_APPLIED := "flatlineBoostApplied"
const FLATLINE_BOOST_BONUS := "flatlineBoostBonus"
const WIN_BOOST_APPLIED := "winBoostApplied"
const WIN_BOOST_PERCENT := "winBoostPercent"
const WIN_BOOST_BONUS := "winBoostBonus"
const WIN_BOOST_COMBO := "winBoostCombo"
const WIN_BOOST_BASE_SCORE := "winBoostBaseScore"
const SPECIALIST_BONUS := "specialistBonus"
const PASSIVE_LUCIDITY := "passiveLucidity"

## The keys every result carries, whatever produced it.
const REQUIRED_KEYS: Array[String] = [
	REELS,
	WIN_TYPE,
	SCORE_EARNED,
	COINS_EARNED,
	SCORE_MULTIPLIER,
	NEURONS_AFTER,
	FREE_SPINS_AFTER,
	IS_FREE_SPIN,
]

## The win types that pay. Eight places used to spell this list inline — four in
## the spin path, three in the power-outcome path, one in machine_scene — which is
## exactly the kind of literal that drifts when a ninth site adds a fourth type.
## Note "heart" is deliberately absent: a Heart spin always wins, and the one
## check that cares treats it separately (see _is_winning_result).
const PAYING_WIN_TYPES: Array[String] = ["pair", "triple", "jackpot"]

## True when this result's win type is one that pays out at all. Says nothing
## about the amount — a 0-score flatline win is not a paying type, but a pair
## that scored nothing still is.
static func is_paying_type(result: Dictionary) -> bool:
	return String(result.get(WIN_TYPE, "")) in PAYING_WIN_TYPES

## Debug-only shape check, called once where the result is assembled. It is an
## assert rather than a push_error because a result missing one of these is a
## programming error that should stop the spin in development, and in an export
## build the assert compiles out entirely — this must never cost a shipped spin.
static func validate(result: Dictionary) -> void:
	for key in REQUIRED_KEYS:
		assert(result.has(key),
			"spin result is missing the required key '%s'; keys present: %s"
				% [key, ", ".join(PackedStringArray(result.keys()))])
