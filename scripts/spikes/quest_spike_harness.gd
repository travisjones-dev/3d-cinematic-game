extends Control
## THROWAWAY Phase C Spike 3 harness: registers the sample quest, shows its live stage, and lets
## you set the stage-completion flags by hand to watch QuestManager advance it (and the HUD toast
## fire). Deleted when real quests arrive in Phase D.

const QUEST: QuestResource = preload("res://data/quests/spike_quest.tres")
const QUEST_ID: String = "act1/spike_quest"

@onready var _status: Label = $Status

func _ready() -> void:
	QuestManager.register(QUEST)
	EventBus.quest_updated.connect(func(_id: String, _s: int) -> void: _refresh())
	EventBus.flag_changed.connect(func(_f: String, _v: Variant) -> void: _refresh())
	QuestManager.start(QUEST_ID)
	_refresh()

func _refresh() -> void:
	var state: String
	if QuestManager.is_complete(QUEST_ID):
		state = "COMPLETE"
	else:
		state = "stage %d — %s" % [GameState.get_quest_stage(QUEST_ID), QuestManager.get_current_summary(QUEST_ID)]
	_status.text = "Quest: %s\n%s\n\n[1] set 'reached shore'   [2] set 'survived'   [R] reset quest" % \
		[QuestManager.get_title(QUEST_ID), state]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			GameState.set_flag("act1/spike_reached_shore")
		KEY_2:
			GameState.set_flag("act1/spike_survived")
		KEY_R:
			GameState.clear_flag("act1/spike_reached_shore")
			GameState.clear_flag("act1/spike_survived")
			GameState.set_quest_stage(QUEST_ID, 0)
			_refresh()
