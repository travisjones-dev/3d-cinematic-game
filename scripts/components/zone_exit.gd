extends "res://scripts/components/interactable.gd"
## A zone-transition trigger built from the Interactable primitive. Interacting with it asks
## SceneDirector to change zones. Place one at a doorway/edge, set the target zone + spawn.
##
## (Extends Interactable by path rather than class_name so it never depends on class-name
## registration order during a fresh import.)

@export var target_zone: String = ""
@export var target_spawn: String = "spawn_default"
## If set, the exit only works once this GameState flag is true; otherwise it shows blocked_text.
@export var required_flag: String = ""
@export_multiline var blocked_text: String = ""

func _ready() -> void:
	super()
	interacted.connect(_on_interacted)

func _on_interacted() -> void:
	if required_flag != "" and not GameState.get_flag(required_flag):
		if blocked_text != "":
			EventBus.narration_requested.emit(blocked_text)
		return
	if target_zone == "":
		push_warning("zone_exit: no target_zone set on %s" % name)
		return
	SceneDirector.change_zone(target_zone, target_spawn)
