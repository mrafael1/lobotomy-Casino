class_name Lucidity
extends RefCounted

## Lucidity gain planner. Restores one spent power per
## restore threshold crossed; the eligible list shrinks each crossing so the same
## instance is never restored twice. Pure and seed-driven (see lucidity_restore.json).

const M32 := 0xFFFFFFFF

# plan_gain(prevCoins, gain, abilitiesUsed, seed)
#   -> { lucidityCoins, abilitiesUsed, restores }
# max_restores caps how many powers this plan may bring back (the caller's remaining
# per-spin budget); a crossing over the cap is simply lost, like a crossing with nothing
# spent left. -1 (the parity-pinned default) means uncapped.
static func plan_gain(prev_coins: int, gain: int, abilities_used: Array, seed: int, coins_per_restore := EconomyConst.LUCIDITY_COINS_PER_RESTORE, max_restores := -1) -> Dictionary:
	var new_coins := maxi(0, prev_coins + gain)
	if gain <= 0:
		return { "lucidityCoins": new_coins, "abilitiesUsed": abilities_used.duplicate(), "restores": [] }

	var per := maxi(1, coins_per_restore)
	var prev_index := floori(float(prev_coins) / per)
	var next_index := floori(float(new_coins) / per)

	var restores := []
	var remaining := abilities_used.duplicate()
	for i in range(prev_index, next_index):
		if remaining.is_empty():
			break # nothing spent left → remaining credits lost
		if max_restores >= 0 and restores.size() >= max_restores:
			break # per-spin restore cap reached → remaining credits lost
		var rng := LobRNG.new((seed ^ (i * 0x517cc1b7)) & M32)
		var idx := mini(remaining.size() - 1, floori(rng.next() * remaining.size()))
		restores.append(remaining[idx])
		remaining.remove_at(idx)
	return { "lucidityCoins": new_coins, "abilitiesUsed": remaining, "restores": restores }
