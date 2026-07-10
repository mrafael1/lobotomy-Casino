class_name Dealer
extends RefCounted

## Deterministic dealer logic — deterministic, seed-driven dealer logic. The
## Fisher-Yates shuffle and seeds match the TS exactly (see dealer_vectors.json).

const THRESHOLD_HIGH := 0.65
const THRESHOLD_LOW := 0.35
const PROC_CHANCE := 0.15
const MAX_COUNT := 3
const MIN_SPIN_GAP := 3

const M32 := 0xFFFFFFFF

# Portable Fisher-Yates — identical to the TS shuffleInPlace.
static func shuffle_in_place(arr: Array, rng: LobRNG) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := floori(rng.next() * (i + 1))
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr

# Returns [String, String] or null.
static func pick_dealer_items(seed: int) -> Variant:
	var candidates := InRunItems.ids() # fresh array, canonical order
	if candidates.size() < 2:
		return null
	var rng := LobRNG.new(seed & M32)
	shuffle_in_place(candidates, rng)
	return [candidates[0], candidates[1]]

# Painting reroll (issue #117): deterministic replacement pair for the current
# dealer offer. Same Fisher-Yates pipeline as pick_dealer_items, but the result is
# guaranteed to differ from `previous` (as a set) when a third candidate exists —
# a reroll that hands back the same pair reads as a no-op. Duplicate ITEMS across
# rerolls of different visits are allowed; only the immediate pair must change.
static func reroll_dealer_items(seed: int, previous: Variant) -> Variant:
	var candidates := InRunItems.ids() # fresh array, canonical order
	if candidates.size() < 2:
		return null
	var rng := LobRNG.new(seed & M32)
	shuffle_in_place(candidates, rng)
	var pick := [candidates[0], candidates[1]]
	if candidates.size() >= 3 and previous is Array and (previous as Array).size() == 2:
		var prev := previous as Array
		if prev.has(pick[0]) and prev.has(pick[1]):
			pick = [candidates[1], candidates[2]] # slide the window off the old pair
	return pick

# evaluate_dealer_trigger(input) -> { shouldTrigger, dealer65SafetyFired, dealer35SafetyFired }.
static func evaluate_dealer_trigger(input: Dictionary) -> Dictionary:
	var neurons := int(input["neurons"])
	var starting := int(input["startingNeurons"])
	var spin_count := int(input["spinCount"])
	var dealer_count := int(input["dealerCount"])
	var dealer_last := int(input["dealerLastSpinCount"])
	var max_count := int(input.get("maxCount", MAX_COUNT))
	var min_spin_gap := int(input.get("minSpinGap", MIN_SPIN_GAP))
	var high_threshold := float(input.get("highThreshold", THRESHOLD_HIGH))
	var low_threshold := float(input.get("lowThreshold", THRESHOLD_LOW))
	var proc_chance := float(input.get("procChance", PROC_CHANCE))
	var fired65: bool = input["dealer65SafetyFired"]
	var fired35: bool = input["dealer35SafetyFired"]
	var proc_seed := int(input["procSeed"])

	if starting <= 0 or dealer_count >= max_count or (spin_count - dealer_last) < min_spin_gap:
		return { "shouldTrigger": false, "dealer65SafetyFired": fired65, "dealer35SafetyFired": fired35 }

	var ratio := float(neurons) / float(starting)
	var should_trigger := false
	var new65 := fired65
	var new35 := fired35

	if not fired65 and ratio <= high_threshold:
		new65 = true
		if dealer_count == 0:
			should_trigger = true

	if not fired35 and ratio <= low_threshold:
		new35 = true
		if dealer_count == 1:
			should_trigger = true

	if not should_trigger:
		var rng := LobRNG.new(proc_seed & M32)
		if rng.next() < proc_chance:
			should_trigger = true

	return { "shouldTrigger": should_trigger, "dealer65SafetyFired": new65, "dealer35SafetyFired": new35 }
