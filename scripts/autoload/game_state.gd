extends Node
## GameState — the single source of truth for story flags, quests, and world
## variables. All narrative branching reads/writes here. Every write emits an
## EventBus signal so systems can react without polling.
##
## Flags are namespaced strings, e.g. "act1/village_burned". They are just keys
## in the `flags` dict — save-safe by construction.

var flags: Dictionary = {}       ## namespaced String -> Variant
var quests: Dictionary = {}      ## quest_id (String) -> stage index (int)
var world_vars: Dictionary = {}  ## arbitrary world state, String -> Variant

# --- Flags ---

func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	EventBus.flag_changed.emit(flag, value)

func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)

func has_flag(flag: String) -> bool:
	return flags.has(flag)

func clear_flag(flag: String) -> void:
	if flags.erase(flag):
		EventBus.flag_changed.emit(flag, null)

## Returns every flag whose key starts with `prefix` (e.g. "act1/").
func get_flags_in_namespace(prefix: String) -> Dictionary:
	var result: Dictionary = {}
	for key: String in flags:
		if key.begins_with(prefix):
			result[key] = flags[key]
	return result

# --- Quests ---

func set_quest_stage(quest_id: String, stage: int) -> void:
	quests[quest_id] = stage
	EventBus.quest_updated.emit(quest_id, stage)

## Stage of a quest, or -1 if the quest has not started.
func get_quest_stage(quest_id: String) -> int:
	return quests.get(quest_id, -1)

# --- World vars ---

func set_world_var(key: String, value: Variant) -> void:
	world_vars[key] = value

func get_world_var(key: String, default: Variant = null) -> Variant:
	return world_vars.get(key, default)

# --- Serialization ---

func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true),
		"world_vars": world_vars.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	# Quest stages survive JSON as floats; coerce back to int so callers get ints.
	var raw_quests: Dictionary = data.get("quests", {})
	quests = {}
	for key: String in raw_quests:
		quests[key] = int(raw_quests[key])
	world_vars = (data.get("world_vars", {}) as Dictionary).duplicate(true)

func reset() -> void:
	flags.clear()
	quests.clear()
	world_vars.clear()
