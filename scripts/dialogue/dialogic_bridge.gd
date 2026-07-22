extends Node
## DialogueBridge — the write half of the Dialogic <-> GameState bridge. Autoloaded so it is
## always listening. Dialogue READS story flags directly in conditions (Dialogic evaluates
## expressions with all autoloads bound, so a timeline can write
## `if GameState.get_flag("act1/x"):` with no glue). Dialogue WRITES flags by emitting
## Dialogic's signal event, which this bridge translates into GameState calls — keeping
## GameState the single source of truth (CLAUDE.md).
##
## Timeline usage (Dialogic "Signal" event, string argument):
##   [signal arg="set_flag act1/some_flag"]        -> GameState.set_flag("act1/some_flag", true)
##   [signal arg="set_flag act1/some_flag false"]  -> GameState.set_flag("act1/some_flag", false)
##   [signal arg="clear_flag act1/some_flag"]      -> GameState.clear_flag("act1/some_flag")
##   [signal arg="quest act1/rescue 2"]            -> GameState.set_quest_stage("act1/rescue", 2)
##
## Or the dictionary form (Signal event, Dictionary argument):
##   {"set_flag": "act1/some_flag", "value": true}
##   {"clear_flag": "act1/some_flag"}

func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)
	# Re-broadcast Dialogic's lifecycle on our EventBus so gameplay (player movement, camera
	# mouse mode) can react through the project's own signal hub instead of touching Dialogic.
	Dialogic.timeline_started.connect(func() -> void: EventBus.dialogue_started.emit(""))
	Dialogic.timeline_ended.connect(func() -> void: EventBus.dialogue_ended.emit(""))

func _on_dialogic_signal(argument: Variant) -> void:
	if argument is Dictionary:
		_handle_dict(argument)
	elif argument is String:
		_handle_command(argument)
	else:
		push_warning("DialogueBridge: unhandled signal argument %s" % [argument])

func _handle_command(command: String) -> void:
	var parts: PackedStringArray = command.split(" ", false)
	if parts.is_empty():
		return
	match parts[0]:
		"set_flag":
			if parts.size() >= 2:
				var value: bool = true
				if parts.size() >= 3:
					value = parts[2].to_lower() == "true"
				GameState.set_flag(parts[1], value)
		"clear_flag":
			if parts.size() >= 2:
				GameState.clear_flag(parts[1])
		"quest":
			if parts.size() >= 3:
				GameState.set_quest_stage(parts[1], int(parts[2]))
		_:
			push_warning("DialogueBridge: unknown signal command '%s'" % command)

func _handle_dict(data: Dictionary) -> void:
	if data.has("set_flag"):
		GameState.set_flag(str(data["set_flag"]), data.get("value", true))
	elif data.has("clear_flag"):
		GameState.clear_flag(str(data["clear_flag"]))
	elif data.has("quest"):
		GameState.set_quest_stage(str(data["quest"]), int(data.get("stage", 0)))
	else:
		push_warning("DialogueBridge: dictionary signal had no recognized key: %s" % [data])
