class_name TutorialScript
extends RefCounted

## The played tutorial (issue #105) as data: what each beat says, where it points, what it
## waits for, and the run state it pins first. Kept out of the director so the copy and the
## ordering can be read and checked without standing a scene up — the same reason the item
## and card tables live in rules/.
##
## Every beat is a Dictionary:
##   scene    — which scene must be on screen for it ("pacte" | "machine" | "dealer")
##   text     — the coaching line. Short: the machine is doing the explaining.
##   anchor   — the scene's own anchor id to ring and to leave tappable ("" = no hole,
##              the beat is read-and-continue). Resolved by that scene's tutorial_anchor().
##   advance  — what ends the beat:
##                "tap"       the player taps anywhere (the mask has no hole)
##                "anchor"    the player uses the ringed control
##                "spin"      a spin resolves
##                "scene"     the next scene opens
##   state    — store fields pinned before the beat is shown (see Tutorial._pin)
##   timeout  — seconds before the beat gives up waiting and offers "tap to continue".
##              A beat that waits on the machine can be beaten by the machine itself
##              (a dealer walking in, an ending firing); none of them may strand the run.

const DEFAULT_TIMEOUT := 20.0

# The wealth the scripted run carries into its target beat. The first target is small, so
# the tutorial's pinned triple is what actually crosses it — the player sees their own spin
# do it rather than arriving pre-won.
const SCRIPTED_TARGET_INDEX := 0
const SCRIPTED_SCORE_BEFORE_WIN := 0

const BEATS: Array[Dictionary] = [
	# ── the ritual ───────────────────────────────────────────────────────────────────
	{
		"id": "pacte_intro", "scene": "pacte", "anchor": "", "advance": "tap",
		"text": "EVERY RUN OPENS WITH A PACTE.\nTHE HOUSE DEALS, YOU KEEP ONE.",
		"state": {},
	},
	{
		"id": "pacte_pick", "scene": "pacte", "anchor": "cards", "advance": "scene",
		# Both pools are dealt in turn and each card is DRAGGED into its slot, so the line
		# has to say drag — a player told to "take" one will tap and wait.
		"text": "DRAG ONE CARD INTO ITS SLOT.\nTHEN ONE MORE. THEY LAST THE RUN.",
		"state": {},
	},
	# ── the machine, first run ───────────────────────────────────────────────────────
	{
		"id": "health", "scene": "machine", "anchor": "health", "advance": "tap",
		"text": "YOUR HEALTH. EVERY PAID SPIN\nCOSTS ONE. AT ZERO THE RUN ENDS.",
		"state": { "neurons": 12, "freeSpinsRemaining": 0 },
	},
	{
		"id": "target", "scene": "machine", "anchor": "target_bar", "advance": "tap",
		"text": "THIS IS THE TARGET.\nBEAT IT AND YOU BANK THE RUN.",
		"state": {},
	},
	{
		"id": "first_spin", "scene": "machine", "anchor": "spin_lever", "advance": "spin",
		"text": "PULL THE LEVER.",
		"state": { "scriptedReels": ["vial", "vial", "eye"] },
	},
	{
		"id": "first_win", "scene": "machine", "anchor": "wealth", "advance": "tap",
		"text": "TWO OF A KIND PAYS.\nIT LANDS ON YOUR WEALTH.",
		"state": {},
	},
	# ── the dealer ───────────────────────────────────────────────────────────────────
	{
		"id": "dealer_due", "scene": "machine", "anchor": "dealer_countdown", "advance": "tap",
		"text": "THE DEALER IS DUE.\nHE COMES ROUND ON HIS OWN CLOCK.",
		"state": { "dealerCountdown": 0 },
	},
	{
		"id": "dealer_spin", "scene": "machine", "anchor": "spin_lever", "advance": "spin",
		"text": "SPIN AGAIN AND HE WALKS IN.",
		"state": { "scriptedReels": ["brain", "eye", "vial"] },
	},
	{
		# `needs` holds this beat back until he is actually on screen: the machine rolls the
		# dealer well after the spin that summons him has finished settling.
		"id": "dealer_take", "scene": "machine", "anchor": "dealer_offer", "advance": "anchor",
		"needs": "dealer",
		# Bottom: his hands bring the items down from the top of the canvas, and a coach box
		# up there covers the very choice the line is asking the player to make.
		"box": "bottom",
		"text": "HE BRINGS ITEMS, NOT BILLS.\nTAKE ONE.",
		"state": {},
	},
	# ── items, and what they cost ────────────────────────────────────────────────────
	{
		"id": "stash", "scene": "machine", "anchor": "stash", "advance": "anchor",
		# The dealer hides the machine's stash while he is in and takes a few frames to slide
		# out: without this the beat opens pointing at a stash that is not drawn yet.
		"needs": "stash",
		"text": "YOUR POCKET. TAP THE POWDER\nTO USE IT.",
		# The powder is put in hand rather than hoped for: the player may well have taken
		# the other item at the counter, and the next two beats are about this one. `give`
		# ADDS it — pinning runConsumables outright would confiscate whatever they just
		# chose, one beat after the tutorial congratulated them for choosing it.
		"give": { "cons_white_powder": 1 },
		"state": {},
	},
	{
		# Two picks, both inside the ring: the reel to copy, then the reel to copy it onto.
		"id": "powder_pick", "scene": "machine", "anchor": "reels", "advance": "anchor",
		"text": "PICK A REEL TO COPY,\nTHEN THE REEL TO COPY IT ONTO.",
		"state": {},
	},
	{
		# Rings the reels, not the TV badge row: White Powder has no duration badge (its
		# price is paid on one spin, not over several), so pointing at that row would ring
		# an empty strip. The covers land on the reels, which is where to look.
		"id": "powder_cost", "scene": "machine", "anchor": "reels", "advance": "tap",
		"text": "EVERY ITEM HAS A PRICE. THIS ONE\nHIDES YOUR NEXT RESULT.",
		"state": {},
	},
	{
		"id": "hidden_spin", "scene": "machine", "anchor": "spin_lever", "advance": "spin",
		"text": "SPIN. THE REELS COME BACK\nUNDER COVERS.",
		"state": { "scriptedReels": ["eye", "eye", "vial"] },
	},
	# ── beating the target ───────────────────────────────────────────────────────────
	{
		"id": "big_spin", "scene": "machine", "anchor": "spin_lever", "advance": "spin",
		"text": "ONE MORE. THREE OF A KIND\nPAYS THE HOUSE OUT.",
		"state": { "scriptedReels": ["brain", "brain", "brain"] },
	},
	{
		# Waits for the payout screen to actually be up, and then does NOT mask it: the
		# receipt is the lesson, and its own button is what moves the game on. A full mask
		# here put the coaching on top of the screen it was describing and made the
		# player's tap go to the tutorial instead of to the payout.
		"id": "target_hit", "scene": "machine", "anchor": "screen", "advance": "scene",
		"needs": "target",
		# Beating a target banks the run and parks the player at the dealer for a break
		# (issue #176). The tutorial has one more thing to show and it is not shopping, so
		# `go` carries them straight back into a fresh run: the break is real, but sitting
		# them at a counter here breaks the showcase in half and the shop is the LAST beat
		# anyway. The dealer is never drawn — the navigation replaces it the same frame.
		"go": "machine",
		"text": "TARGET BEATEN. THE HOUSE TAKES\nITS CUT, YOU BANK THE REST.",
		"state": {},
	},
	# ── the other ending ─────────────────────────────────────────────────────────────
	{
		"id": "last_spin", "scene": "machine", "anchor": "health", "advance": "tap",
		"text": "NEW RUN, ONE HEALTH LEFT.\nTHIS IS HOW RUNS USUALLY END.",
		"state": { "neurons": 1, "freeSpinsRemaining": 0, "scoreEarned": 0 },
	},
	{
		"id": "flatline_spin", "scene": "machine", "anchor": "spin_lever", "advance": "spin",
		"text": "SPEND IT.",
		"state": { "forceFlatlineSpins": 1 },
	},
	{
		# Same shape as the payout screen: wait for it, do not mask it, let its own button
		# be what moves the game on.
		"id": "flatline", "scene": "machine", "anchor": "screen", "advance": "scene",
		"needs": "over",
		# Bottom: the flatline screen's own text runs y25..204 and its button sits at
		# y226..260, so the strip below that is the only place a box does not cover
		# something. (The payout screen is the opposite case — its button is at the bottom
		# and its title says what this line says, so that beat keeps the top.)
		"box": "bottom",
		"text": "FLATLINE. THE RUN IS OVER AND\nTHE CAMPAIGN IS ONE HEALTH DOWN.",
		"state": {},
	},
	# ── between runs ─────────────────────────────────────────────────────────────────
	# A flatline with campaign health left opens a Pacte again on the way out, then the
	# dealer's odds table, and only then the shop. The tutorial follows all three: a player
	# dropped onto a second Pacte with no word about it just sits there.
	{
		"id": "pacte_again", "scene": "pacte", "anchor": "cards", "advance": "scene",
		"text": "A NEW RUN, A NEW PACTE.\nTAKE ONE FROM EACH DECK AGAIN.",
		"state": {},
	},
	{
		# The odds table owns the whole screen and the tutorial normally stands down for it
		# (see Tutorial._present_beat). `over_modal` says this beat is ABOUT it: the line is
		# shown over the table, nothing is masked, and the taps stay the table's. It ends
		# when the phase is finalized, not on a tap.
		"id": "odds", "scene": "dealer", "anchor": "screen", "advance": "anchor",
		# Top: the table's DONE button sits at the very bottom of the canvas (y~307) and its
		# rows start at y45, so the header strip is the only band a box can use.
		"needs": "odds", "over_modal": true, "box": "top",
		"text": "SPEND YOUR TOKENS HERE. BETTER ODDS\nARE PERMANENT — THEY OUTLAST THE RUN.",
		"state": {},
	},
	{
		"id": "shop", "scene": "dealer", "anchor": "offers", "advance": "tap",
		"text": "WHAT YOU BANKED BUYS THE NEXT RUN.\nSPEND IT HERE.",
		"state": {},
	},
	{
		"id": "done", "scene": "dealer", "anchor": "", "advance": "tap",
		"text": "THAT IS THE LOOP.\nGOOD LUCK.",
		"state": {},
	},
]

static func beat(index: int) -> Dictionary:
	if index < 0 or index >= BEATS.size():
		return {}
	return BEATS[index]

static func count() -> int:
	return BEATS.size()

## The scenes the script visits, in first-seen order. The director uses this to know which
## scene a beat is waiting for; the test uses it to check every one of them can anchor
## every id the script asks it for.
static func scenes() -> Array[String]:
	var out: Array[String] = []
	for b in BEATS:
		var scene := String(b["scene"])
		if not out.has(scene):
			out.append(scene)
	return out

## Anchor ids the script asks `scene` for, so a renamed anchor fails a check instead of
## silently pointing the ring at nothing.
static func anchors_for(scene: String) -> Array[String]:
	var out: Array[String] = []
	for b in BEATS:
		if String(b["scene"]) != scene:
			continue
		var anchor := String(b.get("anchor", ""))
		if anchor != "" and not out.has(anchor):
			out.append(anchor)
	return out
