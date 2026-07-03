class_name Endings
extends RefCounted

## Ending and banking rules. bank_run_to_meta takes an explicit `now` (ms) so the
## ending-timestamp fields are deterministic for parity (the store injects the real
## clock). Returns null from check_ending when no ending applies.

# `wealth_threshold` is the campaign goal — @export-tunable from the machine scene
# (issue #38); the default keeps every pinned vector on the parity-locked constant.
static func check_ending(run: Dictionary, _meta: Dictionary,
		wealth_threshold: int = EconomyConst.WEALTH_SCORE_THRESHOLD) -> Variant:
	if int(run["scoreEarned"]) >= wealth_threshold:
		return "wealth"
	if int(run["neurons"]) <= 0:
		return "flatline"
	return null

static func check_exit_eligibility(run: Dictionary, meta: Dictionary) -> bool:
	return (not bool(meta["corruptionEverUsed"])) \
		and int(run["lucidityCoins"]) >= EconomyConst.EXIT_LUCIDITY_THRESHOLD

static func lucidity_kept_fraction(meta: Dictionary) -> float:
	var owned := meta.get("ownedPermanents", []) as Array
	return EconomyConst.SMART_SAVE_LUCIDITY_KEPT \
		if owned.has(EconomyConst.SMART_SAVE_UPGRADE_ID) \
		else EconomyConst.END_OF_RUN_LUCIDITY_KEPT

# bankRunToMeta(run, meta, ending) with Date.now() supplied as `now`.
static func bank_run_to_meta(run: Dictionary, meta: Dictionary, ending: String, now: int) -> Dictionary:
	var endings: Array = (meta["endingsReached"] as Array).duplicate()
	if not endings.has(ending):
		endings.append(ending)

	var kept := floori(float(run["lucidityCoins"]) * lucidity_kept_fraction(meta))

	var mh: Dictionary = meta["history"]
	var hist := {
		"runsPlayed": int(mh["runsPlayed"]) + 1,
		"bestScoreRun": maxi(int(mh["bestScoreRun"]), int(run["scoreEarned"])),
	}

	var existing_w: Variant = mh.get("wealthEndingReachedAt", null)
	var w: Variant = now if (ending == "wealth" and (existing_w == null or existing_w == 0)) else existing_w
	if w != null:
		hist["wealthEndingReachedAt"] = w

	var existing_x: Variant = mh.get("exitEndingReachedAt", null)
	var x: Variant = now if (ending == "exit" and (existing_x == null or existing_x == 0)) else existing_x
	if x != null:
		hist["exitEndingReachedAt"] = x

	var out := meta.duplicate(true)
	out["lucidityWallet"] = int(meta["lucidityWallet"]) + kept
	out["endingsReached"] = endings
	out["history"] = hist
	return out
