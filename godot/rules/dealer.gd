class_name Dealer
extends RefCounted

## Port of src/game/dealer.ts — deterministic, seed-driven dealer logic. The
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

# evaluate_dealer_trigger(input) -> { shouldTrigger, dealer65SafetyFired, dealer35SafetyFired }.
static func evaluate_dealer_trigger(input: Dictionary) -> Dictionary:
	var neurons := int(input["neurons"])
	var starting := int(input["startingNeurons"])
	var spin_count := int(input["spinCount"])
	var dealer_count := int(input["dealerCount"])
	var dealer_last := int(input["dealerLastSpinCount"])
	var fired65: bool = input["dealer65SafetyFired"]
	var fired35: bool = input["dealer35SafetyFired"]
	var proc_seed := int(input["procSeed"])

	if starting <= 0 or dealer_count >= MAX_COUNT or (spin_count - dealer_last) < MIN_SPIN_GAP:
		return { "shouldTrigger": false, "dealer65SafetyFired": fired65, "dealer35SafetyFired": fired35 }

	var ratio := float(neurons) / float(starting)
	var should_trigger := false
	var new65 := fired65
	var new35 := fired35

	if not fired65 and ratio <= THRESHOLD_HIGH:
		new65 = true
		if dealer_count == 0:
			should_trigger = true

	if not fired35 and ratio <= THRESHOLD_LOW:
		new35 = true
		if dealer_count == 1:
			should_trigger = true

	if not should_trigger:
		var rng := LobRNG.new(proc_seed & M32)
		if rng.next() < PROC_CHANCE:
			should_trigger = true

	return { "shouldTrigger": should_trigger, "dealer65SafetyFired": new65, "dealer35SafetyFired": new35 }
