class_name FixedRNG
extends LobRNG

## Test-only RNG that always returns a constant — mirrors the brainRng/flatlineRng
## stubs in __tests__/sacred-rules.test.ts. next()==0 selects the first weighted
## symbol (brain); next()~=0.999 selects the last (flatline).

var _value: float

func _init(value: float) -> void:
	super._init(0)
	_value = value

func next() -> float:
	return _value
