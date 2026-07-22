extends "res://scripts/components/interactable.gd"
## An examinable prop that shows a line of flavor/environmental-storytelling text when interacted
## with. Composes the Interactable primitive (see godot-interaction-system); on interact it asks
## the HUD to show `flavor_text` via EventBus. Optionally sets a GameState flag when first examined
## (e.g. to mark the secret discovered).
##
## NARRATIVE: `flavor_text` is story content — drafted here as placeholder, flag for a writing pass.

@export_multiline var flavor_text: String = ""
## Optional flag set the first time this is examined (e.g. "act1/found_carved_heart").
@export var discovers_flag: String = ""

func _ready() -> void:
	super()
	interacted.connect(_on_interacted)

func _on_interacted() -> void:
	if flavor_text != "":
		EventBus.narration_requested.emit(flavor_text)
	if discovers_flag != "" and not GameState.get_flag(discovers_flag):
		GameState.set_flag(discovers_flag)
