extends GutTest
## Cutscene controller (Phase C Spike 2): fire-once completion flag, EventBus announcements, and
## already-seen gating. The AnimationPlayer-driven shot + Dialogic line are human-tested; this is
## the save-safety / lifecycle logic. A Cutscene with no AnimationPlayer completes immediately.

func before_each() -> void:
	GameState.reset()

func _make(flag: String) -> Cutscene:
	var c: Cutscene = Cutscene.new()
	c.completion_flag = flag
	c.autoplay_on_ready = false  # drive play() explicitly in tests
	add_child_autofree(c)
	return c

func test_finish_sets_flag_and_announces() -> void:
	var c: Cutscene = _make("act1/spike_cutscene_seen")
	watch_signals(EventBus)
	c.play()  # no AnimationPlayer -> finishes immediately
	assert_true(GameState.get_flag("act1/spike_cutscene_seen"), "completion flag set (fire-once/save-safe)")
	assert_signal_emitted(EventBus, "cutscene_started")
	assert_signal_emitted(EventBus, "cutscene_finished")

func test_finished_signal_emitted() -> void:
	var c: Cutscene = _make("")
	watch_signals(c)
	c.play()
	assert_signal_emitted(c, "finished")

func test_already_seen_blocks_play() -> void:
	GameState.set_flag("act1/done", true)
	var c: Cutscene = _make("act1/done")
	assert_true(c.already_seen(), "flag present -> already seen")
	watch_signals(EventBus)
	c.play()  # should be a no-op
	assert_signal_not_emitted(EventBus, "cutscene_started", "seen cutscene does not replay")

func test_no_flag_never_marks_seen() -> void:
	var c: Cutscene = _make("")
	c.play()
	assert_false(c.already_seen(), "empty completion_flag never counts as seen (always replayable)")
