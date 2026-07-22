extends "res://scripts/components/interactable.gd"
## An NPC you can talk to. Composes the Interactable primitive; interacting starts a Dialogic
## timeline. Reaches Dialogic through the tree (not the global identifier) for the same reason
## cutscene.gd does — safe from the class_name/uid-autoload trap (see godot-cutscene-tech).

@export_file("*.dtl") var timeline: String = ""

func _ready() -> void:
	super()
	interacted.connect(_on_interacted)

func _on_interacted() -> void:
	if timeline == "":
		return
	var dialogic: Node = get_node_or_null(^"/root/Dialogic")
	if dialogic == null or not dialogic.has_method(&"start"):
		return
	if dialogic.get(&"current_timeline") != null:
		return  # a conversation is already running
	dialogic.call(&"start", timeline)
