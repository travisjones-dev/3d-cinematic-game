extends GutTest
## GameState: flag set/get, defaults, clearing, and namespacing.

func before_each() -> void:
	GameState.reset()

func test_set_and_get_flag() -> void:
	GameState.set_flag("act1/village_burned", true)
	assert_true(GameState.get_flag("act1/village_burned"), "flag reads back true")

func test_get_flag_default_when_absent() -> void:
	assert_false(GameState.get_flag("act1/nonexistent"), "absent flag defaults to false")
	assert_eq(GameState.get_flag("act1/nonexistent", "fallback"), "fallback",
		"custom default is returned when flag is absent")

func test_has_and_clear_flag() -> void:
	GameState.set_flag("act1/gate_open")
	assert_true(GameState.has_flag("act1/gate_open"))
	GameState.clear_flag("act1/gate_open")
	assert_false(GameState.has_flag("act1/gate_open"), "cleared flag is gone")

func test_namespacing_isolation() -> void:
	# Same leaf name under different namespaces must not collide.
	GameState.set_flag("act1/met_elder", true)
	GameState.set_flag("act2/met_elder", false)
	assert_true(GameState.get_flag("act1/met_elder"))
	assert_false(GameState.get_flag("act2/met_elder"))

func test_get_flags_in_namespace() -> void:
	GameState.set_flag("act1/a", true)
	GameState.set_flag("act1/b", true)
	GameState.set_flag("act2/c", true)
	var act1: Dictionary = GameState.get_flags_in_namespace("act1/")
	assert_eq(act1.size(), 2, "only act1 flags returned")
	assert_true(act1.has("act1/a"))
	assert_false(act1.has("act2/c"), "act2 flag excluded")

func test_quest_stage_default_is_minus_one() -> void:
	assert_eq(GameState.get_quest_stage("q_unstarted"), -1)

func test_flag_changed_signal_emitted() -> void:
	watch_signals(EventBus)
	GameState.set_flag("act1/signal_test", true)
	assert_signal_emitted_with_parameters(EventBus, "flag_changed", ["act1/signal_test", true])
