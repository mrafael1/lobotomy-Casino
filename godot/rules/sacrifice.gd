class_name SacrificeRules
extends RefCounted

## Between-machine Sacrifice route tuning. The route is deliberately small and
## deterministic: each accepted sacrifice trades one current resource for a
## modest spin budget on the next machine round.

## The campaign-wide limit remains three, while one visit can present at most
## two accepted trades before the player returns to the next machine.
const MAX_USES := 3
const MAX_USES_PER_VISIT := 2
const BONUS_SPINS := 5
const COIN_COST := 100

const REWARD_SPINS := "spins_5"

const OPTION_COINS := "coins"
const OPTION_NEURON := "neuron"
const OPTION_AUGMENT_PREFIX := "augment:"
const OPTION_POWER_PREFIX := "power:"

static func option_id_for_augment(card_id: String) -> String:
	return OPTION_AUGMENT_PREFIX + card_id

static func option_id_for_power(power_id: String) -> String:
	return OPTION_POWER_PREFIX + power_id

static func reward_for(reward_id: String) -> Dictionary:
	var resolved_id := REWARD_SPINS if reward_id != REWARD_SPINS else reward_id
	return {
		"id": resolved_id,
		"kind": "spins",
		"amount": BONUS_SPINS,
		"label": "+%d RUN SPINS" % BONUS_SPINS,
		"description": "READY FOR THE NEXT MACHINE ROUND",
	}
