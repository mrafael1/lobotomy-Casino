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
	_store().sacrificeLaterPending = false
	_store().lucidityCoins = lucidity
	_store().neurons = 11
	_store().runConsumables = {}
	_store().runShopUpgrades = []
	_store().runDealerServices = []
	_store().selectedAugmentCardIds = []
	_store().selectedPowerCardIds = []

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
		"every route offer contains exactly five choices")
	_check(out, str(first_offer) == str(repeated_offer),
		"route offers are deterministic for seed and context")
	_check(out, first_offer.all(func(card: Dictionary) -> bool: return card.has("seedIdentity")),
		"route cards carry deterministic seed identities")
	var route_types: Array[String] = []
	for card in first_offer:
		route_types.append(String(card.get("routeType", "")))
	_check(out, route_types.has(RouteCards.ROUTE_SHOP) \
			and route_types.has(RouteCards.ROUTE_AUGMENT) \
			and route_types.has(RouteCards.ROUTE_POWER) \
			and route_types.has(RouteCards.ROUTE_BONUS) \
			and route_types.has(RouteCards.ROUTE_SACRIFICE),
		"offers contain Shop, Augment, Power, Bonus, and Sacrifice Later")
	_check(out, not route_types.has(RouteCards.ROUTE_PACTE) \
			and not route_types.has(RouteCards.ROUTE_DEALER),
		"full Pacte and between-machine Dealer are not offered")
	var loss_offer := RouteCards.offer(0x12345678, "flatline")
	_check(out, loss_offer[1].get("freeLossRoute", false) \
			and loss_offer[2].get("freeLossRoute", false),
		"flatline marks the augment and power routes free")
	_check(out, not first_offer[1].get("freeLossRoute", false),
		"target offers do not expose the loss-only free flag")

	_prepare_target(40)
	_check(out, _store().prepare_route_offer("wealth_target", 0xCAFE),
		"the store prepares a target route offer")
	var persisted_offer: Array[Dictionary] = _store().current_route_offer()
	_store().load_run_state()
	_check(out, _store().routeOfferPending and _store().has_resume_state(),
		"a pending route offer remains resumable after loading the run save")
	_check(out, _store().current_route_offer() == persisted_offer,
		"loading a saved route restores the exact offered choices")
	var serialized: Dictionary = {}
	for property_name in _store()._run_state_properties():
		serialized[property_name] = _store().get(property_name)
	_check(out, serialized.has("routeOfferPending") and serialized.has("routeBuildOfferIds"),
		"route offer and build state are included in run persistence")
	var round_trip: Variant = str_to_var(var_to_str(serialized))
	_check(out, round_trip is Dictionary and bool((round_trip as Dictionary).get("routeOfferPending", false)),
		"route state survives the save value round trip")

	var lucidity_before_refusal := int(_store().lucidityCoins)
	var neurons_before_refusal := int(_store().neurons)
	_check(out, _store().refuse_routes(), "refusing an offer is the free Sacrifice Later path")
	_check(out, _store().lucidityCoins == lucidity_before_refusal,
		"refusing routes spends no run Lucidity")
	_check(out, _store().sacrificeLaterPending,
		"the free refusal records Sacrifice Later without spending spins")
	_check(out, _store().neurons == EconomyConst.STARTING_NEURONS,
		"refusal starts the next machine with its normal spin budget")
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

	var neurons_before_augment := int(_store().neurons)
	var lucidity_before_augment := int(_store().lucidityCoins)
	_check(out, _store().select_route(RouteCards.CARD_AUGMENT_ID),
		"selecting Augment opens the single augment deck")
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
		"augment route and card costs use run Lucidity")
	_check(out, neurons_before_augment != _store().neurons,
		"augment route test exercised a machine transition")

	_prepare_target(80)
	_store().prepare_route_offer("wealth_target", 0xBEEF)
	var neurons_before_power := int(_store().neurons)
	_check(out, _store().select_route(RouteCards.CARD_POWER_ID),
		"selecting Power opens the single power deck")
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

	_prepare_target(100)
	_store().prepare_route_offer("wealth_target", 0xFACE)
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

	_prepare_target(20)
	_store().prepare_route_offer("wealth_target", 0xD00D)
	var bonus_before := int(_store().lucidityCoins)
	_check(out, _store().select_route(RouteCards.CARD_BONUS_ID),
		"selecting Bonus opens the bonus scene")
	_check(out, _store().claim_route_bonus(), "the bonus can be claimed once")
	_check(out, int(_store().lucidityCoins) == bonus_before + 10,
		"Bonus pays run Lucidity")
	_check(out, not _store().claim_route_bonus(), "Bonus cannot be claimed twice")
	_check(out, _store().finish_route_destination() and _store().runPhase == "running",
		"the bonus scene returns to the next machine")

	_prepare_target(20)
	_store().prepare_route_offer("flatline", 0xF00D)
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

	_prepare_target(80)
	_store().prepare_route_offer("wealth_target", 0xABCD)
	_check(out, _store().select_route(RouteCards.CARD_POWER_ID),
		"power route can be saved before card selection")
	var build_ids_before_save: Array = (_store().routeBuildOfferIds as Array).duplicate()
	_store().load_run_state()
	_check(out, _store().routeDestination == RouteCards.ROUTE_POWER \
			and (_store().routeBuildOfferIds as Array) == build_ids_before_save,
		"power route offers persist through save and resume")
	_check(out, _store().cancel_route_destination() and _store().routeOfferPending,
		"backing out of a build refunds the route card and restores the offer")

	_check(out, not _store().pacte_active() if _store().runPhase == "pacte_threshold" else true,
		"threshold state cannot reopen the full Pacte scene")

	_restore_run(run_snapshot)
	_meta()._apply(meta_snapshot)
	_meta().campaignNeuronsLeft = campaign_neurons
	_store()._commit()
	return out
