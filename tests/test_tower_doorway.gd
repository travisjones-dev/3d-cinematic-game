extends GutTest
## The tower interior's south exit doorway must be physically sealed. Regression test for the
## playtest report that the player could walk out through the exit doorway and fall into the void.
##
## The bug: the south wall is built as three pieces around a doorway aperture — `SouthLeft`
## (x -4..-1), `SouthRight` (x 1..4) and `SouthLintel` (x -1..1 but only y 2.5 and up). That left
## the opening x -1..1, y 0..2.5 at z~4 with no geometry in it at all. The `Floor` is 8x8, so its
## top surface stops at exactly z = 4.0 and nothing exists beyond it. Because leaving is a press-E
## interaction on `ExitToVillage` (not a walk-through trigger), nothing ever stopped the player
## walking straight out of the hole and off the floor edge into empty space.
##
## The fix: `Geometry/SouthDoor` — a closed door (mesh + collision) filling the aperture, matching
## how the village seals its buildings and the guard tower itself (visible `Door` box meshes, plus
## collision-only `Barriers` at the map edge). It seals the hole and hides the unmodelled exterior,
## and it makes the press-E exit read as opening the door. `SpawnPoints/from_village` moved from
## z=3.5 to z=2.9 so the player does not spawn overlapping the new door: the capsule radius is 0.4
## and `safe_margin` is 0.2, so its effective shell reaches 0.6 and z=3.5 would have touched the
## door's z 3.9..4.1 span.
##
## As in test_tower_stairs.gd, no camera is present in this test's tree, so the player's
## camera-relative steering falls back to the body's own yaw and world axes map straight onto the
## move actions — `move_back` drives toward +Z, i.e. at the doorway.

const TOWER: PackedScene = preload("res://scenes/zones/zone_01_tower_interior.tscn")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")

## Floor top is y = 0 and the capsule centre rests 1.0 above it, so a fall shows up immediately as
## y plunging. Anything below this and the player has left the floor.
const FLOOR_FALL_LIMIT: float = -0.5

## Outer face of the south wall. The door blocks well short of this; getting past it means the
## player is outside the tower.
const OUTSIDE_WALL_Z: float = 4.2

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
	Input.action_release(&"move_back")
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(tower):
		tower.free()

func test_walking_into_the_exit_doorway_does_not_fall_through() -> void:
	var lowest_y: float = player.global_position.y
	var furthest_z: float = player.global_position.z

	# Run flat at the doorway for ~5s of physics — far longer than it takes to cross the ~1m from
	# the spawn to the door.
	Input.action_press(&"run")
	Input.action_press(&"move_back")
	for _i in range(300):
		await get_tree().physics_frame
		lowest_y = minf(lowest_y, player.global_position.y)
		furthest_z = maxf(furthest_z, player.global_position.z)

	assert_gt(lowest_y, FLOOR_FALL_LIMIT,
		"player fell out of the tower through the exit doorway; lowest y was %f (final %s)" % [lowest_y, player.global_position])
	assert_lt(furthest_z, OUTSIDE_WALL_Z,
		"player pushed past the south wall's outer face; furthest z was %f" % furthest_z)

func test_player_actually_reaches_the_door_and_is_stopped_by_it() -> void:
	# Guards against the test passing for the wrong reason — a player stuck at the spawn point
	# would never fall either. It must genuinely walk up and be blocked by the door.
	Input.action_press(&"move_back")
	for _i in range(300):
		await get_tree().physics_frame

	assert_gt(player.global_position.z, 3.0,
		"player never reached the doorway, so this scene's seal is untested; stopped at %s" % player.global_position)
	assert_almost_eq(player.global_position.y, 1.0, 0.3,
		"player should still be standing on the tower floor at the doorway")
