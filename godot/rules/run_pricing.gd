class_name RunPricing
extends RefCounted

## One readable progression curve for every run-scoped purchase.  Round 1 is
## unchanged; each later machine segment adds 15 percentage points.

const ROUND_PRICE_STEP := 0.15

static func multiplier(round_index: int) -> float:
	return 1.0 + ROUND_PRICE_STEP * float(maxi(0, round_index - 1))

static func calculate_run_price(base_price: int, round_index: int) -> int:
	if base_price <= 0:
		return 0
	return floori(float(base_price) * multiplier(round_index) + 0.5)

static func markup_percent(round_index: int) -> int:
	return roundi((multiplier(round_index) - 1.0) * 100.0)

static func progression_label(round_index: int) -> String:
	var markup := markup_percent(round_index)
	return "ROUND %d PRICE" % round_index if markup <= 0 \
		else "ROUND %d PRICE  /  +%d%%" % [round_index, markup]
