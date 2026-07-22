extends GutTest
## SceneDirector integration: loads main.tscn, then verifies zone swap, spawn-point
## placement, fade clearing, and the zone_entered signal. Fades are set to zero
## duration so the transition coroutine resolves deterministically under headless.

const MAIN: PackedScene = preload("res://scenes/main.tscn")

var main: Node3D

func before_each() -> void:
	SceneDirector.fade_duration = 0.0
	main = MAIN.instantiate()
	# Pin the test's opening zone before _ready runs, so this suite is independent of whatever
	# zone the shipping game currently starts in (main.gd.start_zone).
	main.start_zone = "graybox_a"
	add_child(main)
	await get_tree().process_frame  # let _ready register + load the opening zone

func after_each() -> void:
	# Drop references into the (about-to-be-freed) test scene so autoloads don't dangle,
	# then free the whole tree immediately to keep the orphan count clean.
	SceneDirector.zone_root = null
	SceneDirector.player = null
	SceneDirector.fade_rect = null
	SceneDirector._current_zone = null
	if is_instance_valid(main):
		main.free()

func test_initial_zone_loaded() -> void:
	assert_eq(SceneDirector.get_current_zone_name(), "graybox_a")
	assert_eq(main.get_node("ZoneRoot").get_child_count(), 1, "exactly one zone mounted")

func test_player_placed_at_initial_spawn() -> void:
	# Horizontal placement is deterministic; Y gets a wider tolerance because the
	# CharacterBody3D may settle a hair onto the floor once physics ticks.
	var player: Node3D = main.get_node("Player")
	assert_almost_eq(player.global_position, Vector3(0, 1.25, 3), Vector3(0.05, 0.3, 0.05))

func test_change_zone_swaps_and_moves_player() -> void:
	await SceneDirector.change_zone("graybox_b")
	assert_eq(SceneDirector.get_current_zone_name(), "graybox_b")
	assert_eq(main.get_node("ZoneRoot").get_child_count(), 1, "old zone freed; one zone mounted")
	var player: Node3D = main.get_node("Player")
	assert_almost_eq(player.global_position, Vector3(0, 1.25, -3), Vector3(0.05, 0.3, 0.05))

func test_fade_returns_to_clear_after_transition() -> void:
	await SceneDirector.change_zone("graybox_b")
	var rect: ColorRect = main.get_node("FadeLayer/FadeRect")
	assert_almost_eq(rect.color.a, 0.0, 0.01, "screen is clear once the transition ends")

func test_zone_entered_signal_emitted() -> void:
	watch_signals(EventBus)
	await SceneDirector.change_zone("graybox_b")
	assert_signal_emitted_with_parameters(EventBus, "zone_entered", ["graybox_b"])

func test_load_into_places_player_at_explicit_transform() -> void:
	# The save/load path: swap zone AND drop the player at a stored transform, not a spawn.
	var saved: Transform3D = Transform3D(Basis.IDENTITY, Vector3(2, 1.25, -5))
	SceneDirector.load_into("graybox_b", saved)
	assert_eq(SceneDirector.get_current_zone_name(), "graybox_b")
	var player: Node3D = main.get_node("Player")
	assert_almost_eq(player.global_position, Vector3(2, 1.25, -5), Vector3(0.05, 0.3, 0.05))
