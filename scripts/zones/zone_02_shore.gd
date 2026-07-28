extends Node3D
## Zone 02 (the shore). The player walks (with control) up a wooded path to the water's edge; a
## trigger there fires the cinematic once. The cutscene is a paced, multi-beat sequence driven by
## the AnimationPlayer, which calls _narrate(beat) at each beat: establish -> ships emerge ->
## friend breaks -> run. Lines are timed HUD narration (auto-clearing, no click).

@onready var _cutscene: Cutscene = $Cutscene
@onready var _trigger: Area3D = $ShoreTrigger

func _ready() -> void:
	_cutscene.finished.connect(_on_cutscene_finished)
	# If the moment has already played (save/replay), don't re-arm the trigger.
	if not _cutscene.already_seen():
		_trigger.body_entered.connect(_on_shore_reached)

func _on_shore_reached(body: Node3D) -> void:
	if not body.is_in_group("player") or _cutscene.already_seen():
		return
	_trigger.body_entered.disconnect(_on_shore_reached)  # fire once
	_cutscene.play()

## Called by the cutscene AnimationPlayer's method track at each beat.
func _narrate(beat: int) -> void:
	var line: String = ""
	match beat:
		0:
			line = "The trees fall away and the shore opens before you. Mist lies heavy on the water. No gulls. No wind. Only the tide, gone out further than it should be."
		1:
			line = "Shapes harden in the fog. Not one, not five. More hulls than you can count, sliding low and silent toward the sand. You have heard the stories. Now you are counting them."
		2:
			line = "Your friend's sword slips from his fingers and rings on the stones. He sinks into the surf, and he does not look afraid. He looks like a man who already knew how this ends."
		3:
			line = "There is nothing you can do for him now. You turn from the shore and run, and behind you the water keeps bringing them in."
	EventBus.narration_requested.emit(line)

func _on_cutscene_finished() -> void:
	GameState.set_flag("act1/slice_complete")
	# Land the ending: slow fade to black after "you turn and run".
	SceneDirector.fade_to_black(2.5)
