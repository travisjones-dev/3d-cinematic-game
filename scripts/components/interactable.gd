class_name Interactable
extends Area3D
## The one reusable interaction primitive. Put it on props, NPCs, exits, secrets — anything
## the player can act on. When the player enters range it announces itself on EventBus so the
## HUD can show a prompt; leaving withdraws it. Calling interact() fires `interacted`, which
## the composing script/scene connects to for the actual behavior.
##
## Detection uses Area3D body overlap: the player is a CharacterBody3D in the "player" group
## on the default collision layer, which this Area's default mask picks up.

signal interacted

@export var prompt: String = "Interact"
@export var enabled: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func interact() -> void:
	if enabled:
		interacted.emit()

func get_prompt() -> String:
	return prompt

func _on_body_entered(body: Node3D) -> void:
	if enabled and body.is_in_group("player"):
		EventBus.interaction_available.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		EventBus.interaction_lost.emit(self)
