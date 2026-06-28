extends GutTest

## GUT wrapper around the native sacred-rule invariants (mirrors
## __tests__/sacred-rules.test.ts). Requires the GUT addon.

func test_sacred_rules():
	var failures: Array = SacredRules.run_all()
	assert_eq(failures.size(), 0, "Sacred rules violated:\n%s" % "\n".join(failures))
