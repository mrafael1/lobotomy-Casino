class_name EconomyConst
extends RefCounted

## Economy constants. No magic numbers
## elsewhere — only here.

# One spin currency: 1 neuron = 1 spin (issue #85). STARTING_NEURONS is the
# intended base run length, and the run never holds more than 18 normal spins.
const STARTING_NEURONS := 15
const NEURON_DECAY_PER_SPIN := 1
const MIN_NEURONS_TO_SPIN := 1
const MAX_NEURONS := 18
# Kept as a named compatibility constant for callers that distinguish the
# post-Wealth continuation, although the current machine also caps it at 18.
const MAX_NEURONS_ACT2 := 18
const MIN_NEURON_DECAY := 1

const BASE_MAX_FREE_SPINS := 1
const UPGRADED_MAX_FREE_SPINS := 3

const BASE_LUCIDITY_MULTIPLIER := 1.0

const WEALTH_SCORE_THRESHOLD := 2000
const EXIT_LUCIDITY_THRESHOLD := 750
const LUCIDITY_OBJECTIVE := 1000
const LUCIDITY_COINS_PER_RESTORE := 50
const END_OF_RUN_LUCIDITY_KEPT := 0.10
const SMART_SAVE_LUCIDITY_KEPT := 0.20
const SMART_SAVE_UPGRADE_ID := "pos_smart_save"
const CAMPAIGN_STARTING_NEURONS := 10

# Issue #76: a 3x-flatline strike charges the NEXT winning pair/triple to score at
# this multiplier (its points AND lucidity coins both scale, since the bonus rides
# on top of the pinned score before the coin plan). Re-armed by each strike, spent
# on the next scoring win; misses and 0-score flatline wins never spend it.
const FLATLINE_WIN_BOOST_MULT := 2

# The Nth coin (50, 100, …) is a "power coin". Pass the total AFTER counting it.
static func is_power_coin(total_after_coin: int) -> bool:
	return total_after_coin > 0 and total_after_coin % LUCIDITY_COINS_PER_RESTORE == 0
