---
name: godot-phantom-camera
description: >-
  Set up a Phantom Camera 0.11 third-person follow rig in this Godot project — the
  exact node structure, follow_mode, spring-arm properties, and mouse-look API for
  the installed version. Use this WHENEVER the task involves the cinematic camera:
  a third-person follow camera, orbiting/aiming the camera, camera damping/distance/
  pitch, switching camera angles by priority, or debugging why the Phantom Camera
  isn't following. Also the reference for the general trick of discovering an addon's
  real API from its bundled examples instead of guessing from docs.
---

# Phantom Camera 0.11 — third-person follow rig

Phantom Camera is this project's cinematic camera (a pinned decision). This skill is the
setup for the **installed version, 0.11.0.2**, whose API differs from older docs. Verified
working on Godot 4.6.3.

## First principle: trust the installed examples, not the internet

Addon APIs drift between versions. Before wiring anything, read the addon's own example
scenes and scripts — they are ground truth for the version you actually have:

- `addons/phantom_camera/examples/example_scenes/3D/3d_follow_third_person_example_scene.tscn`
  — the canonical third-person node graph + property values.
- `addons/phantom_camera/examples/scripts/3D/player_controller_third_person.gd` and its base
  `player_controller.gd` — how movement and mouse-look are wired.

`grep` the addon for an enum or method (`enum FollowMode`, `THIRD_PERSON`,
`third_person_rotation`) to find exact names. This "read the bundled examples" habit is the
fastest reliable way to use ANY Godot addon correctly.

## Node structure (lives in the persistent scene, e.g. main.tscn)

The camera persists across zone transitions, so it belongs in the persistent root, not in a
zone. Three pieces:

```
[ext_resource type="Script" path="res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd" id="3_pcam"]
[ext_resource type="Script" path="res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd" id="4_host"]

[node name="MainCamera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.8660254, 0.5, 0, -0.5, 0.8660254, 0, 3.5, 4.5)

[node name="PhantomCameraHost" type="Node" parent="MainCamera3D"]
process_priority = 300
process_physics_priority = 300
script = ExtResource("4_host")

[node name="PlayerPhantomCamera3D" type="Node3D" parent="." node_paths=PackedStringArray("follow_target")]
transform = Transform3D(1, 0, 0, 0, 0.8660254, 0.5, 0, -0.5, 0.8660254, 0, 3.5, 4.5)
script = ExtResource("3_pcam")
priority = 10
follow_mode = 6
follow_target = NodePath("../Player")
follow_damping = true
follow_distance = 4.0
follow_offset = Vector3(0, 0.6, 0)
vertical_rotation_offset = 0.4
spring_length = 4.0
tween_on_load = false
```

Key facts (all learned from the example scene):
- **`PhantomCameraHost` is a `Node` child of the actual `Camera3D`.** The host finds
  PhantomCamera3D nodes anywhere in the tree and drives the real camera. Give it high
  process priorities (300) so it runs after gameplay.
- **`follow_mode = 6` is THIRD_PERSON.** (The enum: 0 none … 6 third-person. Confirm with
  `grep "enum FollowMode" addons/phantom_camera`.)
- **PhantomCamera3D is `type="Node3D"` + the script** (custom types serialize as base+script
  — see `godot-scene-authoring`). Its own transform sets the initial orbit angle/pitch.
- **`follow_target` needs the `node_paths=PackedStringArray("follow_target")` header**, or it
  won't resolve.
- Third-person tuning knobs: `follow_distance`, `spring_length` (arm length for collision),
  `vertical_rotation_offset` (radians, initial pitch), `follow_offset` (aim above feet),
  `follow_damping` (smooth lag). `priority` decides which pcam wins when several exist.
- `tween_on_load = false` avoids an intro sweep from the origin on scene start.

## Mouse-look (orbit the spring arm)

Mouse-look rotates the third-person arm via two methods — NOT by rotating the Camera3D
directly. Capture the mouse, then in `_unhandled_input`:

```gdscript
@onready var _pcam: PhantomCamera3D = $PlayerPhantomCamera3D

func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        var rot: Vector3 = _pcam.get_third_person_rotation_degrees()
        rot.x = clampf(rot.x - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)
        rot.y = wrapf(rot.y - event.relative.x * mouse_sensitivity, 0.0, 360.0)
        _pcam.set_third_person_rotation_degrees(rot)
```

- `get_third_person_rotation_degrees()` / `set_third_person_rotation_degrees(Vector3)` are the
  API. `.x` = pitch (clamp so the camera can't flip), `.y` = yaw (wrap 0–360).
- `PhantomCamera3D` has `class_name`, so you can type variables as `PhantomCamera3D` and use
  `PhantomCamera3D.FollowMode.THIRD_PERSON`.
- Always give the player a way OUT of captured mouse mode (pause menu, or a temporary Escape
  toggle) — otherwise the cursor is trapped and you can't reach the editor while testing.

## Multiple angles = multiple pcams + priority
Extra cameras (aim, ceiling, cutscene shots) are additional PhantomCamera3D nodes; raise a
pcam's `priority` (or `set_priority()`) to make the host tween to it. This is how cutscene
shots will work in Phase C — one host, many pcams, priority chooses the active shot.

## Spawn clearance: the camera sits BEHIND the player
A third-person rig places the camera `spring_length` behind the player. So a spawn point must
have clear space *behind* it, not just in front — if the player spawns a metre in front of a
wall/tree/prop, the camera lands inside or behind that object and the first thing the player sees
on load is its backside (this happened at launch: spawn at z=18, one metre ahead of the perimeter
tree row at z=20 → the opening shot was a tree trunk). Rule: keep a spawn at least
`spring_length + ~1m` clear of anything behind it (relative to the facing direction), or the
spring arm will frame that thing. Fix is usually to move the spawn marker forward, not to touch
the camera. (Phantom Camera's spring arm *does* pull in on collision, but only against bodies on
its collision mask — decorative props like trees often aren't on it, so don't rely on it.)

## Verify
Camera framing/feel can't be judged headless — boot (`--quit-after`) only proves it loads
without script errors. The look (distance, pitch, damping) is a human playtest call; expect
to tune the knobs above after someone drives it.
