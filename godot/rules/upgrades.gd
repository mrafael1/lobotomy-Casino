class_name Upgrades
extends RefCounted

## Upgrade definitions. Ids preserved verbatim (perm_*, corr_*, pos_*).
## Each effect is a Dictionary with a "type" discriminator mirroring UpgradeEffect.

const ABILITY_UPGRADES := [
	{ "id": "perm_shift", "name": "Shift", "category": "positive", "cost": 45,
	  "effect": { "type": "abilityUnlock", "abilityId": "shift" } },
	{ "id": "perm_memory", "name": "Memory", "category": "positive", "cost": 45,
	  "effect": { "type": "abilityUnlock", "abilityId": "memory" } },
]

const CORRUPTED_UPGRADES := [
	{ "id": "corr_reward_amp_1", "name": "Reward Amplification", "category": "corrupted", "cost": 30,
	  "effect": { "type": "symbolRewardAmpBonus", "bonus": 0.15 }, "tierGroup": "reward_amp", "tierLabel": "I" },
	{ "id": "corr_reward_amp_2", "name": "Reward Amplification", "category": "corrupted", "cost": 55,
	  "requiresId": "corr_reward_amp_1",
	  "effect": { "type": "symbolRewardAmpBonus", "bonus": 0.10 }, "tierGroup": "reward_amp", "tierLabel": "II" },
	{ "id": "corr_reward_amp_3", "name": "Reward Amplification", "category": "corrupted", "cost": 90,
	  "requiresId": "corr_reward_amp_2",
	  "effect": { "type": "symbolRewardAmpBonus", "bonus": 0.15 }, "tierGroup": "reward_amp", "tierLabel": "III" },
	{ "id": "corr_sedative", "name": "Sedative Protocol", "category": "corrupted", "cost": 180,
	  "effect": { "type": "sedativeBonusSpin" } },
	{ "id": "corr_pattern_23", "name": "Pattern Fabrication", "category": "corrupted", "cost": 160,
	  "effect": { "type": "pattern23Triple" } },
	{ "id": "corr_jackpot_double", "name": "Euphoria Spiral", "category": "corrupted", "cost": 250,
	  "effect": { "type": "jackpotLucidityMultiplier", "multiplier": 2.0 } },
]

const POSITIVE_UPGRADES := [
	{ "id": "pos_hydration_1", "name": "Hydration", "category": "positive", "cost": 80,
	  "effect": { "type": "startingNeuronBonus", "amount": 3 }, "tierGroup": "hydration", "tierLabel": "I" },
	{ "id": "pos_hydration_2", "name": "Hydration", "category": "positive", "cost": 140,
	  "requiresId": "pos_hydration_1",
	  "effect": { "type": "startingNeuronBonus", "amount": 5 }, "tierGroup": "hydration", "tierLabel": "II" },
	{ "id": "pos_hydration_3", "name": "Hydration", "category": "positive", "cost": 200,
	  "requiresId": "pos_hydration_2",
	  "effect": { "type": "startingNeuronBonus", "amount": 5 }, "tierGroup": "hydration", "tierLabel": "III" },
	{ "id": "pos_passive_lucidity", "name": "Passive Cognition", "category": "positive", "cost": 200,
	  "effect": { "type": "passiveLucidityPerSpin", "amount": 5 } },
	{ "id": "pos_enlightenment", "name": "Hallucination", "category": "positive", "cost": 120,
	  "effect": { "type": "hallucination", "rewardScale": 0.30 } },
	{ "id": "pos_learning", "name": "Learning", "category": "positive", "cost": 120,
	  "effect": { "type": "bookSymbol", "weight": 7, "rewardScale": 0.70 } },
	{ "id": "pos_smart_save", "name": "Smart Save", "category": "positive", "cost": 30,
	  "effect": { "type": "smartSaveRetention", "kept": 0.50 } },
]

# These definitions are resolved by Economy so Pacte can re-apply a selected
# augment after a save/continue, but they are intentionally absent from
# all_upgrades(): they are run-choice cards, not Lab purchases.
const PACTE_UPGRADES := [
	{ "id": "pacte_tunnel_vision", "name": "Tunnel Vision", "category": "augment",
	  "effect": { "type": "tunnelVision", "hiddenReels": 1, "rewardMultiplier": 1.50 } },
	{ "id": "pacte_how_to_cheat", "name": "How to Cheat", "category": "augment",
	  "effect": { "type": "soloAsPair", "pairMultiplier": 0.60 } },
	{ "id": "pacte_adrenaline", "name": "Adrenaline", "category": "augment",
	  "effect": { "type": "powerRestoreThreshold", "amount": 30 } },
	{ "id": "pacte_passive_gain", "name": "Passive Gain", "category": "augment",
	  "effect": { "type": "passiveLucidityPerSpin", "amount": 10 } },
]

static func all_upgrades() -> Array:
	var out := []
	out.append_array(ABILITY_UPGRADES)
	out.append_array(CORRUPTED_UPGRADES)
	out.append_array(POSITIVE_UPGRADES)
	return out

static func upgrade_map() -> Dictionary:
	var m := {}
	for u in all_upgrades():
		m[u["id"]] = u
	for u in PACTE_UPGRADES:
		m[u["id"]] = u
	return m
