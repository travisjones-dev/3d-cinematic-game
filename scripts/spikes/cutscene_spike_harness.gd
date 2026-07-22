extends Control
## THROWAWAY Phase C Spike 2 harness: on-screen status + replay/reset for the cutscene spike.
## Deleted when real cutscenes arrive in Phase D. Skipping is handled by cutscene.gd (Esc).

@export var cutscene: Cutscene

@onready var _status: Label = $Status

func _ready() -> void:
	EventBus.cutscene_started.connect(func(_id: String) -> void: _refresh())
	EventBus.cutscene_finished.connect(func(_id: String) -> void: _refresh())
	EventBus.flag_changed.connect(func(_f: String, _v: Variant) -> void: _refresh())
	_refresh()

func _refresh() -> void:
	_status.text = "act1/spike_cutscene_seen = %s\n\n[Esc] skip (while playing)    [Enter] replay    [R] reset flag" % \
		str(GameState.get_flag("act1/spike_cutscene_seen"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			GameState.clear_flag("act1/spike_cutscene_seen")
			if cutscene != null:
				cutscene.play()
		elif event.keycode == KEY_R:
			GameState.clear_flag("act1/spike_cutscene_seen")
			_refresh()
