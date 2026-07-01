class_name EconomyConst
extends RefCounted

## Port of the ECONOMY constants in src/content/economy.ts. No magic numbers
## elsewhere — only here.

const STARTING_NEURONS := 100
const NEURON_DECAY_PER_SPIN := 3
const MIN_NEURONS_TO_SPIN := 3
const MAX_NEURONS := 100
const MAX_NEURONS_ACT2 := 300
const MIN_NEURON_DECAY := 1

const BASE_MAX_FREE_SPINS := 1
const UPGRADED_MAX_FREE_SPINS := 3

const BASE_LUCIDITY_MULTIPLIER := 1.0

const WEALTH_SCORE_THRESHOLD := 1000
const EXIT_LUCIDITY_THRESHOLD := 750
const LUCIDITY_OBJECTIVE := 1000
const LUCIDITY_COINS_PER_RESTORE := 50
const END_OF_RUN_LUCIDITY_KEPT := 0.10

# The Nth coin (50, 100, …) is a "power coin". Pass the total AFTER counting it.
static func is_power_coin(total_after_coin: int) -> bool:
	return total_after_coin > 0 and total_after_coin % LUCIDITY_COINS_PER_RESTORE == 0
