extends GutTest
## Interactable: interact() gating and the EventBus announce/withdraw behavior. Detection is
## driven by direct handler calls with a stand-in player node, so the tests stay deterministic
## and don't depend on physics-frame Area3D overlap timing.

var interactable: Interactable
var dummy_player: Node3D

func before_each() -> void:
	interactable = Interactable.new()
	interactable.prompt = "Talk"
	add_child_autofree(interactable)
	dummy_player = Node3D.new()
	dummy_player.add_to_group("player")
	add_child_autofree(dummy_player)

func test_interact_emits_signal() -> void:
	watch_signals(interactable)
	interactable.interact()
	assert_signal_emitted(interactable, "interacted")

func test_disabled_interactable_does_not_emit() -> void:
	interactable.enabled = false
	watch_signals(interactable)
	interactable.interact()
	assert_signal_not_emitted(interactable, "interacted")

func test_get_prompt_returns_export() -> void:
	assert_eq(interactable.get_prompt(), "Talk")

func test_player_entering_announces_on_eventbus() -> void:
	watch_signals(EventBus)
	interactable._on_body_entered(dummy_player)
	assert_signal_emitted_with_parameters(EventBus, "interaction_available", [interactable])

func test_nonplayer_entering_is_ignored() -> void:
	var npc: Node3D = Node3D.new()
	add_child_autofree(npc)
	watch_signals(EventBus)
	interactable._on_body_entered(npc)
	assert_signal_not_emitted(EventBus, "interaction_available")

func test_player_leaving_withdraws() -> void:
	watch_signals(EventBus)
	interactable._on_body_exited(dummy_player)
	assert_signal_emitted_with_parameters(EventBus, "interaction_lost", [interactable])
