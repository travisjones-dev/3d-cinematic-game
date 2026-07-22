extends Control
## Phase C Spike 1 (THROWAWAY test harness, not shipped content). Drives the bridge_test
## timeline to demonstrate the Dialogic <-> GameState bridge on screen:
##   - choices are GATED by reading a GameState flag (the read path), and
##   - choosing "Take the sword" WRITES the flag via the signal bridge (the write path).
## The status label refreshes live on any flag change, so the write is visible the instant
## the choice is made. Deleted when real dialogue arrives in Phase D.

const TIMELINE: String = "res://dialogue/spikes/bridge_test.dtl"

@onready var _status: Label = $Status

var _running: bool = false

func _ready() -> void:
	Dialogic.timeline_started.connect(_on_timeline_started)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# Live flag readout — updates the moment the bridge writes the flag.
	EventBus.flag_changed.connect(_on_flag_changed)
	_refresh()
	Dialogic.start(TIMELINE)

func _on_timeline_started() -> void:
	_running = true
	_refresh()

func _on_timeline_ended() -> void:
	_running = false
	_refresh()

func _on_flag_changed(_flag: String, _value: Variant) -> void:
	_refresh()

func _refresh() -> void:
	var hint: String = "dialogue running — click the ▼ to continue / finish" if _running \
		else "[Enter] replay timeline    [R] reset flag"
	_status.text = "act1/spike_sword_taken = %s\n\n%s" % \
		[str(GameState.get_flag("act1/spike_sword_taken")), hint]

func _unhandled_input(event: InputEvent) -> void:
	if _running:
		return  # a timeline is showing; let Dialogic consume input
	if event.is_action_pressed("ui_accept"):
		Dialogic.start(TIMELINE)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameState.clear_flag("act1/spike_sword_taken")
		_refresh()
