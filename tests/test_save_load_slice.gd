extends GutTest
## Phase E closeout: save/load from ANY point restores the full picture — story flags, quest stage,
## the active zone, AND the player's exact position (the milestone's "reload mid-quest" criterion).
## Drives the real save path (SaveManager) + the real load path (SaveManager + SceneDirector.load_into)
## through a live main.tscn, using the graybox zones so the test is fast and free of content side effects.

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const SLOT: int = 99

var main: Node3D

func before_each() -> void:
	SceneDirector.fade_duration = 0.0
	GameState.reset()
	SaveManager.delete_save(SLOT)
	main = MAIN.instantiate()
	main.start_zone = "graybox_a"
	add_child(main)
	await get_tree().process_frame

func after_each() -> void:
	SceneDirector.zone_root = null
	SceneDirector.player = null
	SceneDirector.fade_rect = null
	SceneDirector._current_zone = null
	if is_instance_valid(main):
		main.free()
	GameState.reset()
	SaveManager.delete_save(SLOT)

func test_save_load_restores_flags_quest_zone_and_position() -> void:
	# 1. Reach a representative mid-slice state: some flags, a quest stage, a different zone, a moved player.
	GameState.set_flag("act1/talked_to_friend")
	GameState.set_quest_stage("act1/village_quest", 1)
	GameState.set_world_var("current_act", "act1")
	await SceneDirector.change_zone("graybox_b")
	SceneDirector.player.global_position = Vector3(2, 1.25, -3)

	# 2. Save from that point.
	var ok: bool = SaveManager.save_game(SLOT, SceneDirector.get_current_zone_name(), SceneDirector.player.global_transform)
	assert_true(ok, "save succeeds")

	# 3. Wipe everything and go elsewhere, to prove the reload is real.
	GameState.reset()
	await SceneDirector.change_zone("graybox_a")
	assert_false(GameState.has_flag("act1/talked_to_friend"), "state cleared before load")

	# 4. Load: SaveManager restores GameState; SceneDirector.load_into restores zone + exact position.
	var data: Dictionary = SaveManager.load_game(SLOT)
	SceneDirector.load_into(data.get("zone"), SaveManager.array_to_transform(data.get("player_transform")))

	# 5. Everything is back.
	assert_true(GameState.get_flag("act1/talked_to_friend"), "flag restored")
	assert_eq(GameState.get_quest_stage("act1/village_quest"), 1, "quest stage restored (reload mid-quest)")
	assert_eq(GameState.get_world_var("current_act"), "act1", "world var restored")
	assert_eq(SceneDirector.get_current_zone_name(), "graybox_b", "zone restored")
	assert_almost_eq(SceneDirector.player.global_position, Vector3(2, 1.25, -3), Vector3(0.1, 0.4, 0.1),
		"player position restored")

func test_cutscene_seen_flag_survives_save_load() -> void:
	# A one-shot cinematic must stay watched across a save/load (no replay on reload).
	GameState.set_flag("act1/shore_cutscene_seen")
	SaveManager.save_game(SLOT, "graybox_a", Transform3D.IDENTITY)
	GameState.reset()
	assert_false(GameState.get_flag("act1/shore_cutscene_seen"))
	SaveManager.load_game(SLOT)
	assert_true(GameState.get_flag("act1/shore_cutscene_seen"), "fire-once cutscene stays seen after reload")
