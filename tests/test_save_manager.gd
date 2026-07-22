extends GutTest
## SaveManager: GameState save/load round-trip and transform persistence.

const SLOT: int = 99  # dedicated test slot, never a real save

func before_each() -> void:
	GameState.reset()
	SaveManager.delete_save(SLOT)

func after_each() -> void:
	SaveManager.delete_save(SLOT)
	GameState.reset()

func test_save_then_load_restores_state() -> void:
	GameState.set_flag("act1/village_burned", true)
	GameState.set_quest_stage("q_vengeance", 2)
	GameState.set_world_var("current_act", "act1")

	var saved: bool = SaveManager.save_game(SLOT, "zone_01_home_village", Transform3D.IDENTITY)
	assert_true(saved, "save_game reports success")

	# Wipe live state so we know the values come from disk, not memory.
	GameState.reset()
	assert_false(GameState.has_flag("act1/village_burned"), "state cleared before load")

	var data: Dictionary = SaveManager.load_game(SLOT)
	assert_true(GameState.get_flag("act1/village_burned"), "flag restored")
	assert_eq(GameState.get_quest_stage("q_vengeance"), 2, "quest stage restored as int")
	assert_eq(GameState.get_world_var("current_act"), "act1", "world var restored")
	assert_eq(data.get("zone"), "zone_01_home_village", "envelope carries zone")
	assert_eq(int(data.get("version")), SaveManager.SAVE_VERSION, "envelope carries version")

func test_transform_round_trip() -> void:
	var t: Transform3D = Transform3D(Basis.IDENTITY, Vector3(3, 5, 7))
	SaveManager.save_game(SLOT, "zone_a", t)
	var data: Dictionary = SaveManager.load_game(SLOT)
	var restored: Transform3D = SaveManager.array_to_transform(data.get("player_transform"))
	assert_almost_eq(restored.origin, Vector3(3, 5, 7), Vector3(0.001, 0.001, 0.001),
		"player position survives the round-trip")

func test_load_missing_slot_returns_empty() -> void:
	var data: Dictionary = SaveManager.load_game(SLOT)
	assert_eq(data.size(), 0, "loading an empty slot yields an empty dict")
