extends SceneTree

## The behavioural gate for everything outside rules/ (parity vectors cover the rest).
## Started life as a throwaway smoke check for issue #21 — instantiate the changed scenes,
## assert the dealer's offer-pool branching — and grew into the only thing standing between
## machine_scene.gd and a silent regression.
##
##   godot --headless --path godot -s res://test/scene_smoke.gd
##   godot --headless --path godot -s res://test/scene_smoke.gd -- --shuffle
##   godot --headless --path godot -s res://test/scene_smoke.gd -- --shuffle=12345 --trace
##
## This file is the RUNNER and nothing else: isolation, the check table, dispatch and the
## lint. The checks themselves live in test/checks/, one file per domain, sharing
## test/checks/_base.gd. Adding a check means writing it in the domain file it belongs to
## and registering it in CHECKS — the lint fails the suite if you do only the first,
## because an unregistered check does not fail, it silently does not run.

const _MACHINE_SCENE_PATH := "res://scenes/machine_scene.tscn"

## Root children that belong to the engine, not to a check: the autoloads, plus whatever
## an editor addon has parented there. Captured once before the first check so _reap_strays
## can tell "the game" from "something a check left lying around" without a hardcoded list
## that would silently start deleting a new autoload the day one is added.
var _resident: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

## Hands the next check a machine and a campaign that owe nothing to the previous one.
##
## The suite used to build ONE machine and thread it through every check. That node
## carries ~220 fields, 15 animation flags and 20 live tweens, none of which
## reset_run_state() can reach — so a check inherited whatever presentation state its
## predecessor left armed, and the resulting failure surfaced somewhere unrelated to
## the bug. Both stores are returned to fresh-install defaults and the outgoing machine
## is replaced outright.
##
## Freed immediately rather than with queue_free(): the checks run as one synchronous
## burst, so deferred frees would pile up every machine the suite ever built before the
## first one actually went.
## `start_run` picks which of the two viable baselines the check gets, and the ORDER of
## the reset is what decides it — machine_scene._ready() ends in _enter_run(), which
## starts a run whenever the store is not already running:
##
##   true  — reset first, so _enter_run() opens a fresh, VIABLE run on a clean campaign.
##           What nearly every machine check wants. Resetting afterwards instead leaves
##           the store zeroed under a live machine, and the machine reads zero neurons
##           and flatlines the run a few frames in (this is what used to strand
##           _check_forced_spin_persistence_161's queued spin).
##   false — reset after, so the machine exists but the store is idle and
##           has_resume_state() is false. Required by anything that may not run with a
##           run already held, i.e. Tutorial.can_start().
func _isolate(previous: Node, run_store: Node, meta_store: Node, start_run := true) -> Node:
	if previous != null:
		previous.free()
	_reap_strays()
	if start_run:
		_reset_stores(run_store, meta_store)
	var machine := (load(_MACHINE_SCENE_PATH) as PackedScene).instantiate()
	get_root().add_child(machine)
	if not start_run:
		_reset_stores(run_store, meta_store)
	return machine

## Isolation for the checks that never touch the machine — menu, upgrades, collection,
## odds and the pure-rules checks. They get no machine at all rather than an idle one,
## because a live machine is not inert: on its first processed frame against a
## just-reset store it reads zero neurons and drives the run to a flatline ending,
## which then locks the start menu's augmented selector behind has_resume_state().
func _isolate_stores(previous: Node, run_store: Node, meta_store: Node) -> Node:
	if previous != null:
		previous.free()
	_reap_strays()
	_reset_stores(run_store, meta_store)
	return null

## Everything the suite left standing in the root, other than the autoloads.
##
## Freeing the machine _isolate handed out is not enough, because plenty of checks build
## their own scenes — menus, dealers, overlays, and in two places a second machine — and
## dismiss them with queue_free(). queue_free() does not free anything: it schedules the
## free for the end of the frame, and the checks run as one synchronous burst that almost
## never reaches a frame boundary. So those scenes stay in the tree, ALIVE, until some
## later check awaits a frame — and they get one more _process() during it.
##
## That is not theoretical. A machine dismissed this way inside an earlier check ran its
## _check_ending() during the awaited frame of _check_augmented_menu_111, flatlined the
## freshly-reset run, and locked the start menu's selector behind has_resume_state(). The
## failure surfaced in a menu check that had never built a machine, three checks away from
## the one that leaked it — the exact signature this harness exists to eliminate.
##
## Freed outright, including the ones already queued for deletion, rather than merely
## removed from the tree. Taking a node out of the tree stops it processing but does NOT
## cancel the deferred calls it has already posted, and the machine posts exactly such a
## call: `call_deferred("_check_ending")` when it rebuilds mid-run. A queue_free()d node is
## still a valid object when the message queue flushes, so that call lands anyway and ends
## a run the next check just reset. Freeing now invalidates the target and the queued call
## is dropped with it — which is why _isolate has always used free() over queue_free() for
## the machine it owns, and why the scenes the checks build themselves need the same
## treatment. The SceneTree's delete queue skips instances that are already gone.
func _reap_strays() -> void:
	for node in get_root().get_children():
		if _resident.has(node.name):
			continue
		get_root().remove_child(node)
		node.free()


func _reset_stores(run_store: Node, meta_store: Node) -> void:
	run_store.reset_run_state()
	meta_store.reset_to_defaults()
	# Matches the precondition the suite has always run under: these checks assert on a
	# returning player, not on the first-launch tutorial prompt. The checks that do care
	# set it themselves.
	meta_store.is_first_launch = false
	SaveIO.remove(run_store.RUN_SAVE_PATH)
	SaveIO.remove(meta_store.SAVE_PATH)

## ── the check table ───────────────────────────────────────────────────────────────
##
## Which isolation a check opens with, in the terms _isolate() already draws:
##   ISO_MACHINE       fresh machine over a fresh, viable run. What nearly all of them want.
##   ISO_MACHINE_IDLE  fresh machine, stores reset AFTER it is built, so no run is held.
##   ISO_STORES        no machine at all (see _isolate_stores for why not an idle one).
const ISO_MACHINE := 0
const ISO_MACHINE_IDLE := 1
const ISO_STORES := 2

## Every check the suite runs, as data rather than as a hand-written call list.
##
## The point of the table is the ORDER. As statements, the checks could only ever run in
## the order they were typed, which meant the isolation work could be asserted (each call
## sits behind an isolate line) but never demonstrated — a check that still leaned on its
## predecessor would pass forever. As data the list can be shuffled, and a shuffled run
## that passes is the actual proof:
##
##   godot --headless --path godot -s res://test/scene_smoke.gd -- --shuffle
##   godot --headless --path godot -s res://test/scene_smoke.gd -- --shuffle=12345
##
## `args` names what the check is handed, resolved by _bind_args. Signatures differ per
## check and are left alone deliberately: a uniform (machine, run, meta, failures) would
## have meant editing 80 function headers to serve the runner, and would have hidden which
## checks actually touch the machine — the very thing the isolation kind turns on.
const CHECKS: Array = [
	{"fn": "_check_scene_instantiation", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_jackpot_burst_hook", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_machine_art_mix", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_pacte_flow", "file": "pacte", "iso": ISO_MACHINE, "args": ["machine", "run_store", "meta_store", "failures"]},
	{"fn": "_check_pacte_power_rules", "file": "pacte", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_pacte_augment_effects", "file": "pacte", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_base_scene_parity", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_first_launch_tutorial", "file": "meta", "iso": ISO_STORES, "args": ["meta_store", "failures"]},
	{"fn": "_check_scene_nav", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_machine_ending_flow_source", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_flatline_action_text", "file": "flatline", "iso": ISO_MACHINE, "args": ["machine", "meta_store", "failures"]},
	{"fn": "_check_global_options_layout", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_painting_reroll_117", "file": "pacte", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_chip_augments", "file": "pacte", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_dealer_tip_132", "file": "dealer", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_emergency_reserve_132", "file": "dealer", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_symbol_level_picker_132", "file": "dealer", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_pair_triple_picker_bounds_132", "file": "dealer", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_augment_feedback_map_132", "file": "pacte", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_wealth_ending_augment_teardown_132", "file": "pacte", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_water_lucidity_gain", "file": "consumables", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_additive_power_payout_181", "file": "economy", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_jackpot_payout_181", "file": "economy", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_target_readout_181", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_machine_water_feedback", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_water_wealth_169", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "meta_store", "failures"]},
	{"fn": "_check_off_spin_target_proc", "file": "wealth", "iso": ISO_MACHINE, "args": ["machine", "run_store", "meta_store", "failures"]},
	{"fn": "_check_augment_level_readouts", "file": "pacte", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_reserve_glow_132", "file": "dealer", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_dealer_tip_steps_132", "file": "dealer", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_machine_consumable_feedback", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_upgrades_scene", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_smart_save_retention", "file": "meta", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_issue27_overlay_layout", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_issue27_machine_stash_drag", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_issue28_machine_sequence_lock", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_options_spin_lock_77", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_dealer_compulsion_softlock_96", "file": "dealer", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_dealer_refusal_countdown_161", "file": "dealer", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_dealer_gate_161", "file": "dealer", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_energy_drink_x2_161", "file": "consumables", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_forced_spin_persistence_161", "file": "economy", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_tap_duration_161", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_energy_drink_discard_161", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_loss_visuals_161", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_ending_cleanup_161", "file": "flatline", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_new_run_balance_161", "file": "economy", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_consumable_roster_32", "file": "consumables", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_machine_reactions_35", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_campaign_rebalance_38", "file": "economy", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_odds_table_36", "file": "dealer", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_neuron_meter_on_menu", "file": "scenes", "iso": ISO_STORES, "args": ["failures"]},
	{"fn": "_check_flatline_overlay_meter", "file": "flatline", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_wealth_screen", "file": "wealth", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_wealth_target_flow_176", "file": "wealth", "iso": ISO_MACHINE, "args": ["machine", "run_store", "meta_store", "failures"]},
	{"fn": "_check_wealth_score_feed", "file": "wealth", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_wealth_zero_spins_62", "file": "wealth", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_flatline_free_spins_75", "file": "flatline", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_flatline_win_boost_76", "file": "flatline", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_deferred_negative_76", "file": "flatline", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_dealer_pacing_76", "file": "dealer", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_frenzy_gauge_155", "file": "economy", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_pending_combo_and_free_spin_ui", "file": "economy", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_compulsion_multiplier_76", "file": "economy", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_tv_information_priority", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_boost_duration_icons_76", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_red_pill_tv_badge_185", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_item_badge_popup_185", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_water_animation_185", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_dealer_item_usage_flow_185", "file": "dealer", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_hallucination_machine_reaction_185", "file": "consumables", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_power_bar_76", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_restore_cap_181", "file": "economy", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_eye_reveal", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_score_table_51", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "failures"]},
	{"fn": "_check_spin_gain_fx_66", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_spins_bar_lever_80", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_spins_counter_accuracy_80", "file": "machine", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_free_spin_multiplier_cost", "file": "economy", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_issue92_rule_reworks", "file": "economy", "iso": ISO_MACHINE, "args": ["machine", "run_store", "meta_store", "failures"]},
	{"fn": "_check_starting_powers_and_random_118", "file": "economy", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_augmented_run_111", "file": "augmented", "iso": ISO_MACHINE, "args": ["machine", "run_store", "meta_store", "failures"]},
	{"fn": "_check_joker_forced_visit_111", "file": "augmented", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_augmented_menu_111", "file": "augmented", "iso": ISO_STORES, "args": ["run_store", "meta_store", "failures"]},
	{"fn": "_check_run_persistence_111", "file": "augmented", "iso": ISO_STORES, "args": ["run_store", "failures"]},
	{"fn": "_check_save_resume_151", "file": "meta", "iso": ISO_MACHINE, "args": ["machine", "run_store", "failures"]},
	{"fn": "_check_tier_win_counter_142", "file": "meta", "iso": ISO_STORES, "args": ["run_store", "meta_store", "failures"]},
	{"fn": "_check_card_collection_52", "file": "meta", "iso": ISO_STORES, "args": ["meta_store", "failures"]},
	{"fn": "_check_card_unlock_rules_52", "file": "meta", "iso": ISO_MACHINE, "args": ["machine", "run_store", "meta_store", "failures"]},
	# Tutorial.can_start() refuses while a run is held, so this one takes the idle-store
	# baseline rather than the fresh-run one.
	{"fn": "_check_tutorial_105", "file": "meta", "iso": ISO_MACHINE_IDLE, "args": ["machine", "run_store", "meta_store", "failures"]},
	{"fn": "_check_dealer_offer_pools", "file": "dealer", "iso": ISO_STORES, "args": ["run_store", "failures"]},
]

const _ARG_TOKENS := ["machine", "run_store", "meta_store", "failures"]

const CHECK_DIR := "res://test/checks"

## ── the runner ────────────────────────────────────────────────────────────────────

## One instance per domain file, built on first use and kept for the rest of the run.
##
## Deliberately NOT rebuilt per check: these objects hold no state between checks — every
## baseline a check needs comes from _isolate and the stores — and standing 91 of them up
## would only invite someone to start caching state on them.
var _domains: Dictionary = {}

func _domain(file: String) -> Object:
	if not _domains.has(file):
		var script: Script = load("%s/%s.gd" % [CHECK_DIR, file])
		_domains[file] = script.new(self)
	return _domains[file]

func _run() -> void:
	var failures: Array = []
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	meta_store.is_first_launch = false
	for node in get_root().get_children():
		_resident[node.name] = true

	_assert_check_table(failures)
	if not failures.is_empty():
		# A malformed table would dispatch garbage into 91 checks and bury this message
		# under the wreckage. Report it alone.
		for f in failures:
			printerr("✗ ", f)
		quit(1)
		return

	var order: Array = []
	for i in CHECKS.size():
		order.append(i)
	var shuffle_seed := _shuffle_seed()
	if shuffle_seed != 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = shuffle_seed
		# Fisher-Yates. RandomNumberGenerator rather than Array.shuffle() so the order is
		# reproducible from the printed seed — an order-dependent failure is worthless if
		# you cannot run it again.
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = order[i]
			order[i] = order[j]
			order[j] = tmp
		print("· shuffled check order, seed %d (re-run with --shuffle=%d)"
			% [shuffle_seed, shuffle_seed])

	# `--trace` names each check as it starts. An order-dependent failure is only ever
	# diagnosable against the run that produced it, and the seed alone does not tell you
	# what ran immediately before the check that broke.
	var trace := OS.get_cmdline_user_args().has("--trace")

	# Which check each failure came from. Under a shuffled order the message alone no
	# longer tells you where in the run it happened.
	var blamed: Array = []
	var machine: Node = null
	for index in order:
		var check: Dictionary = CHECKS[index]
		var kind := int(check["iso"])
		if kind == ISO_MACHINE:
			machine = _isolate(machine, run_store, meta_store)
		elif kind == ISO_MACHINE_IDLE:
			machine = _isolate(machine, run_store, meta_store, false)
		else:
			machine = _isolate_stores(machine, run_store, meta_store)
		var name := String(check["fn"])
		var file := String(check["file"])
		if trace:
			print("· %02d %s/%s" % [order.find(index), file, name])
		var before := failures.size()
		# Awaited unconditionally. Roughly a third of the checks are coroutines and the
		# rest are not; `await` over a Callable resolves the coroutine ones and passes the
		# plain ones straight through, so the runner does not have to keep a second list
		# of which is which — a list that would be wrong the first time someone added an
		# `await` inside an existing check.
		await Callable(_domain(file), name).callv(
			_bind_args(check["args"], machine, run_store, meta_store, failures))
		for _i in range(before, failures.size()):
			blamed.append("%s/%s" % [file, name])
	machine = _isolate_stores(machine, run_store, meta_store)

	if failures.is_empty():
		print("✓ scene smoke PASSED (%d checks)" % CHECKS.size())
		quit(0)
	else:
		for i in failures.size():
			var who: String = blamed[i] if i < blamed.size() else "?"
			printerr("✗ [%s] %s" % [who, failures[i]])
		if shuffle_seed != 0:
			printerr("  (shuffled order, seed %d — reproduce with --shuffle=%d)"
				% [shuffle_seed, shuffle_seed])
		quit(1)

## Resolves each check's declared parameter names to the live objects. `machine` is null
## for an ISO_STORES check, which is why no check that takes one may be registered under
## that kind — _assert_check_table enforces it.
func _bind_args(tokens: Array, machine: Node, run_store: Node, meta_store: Node,
		failures: Array) -> Array:
	var out: Array = []
	for token in tokens:
		match String(token):
			"machine": out.append(machine)
			"run_store": out.append(run_store)
			"meta_store": out.append(meta_store)
			"failures": out.append(failures)
	return out

## 0 = run in table order. Anything else is the shuffle seed.
##   --shuffle          a fresh seed from the clock (printed, so a failure is repeatable)
##   --shuffle=12345    that exact seed
func _shuffle_seed() -> int:
	for raw in OS.get_cmdline_user_args():
		var arg := String(raw)
		if arg == "--shuffle":
			return Time.get_unix_time_from_system() as int
		if arg.begins_with("--shuffle="):
			var given := arg.get_slice("=", 1).to_int()
			# A caller who asked for a seed and typoed it into 0 would silently get an
			# unshuffled run and read it as proof of isolation.
			return given if given != 0 else 1
	return 0

## Guards the table, which is now the only thing standing between a check and the
## previous check's leftovers.
##
## The old lint read this file's source and asserted every call in _run() sat behind an
## isolate line. The runner makes that true by construction, so the risk moved: a check
## can now be WRITTEN and never registered, and an unregistered check does not fail — it
## silently does not run, which is the same as deleting it but looks like coverage.
func _assert_check_table(failures: Array) -> void:
	var registered: Dictionary = {}
	for entry in CHECKS:
		var name := String(entry.get("fn", ""))
		if name.is_empty():
			failures.append("check table: an entry has no 'fn'")
			continue
		if registered.has(name):
			failures.append("check table: '%s' is registered twice" % name)
		registered[name] = true
		var file := String(entry.get("file", ""))
		if not ResourceLoader.exists("%s/%s.gd" % [CHECK_DIR, file]):
			failures.append("check table: '%s' names domain file '%s', which does not exist"
				% [name, file])
		elif not _domain(file).has_method(name):
			failures.append("check table: '%s' is registered under '%s' but is not defined there"
				% [name, file])
		var kind := int(entry.get("iso", -1))
		if kind != ISO_MACHINE and kind != ISO_MACHINE_IDLE and kind != ISO_STORES:
			failures.append("check table: '%s' has an unknown isolation kind %d" % [name, kind])
		var args: Array = entry.get("args", [])
		for token in args:
			if not _ARG_TOKENS.has(String(token)):
				failures.append("check table: '%s' asks for unknown argument '%s'"
					% [name, String(token)])
		if kind == ISO_STORES and args.has("machine"):
			failures.append("check table: '%s' takes a machine but is registered ISO_STORES, "
				% name + "so it would be handed null")
	# A refactor that emptied or halved the table would otherwise "pass" by running almost
	# nothing at all.
	if CHECKS.size() < 88:
		failures.append("check table: only %d checks registered; the suite has lost entries"
			% CHECKS.size())

	# Every _check_* defined anywhere under test/checks/ must be either registered in the
	# table or called by another check. Neither is a judgement about which it should be —
	# only that it is reachable. Scanning the whole directory rather than one file is the
	# point: splitting the suite made "add a check to a domain file and forget the table"
	# considerably easier to do by accident.
	var dir := DirAccess.open(CHECK_DIR)
	if dir == null:
		failures.append("check table: could not open %s" % CHECK_DIR)
		return
	var source := ""
	var defined: Array = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var f := FileAccess.open("%s/%s" % [CHECK_DIR, file_name], FileAccess.READ)
		if f == null:
			failures.append("check table: could not read %s" % file_name)
			continue
		var text := f.get_as_text()
		f.close()
		source += text
		for raw in text.split("\n"):
			var line := String(raw)
			if line.begins_with("func _check_"):
				defined.append(line.substr(5).get_slice("(", 0))
	if defined.size() < 100:
		failures.append("check table: the source scan found only %d check functions across %s "
			% [defined.size(), CHECK_DIR] + "and has lost track of the suite")
	for name in defined:
		if registered.has(name):
			continue
		# A nested call appears as `name(`; its own definition is the other occurrence.
		if source.count("%s(" % name) > 1:
			continue
		failures.append("check table: '%s' is defined but never registered and never " % name
			+ "called — it does not run")
