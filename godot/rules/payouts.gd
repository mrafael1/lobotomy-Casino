class_name Payouts
extends RefCounted

## Port of src/content/payouts.ts.

const JACKPOT_SCORE := 200
const JACKPOT_FREE_SPIN_GRANT := 1

const TRIPLE_SCORE := {
	"eye": 50, "pill": 35, "syringe": 25, "vial": 15, "flatline": 0, "book": 15,
	# brain -> jackpot, handled separately
}

const PAIR_SCORE := {
	"brain": 20, "eye": 10, "pill": 7, "syringe": 5, "vial": 3, "flatline": 0, "book": 5,
}

const BOOK_BONUS_PER_VISIBLE := 10
