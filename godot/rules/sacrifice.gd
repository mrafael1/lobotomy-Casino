class_name SacrificeRules
extends RefCounted

## Between-machine Sacrifice route tuning. The route is deliberately small and
## deterministic: each accepted sacrifice trades one current resource for a
## modest spin budget on the next machine round.

const MAX_USES := 3
const BONUS_SPINS := 5
const COIN_COST := 100

const OPTION_COINS := "coins"
const OPTION_NEURON := "neuron"
const OPTION_AUGMENT_PREFIX := "augment:"
const OPTION_POWER_PREFIX := "power:"

static func option_id_for_augment(card_id: String) -> String:
	return OPTION_AUGMENT_PREFIX + card_id

static func option_id_for_power(power_id: String) -> String:
	return OPTION_POWER_PREFIX + power_id
