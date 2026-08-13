class_name RouteChecks
extends RefCounted

## Focused invariants for the between-machine route economy. These checks deliberately
## exercise the real stores, but restore both singletons before returning so the harness
## cannot turn a diagnostic route visit into a saved player session.

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
	_store().routeDestination = ""
	_store().routeContext = ""
	_store().routePacteVisit = false
	_store().routePacteFreeTier = false
	_store().pacteCostsActive = false
	_store().lucidityCoins = lucidity
	_store().neurons = 11
	_store().runConsumables = {}
	_store().runShopUpgrades = []
	_store().selectedAugmentCardIds = []
	_store().selectedPowerCardIds = []

static func run_all() -> Array:
	var out: Array = []
	var run_snapshot := _snapshot_run()
	var meta_snapshot: Dictionary = _meta()._as_dict()
	var campaign_neurons := int(_meta().campaignNeuronsLeft)

	var first_offer := RouteCards.offer(0x12345678, "wealth_target")
	var repeated_offer := RouteCards.offer(0x12345678, "wealth_target")
	_check(out, first_offer.size() == RouteCards.OFFER_COUNT,
		"every route offer contains exactly three cards")
	_check(out, str(first_offer) == str(repeated_offer),
		"route offers are deterministic for seed and context")
	_check(out, first_offer[0].has("seedIdentity") and first_offer[1].has("seedIdentity"),
		"route cards carry deterministic seed identities")
	_check(out, RouteCards.offer(0x12345678, "flatline")[0].get("freeLossRoute", false),
		"flatline offers mark the free loss Pacte route")
	_check(out, not RouteCards.offer(0x12345678, "wealth_target")[0].get("freeLossRoute", false),
		"target offers do not expose the loss-only free flag")

	_prepare_target(40)
	_check(out, _store().prepare_route_offer("wealth_target", 0xCAFE),
		"the store prepares a target route offer")
	var persisted_offer: Array[Dictionary] = _store().current_route_offer()
	_store().load_run_state()
	_check(out, _store().routeOfferPending and _store().has_resume_state(),
		"a pending route offer remains resumable after loading the run save")
	_check(out, _store().current_route_offer() == persisted_offer,
		"loading a saved route restores the exact offered cards")
	var serialized: Dictionary = {}
	for property_name in _store()._run_state_properties():
		serialized[property_name] = _store().get(property_name)
	_check(out, serialized.has("routeOfferPending") and serialized.has("routeOfferCards"),
		"route offer state is included in the run save property set")
	var round_trip: Variant = str_to_var(var_to_str(serialized))
	_check(out, round_trip is Dictionary and bool((round_trip as Dictionary).get("routeOfferPending", false)),
		"route offer state survives the save value round trip")

	var lucidity_before_refusal: int = int(_store().lucidityCoins)
	var neurons_before_refusal: int = int(_store().neurons)
	_check(out, _store().refuse_routes(), "refusing an offer continues to the next machine")
	_check(out, _store().lucidityCoins == lucidity_before_refusal,
		"refusing routes spends no run Lucidity")
	_check(out, _store().neurons == EconomyConst.STARTING_NEURONS,
		"refusing routes starts the next machine with its normal spin budget")
	_check(out, neurons_before_refusal != _store().neurons,
		"the refusal assertion exercised a real machine transition")

	_prepare_target(80)
	_store().prepare_route_offer("wealth_target", 0xBEEF)
	var has_affordable_route := false
	for card in _store().current_route_offer():
		if _store().route_card_affordable(String(card.get("id", ""))):
			has_affordable_route = true
			break
	_check(out, has_affordable_route,
		"a funded route offer keeps at least one valid investment affordable")
	var pacte_card := RouteCards.CARD_PACTE_ID
	var pacte_before: int = int(_store().lucidityCoins)
	var neurons_before_pacte: int = int(_store().neurons)
	_check(out, _store().route_card_affordable(pacte_card),
		"a normal Pacte route is affordable when its investment is affordable")
	_check(out, _store().select_route(pacte_card), "selecting Pacte opens the paid ritual")
	_check(out, _store().pacteCostsActive and not _store().routeOfferPending,
		"Pacte selection closes the route offer and activates card pricing")
	_check(out, _store().neurons == neurons_before_pacte,
		"normal Pacte purchases do not sacrifice spins")
	var augment_offer: Array = _store().pacteOfferAugmentIds as Array
	var power_offer: Array = _store().pacteOfferPowerIds as Array
	if not augment_offer.is_empty() and not power_offer.is_empty():
		var augment_id := String(augment_offer[0])
		var power_id := String(power_offer[0])
		var card_cost: int = int(_store().pacte_card_cost(augment_id)) \
			+ _store().pacte_card_cost(power_id)
		_check(out, card_cost > 0, "normal route Pacte cards carry Lucidity prices")
		_check(out, _store().complete_pacte_selection(augment_id, power_id),
			"an affordable route Pacte selection completes")
		_check(out, _store().lucidityCoins == pacte_before \
			- RouteCards.PACTE_ROUTE_COST - card_cost,
			"Pacte route and card costs are both charged from run Lucidity")
	else:
		_check(out, false, "normal route Pacte exposes an augment and a power")

	_prepare_target(100)
	_store().prepare_route_offer("wealth_target", 0xFACE)
	_check(out, _store().select_route(RouteCards.CARD_SHOP_ID), "selecting Shop opens the run Shop")
	var shop_neurons: int = int(_store().neurons)
	_check(out, _store().buy_route_shop_item("cons_tea"),
		"the run Shop sells a consumable from run Lucidity")
	_check(out, _store().neurons == shop_neurons,
		"buying a Shop consumable does not sacrifice spins")
	_check(out, int(_store().runConsumables.get("cons_tea", 0)) == 1,
		"buying a Shop consumable adds one stash copy")
	_store().runPhase = "running"
	_check(out, _store().use_consumable("cons_tea"),
		"a Shop consumable can be used by the machine")
	_check(out, not _store().runConsumables.has("cons_tea"),
		"a used Shop consumable disappears from the stash")
	_check(out, not _meta().ownedPermanents.has("shop_spin_reserve"),
		"run Shop upgrades do not leak into persistent Lab state")

	_prepare_target(100)
	_store().prepare_route_offer("wealth_target", 0xD00D)
	_check(out, _store().select_route(RouteCards.CARD_DEALER_ID),
		"selecting Dealer opens tactical services")
	var dealer_neurons: int = int(_store().neurons)
	_check(out, _store().buy_route_dealer_service("dealer_route_spins"),
		"Dealer route services spend run Lucidity")
	_check(out, _store().runDealerServices.has("dealer_route_spins"),
		"Dealer spin service is queued for the next machine segment")
	_check(out, _store().finish_route_destination() and _store().runPhase == "running",
		"Dealer service destination returns to a live machine segment")
	_check(out, _store().neurons == mini(EconomyConst.MAX_NEURONS,
		EconomyConst.STARTING_NEURONS + 3),
		"Dealer spin service restores spins subject to the normal cap")
	_check(out, dealer_neurons != _store().neurons,
		"Dealer spin service changes the next segment's starting budget")
	_check(out, _store().dealerOfferIds == null and not _store().dealerPending,
		"the route Dealer does not create an in-machine offer")

	_prepare_target(20)
	_meta().campaignNeuronsLeft = maxi(1, campaign_neurons)
	_store().prepare_route_offer("flatline", 0xF00D)
	_check(out, _store().select_route(RouteCards.CARD_PACTE_ID),
		"a survivable loss opens the free Pacte route")
	_check(out, _store().routePacteFreeTier,
		"the loss Pacte is marked as the free lowest-tier route")
	var loss_augments: Array = _store().pacteOfferAugmentIds as Array
	var loss_powers: Array = _store().pacteOfferPowerIds as Array
	if not loss_augments.is_empty() and not loss_powers.is_empty():
		_check(out, int(PacteCards.tier_for(String(loss_augments[0]))) == 0 \
			and int(PacteCards.tier_for(String(loss_powers[0]))) == 0,
			"loss recovery Pacte offers are capped at the lowest tier")
		_check(out, _store().pacte_card_cost(String(loss_augments[0])) == 0 \
			and _store().pacte_card_cost(String(loss_powers[0])) == 0,
			"loss recovery Pacte cards are free")

	_restore_run(run_snapshot)
	_meta()._apply(meta_snapshot)
	_meta().campaignNeuronsLeft = campaign_neurons
	_store()._commit()
	return out
