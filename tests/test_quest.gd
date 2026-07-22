extends GutTest
## Quest system (Phase C Spike 3): QuestResource loads, QuestManager advances stages by reading
## GameState flags, completion is detected, and quest_updated fires — all headless. The HUD toast
## is human-tested.

const QUEST: QuestResource = preload("res://data/quests/spike_quest.tres")
const QID: String = "act1/spike_quest"

func before_each() -> void:
	GameState.reset()
	QuestManager.register(QUEST)

func test_quest_resource_loads_from_tres() -> void:
	assert_eq(QUEST.id, QID, "quest id loaded")
	assert_eq(QUEST.stage_count(), 2, "two stages loaded from .tres typed array")
	assert_eq(QUEST.get_stage(0).complete_flag, "act1/spike_reached_shore")

func test_start_sets_stage_zero() -> void:
	QuestManager.start(QID)
	assert_eq(GameState.get_quest_stage(QID), 0)
	assert_true(QuestManager.is_active(QID))

func test_flag_advances_stage() -> void:
	QuestManager.start(QID)
	GameState.set_flag("act1/spike_reached_shore")
	assert_eq(GameState.get_quest_stage(QID), 1, "setting stage 0's flag advances to stage 1")

func test_completing_all_stages() -> void:
	QuestManager.start(QID)
	GameState.set_flag("act1/spike_reached_shore")
	GameState.set_flag("act1/spike_survived")
	assert_true(QuestManager.is_complete(QID), "both stage flags set -> quest complete")
	assert_false(QuestManager.is_active(QID))

func test_quest_updated_emitted_on_advance() -> void:
	QuestManager.start(QID)
	watch_signals(EventBus)
	GameState.set_flag("act1/spike_reached_shore")
	assert_signal_emitted(EventBus, "quest_updated")

func test_unrelated_flag_does_not_advance() -> void:
	QuestManager.start(QID)
	GameState.set_flag("act1/some_other_flag")
	assert_eq(GameState.get_quest_stage(QID), 0, "a flag that isn't the stage's complete_flag does nothing")
