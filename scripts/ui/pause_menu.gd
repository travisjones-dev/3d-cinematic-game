extends Control
## Pause menu — toggled by the "pause" action. Pauses the tree, frees the mouse, and wires
## Save/Load/Quit to SaveManager + SceneDirector. Its process_mode is ALWAYS (set in the
## scene) so it keeps running while the rest of the tree is paused.
##
## Uses a single quick-save slot (0) for the slice; slot selection is a later-milestone UI.

const SLOT: int = 0

func _ready() -> void:
	visible = false
	$Center/VBox/ResumeButton.pressed.connect(_resume)
	$Center/VBox/SaveButton.pressed.connect(_on_save)
	$Center/VBox/LoadButton.pressed.connect(_on_load)
	$Center/VBox/QuitButton.pressed.connect(_on_quit)
	# Load is only meaningful if a save exists; reflect that when the menu opens.
	$Center/VBox/LoadButton.disabled = not SaveManager.has_save(SLOT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_resume()
		else:
			_open()

func _open() -> void:
	$Center/VBox/LoadButton.disabled = not SaveManager.has_save(SLOT)
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_save() -> void:
	var zone: String = SceneDirector.get_current_zone_name()
	var xform: Transform3D = Transform3D.IDENTITY
	if SceneDirector.player != null:
		xform = SceneDirector.player.global_transform
	SaveManager.save_game(SLOT, zone, xform)
	$Center/VBox/LoadButton.disabled = false

func _on_load() -> void:
	if not SaveManager.has_save(SLOT):
		return
	var data: Dictionary = SaveManager.load_game(SLOT)  # restores GameState
	var zone: String = data.get("zone", "")
	var xform: Transform3D = SaveManager.array_to_transform(data.get("player_transform", []))
	if zone != "":
		SceneDirector.load_into(zone, xform)
	_resume()

func _on_quit() -> void:
	get_tree().quit()
