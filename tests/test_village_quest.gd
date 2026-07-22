extends GutTest
## Zone 01 village micro-quest flow (Pass D2): the quest advances through the friend → farewell →
## friend beats as their flags are set, and both conversation timelines are well-formed. Dialogue
## *display* is human-tested; this is the wiring.

const QUEST: QuestResource = preload("res://data/quests/village_quest.tres")
const QID: String = "act1/village_quest"

func before_each() -> void:
	GameState.reset()
	QuestManager.register(QUEST)
	QuestManager.start(QID)

func test_starts_at_stage_zero() -> void:
	assert_eq(GameState.get_quest_stage(QID), 0)

func test_talking_to_friend_advances_to_farewell() -> void:
	GameState.set_flag("act1/talked_to_friend")
	assert_eq(GameState.get_quest_stage(QID), 1)

func test_full_flow_completes() -> void:
	GameState.set_flag("act1/talked_to_friend")
	GameState.set_flag("act1/said_farewell")
	GameState.set_flag("act1/ready_to_leave")
	assert_true(QuestManager.is_complete(QID))

func test_out_of_order_flag_does_not_skip_then_catches_up() -> void:
	# Setting a later stage's flag first must NOT advance past the current stage...
	GameState.set_flag("act1/said_farewell")
	assert_eq(GameState.get_quest_stage(QID), 0, "stage 0 needs its own flag first")
	# ...but once stage 0's flag lands, the catch-up loop consumes the already-set stage-1 flag too.
	GameState.set_flag("act1/talked_to_friend")
	assert_eq(GameState.get_quest_stage(QID), 2, "advances through both satisfied stages in one pass")

func test_conversation_timelines_parse() -> void:
	for path: String in ["res://dialogue/act1/friend.dtl", "res://dialogue/act1/love.dtl"]:
		var tl: Resource = load(path)
		assert_not_null(tl, "%s loads" % path)
		tl.process()
		assert_gt(tl.events.size(), 0, "%s parsed into events" % path)
