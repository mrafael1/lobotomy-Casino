class_name RouteChecks
extends RefCounted

## Focused invariants for the between-machine route economy. These checks exercise
## the real stores and restore both singletons before returning to the harness.

static func _check(out: Array, condition: bool, label: String) -> void:
	if not condition:
		out.append("ROUTE: " + label)

static func _store() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"RunStateStore") as Node

static func _meta() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"MetaStateStore") as Node

static func _snapshot_run() -> Dictionary:
	var snapshot: Dictionary = {}
	for property_name in _store()._run_state_properties():
		snapshot[property_name] = _store().get(property_name)
	return snapshot

static func _restore_run(snapshot: Dictionary) -> void:
	for property_name in snapshot:
		_store().set(String(property_name), snapshot[property_name])

static func _prepare_target(lucidity: int) -> void:
	_store().runPhase = "over"
	_store().lastEnding = null
	_store().roundContinuationPending = true
	_store().routeOfferPending = false
	_store().routeOfferCards = null
	_store().routeOfferRerollCount = 0
	_store().routeDestination = ""
	_store().routeContext = ""
	_store().routeSelectedCardId = ""
	_store().routePacteVisit = false
	_store().routePacteFreeTier = false
	_store().pacteCostsActive = false
	_store().routeBuildKind = ""
	_store().routeBuildOfferIds = null
	_store().routeBuildFreeTier = false
	_store().routeBuildSelectedId = ""
	_store().routeBonusClaimed = false
	_store().routeBonusRewardId = ""
	_store().routeBonusSpinSeed = 0
	_store().sacrificeClaimed = false
	_store().sacrificeSelectedId = ""
	_store().nextRoundGainMultiplier = 1.0
	_store().nextRoundStartingScore = 0
	_store().nextRoundSpinBonus = 0
	_store().oddsTokenBudgetOverride = 0
	_store().oddsTokensRemaining = 0
	_store().oddsPendingUpgrades = {}
	_store().oddsPhaseCompleted = false
	_store().lucidityCoins = lucidity
	_store().neurons = 11
	_store().runConsumables = {}
	_store().runShopUpgrades = []
	_store().runDealerServices = []
	_store().selectedAugmentCardIds = []
	_store().selectedPowerCardIds = []

static func _offer_has_card(card_id: String) -> bool:
	for card in _store().current_route_offer():
		if String(card.get("id", "")) == card_id:
			return true
	return false

static func _prepare_offer_with_card(lucidity: int, context: String, card_id: String,
		seed_start: int) -> bool:
	for offset in 64:
		_prepare_target(lucidity)
		if _store().prepare_route_offer(context, seed_start + offset) \
			and _offer_has_card(card_id):
			return true
	return false

static func _build_card_id(store: Node) -> String:
	var offers: Array = store.routeBuildOfferIds as Array
	return String(offers[0]) if not offers.is_empty() else ""

static func _complete_build(store: Node, card_id: String) -> bool:
	var symbol := "brain" if store.route_build_card_requires_symbol(card_id) else ""
	return store.complete_route_build_selection(card_id, symbol)

static func run_all() -> Array:
	var out: Array = []
	var run_snapshot := _snapshot_run()
	var meta_snapshot: Dictionary = _meta()._as_dict()
	var campaign_neurons := int(_meta().campaignNeuronsLeft)

	var first_offer := RouteCards.offer(0x12345678, "wealth_target")
	var repeated_offer := RouteCards.offer(0x12345678, "wealth_target")
	_check(out, first_offer.size() == RouteCards.OFFER_COUNT,
		"every dealer offer contains exactly two choices")
	_check(out, str(first_offer) == str(repeated_offer),
		"route offers are deterministic for seed and context")
	_check(out, first_offer.all(func(card: Dictionary) -> bool: return card.has("seedIdentity")),
		"route cards carry deterministic seed identities")
	var route_types: Array[String] = []
	for card in first_offer:
		route_types.append(String(card.get("routeType", "")))
		_check(out, RouteCards.card_cost(card) == 0,
			"route-door entry is free for every offered card")
	_check(out, route_types.size() == 2 and route_types[0] != route_types[1],
		"dealer offers contain two distinct route types")
	_check(out, route_types.any(func(route_type: String) -> bool:
		return route_type == RouteCards.ROUTE_SHOP \
			or route_type == RouteCards.ROUTE_AUGMENT \
			or route_type == RouteCards.ROUTE_POWER),
		"target dealer offers include an investment route")
	_check(out, not route_types.has(RouteCards.ROUTE_PACTE) \
			and not route_types.has(RouteCards.ROUTE_DEALER),
		"full Pacte and between-machine Dealer are not offered")
	var loss_offer := RouteCards.offer(0x12345678, "flatline")
	_check(out, loss_offer.any(func(card: Dictionary) -> bool:
		return bool(card.get("freeLossRoute", false)) \
			and (String(card.get("routeType", "")) == RouteCards.ROUTE_AUGMENT \
			or String(card.get("routeType", "")) == RouteCards.ROUTE_POWER)),
		"flatline dealer offers include a free tier-capped build route")
	_check(out, not first_offer.any(func(card: Dictionary) -> bool:
		return bool(card.get("freeLossRoute", false))),
		"target offers do not expose the loss-only free flag")
	var rerolled_offer := RouteCards.reroll_offer(0x12345678, "wealth_target", 1,
		first_offer)
	_check(out, rerolled_offer.size() == RouteCards.OFFER_COUNT \
		and str(rerolled_offer) != str(first_offer),
		"route rerolls change both visible door data and their identities")

	_prepare_target(0)
	_check(out, _store().prepare_route_offer("wealth_target", 0xD00D),
		"a zero-gold run still prepares its route doors")
	for card in _store().current_route_offer():
		_check(out, _store().route_card_affordable(String(card.get("id", ""))),
			"route doors remain selectable without run Lucidity")

	_prepare_target(40)
	_check(out, _store().prepare_route_offer("wealth_target", 0xCAFE),
		"the store prepares a target route offer")
	var persisted_offer: Array[Dictionary] = _store().current_route_offer()
	_store().load_run_state()
	_check(out, _store().routeOfferPending and _store().has_resume_state(),
		"a pending route offer remains resumable after loading the run save")
	_check(out, _store().current_route_offer() == persisted_offer,
		"loading a saved route restores the exact offered choices")
	var lucidity_before_reroll := int(_store().lucidityCoins)
	var first_reroll_offer: Array[Dictionary] = _store().current_route_offer()
	_check(out, _store().route_offer_reroll_price() == 10,
		"the first route-door reroll costs 10G")
	_check(out, _store().reroll_route_offer(),
		"the dealer can reshuffle a funded route offer")
	_check(out, _store().routeOfferRerollCount == 1 \
		and _store().lucidityCoins == lucidity_before_reroll - 10 \
		and _store().current_route_offer() != first_reroll_offer,
		"a route reroll charges Lucidity and replaces the doors")
	_check(out, _store().route_offer_reroll_price() == 20,
		"route-door reroll price escalates after each payment")
	var rerolled_persisted_offer: Array[Dictionary] = _store().current_route_offer()
	_store().load_run_state()
	_check(out, _store().routeOfferRerollCount == 1 \
		and _store().current_route_offer() == rerolled_persisted_offer,
		"the rerolled route doors persist through save and resume")
	var serialized: Dictionary = {}
	for property_name in _store()._run_state_properties():
		serialized[property_name] = _store().get(property_name)
	_check(out, serialized.has("routeOfferPending") and serialized.has("routeOfferRerollCount") \
		and serialized.has("routeBuildOfferIds"),
		"route offer, reroll and build state are included in run persistence")
	var round_trip: Variant = str_to_var(var_to_str(serialized))
	_check(out, round_trip is Dictionary and bool((round_trip as Dictionary).get("routeOfferPending", false)),
		"route state survives the save value round trip")

	var lucidity_before_refusal := int(_store().lucidityCoins)
	var neurons_before_refusal := int(_store().neurons)
	_check(out, _store().refuse_routes(), "refusing an offer is the free CONTINUE path")
	_check(out, _store().lucidityCoins == lucidity_before_refusal,
		"refusing routes spends no run Lucidity")
	_check(out, _store().routeDestination == "",
		"the free refusal does not silently enter Sacrifice")
	_check(out, _store().neurons == EconomyConst.STARTING_NEURONS,
		"refusal starts the next machine with its normal spin budget")
	_check(out, neurons_before_refusal != _store().neurons,
		"the refusal assertion exercised a real machine transition")

	_prepare_offer_with_card(80, "wealth_target", RouteCards.CARD_AUGMENT_ID, 0xBEEF)
	var has_affordable_route := false
	for card in _store().current_route_offer():
		if _store().route_card_affordable(String(card.get("id", ""))):
			has_affordable_route = true
			break
	_check(out, has_affordable_route,
		"a funded route offer keeps at least one valid investment affordable")

	var neurons_before_augment := int(_store().neurons)
	var lucidity_before_augment := int(_store().lucidityCoins)
	_check(out, _store().select_route(RouteCards.CARD_AUGMENT_ID),
		"selecting Augment opens the single augment deck")
	_check(out, int(_store().lucidityCoins) == lucidity_before_augment,
		"selecting Augment does not charge a route-entry fee")
	_check(out, _store().routeDestination == RouteCards.ROUTE_AUGMENT \
			and not _store().pacte_active() and not _store().pacteCostsActive,
		"the augment route never enters the full Pacte scene")
	_check(out, _store().routeBuildOfferIds is Array \
			and (_store().routeBuildOfferIds as Array).size() > 0,
		"the augment route exposes only augment cards")
	var augment_id := _build_card_id(_store())
	_check(out, _complete_build(_store(), augment_id),
		"the augment route accepts one affordable augment")
	_check(out, _store().finish_route_destination() and _store().runPhase == "running",
		"the augment route returns to the next machine")
	_check(out, _store().neurons == EconomyConst.STARTING_NEURONS,
		"augment route payment does not sacrifice spins")
	_check(out, int(_store().lucidityCoins) < lucidity_before_augment,
		"the selected augment card, not route entry, uses run Lucidity")
	_check(out, neurons_before_augment != _store().neurons,
		"augment route test exercised a machine transition")

	_prepare_offer_with_card(80, "wealth_target", RouteCards.CARD_POWER_ID, 0xBEEF)
	var neurons_before_power := int(_store().neurons)
	var lucidity_before_power := int(_store().lucidityCoins)
	_check(out, _store().select_route(RouteCards.CARD_POWER_ID),
		"selecting Power opens the single power deck")
	_check(out, int(_store().lucidityCoins) == lucidity_before_power,
		"selecting Power does not charge a route-entry fee")
	_check(out, _store().routeDestination == RouteCards.ROUTE_POWER \
			and not _store().pacte_active(),
		"the power route is separate from Pacte")
	_check(out, _store().routeBuildOfferIds is Array \
			and (_store().routeBuildOfferIds as Array).size() > 0,
		"the power route exposes only power cards")
	var power_id := _build_card_id(_store())
	_check(out, _complete_build(_store(), power_id),
		"the power route accepts one affordable power")
	_check(out, _store().finish_route_destination() and _store().runPhase == "running",
		"the power route returns to the next machine")
	_check(out, _store().neurons == EconomyConst.STARTING_NEURONS \
			and neurons_before_power != _store().neurons,
		"power route payment does not sacrifice spins")

	_prepare_offer_with_card(100, "wealth_target", RouteCards.CARD_SHOP_ID, 0xFACE)
	_check(out, _store().select_route(RouteCards.CARD_SHOP_ID), "selecting Shop opens the run Shop")
	var shop_neurons := int(_store().neurons)
	_check(out, _store().buy_route_shop_item("cons_tea"),
		"the run Shop sells a consumable from run Lucidity")
	_check(out, _store().neurons == shop_neurons,
		"buying a Shop consumable does not sacrifice spins")
	_check(out, int(_store().runConsumables.get("cons_tea", 0)) == 1,
		"buying a Shop consumable adds one stash copy")
	_store().runPhase = "running"
	_check(out, _store().use_consumable("cons_tea"), "a Shop consumable can be used by the machine")
	_check(out, not _store().runConsumables.has("cons_tea"),
		"a used Shop consumable disappears from the stash")
	_check(out, not _meta().ownedPermanents.has("shop_spin_reserve"),
		"run Shop upgrades do not leak into persistent Lab state")

	_prepare_offer_with_card(20, "wealth_target", RouteCards.CARD_BONUS_ID, 0xD00D)
	var bonus_before := int(_store().lucidityCoins)
	_check(out, _store().select_route(RouteCards.CARD_BONUS_ID),
		"selecting Bonus opens the bonus scene")
	_check(out, _store().claim_route_bonus(), "the bonus can be claimed once")
	_check(out, int(_store().lucidityCoins) == bonus_before + 50,
		"Bonus pays 50 run coins")
	_check(out, not _store().claim_route_bonus(), "Bonus cannot be claimed twice")
	_check(out, _store().finish_route_destination() and _store().runPhase == "running",
		"the bonus scene returns to the next machine")

	_check(out, FortuneWheelRules.SEGMENT_IDS.size() == 5,
		"the Fortune Wheel has exactly the five requested rewards")
	_check(out, FortuneWheelRules.reward_for_id(FortuneWheelRules.REWARD_COINS_50).get(
		"runLucidity", 0) == 50, "the wheel's coin prize is 50 run coins")
	_check(out, is_equal_approx(float(FortuneWheelRules.reward_for_id(
		FortuneWheelRules.REWARD_GAIN_125).get("gainMultiplier", 0.0)), 1.25),
		"the wheel exposes the x1.25 gain prize")
	var jackpot_reward := FortuneWheelRules.reward_for_id(FortuneWheelRules.REWARD_JACKPOT)
	_check(out, bool(jackpot_reward.get("flatlineRestrictionRemoved", false)) \
		and int(jackpot_reward.get("runLucidity", 0)) == 100 \
		and is_equal_approx(float(jackpot_reward.get("startingScoreFraction", 0.0)), 0.5),
		"the jackpot carries its no-cap, half-score and 100-coin effects")

	_prepare_offer_with_card(20, "wealth_target", RouteCards.CARD_BONUS_ID, 0xD100)
	_check(out, _store().select_route(RouteCards.CARD_BONUS_ID),
		"the gain prize can open the bonus route")
	_check(out, _store().claim_route_bonus_reward(FortuneWheelRules.REWARD_GAIN_125),
		"the gain prize can be claimed")
	_check(out, is_equal_approx(float(_store().nextRoundGainMultiplier), 1.25),
		"the gain prize is stored for the next round")
	var base_gain_multiplier := Economy.compute_lucidity_multiplier(_store().ownedUpgrades)
	_check(out, _store().finish_route_destination() \
		and is_equal_approx(float(_store().lucidityMultiplier), base_gain_multiplier * 1.25),
		"the gain prize applies to the next machine round")

	_prepare_offer_with_card(20, "wealth_target", RouteCards.CARD_BONUS_ID, 0xD200)
	_check(out, _store().select_route(RouteCards.CARD_BONUS_ID),
		"the jackpot can open the bonus route")
	_store().wealthTargetIndex = 1
	var jackpot_target: int = _store().current_wealth_target()
	var jackpot_coins_before := int(_store().lucidityCoins)
	_check(out, _store().claim_route_bonus_reward(FortuneWheelRules.REWARD_JACKPOT),
		"the jackpot can be claimed")
	_check(out, int(_store().lucidityCoins) == jackpot_coins_before + 100 \
		and _store().flatlineRestrictionRemoved \
		and int(_store().nextRoundStartingScore) == floori(float(jackpot_target) * 0.5),
		"the jackpot stores all three next-round effects")
	_check(out, _store().finish_route_destination() \
		and int(_store().scoreEarned) == floori(float(jackpot_target) * 0.5) \
		and _store().flatlineRestrictionRemoved,
		"the jackpot starts the next round with half its target and no cap")

	_prepare_offer_with_card(20, "wealth_target", RouteCards.CARD_BONUS_ID, 0xD300)
	_check(out, _store().select_route(RouteCards.CARD_BONUS_ID),
		"the eight-token odds prize can open the bonus route")
	_check(out, _store().claim_route_bonus_reward(FortuneWheelRules.REWARD_ODDS_8),
		"the eight-token odds prize can be claimed")
	_check(out, int(_store().oddsTokenBudgetOverride) == 8,
		"the odds prize stores an eight-token table override")
	_store().begin_odds_phase()
	_check(out, int(_store().oddsTokensRemaining) == 8,
		"the eight-token odds table opens with eight tokens")
	_store().finalize_odds_phase()
	_check(out, _store().oddsPhaseCompleted and int(_store().oddsTokensRemaining) == 0,
		"the odds prize closes as a completed phase")
	_check(out, _store().finish_route_destination() and _store().runPhase == "running",
		"the odds prize returns to the next machine")

	_prepare_offer_with_card(200, "wealth_target", RouteCards.CARD_SACRIFICE_ID, 0xD400)
	_store().selectedAugmentCardIds = ["augment_book"]
	_store().selectedPowerCardIds = ["reroll"]
	_store().ownedPowerIds = ["reroll"]
	_store().ownedUpgrades = []
	_check(out, _store().select_route(RouteCards.CARD_SACRIFICE_ID),
		"selecting Sacrifice opens the resource trade scene")
	_meta().campaignNeuronsLeft = 1
	var sacrifice_options: Array = _store().sacrifice_options()
	var has_neuron_option := false
	for option in sacrifice_options:
		if String(option.get("id", "")) == SacrificeRules.OPTION_NEURON:
			has_neuron_option = true
	_check(out, not has_neuron_option,
		"Sacrifice hides the neuron choice when only one remains")
	_meta().campaignNeuronsLeft = 3
	sacrifice_options = _store().sacrifice_options()
	_check(out, sacrifice_options.size() == 4,
		"Sacrifice exposes augment, power, coin and neuron choices")
	var sacrifice_coins_before := int(_store().lucidityCoins)
	_check(out, _store().claim_sacrifice(SacrificeRules.OPTION_COINS),
		"Sacrifice accepts the 100-coin trade")
	_check(out, int(_store().lucidityCoins) == sacrifice_coins_before - 100 \
		and int(_store().nextRoundSpinBonus) == SacrificeRules.BONUS_SPINS \
		and int(_store().sacrificeCount) == 1,
		"Sacrifice grants its next-round spin boon once")
	_check(out, not _store().claim_sacrifice(SacrificeRules.OPTION_COINS),
		"one Sacrifice route cannot be claimed twice")
	_check(out, _store().finish_route_destination() and _store().runPhase == "running",
		"Sacrifice returns to the next machine")
	_check(out, int(_store().neurons) == mini(EconomyConst.STARTING_NEURONS +
		SacrificeRules.BONUS_SPINS, Economy.compute_neuron_cap(_store().ownedUpgrades)),
		"Sacrifice's spin boon is applied within the neuron cap")

	_prepare_offer_with_card(0, "wealth_target", RouteCards.CARD_SACRIFICE_ID, 0xD500)
	_store().selectedAugmentCardIds = ["augment_book"]
	_store().ownedUpgrades = ["pos_learning"]
	_store().selectedPowerCardIds = ["reroll"]
	_store().ownedPowerIds = ["reroll"]
	_check(out, _store().select_route(RouteCards.CARD_SACRIFICE_ID) \
		and _store().claim_sacrifice(SacrificeRules.option_id_for_augment("augment_book")) \
		and not _store().selectedAugmentCardIds.has("augment_book") \
		and not _store().ownedUpgrades.has("pos_learning"),
		"Sacrifice can remove an owned augment")
	_check(out, _store().finish_route_destination(),
		"the augment sacrifice can start its next machine")

	_prepare_offer_with_card(0, "wealth_target", RouteCards.CARD_SACRIFICE_ID, 0xD600)
	_store().selectedPowerCardIds = ["reroll"]
	_store().ownedPowerIds = ["reroll"]
	_check(out, _store().select_route(RouteCards.CARD_SACRIFICE_ID) \
		and _store().claim_sacrifice(SacrificeRules.option_id_for_power("reroll")) \
		and not _store().has_power("reroll"),
		"Sacrifice can remove an owned power")
	_check(out, _store().finish_route_destination(),
		"the power sacrifice can start its next machine")
	_prepare_offer_with_card(0, "wealth_target", RouteCards.CARD_SACRIFICE_ID, 0xD700)
	_check(out, _store().select_route(RouteCards.CARD_SACRIFICE_ID),
		"a fourth Sacrifice route can still be offered")
	_check(out, _store().sacrifice_options().is_empty() \
		and not _store().claim_sacrifice(SacrificeRules.OPTION_COINS),
		"Sacrifice refuses every trade after its three-use cap")
	_check(out, _store().refuse_sacrifice() and _store().runPhase == "running",
		"a maxed Sacrifice route can be refused safely")

	_prepare_offer_with_card(20, "flatline", RouteCards.CARD_AUGMENT_ID, 0xF00D)
	var loss_before_spins := int(_store().neurons)
	_check(out, _store().select_route(RouteCards.CARD_AUGMENT_ID),
		"a survivable loss opens the free Augment route")
	_check(out, _store().routeBuildFreeTier and _store().route_build_card_cost(
			_build_card_id(_store())) == 0,
		"loss recovery is free and tier-capped")
	_check(out, _complete_build(_store(), _build_card_id(_store())),
		"loss recovery accepts one lowest-tier augment")
	_check(out, _store().finish_route_destination() and _store().neurons == EconomyConst.STARTING_NEURONS,
		"loss recovery returns to a machine without spending spins")
	_check(out, loss_before_spins != _store().neurons,
		"loss recovery exercised a real machine transition")

	_prepare_offer_with_card(80, "wealth_target", RouteCards.CARD_POWER_ID, 0xABCD)
	_check(out, _store().select_route(RouteCards.CARD_POWER_ID),
		"power route can be saved before card selection")
	var build_ids_before_save: Array = (_store().routeBuildOfferIds as Array).duplicate()
	_store().load_run_state()
	_check(out, _store().routeDestination == RouteCards.ROUTE_POWER \
			and (_store().routeBuildOfferIds as Array) == build_ids_before_save,
		"power route offers persist through save and resume")
	_check(out, not _store().routeOfferPending \
		and _store().routeDestination == RouteCards.ROUTE_POWER,
		"selecting a door keeps the route committed while its build screen is open")

	_check(out, not _store().pacte_active() if _store().runPhase == "pacte_threshold" else true,
		"threshold state cannot reopen the full Pacte scene")

	# Shared progression pricing: every run-scoped price reads the same curve, while
	# the route door itself remains free at every round.
	var previous_round := int(_store().wealthTargetIndex)
	var previous_pacte_costs := bool(_store().pacteCostsActive)
	var previous_route_context := String(_store().routeContext)
	var previous_route_kind := String(_store().routeBuildKind)
	var previous_dealer_reroll_count := int(_store().dealerRerollCount)
	_store().pacteCostsActive = true
	_store().routePacteFreeTier = false
	_store().routeBuildFreeTier = false
	_store().routeContext = "wealth_target"
	_store().routeBuildKind = RouteCards.ROUTE_POWER
	_store().dealerRerollCount = 0
	_store().wealthTargetIndex = 0
	var round_one_card: int = int(_store().pacte_card_cost("reroll"))
	var round_one_shop: int = int(_store().route_shop_item_cost("shop_pair_guard"))
	var round_one_dealer: int = int(_store().dealer_reroll_price())
	_store().wealthTargetIndex = 1
	var round_two_card: int = int(_store().pacte_card_cost("reroll"))
	var round_two_shop: int = int(_store().route_shop_item_cost("shop_pair_guard"))
	var round_two_dealer: int = int(_store().dealer_reroll_price())
	_store().wealthTargetIndex = 2
	var round_three_card: int = int(_store().pacte_card_cost("reroll"))
	_check(out, round_one_card == RunPricing.calculate_run_price(8, 1)
		and round_two_card == RunPricing.calculate_run_price(8, 2)
		and round_three_card == RunPricing.calculate_run_price(8, 3),
		"Pacte card prices use the centralized round curve")
	_check(out, round_one_card < round_two_card and round_two_card < round_three_card,
		"Pacte card prices increase with each round")
	_check(out, round_one_shop < round_two_shop,
		"Shop prices increase with each round")
	_check(out, round_one_dealer < round_two_dealer,
		"Dealer service prices increase with each round")
	_check(out, _store().run_price_label(3).contains("ROUND 3")
		and _store().run_price_label(3).contains("+30%"),
		"progression pricing exposes its round markup to the UI")
	_store().wealthTargetIndex = previous_round
	_store().pacteCostsActive = previous_pacte_costs
	_store().routeContext = previous_route_context
	_store().routeBuildKind = previous_route_kind
	_store().dealerRerollCount = previous_dealer_reroll_count

	_restore_run(run_snapshot)
	_meta()._apply(meta_snapshot)
	_meta().campaignNeuronsLeft = campaign_neurons
	_store()._commit()
	return out
