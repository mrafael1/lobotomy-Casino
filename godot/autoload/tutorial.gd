extends Node

## The played tutorial (issue #105). It drives the REAL scenes with pinned state rather
## than miming them in a tutorial scene of its own: a mock machine would drift from the
## machine within a release, and the first thing a new player learns would be the one
## screen the game does not actually have.
##
## What lives here: the beat cursor (it has to survive pacte -> machine -> dealer), the
## scripted state each beat pins, and the sandbox that keeps all of it off the player's
## save. What does NOT live here: anything about a scene's layout. A scene answers
## `tutorial_anchor(id)` with its own rects and is otherwise untouched.
##
## The beats themselves are data in rules/tutorial_script.gd.

const OVERLAY_SCRIPT := preload("res://ui/tutorial_overlay.gd")
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const PACTE_SCENE := "res://scenes/pacte_scene.tscn"
const MACHINE_SCENE := "res://scenes/machine_scene.tscn"

## Scripted starting position. Small numbers: the tutorial is two or three minutes and the
## player has to see a target actually fall to their own spin.
const SANDBOX_WALLET := 120
const SANDBOX_CAMPAIGN_HEALTH := 3

signal beat_changed(index: int)
signal finished(completed: bool)

var active := false
var beat_index := -1

var _scene: Node = null            # the scene currently attached ("" until one is)
var _scene_kind := ""              # "pacte" | "machine" | "dealer"
var _overlay: Control = null
var _meta_snapshot: Dictionary = {}
var _run_snapshot: Dictionary = {}
var _waiting_for := ""
var _timeout_left := 0.0
var _spin_count_at_beat := -1
var _anchor_watch: Dictionary = {} # how things stood when the current beat opened
var _armed := false                # the current beat has been shown and is live
var _awaiting_ready := false       # the beat is holding for something to reach the screen
var _ready_wait_left := 0.0
var _ready_gave_up := false        # waited long enough; show the beat regardless
var _awaiting_scene := false       # the beat belongs to a screen that is not up yet
var _scene_wait_left := 0.0
var _awaiting_modal := false       # another modal owns the screen; coaching stands down
var _beat_age := 0.0               # seconds the current beat has been readable

## A beat that never gets what it is waiting for shows itself anyway rather than leaving
## the player looking at an unexplained screen.
const READY_WAIT_TIMEOUT := 8.0
## And a beat whose SCREEN never opens is dropped: the run has gone somewhere the script
## did not plan for, and the tutorial following it beat by beat matters less than the
## tutorial being escapable and eventually finishing.
const SCENE_WAIT_TIMEOUT := 45.0

# ── entry / exit ─────────────────────────────────────────────────────────────────────

## True when the tutorial can be started right now. A held run is the one hard no: the
## sandbox would have to snapshot over a live run, and a player who tapped the wrong
## button would come back to a machine mid-spin.
func can_start() -> bool:
	return not active and not RunStateStore.has_resume_state()

## Snapshots both stores, seals them off from the disk, and opens the Pacte on a scripted
## campaign. Returns false when a run is already held.
func start() -> bool:
	if not can_start():
		return false
	_meta_snapshot = MetaStateStore._as_dict()
	_run_snapshot = _snapshot_run()
	MetaStateStore.sandboxed = true
	RunStateStore.sandboxed = true
	active = true
	beat_index = -1
	_seed_sandbox_campaign()
	_navigate(PACTE_SCENE)
	_advance()
	return true

## Scene changes go through here so the director can be driven headlessly. A test harness
## stands its own scenes up as children of the root and has no current_scene to replace;
## in the game there is always one, so this is the real path every time it matters.
func _navigate(path: String) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	if path == MENU_SCENE:
		SceneNav.go_to_menu(path)
	else:
		SceneNav.change_to(path)

## Ends the tutorial and puts the player's own campaign back exactly as it was. Called by
## SKIP, by the last beat, and by anything that decides the tutorial cannot continue.
## `completed` only decides whether the first-launch prompt offers it again.
func stop(completed: bool) -> void:
	if not active:
		return
	active = false
	beat_index = -1
	_waiting_for = ""
	_armed = false
	_teardown_overlay()
	_scene = null
	_scene_kind = ""
	_restore_run(_run_snapshot)
	MetaStateStore._apply(_meta_snapshot)
	MetaStateStore.sandboxed = false
	RunStateStore.sandboxed = false
	MetaStateStore.mark_tutorial_completed(false)
	MetaStateStore.save_state()
	RunStateStore._commit()
	_meta_snapshot = {}
	_run_snapshot = {}
	finished.emit(completed)
	_navigate(MENU_SCENE)

# ── scene attachment ─────────────────────────────────────────────────────────────────

## Every participating scene calls this at the end of its _ready. Nothing happens unless a
## tutorial is running, so the call is inert in a normal game.
func attach(scene: Node, kind: String) -> void:
	if not active or scene == null:
		return
	_scene = scene
	_scene_kind = kind
	_teardown_overlay()
	_overlay = OVERLAY_SCRIPT.new()
	_overlay.tapped.connect(_on_overlay_tapped)
	_overlay.skip_pressed.connect(func() -> void: stop(false))
	scene.add_child(_overlay)
	# The scene that just opened may be the one the pending beat was waiting for.
	if beat_index < 0:
		_advance()
		return
	# A beat that was waiting for the player to LEAVE its scene is finished the moment
	# another one opens; re-presenting it here would stall the tutorial on a beat whose
	# scene is gone until its timeout rescued it.
	var pending := TutorialScript.beat(beat_index)
	if String(pending.get("advance", "")) == "scene" \
			and String(pending.get("scene", "")) != kind:
		_advance()
		return
	_present_beat()

func _teardown_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		# Out of the tree before it is freed. queue_free leaves it in place until the end
		# of the frame, and its mask panels stop mouse input: a scene that attaches twice
		# (or re-attaches on the same frame) would otherwise have a dead overlay eating
		# taps under the live one, and get_node("TutorialOverlay") would find the corpse.
		if _overlay.get_parent() != null:
			_overlay.get_parent().remove_child(_overlay)
		_overlay.queue_free()
	_overlay = null

# ── beat flow ────────────────────────────────────────────────────────────────────────

func _advance() -> void:
	var finished_beat := TutorialScript.beat(beat_index)
	_armed = false
	_awaiting_ready = false
	_ready_gave_up = false
	_awaiting_scene = false
	_awaiting_modal = false
	beat_index += 1
	if beat_index >= TutorialScript.count():
		stop(true)
		return
	beat_changed.emit(beat_index)
	# A beat may take the player somewhere itself rather than waiting for the game to get
	# there on its own — see `go` in tutorial_script.gd.
	var go := String(finished_beat.get("go", ""))
	if go != "":
		_go(go)
		return
	_present_beat()

## Hands the player to `kind` directly, starting a fresh run first when one is needed. Only
## the machine is a destination today: a banked target leaves the run "over" and parked at
## the dealer, and the tutorial has a losing run left to show.
func _go(kind: String) -> void:
	match kind:
		"machine":
			if String(RunStateStore.runPhase) != "running":
				# The same start the dealer's own START performs, so the run the tutorial
				# drops into is an ordinary one.
				if not RunStateStore.start_new_run(MetaStateStore.ownedPermanents,
						MetaStateStore.get_pending_consumables()):
					# Nothing left to start (no campaign health): let the game go where it
					# was going and finish the tutorial from wherever that is.
					_present_beat()
					return
			_navigate(MACHINE_SCENE)
	_present_beat()

## Shows the current beat if its scene is the one on screen. When it is not, the beat sits
## and waits: the scene it belongs to will attach() shortly and call back in here.
func _present_beat() -> void:
	var beat := TutorialScript.beat(beat_index)
	if beat.is_empty() or _overlay == null or not is_instance_valid(_overlay):
		return
	if String(beat["scene"]) != _scene_kind:
		# Waiting for the screen this beat belongs to. SKIP stays live throughout, and the
		# wait is bounded: a scene that never opens (the run went somewhere the script did
		# not expect) drops the beat instead of parking the tutorial forever.
		_overlay.show_waiting()
		if not _awaiting_scene:
			_awaiting_scene = true
			_scene_wait_left = SCENE_WAIT_TIMEOUT
		return
	_awaiting_scene = false
	# Something else owns the screen (the odds table opens on EVERY post-run visit, a card
	# unlock takes the whole scene). Stand down completely — mask off, tap not captured —
	# until it is done with. No timeout on this one: finishing it is a real thing the player
	# has to do, and SKIP stays live throughout.
	# ...unless the beat is ABOUT that modal (the odds table is a whole screen of its own
	# and needs explaining), in which case it is shown over it and never masks it.
	if not bool(beat.get("over_modal", false)) \
			and _scene.has_method("tutorial_blocking_modal") \
			and bool(_scene.call("tutorial_blocking_modal")):
		_overlay.show_waiting()
		_awaiting_modal = true
		return
	_awaiting_modal = false
	# Some beats need something to be ON SCREEN before they mean anything. The machine
	# rolls the dealer AFTER the spin has finished settling, so a beat that opened the
	# moment the spin resolved would tell the player to take an item from a dealer who is
	# not there yet — and would judge "did they take one?" against a counter with no
	# dealer in it, which is a beat that can never complete.
	if not _ready_gave_up and not _beat_ready(beat):
		# Stand down rather than vanish, for the same reason as the scene wait: the overlay
		# carries the only way out of the tutorial and must never be taken off the screen.
		_overlay.show_waiting()
		if not _awaiting_ready:
			_awaiting_ready = true
			_ready_wait_left = READY_WAIT_TIMEOUT
		return
	_awaiting_ready = false
	_pin(beat.get("state", {}) as Dictionary)
	_give(beat.get("give", {}) as Dictionary)
	var anchor := _anchor_rect(String(beat.get("anchor", "")))
	var advance := String(beat.get("advance", "tap"))
	# Any beat that ends because the player DID something has to let them do it: the ring
	# and the hole are the same decision. Only a read-and-continue beat ("tap") keeps its
	# ring illustrative and masks everything, because there the tap itself is the advance.
	var hand_through := anchor.size != Vector2.ZERO and advance != "tap"
	_overlay.show_beat(String(beat["text"]), anchor, hand_through,
		String(beat.get("box", "")))
	_waiting_for = advance
	_timeout_left = float(beat.get("timeout", TutorialScript.DEFAULT_TIMEOUT))
	_spin_count_at_beat = int(RunStateStore.spinCount)
	_anchor_watch = _watch_anchor_state()
	_beat_age = 0.0
	# It gave up waiting for the thing it is about (the dealer never came, the player waved
	# him off). Do not ask them to do something to a screen that is not there — say the line
	# and let a tap move on.
	if _ready_gave_up and String(beat.get("advance", "")) != "tap":
		_waiting_for = "tap"
		_overlay.show_beat(tr(String(beat["text"])) + "\n" + tr("(TAP TO GO ON)"), Rect2(), false,
			String(beat.get("box", "")))
	_armed = true

## Whether the thing a beat is about has actually arrived. Only beats that name a `needs`
## wait; everything else is ready the moment its scene is.
func _beat_ready(beat: Dictionary) -> bool:
	match String(beat.get("needs", "")):
		"dealer":
			return RunStateStore.dealerPending or RunStateStore.dealerIncoming
		"target":
			# The payout screen is claimed before it animates (begin_wealth_target sets
			# this), so the beat opens with the receipt actually on screen instead of
			# talking about a target the machine has not finished paying out yet.
			return RunStateStore.wealthTargetPending
		"over":
			return String(RunStateStore.runPhase) == "over"
	# Anything the store cannot answer is the scene's own business — whether a control is
	# actually on screen and tappable yet. A scene that does not answer is treated as ready.
	var needs := String(beat.get("needs", ""))
	if needs != "" and _scene != null and is_instance_valid(_scene) \
			and _scene.has_method("tutorial_ready_for"):
		return bool(_scene.call("tutorial_ready_for", needs))
	return true

func _anchor_rect(anchor_id: String) -> Rect2:
	if anchor_id == "" or _scene == null or not is_instance_valid(_scene):
		return Rect2()
	if not _scene.has_method("tutorial_anchor"):
		return Rect2()
	return _scene.call("tutorial_anchor", anchor_id) as Rect2

## The scripted state a beat runs on. Only ever assigns fields the store already owns —
## the tutorial pins the situation, it does not invent rules.
func _pin(state: Dictionary) -> void:
	for key in state:
		var prop := String(key)
		if not (prop in RunStateStore):
			continue
		var value: Variant = state[key]
		# The beats are script CONSTANTS, and a const container is a shared reference in
		# GDScript: handing one straight to the store would let a later run mutate the
		# tutorial's own script. Containers are copied in.
		if value is Dictionary:
			value = (value as Dictionary).duplicate(true)
		elif value is Array:
			value = (value as Array).duplicate(true)
		RunStateStore.set(prop, value)
	if not state.is_empty():
		RunStateStore._commit()

## A tap only counts once the beat has been readable for a moment. Without this, tapping
## through one beat carries into the next — a player double-tapping the machine skips a line
## they never saw, and the burst of taps a spin invites can eat two beats at once.
const TAP_GRACE := 0.35

func _on_overlay_tapped() -> void:
	if _armed and _waiting_for == "tap" and _beat_age >= TAP_GRACE:
		_advance()

func _process(delta: float) -> void:
	if not active:
		return
	if _awaiting_modal:
		# Re-present the moment the screen is the player's again.
		if _scene == null or not is_instance_valid(_scene) \
				or not _scene.has_method("tutorial_blocking_modal") \
				or not bool(_scene.call("tutorial_blocking_modal")):
			_awaiting_modal = false
			_present_beat()
		return
	if _awaiting_scene:
		_scene_wait_left -= delta
		if _scene_wait_left <= 0.0:
			_awaiting_scene = false
			_advance()
		return
	if _awaiting_ready:
		_ready_wait_left -= delta
		if _ready_wait_left <= 0.0:
			# It is not coming. Show the beat anyway — a hidden overlay waiting forever is
			# the one failure mode a tutorial must not have.
			_ready_gave_up = true
		if _ready_gave_up or _beat_ready(TutorialScript.beat(beat_index)):
			_awaiting_ready = false
			_present_beat()
		return
	if not _armed:
		return
	_beat_age += delta
	match _waiting_for:
		"spin":
			# The spin the beat asked for has resolved (the machine is idle again).
			if int(RunStateStore.spinCount) > _spin_count_at_beat \
					and not RunStateStore.isSpinning:
				_advance()
		"anchor":
			# The ringed control did its job when the state it drives changed: an item
			# taken leaves the dealer, an item used empties the pocket.
			if _anchor_action_done():
				_advance()
	if _timeout_left > 0.0:
		_timeout_left -= delta
		if _timeout_left <= 0.0:
			# Whatever the beat was waiting for is not coming — the machine may have taken
			# the moment itself. Fall back to a plain read-and-continue rather than leaving
			# the player behind a mask with nothing to do. No beat may strand the run.
			_waiting_for = "tap"
			if _overlay != null and is_instance_valid(_overlay):
				_overlay.show_beat(tr(String(TutorialScript.beat(beat_index)["text"]))
					+ "\n" + tr("(TAP TO GO ON)"), Rect2(), false)

## Puts an item in the player's pocket for a beat that is about to teach it, without taking
## away what they already chose. Beats the slot cap on purpose: the beat exists to have the
## item used immediately, and refusing to hand it over would strand the lesson.
func _give(items: Dictionary) -> void:
	if items.is_empty():
		return
	# Given item FIRST, then everything already held. The stash draws its slots in the
	# dictionary's own order and shows only as many as the cap allows: added at the end, a
	# gift handed to a player whose pockets are already full would sit in an invisible slot
	# while the beat rang slot 0 — which holds something else entirely. Nothing is taken
	# away; an item pushed past the visible slots comes back as soon as this one is used.
	var stash: Dictionary = {}
	var held: Dictionary = RunStateStore.runConsumables as Dictionary
	for id in items:
		stash[String(id)] = maxi(int(held.get(String(id), 0)), int(items[id]))
	for id in held:
		if not stash.has(String(id)):
			stash[String(id)] = int(held[id])
	RunStateStore.runConsumables = stash
	RunStateStore._commit()

## Whether the ringed control has been used, judged against how things stood when the beat
## STARTED rather than against an absolute condition. An absolute test ("the stash is
## empty") is true before the player has done anything whenever the beat opens that way,
## and the beat completes itself the instant it appears.
func _anchor_action_done() -> bool:
	match String(TutorialScript.beat(beat_index).get("id", "")):
		"dealer_take":
			# An item in the pocket that was not there before is the unambiguous answer.
			# "The dealer left" is not: he is also gone if the player waved him off, and
			# he had not even walked in when this beat first opened.
			if _stash_total() > int(_anchor_watch.get("stash", 0)):
				return true
			# Declined instead. The lesson is missed but the run must not stall on it.
			return bool(_anchor_watch.get("dealer", false)) \
				and not RunStateStore.dealerPending and not RunStateStore.dealerIncoming
		"stash":
			return _stash_total() < int(_anchor_watch.get("stash", 0))
		"powder_pick":
			# The copy takes two taps (source, then target) and lands as a changed reel.
			return _reels_signature() != String(_anchor_watch.get("reels", ""))
		"odds":
			# The table is done with when the phase it belongs to is finalized. The beat
			# cannot use a tap: the taps belong to the table.
			return bool(RunStateStore.oddsPhaseCompleted)
	return false

## The reels as they stand, so a beat can tell that a power or an item rearranged them.
func _reels_signature() -> String:
	if not (RunStateStore.lastResult is Dictionary):
		return ""
	return str((RunStateStore.lastResult as Dictionary).get("reels", []))

## Everything in the pocket, copies included.
func _stash_total() -> int:
	var total := 0
	for count in (RunStateStore.runConsumables as Dictionary).values():
		total += int(count)
	return total

## The slice of state the current beat's completion is measured against.
func _watch_anchor_state() -> Dictionary:
	var stash := _stash_total()
	return {
		"dealer": bool(RunStateStore.dealerPending),
		"stash": stash,
		"reels": _reels_signature(),
	}

# ── sandbox ──────────────────────────────────────────────────────────────────────────

## A campaign that exists only for the tutorial: full health, a little banked Lucidity so
## the closing shop beat has something to spend, and no unlock progress to disturb.
func _seed_sandbox_campaign() -> void:
	RunStateStore.reset_run_state()
	MetaStateStore.start_new_campaign(false)
	MetaStateStore.lucidityWallet = SANDBOX_WALLET
	MetaStateStore.campaignNeuronsLeft = SANDBOX_CAMPAIGN_HEALTH
	MetaStateStore.pendingCardUnlocks = []
	RunStateStore.augmentedTier = ""
	RunStateStore.start_new_run(MetaStateStore.ownedPermanents, {}, true, -1, true)

## Uses the store's own definition of "what is run state" (the same reflection its save
## goes through), so a field added later is snapshotted without anyone remembering to.
func _snapshot_run() -> Dictionary:
	var out := {}
	for prop in RunStateStore._run_state_properties():
		out[prop] = RunStateStore.get(prop)
	return out

func _restore_run(snapshot: Dictionary) -> void:
	for prop in snapshot:
		RunStateStore.set(String(prop), snapshot[prop])
