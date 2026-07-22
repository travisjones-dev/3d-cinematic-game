class_name QuestResource
extends Resource
## A quest definition: an id, a title, and an ordered list of stages. Pure data — QuestManager
## advances it by reading GameState flags, and the live stage index lives in GameState (so it's
## save-safe). Authored as .tres files under data/quests/.

## Namespaced quest id, e.g. "act1/rescue". Also the key used in GameState.quests.
@export var id: String = ""

## Player-facing quest name (flag for a human writing pass — narrative content).
@export var title: String = ""

@export var stages: Array[QuestStage] = []

func stage_count() -> int:
	return stages.size()

func get_stage(index: int) -> QuestStage:
	if index >= 0 and index < stages.size():
		return stages[index]
	return null
