---
name: godot-thirdperson-controller
description: >-
  Build or tune a third-person CharacterBody3D walk/run controller in this Godot
  project — camera-relative movement, acceleration/deceleration "feel", a model
  pivot that turns to face travel, and gravity. Use this WHENEVER the task involves
  the player character's movement: making the player walk/run, camera-relative WASD,
  tuning how movement feels (weighty vs snappy), the character turning to face where
  it moves, gravity/floor handling, or debugging a character that won't move or moves
  in the wrong direction relative to the camera. No combat/jump — walk/run scope.
---

# Third-person CharacterBody3D controller (camera-relative)

The slice's player: solid, unobtrusive movement that never fights the story (pillar #3 —
"solid" is the bar, not "innovative"). This is the pattern that works with the Phantom
Camera rig (`godot-phantom-camera`) and the input actions (`godot-input-map`).

## Scene shape (see `godot-scene-authoring` for the .tscn)
`CharacterBody3D` root + `CollisionShape3D` (capsule) + a **separate `Model` pivot** holding
the mesh. The Model rotates to face travel; the body/collision never spins. A small offset
"nose" mesh on the Model makes facing visible for graybox testing.

**Origin convention:** a center-origin capsule (mesh + shape centered at the body origin)
means a spawn marker at `y = floor_top + capsule_half_height` rests the feet exactly on the
floor. Pick one convention and make spawn-point Y match it, or just let gravity settle it.

## Movement — camera-relative, weighty feel

```gdscript
extends CharacterBody3D

@export var walk_speed: float = 2.8
@export var run_speed: float = 5.5
@export var acceleration: float = 14.0   # ramp toward target speed (lower = weightier)
@export var deceleration: float = 18.0   # bleed off when no input
@export var turn_speed: float = 9.0      # how fast the model swings to face travel

@onready var model: Node3D = $Model
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= _gravity * delta

    var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction: Vector3 = _camera_relative_direction(input_dir)

    var speed: float = run_speed if Input.is_action_pressed("run") else walk_speed
    var target: Vector3 = direction * speed
    var rate: float = acceleration if direction != Vector3.ZERO else deceleration
    velocity.x = move_toward(velocity.x, target.x, rate * delta)
    velocity.z = move_toward(velocity.z, target.z, rate * delta)

    move_and_slide()
    _face_travel_direction(delta)

func _camera_relative_direction(input_dir: Vector2) -> Vector3:
    if input_dir == Vector2.ZERO:
        return Vector3.ZERO
    var cam: Camera3D = get_viewport().get_camera_3d()
    var yaw: float = cam.global_rotation.y if cam != null else global_rotation.y
    return Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, yaw).normalized()

func _face_travel_direction(delta: float) -> void:
    var horizontal: Vector2 = Vector2(velocity.x, velocity.z)
    if horizontal.length() < 0.2:
        return
    var target_angle: float = atan2(-velocity.x, -velocity.z)
    model.rotation.y = lerp_angle(model.rotation.y, target_angle, turn_speed * delta)
```

## The non-obvious bits (why it's written this way)

- **Camera-relative via the active viewport camera.** `get_viewport().get_camera_3d()` returns
  whatever camera is live (the one the Phantom Camera host drives) — so "forward" always means
  "away from the camera" with zero hard node paths to the camera rig. Decoupled and robust.
- **Godot forward is -Z.** `Input.get_vector(left, right, forward, back)` gives `y < 0` for
  forward, and `Vector3(x, 0, y)` maps that straight to -Z before rotating by the camera yaw.
  If movement comes out mirrored/backwards, this axis mapping is the first suspect.
- **`move_toward` with separate accel/decel rates** gives the weighty ramp. Higher rates =
  snappier/arcadey; lower = heavier. This is the main "feel" knob to tune after a playtest.
- **Facing angle is `atan2(-velocity.x, -velocity.z)`** because the model's forward is -Z; a
  naive `atan2(vx, vz)` faces the character backwards. (Moot for a symmetric capsule — hence
  the nose indicator — but correct for a real model later.)
- **Gravity from ProjectSettings**, not a magic number, so it stays in sync with the project.
- **The floor needs collision** (`StaticBody3D` + shape) or the body falls through — a common
  "why won't it stand" gotcha. See `godot-scene-authoring`.

## Feel tuning defaults (grounded & weighty baseline)
walk 2.8 / run 5.5 / accel 14 / decel 18 / turn 9. Adjust to taste — this is a human
playtest call, not something verifiable headless.

## Testing
Movement/feel is human-tested. What you CAN assert headlessly: spawn placement (horizontal
tight, Y loose because physics settles the body — see `godot-gut-headless-testing`), and that
a boot runs `_physics_process` with no script errors.
