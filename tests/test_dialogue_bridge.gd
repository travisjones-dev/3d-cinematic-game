extends GutTest
## Dialogic <-> GameState bridge (Phase C Spike 1). Verifies the write path (Dialogic signal
## events -> GameState) and the read path (Dialogic conditions evaluate against GameState), plus
## that the spike timeline parses. Dialogue *display* is human-tested; this is pure bridge logic.

func before_each() -> void:
	GameState.reset()

# --- Write path: Dialogic signal event -> GameState (via DialogueBridge autoload) ---

func test_signal_sets_flag() -> void:
	Dialogic.emit_signal("signal_event", "set_flag act1/spike_test")
	assert_true(GameState.get_flag("act1/spike_test"), "set_flag command sets the flag true")

func test_signal_sets_flag_false() -> void:
	GameState.set_flag("act1/x", true)
	Dialogic.emit_signal("signal_event", "set_flag act1/x false")
	assert_false(GameState.get_flag("act1/x"), "explicit false value honored")

func test_signal_clears_flag() -> void:
	GameState.set_flag("act1/y", true)
	Dialogic.emit_signal("signal_event", "clear_flag act1/y")
	assert_false(GameState.has_flag("act1/y"), "clear_flag removes the flag")

func test_signal_sets_quest_stage() -> void:
	Dialogic.emit_signal("signal_event", "quest act1/rescue 2")
	assert_eq(GameState.get_quest_stage("act1/rescue"), 2)

func test_dictionary_signal_sets_flag() -> void:
	Dialogic.emit_signal("signal_event", {"set_flag": "act1/d", "value": true})
	assert_true(GameState.get_flag("act1/d"), "dictionary form sets the flag")

# --- Read path: Dialogic condition expression reads GameState directly ---

func test_condition_reads_true_flag() -> void:
	GameState.set_flag("act1/z", true)
	assert_true(Dialogic.Expressions.execute_condition('GameState.get_flag("act1/z")'),
		"condition sees a set flag")

func test_condition_reads_false_flag() -> void:
	GameState.clear_flag("act1/z")
	assert_false(Dialogic.Expressions.execute_condition('GameState.get_flag("act1/z")'),
		"condition sees an unset flag as false")

# --- The spike timeline is well-formed ---

func test_spike_timeline_parses() -> void:
	var timeline: Resource = load("res://dialogue/spikes/bridge_test.dtl")
	assert_not_null(timeline, "bridge_test.dtl loads as a DialogicTimeline")
	timeline.process()
	assert_gt(timeline.events.size(), 0, "timeline parsed into events")
