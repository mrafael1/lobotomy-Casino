class_name EconomyConst
extends RefCounted

## Economy constants. No magic numbers
## elsewhere — only here.

# One spin currency: 1 neuron = 1 spin (issue #85). STARTING_NEURONS is the
# intended base run length, and the run never holds more than 19 normal spins.
# The cap is what the authored health tube can draw: health_bar.png carries one
# frame per spin count (0..MAX_NEURONS), so the two move together.
const STARTING_NEURONS := 15
const NEURON_DECAY_PER_SPIN := 1
const MIN_NEURONS_TO_SPIN := 1
const MAX_NEURONS := 19
# Kept as a named compatibility constant for callers that distinguish the
# post-Wealth continuation, although the current machine also caps it at 19.
const MAX_NEURONS_ACT2 := 19
const MIN_NEURON_DECAY := 1

const BASE_MAX_FREE_SPINS := 1
const UPGRADED_MAX_FREE_SPINS := 3

const BASE_LUCIDITY_MULTIPLIER := 1.0

# Wealth objectives advance through the authored ladder. The final target is the
# ending threshold; the earlier steps keep the odometer's TARGET readout useful
# throughout a run.
const WEALTH_TARGETS := [100, 200, 500, 800, 1500, 2500, 3500, 5000]
const WEALTH_SCORE_THRESHOLD := 5000
const EXIT_LUCIDITY_THRESHOLD := 750
const LUCIDITY_OBJECTIVE := 1000
const LUCIDITY_COINS_PER_RESTORE := 50
# Soft cap on the score-driven power restore economy, held as charges: each score-driven
# restore spends one, and a spin gives one back. The pool holds a single charge and so
# cannot be banked — a spin restores at most one power however much it scores, and a spin
# that pays a pair has nothing left for the powers built on top of it. Once spent the
# gauge stops one frame short of full, exactly as it does with nothing left to restore.
# Consumables that hand a power back (Tea, Potion) are item effects, not part of this
# economy, and spend no charge.
const POWER_RESTORE_CHARGE_MAX := 1
const POWER_RESTORE_RECHARGE_PER_SPIN := 1
# Augmented spade (issue #111): spins a SPENT restore charge takes to come back, counted
# from the spend rather than from spin parity, and therefore how many pips the machine
# draws under the restore light. It lives here rather than on RunStateStore because
# reading a const through an autoload NAME makes GDScript compile that store as a plain
# class, outside the autoload context where its own singleton references resolve.
const SPADE_RESTORE_CYCLE_SPINS := 2
const END_OF_RUN_LUCIDITY_KEPT := 0.10
const SMART_SAVE_LUCIDITY_KEPT := 0.50
const SMART_SAVE_UPGRADE_ID := "pos_smart_save"
const CAMPAIGN_STARTING_NEURONS := 3

# Issue #76: a 3x-flatline strike charges the NEXT winning pair/triple to score at
# this multiplier (its points AND lucidity coins both scale, since the bonus rides
# on top of the pinned score before the coin plan). Re-armed by each strike, spent
# on the next scoring win; misses and 0-score flatline wins never spend it.
const FLATLINE_WIN_BOOST_MULT := 2

# What a run made OVER a beaten target is not banked whole: the casino bills it first.
# The bracket is picked from the overflow measured against THAT target, never from the
# raw score — the payout table is flat (a jackpot is 200 either way) while the target
# ladder spans 100..5000, so +200 is a blowout on the first goal and a rounding error on
# the sixth. Reading the ratio keeps one table honest at both ends.
# Bands are read in order; the first whose bound the ratio falls at or under wins.
const OVERFLOW_TAX_BANDS := [
	{"upTo": 0.25, "state": 0.05, "dealer": 0.05, "maintenance": 0.05},
	{"upTo": 0.75, "state": 0.15, "dealer": 0.08, "maintenance": 0.05},
	{"upTo": 1.50, "state": 0.30, "dealer": 0.12, "maintenance": 0.05},
	{"upTo": INF, "state": 0.45, "dealer": 0.15, "maintenance": 0.05},
]

# Bill rows, in the order they are stamped onto the payout screen. The key indexes the
# band dictionaries above; the label is what the player reads.
const OVERFLOW_TAX_LINES := [
	{"key": "state", "label": "STATE TAX"},
	{"key": "dealer", "label": "CASINO DEALER"},
	{"key": "maintenance", "label": "MAINTENANCE"},
]

# The augmented club charge (issue #111). It is a FLAT rate rather than a fifth column on
# the bands: one number to balance, and a row that appears out of nowhere on the receipt
# says "the casino is angry with you" more plainly than three rates quietly going up.
# Deliberately sized so the worst band takes 80%, not everything — an overflow that banks
# nothing would just teach the player to stop overshooting, which flattens the run.
const OVERFLOW_ANGER_RATE := 0.15
const OVERFLOW_ANGER_LINE := {"key": "anger", "label": "HOUSE ANGER"}


## The tax band for an overflow, as a share of the target it overshot.
static func overflow_tax_band(overflow: int, target: int) -> Dictionary:
	var ratio := float(maxi(0, overflow)) / float(maxi(1, target))
	for band: Dictionary in OVERFLOW_TAX_BANDS:
		if ratio <= float(band["upTo"]):
			return band
	return OVERFLOW_TAX_BANDS[OVERFLOW_TAX_BANDS.size() - 1]


## Itemises what the casino takes out of an overflow before it reaches the wallet.
## Returns { lines: [{key, label, rate, amount}], taxed, net, ratio }. Every line is
## floored — the rounding goes to the player — and `net` is the true remainder, so the
## rows on screen always add up to exactly what was banked.
## `anger_rate` is the augmented club charge; callers pass RunStateStore's live rate so
## this stays a pure rules file with no store dependency. 0.0 (the default) bills exactly
## as before, which is every classic run and every other suit.
static func overflow_bill(overflow: int, target: int, anger_rate := 0.0) -> Dictionary:
	var gross := maxi(0, overflow)
	var band := overflow_tax_band(gross, target)
	var billed: Array = OVERFLOW_TAX_LINES.duplicate()
	if anger_rate > 0.0:
		billed.append(OVERFLOW_ANGER_LINE)
	var lines: Array[Dictionary] = []
	var taxed := 0
	for line: Dictionary in billed:
		var rate: float = anger_rate if line["key"] == OVERFLOW_ANGER_LINE["key"] \
			else float(band[line["key"]])
		var amount := floori(float(gross) * rate)
		taxed += amount
		lines.append({
			"key": String(line["key"]),
			"label": String(line["label"]),
			"rate": rate,
			"amount": amount,
		})
	taxed = mini(taxed, gross)
	return {
		"lines": lines,
		"taxed": taxed,
		"net": gross - taxed,
		"ratio": float(gross) / float(maxi(1, target)),
	}


## What actually reaches the wallet out of an overflow.
static func overflow_after_tax(overflow: int, target: int, anger_rate := 0.0) -> int:
	return int(overflow_bill(overflow, target, anger_rate)["net"])


# The Nth coin (50, 100, …) is a "power coin". Pass the total AFTER counting it.
static func is_power_coin(total_after_coin: int,
		coins_per_restore: int = LUCIDITY_COINS_PER_RESTORE) -> bool:
	var threshold := maxi(1, coins_per_restore)
	return total_after_coin > 0 and total_after_coin % threshold == 0
