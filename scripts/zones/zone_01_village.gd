extends Node3D
## Zone 01 (home village) controller. Registers and starts the village micro-quest when the zone
## loads. Re-entering the zone (e.g. from the shore) is safe: QuestManager.start() is a no-op once
## the quest has begun, so progress is preserved (the stage index lives in GameState).

const VILLAGE_QUEST: QuestResource = preload("res://data/quests/village_quest.tres")

func _ready() -> void:
	QuestManager.register(VILLAGE_QUEST)
	QuestManager.start("act1/village_quest")
