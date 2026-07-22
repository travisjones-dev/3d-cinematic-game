extends Node
## QuestManager — advances registered quests as GameState flags change. Quest logic reads flags
## only, never world state (CLAUDE.md). The live stage index is stored in GameState via
## get/set_quest_stage, so quests are save-safe by construction, and advancing a stage emits
## EventBus.quest_updated (through GameState.set_quest_stage) for the HUD toast to react to.
##
## Stage index convention: -1 = not started, 0..count-1 = active stage, >= count = complete.

var _quests: Dictionary = {}  ## quest_id (String) -> QuestResource

func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag_changed)

## Make a quest known to the manager (does not start it).
func register(quest: QuestResource) -> void:
	if quest == null or quest.id == "":
		push_warning("QuestManager: cannot register a null/idless quest.")
		return
	_quests[quest.id] = quest

## Begin a registered quest at stage 0 (no-op if already started).
func start(quest_id: String) -> void:
	if not _quests.has(quest_id):
		push_warning("QuestManager: start() on unregistered quest '%s'." % quest_id)
		return
	if GameState.get_quest_stage(quest_id) < 0:
		GameState.set_quest_stage(quest_id, 0)  # emits quest_updated
		_enter_stage(quest_id, 0)
		_try_advance(quest_id)  # in case stage 0 is already satisfied

func is_active(quest_id: String) -> bool:
	var s: int = GameState.get_quest_stage(quest_id)
	return _quests.has(quest_id) and s >= 0 and s < _quests[quest_id].stage_count()

func is_complete(quest_id: String) -> bool:
	return _quests.has(quest_id) and GameState.get_quest_stage(quest_id) >= _quests[quest_id].stage_count()

func get_current_summary(quest_id: String) -> String:
	if not _quests.has(quest_id):
		return ""
	var stage: QuestStage = _quests[quest_id].get_stage(GameState.get_quest_stage(quest_id))
	return stage.summary if stage != null else ""

func get_title(quest_id: String) -> String:
	return _quests[quest_id].title if _quests.has(quest_id) else ""

func _on_flag_changed(_flag: String, _value: Variant) -> void:
	# A flag changed; re-check every active quest. (Fine for the handful of quests a slice has.)
	for quest_id: String in _quests:
		_try_advance(quest_id)

## Advances a quest through every stage whose complete_flag is currently set, in one pass.
func _try_advance(quest_id: String) -> void:
	var quest: QuestResource = _quests[quest_id]
	while true:
		var stage_idx: int = GameState.get_quest_stage(quest_id)
		if stage_idx < 0 or stage_idx >= quest.stage_count():
			return  # not started, or already complete
		var stage: QuestStage = quest.get_stage(stage_idx)
		if stage != null and stage.complete_flag != "" and GameState.get_flag(stage.complete_flag):
			var next_idx: int = stage_idx + 1
			GameState.set_quest_stage(quest_id, next_idx)  # emits quest_updated
			if next_idx < quest.stage_count():
				_enter_stage(quest_id, next_idx)
			# loop to check the newly-active stage too
		else:
			return

func _enter_stage(quest_id: String, index: int) -> void:
	var stage: QuestStage = _quests[quest_id].get_stage(index)
	if stage == null:
		return
	for flag: String in stage.set_flags_on_enter:
		GameState.set_flag(flag)
