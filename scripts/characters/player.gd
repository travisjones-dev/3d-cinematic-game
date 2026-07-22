extends CharacterBody3D
## Player — third-person walk/run controller. Movement is camera-relative (WASD are
## interpreted against the active camera's yaw), and the visual model turns to face
## the direction of travel. No combat, no jump — walk/run/gravity only (slice scope).
##
## Feel target: "grounded & weighty" — noticeable acceleration ramp and deliberate
## turning, to suit the cinematic, story-first tone. Tune the constants below.

@export_group("Speed")
@export var walk_speed: float = 2.8
@export var run_speed: float = 5.5

@export_group("Feel")
## How fast horizontal velocity ramps toward the target speed (higher = snappier).
@export var acceleration: float = 14.0
## How fast horizontal velocity bleeds off when there's no input (higher = stops sooner).
@export var deceleration: float = 18.0
## How fast the model swings to face the travel direction (radians/sec-ish via lerp).
@export var turn_speed: float = 9.0

## The visual pivot that rotates to face movement. Kept separate from the body so the
## collision capsule never spins — only the look direction does.
@onready var model: Node3D = $Model

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

## The interactable currently in range, if any. Tracked via EventBus so the player never
## needs a direct reference to props/NPCs.
var _current_interactable: Interactable = null

## True while a dialogue/cutscene has control — movement and interaction are suspended.
var _input_suspended: bool = false

func _ready() -> void:
	# Interactables detect the player by this group; keep it in sync with interactable.gd.
	add_to_group("player")
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_lost.connect(_on_interaction_lost)
	# A zone swap frees the old zone (and its interactables) without firing body_exited,
	# so clear the reference on zone entry to avoid acting on a freed node.
	EventBus.zone_entered.connect(_on_zone_entered)
	# Hand control to conversations/cutscenes: stop moving while one is playing.
	EventBus.dialogue_started.connect(func(_t: String) -> void: _input_suspended = true)
	EventBus.dialogue_ended.connect(func(_t: String) -> void: _input_suspended = false)
	EventBus.cutscene_started.connect(func(_id: String) -> void: _input_suspended = true)
	EventBus.cutscene_finished.connect(func(_id: String) -> void: _input_suspended = false)

func _unhandled_input(event: InputEvent) -> void:
	if _input_suspended:
		return
	if event.is_action_pressed("interact") \
			and _current_interactable != null \
			and is_instance_valid(_current_interactable):
		_current_interactable.interact()

func _on_interaction_available(target: Node) -> void:
	_current_interactable = target as Interactable

func _on_interaction_lost(target: Node) -> void:
	if _current_interactable == target:
		_current_interactable = null

func _on_zone_entered(_zone_name: String) -> void:
	_current_interactable = null

func _physics_process(delta: float) -> void:
	# Gravity keeps the body on the floor and settles it after a spawn drop.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Vector2.ZERO if _input_suspended \
		else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = _camera_relative_direction(input_dir)

	var speed: float = run_speed if Input.is_action_pressed("run") else walk_speed
	var target: Vector3 = direction * speed
	var rate: float = acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	move_and_slide()
	_face_travel_direction(delta)

## Converts stick/WASD input into a world direction aligned to where the camera looks,
## so "forward" always means "away from the camera". Falls back to the body's own yaw
## if no camera is active yet (e.g. one frame during setup).
func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var cam: Camera3D = get_viewport().get_camera_3d()
	var yaw: float = cam.global_rotation.y if cam != null else global_rotation.y
	# Godot forward is -Z, so move_forward (input_dir.y < 0) maps to -Z before rotation.
	return Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, yaw).normalized()

## Rotates the model so its forward (-Z) points along horizontal velocity. Skipped at
## very low speed so the model doesn't jitter when nearly stopped.
func _face_travel_direction(delta: float) -> void:
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z)
	if horizontal.length() < 0.2:
		return
	var target_angle: float = atan2(-velocity.x, -velocity.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, turn_speed * delta)
