extends Node

## Which language the game is in, and the one place that decides it.
##
## The rule is: the player's choice wins if they have made one, otherwise the device does.
## MetaStateStore.locale holds "" until they pick from OPTIONS, which is what lets a French
## phone open in French without ever taking the choice away from them afterwards.
##
## Almost nothing calls into here. Godot auto-translates every Control's `text` at draw
## time, so switching the locale re-renders the whole game on its own; only strings that
## are BUILT (formatted or concatenated) need an explicit tr() at their own call site.

signal locale_changed(code: String)

## The languages the game ships. Order is the order the OPTIONS row cycles through.
const SUPPORTED: Array[String] = ["en", "fr"]
const FALLBACK := "en"

## Short label for the OPTIONS row. Only a FALLBACK now that the row shows a flag: it is
## what renders while the flag art for a language is missing, so adding a third language
## never leaves the row blank before its flag is drawn.
const LABELS := { "en": "EN", "fr": "FR" }

## Compact flags in the shared muted UI palette. Both keep a 16x10 layout footprint.
const FLAGS := {
	"en": "ui/premium/flag_en.svg",
	"fr": "ui/premium/flag_fr.svg",
}
## Ceiling for a flag inside the 20px OPTIONS row. Art taller than this would crowd the
## row's border; it is a guard on the authoring, not a size anything is scaled to.
const FLAG_MAX_HEIGHT := 14.0

## The flag for a language, or null while its art has not been drawn yet. Callers fall back
## to label_for() rather than showing an empty row.
func flag_for(code: String) -> Texture2D:
	var rel := String(FLAGS.get(code, ""))
	if rel == "":
		return null
	return Assets.texture(rel)

func _ready() -> void:
	# Autoload order puts MetaStateStore before this, so its save is already loaded.
	apply(resolve())

## The locale to run in: the player's saved choice, or the device's language if they have
## never chosen, or English if the device speaks something the game does not.
func resolve() -> String:
	var chosen := String(MetaStateStore.locale)
	if SUPPORTED.has(chosen):
		return chosen
	return from_device()

## Maps the OS language onto something the game ships. `OS.get_locale()` returns things
## like "fr_FR", "fr_CA", "en_GB" — the region is irrelevant here, only the language is.
func from_device() -> String:
	var code := OS.get_locale().to_lower()
	var language := code.split("_")[0].split("-")[0]
	return language if SUPPORTED.has(language) else FALLBACK

## Switches the game's language. Does NOT record a preference — _ready calls this for the
## device default, and a device default must stay a default.
func apply(code: String) -> void:
	var safe := code if SUPPORTED.has(code) else FALLBACK
	if TranslationServer.get_locale() == safe:
		return
	TranslationServer.set_locale(safe)
	locale_changed.emit(safe)

## The player chose. Applies it AND remembers it, so the device no longer decides.
func choose(code: String) -> void:
	var safe := code if SUPPORTED.has(code) else FALLBACK
	MetaStateStore.locale = safe
	MetaStateStore.save_state()
	apply(safe)

func current() -> String:
	var code := TranslationServer.get_locale().split("_")[0]
	return code if SUPPORTED.has(code) else FALLBACK

## The next language in SUPPORTED, wrapping. The OPTIONS row is a single button rather than
## a list because there are two languages; this is what it does when tapped.
func next_of(code: String) -> String:
	var index := SUPPORTED.find(code)
	return SUPPORTED[(index + 1) % SUPPORTED.size()] if index >= 0 else FALLBACK

func label_for(code: String) -> String:
	return String(LABELS.get(code, code.to_upper()))
