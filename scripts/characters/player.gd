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

@export_group("Animation")
## Crossfade time when switching locomotion clips. Long enough to hide the cut, short
## enough that a stop still reads as deliberate.
@export var anim_blend: float = 0.15
## Horizontal speed below which the character counts as standing still.
@export var idle_threshold: float = 0.2
## Clamp on animation playback rate, so easing in/out of a speed does not produce a
## comically fast or sludgy stride while the velocity ramp is still running.
@export var anim_rate_min: float = 0.6
@export var anim_rate_max: float = 1.6

## The visual pivot that rotates to face movement. Kept separate from the body so the
## collision capsule never spins — only the look direction does.
@onready var model: Node3D = $Model

## Locomotion clips live on the imported character's own AnimationPlayer. Driven directly
## with crossfades rather than through an AnimationTree: same result on screen for
## idle/walk/run, without hand-authoring a blend-tree resource. A BlendSpace1D is the
## natural upgrade if locomotion ever needs more than three states.
@onready var _anim: AnimationPlayer = get_node_or_null("Model/Warrior/AnimationPlayer")

## Which locomotion clip is playing, so play() is only called on an actual state change —
## calling it every frame would restart the clip and freeze the character mid-stride.
var _current_clip: String = ""

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
	_update_locomotion()

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

## Picks idle/walk/run from actual horizontal speed — not from input — so the character keeps
## striding through the deceleration ramp instead of snapping to idle the instant a key is
## released, and so a cutscene or dialogue that zeroes the velocity settles into Idle for free.
##
## Playback rate tracks speed against the clip's nominal speed. That is the cheap 80% of a
## foot-slide fix: the stride still will not match perfectly at every velocity (that needs a
## BlendSpace1D and stride measurement), but it removes the obvious mismatch while accelerating.
func _update_locomotion() -> void:
	if _anim == null:
		return

	var speed: float = Vector2(velocity.x, velocity.z).length()
	var clip: String = "Idle"
	var rate: float = 1.0

	if speed >= idle_threshold:
		# Split at the midpoint between the two gaits rather than at run_speed, so the run clip
		# takes over while still accelerating instead of only at full sprint.
		if speed <= (walk_speed + run_speed) * 0.5:
			clip = "Walk"
			rate = clampf(speed / walk_speed, anim_rate_min, anim_rate_max)
		else:
			clip = "Run"
			rate = clampf(speed / run_speed, anim_rate_min, anim_rate_max)

	if clip != _current_clip:
		_anim.play(clip, anim_blend)
		_current_clip = clip
	_anim.speed_scale = rate

## Rotates the model so its forward (-Z) points along horizontal velocity. Skipped at
## very low speed so the model doesn't jitter when nearly stopped.
func _face_travel_direction(delta: float) -> void:
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z)
	if horizontal.length() < 0.2:
		return
	var target_angle: float = atan2(-velocity.x, -velocity.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, turn_speed * delta)
