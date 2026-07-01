extends GutTest

## GUT wrapper around ParityChecks — asserts the GDScript rules core reproduces
## every golden vector from parity/vectors/. Requires the GUT addon (see
## test/README.md). The same checks run dependency-free via run_parity_headless.gd.

func _assert_no_failures(failures: Array, what: String) -> void:
	assert_eq(failures.size(), 0, "%s diverged:\n%s" % [what, "\n".join(failures)])

func test_rng():
	var out: Array = []
	ParityChecks.check_rng(out)
	_assert_no_failures(out, "rng.json")

func test_score_reels():
	var out: Array = []
	ParityChecks.check_score_reels(out)
	_assert_no_failures(out, "score_reels.json")

func test_rounding():
	var out: Array = []
	ParityChecks.check_rounding(out)
	_assert_no_failures(out, "rounding.json")

func test_evaluate():
	var out: Array = []
	ParityChecks.check_evaluate(out)
	_assert_no_failures(out, "evaluate.json")

func test_abilities():
	var out: Array = []
	ParityChecks.check_abilities(out)
	_assert_no_failures(out, "abilities.json")

func test_dealer():
	var out: Array = []
	ParityChecks.check_dealer(out)
	_assert_no_failures(out, "dealer_vectors.json")

func test_bank():
	var out: Array = []
	ParityChecks.check_bank(out)
	_assert_no_failures(out, "bank.json")

func test_lucidity():
	var out: Array = []
	ParityChecks.check_lucidity(out)
	_assert_no_failures(out, "lucidity_restore.json")

func test_endings():
	var out: Array = []
	ParityChecks.check_endings(out)
	_assert_no_failures(out, "endings.json")
