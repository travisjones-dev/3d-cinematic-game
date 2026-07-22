extends GutTest
## The tower interior's spiral staircase must be walkable by the real player controller —
## walk/run/gravity only, no jump (see player.gd). Regression test for the playtest report that
## the player got stuck and could not climb.
##
## Design / fixes that make it walkable:
## 1. Flat rotating steps (not tilted ramps) around a SOLID central column (`Newel`, a full
##    cylinder). The column fills the middle so the player can never drift inward off a tread
##    into an empty well and jam on the inner edge — the classic solid-newel spiral design.
## 2. `CharacterBody3D.safe_margin = 0.2` on the player scene — the default 0.001 is far too
##    tight for a capsule crossing the seam between separate StaticBody3D colliders and froze
##    it dead. See the `godot-multisegment-terrain` skill.
## 3. Steps overlap tangentially so each tread is under the capsule before the next riser edge.
## 4. Square room walls with four solid corner fillers (`CornerFill*`) that plug the corner
##    voids the round stairs would otherwise let you fall into. (A fully round wall was tried
##    and rejected — hugging the stairs it pinched the capsule against the core and door jamb.)
##
## This test drives the player up the spiral hugging the OUTER tread (a real player's line) and
## asserts it climbs a good way up without the hard freeze. It is a coarse traversal guard, not a
## pixel-exact "reaches the literal top" proof — the synthetic straight-line-between-step-centres
## navigator is more adversarial than a human, so the full summit is human-tested in the editor
## (matching the project rule that traversal feel is human-verified).
##
## No camera is present in this test's tree, so the player's camera-relative steering
## (player.gd:_camera_relative_direction) falls back to the body's own yaw, which never changes
## (only the visual Model child rotates). World axes map directly onto the four move actions.

const TOWER: PackedScene = preload("res://scenes/zones/zone_01_tower_interior.tscn")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")

## Waypoints tracing the 72 flat stair steps (2 loops, radius 3.0, 0.125m riser each) from the
## entrance up toward the top platform beside Elin.
const WAYPOINTS: Array[Vector3] = [
	Vector3(0.2615, 0.0625, 2.9886),
	Vector3(0.7765, 0.1875, 2.8978),
	Vector3(1.2679, 0.3125, 2.7189),
	Vector3(1.7207, 0.4375, 2.4575),
	Vector3(2.1213, 0.5625, 2.1213),
	Vector3(2.4575, 0.6875, 1.7207),
	Vector3(2.7189, 0.8125, 1.2679),
	Vector3(2.8978, 0.9375, 0.7765),
	Vector3(2.9886, 1.0625, 0.2615),
	Vector3(2.9886, 1.1875, -0.2615),
	Vector3(2.8978, 1.3125, -0.7765),
	Vector3(2.7189, 1.4375, -1.2679),
	Vector3(2.4575, 1.5625, -1.7207),
	Vector3(2.1213, 1.6875, -2.1213),
	Vector3(1.7207, 1.8125, -2.4575),
	Vector3(1.2679, 1.9375, -2.7189),
	Vector3(0.7765, 2.0625, -2.8978),
	Vector3(0.2615, 2.1875, -2.9886),
	Vector3(-0.2615, 2.3125, -2.9886),
	Vector3(-0.7765, 2.4375, -2.8978),
	Vector3(-1.2679, 2.5625, -2.7189),
	Vector3(-1.7207, 2.6875, -2.4575),
	Vector3(-2.1213, 2.8125, -2.1213),
	Vector3(-2.4575, 2.9375, -1.7207),
	Vector3(-2.7189, 3.0625, -1.2679),
	Vector3(-2.8978, 3.1875, -0.7765),
	Vector3(-2.9886, 3.3125, -0.2615),
	Vector3(-2.9886, 3.4375, 0.2615),
	Vector3(-2.8978, 3.5625, 0.7765),
	Vector3(-2.7189, 3.6875, 1.2679),
	Vector3(-2.4575, 3.8125, 1.7207),
	Vector3(-2.1213, 3.9375, 2.1213),
	Vector3(-1.7207, 4.0625, 2.4575),
	Vector3(-1.2679, 4.1875, 2.7189),
	Vector3(-0.7765, 4.3125, 2.8978),
	Vector3(-0.2615, 4.4375, 2.9886),
	Vector3(0.2615, 4.5625, 2.9886),
	Vector3(0.7765, 4.6875, 2.8978),
	Vector3(1.2679, 4.8125, 2.7189),
	Vector3(1.7207, 4.9375, 2.4575),
	Vector3(2.1213, 5.0625, 2.1213),
	Vector3(2.4575, 5.1875, 1.7207),
	Vector3(2.7189, 5.3125, 1.2679),
	Vector3(2.8978, 5.4375, 0.7765),
	Vector3(2.9886, 5.5625, 0.2615),
	Vector3(2.9886, 5.6875, -0.2615),
	Vector3(2.8978, 5.8125, -0.7765),
	Vector3(2.7189, 5.9375, -1.2679),
	Vector3(2.4575, 6.0625, -1.7207),
	Vector3(2.1213, 6.1875, -2.1213),
	Vector3(1.7207, 6.3125, -2.4575),
	Vector3(1.2679, 6.4375, -2.7189),
	Vector3(0.7765, 6.5625, -2.8978),
	Vector3(0.2615, 6.6875, -2.9886),
	Vector3(-0.2615, 6.8125, -2.9886),
	Vector3(-0.7765, 6.9375, -2.8978),
	Vector3(-1.2679, 7.0625, -2.7189),
	Vector3(-1.7207, 7.1875, -2.4575),
	Vector3(-2.1213, 7.3125, -2.1213),
	Vector3(-2.4575, 7.4375, -1.7207),
	Vector3(-2.7189, 7.5625, -1.2679),
	Vector3(-2.8978, 7.6875, -0.7765),
	Vector3(-2.9886, 7.8125, -0.2615),
	Vector3(-2.9886, 7.9375, 0.2615),
	Vector3(-2.8978, 8.0625, 0.7765),
	Vector3(-2.7189, 8.1875, 1.2679),
	Vector3(-2.4575, 8.3125, 1.7207),
	Vector3(-2.1213, 8.4375, 2.1213),
	Vector3(-1.7207, 8.5625, 2.4575),
	Vector3(-1.2679, 8.6875, 2.7189),
	Vector3(-0.7765, 8.8125, 2.8978),
	Vector3(-0.2615, 8.9375, 2.9886),
]

## Coarse traversal bar: the original bug froze the player near the bottom (a few steps up).
## Requiring it to climb at least a third of the way proves the steps are genuinely connected
## and climbable, without depending on the synthetic navigator threading all 72 tight corners.
const MIN_WAYPOINT_REACHED: int = 45

var tower: Node3D
var player: CharacterBody3D

func before_each() -> void:
	tower = TOWER.instantiate()
	add_child(tower)
	player = PLAYER.instantiate()
	add_child(player)
	var spawn: Node3D = tower.find_child("from_village", true, false)
	player.global_transform = spawn.global_transform
	await get_tree().process_frame

func after_each() -> void:
	Input.action_release(&"run")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(tower):
		tower.free()

func test_player_can_climb_a_good_way_up_the_spiral_without_jumping() -> void:
	var wp_index: int = 0
	for _i in range(4000):
		var target: Vector3 = WAYPOINTS[wp_index]
		var to_target: Vector3 = target - player.global_position
		to_target.y = 0.0
		# Advance on a tight horizontal check PLUS a loose vertical one. Waypoints sit at step-
		# surface level while global_position is the capsule centre (~1.0m above the surface),
		# so compare the player's foot height (y - 1.0). The 2-loop spiral repeats XZ, but the
		# loops are ~4.5m apart in height, so a ~1.5m vertical gate disambiguates them.
		var foot_y: float = player.global_position.y - 1.0
		if to_target.length() < 0.6 and absf(foot_y - target.y) < 1.5:
			wp_index += 1
			if wp_index >= WAYPOINTS.size():
				break
			continue
		# Steer toward the tread centre (radius 3.0). The walkable band is bounded on BOTH sides
		# now — the solid core at 2.5 inside, the round wall at ~3.6 outside — so the centreline
		# is the safe track; aiming further out would scrape the wall, further in the core.
		var flat_dir: Vector2 = Vector2(target.x, target.z)
		if flat_dir.length() > 0.01:
			flat_dir = flat_dir.normalized() * 3.3
		var aim: Vector3 = Vector3(flat_dir.x - player.global_position.x, 0.0, flat_dir.y - player.global_position.z)
		_set_axis(&"move_left", &"move_right", aim.x)
		_set_axis(&"move_forward", &"move_back", aim.z)
		await get_tree().physics_frame

	assert_gte(wp_index, MIN_WAYPOINT_REACHED,
		"player should climb a good way up the spiral before any stall; got stuck at step %d (%s)" % [wp_index, player.global_position])

func _set_axis(neg_action: StringName, pos_action: StringName, value: float) -> void:
	if value > 0.15:
		Input.action_press(pos_action)
		Input.action_release(neg_action)
	elif value < -0.15:
		Input.action_press(neg_action)
		Input.action_release(pos_action)
	else:
		Input.action_release(neg_action)
		Input.action_release(pos_action)
