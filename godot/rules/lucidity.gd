class_name Lucidity
extends RefCounted

## Port of planLucidityGain from src/state/runState.ts. Restores one spent power per
## 50-coin threshold crossed; the eligible list shrinks each crossing so the same
## instance is never restored twice. Pure and seed-driven (see lucidity_restore.json).

const M32 := 0xFFFFFFFF

# plan_gain(prevCoins, gain, abilitiesUsed, seed)
#   -> { lucidityCoins, abilitiesUsed, restores }
static func plan_gain(prev_coins: int, gain: int, abilities_used: Array, seed: int) -> Dictionary:
	var new_coins := maxi(0, prev_coins + gain)
	if gain <= 0:
		return { "lucidityCoins": new_coins, "abilitiesUsed": abilities_used.duplicate(), "restores": [] }

	var per := EconomyConst.LUCIDITY_COINS_PER_RESTORE
	var prev_index := floori(float(prev_coins) / per)
	var next_index := floori(float(new_coins) / per)

	var restores := []
	var remaining := abilities_used.duplicate()
	for i in range(prev_index, next_index):
		if remaining.is_empty():
			break # nothing spent left → remaining credits lost
		var rng := LobRNG.new((seed ^ (i * 0x517cc1b7)) & M32)
		var idx := mini(remaining.size() - 1, floori(rng.next() * remaining.size()))
		restores.append(remaining[idx])
		remaining.remove_at(idx)
	return { "lucidityCoins": new_coins, "abilitiesUsed": remaining, "restores": restores }
