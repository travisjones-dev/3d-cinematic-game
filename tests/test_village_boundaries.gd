extends GutTest
## The village must be sealed on all four edges. Regression test for the playtest report that the
## player could still walk off the edge of the map.
##
## The bug: `Barriers/North*` is deliberately split into two 18m pieces — `NorthWest` covering
## x -22..-4 and `NorthEast` covering x 4..22 — leaving an 8m gap at x -4..4 on the z=-21 edge.
## That gap is where `ExitToShore` sits, and because that exit is a press-E interaction
## (zone_exit.gd extends interactable.gd), nothing physically stopped the player walking straight
## through the gap and off the Ground's edge at z=-22 into the void. Same class of bug as the tower
## exit doorway (see test_tower_doorway.gd): a press-E transition left physically unsealed.
##
## The fix: `Barriers/NorthGap`, an invisible collision-only StaticBody3D at (0, 3, -21) with an
## 8.4 x 6 x 0.5 box — 0.4 wider than the gap so it overlaps both neighbours and leaves no hairline
## seam. It sits far enough out that the player is still well inside the ExitToShore trigger
## (10 x 4 x 6 centred at z=-21, so z -24..-18) when blocked, leaving the prompt behaviour intact.
##
## Note the perimeter `Tree` props have no collision whatsoever (visual MeshInstance3D only), so the
## barriers are the only thing bounding the play space and these straight-line drives are unobstructed.
##
## As in test_tower_stairs.gd, no camera is present in this tree, so the player's camera-relative
## steering falls back to body yaw and world axes map straight onto the move actions:
## move_forward = -Z, move_back = +Z, move_right = +X, move_left = -X.

const VILLAGE: PackedScene = preload("res://scenes/zones/zone_01_village.tscn")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")

## Ground top is y = 0 and the capsule centre rests 1.0 above it, so a fall shows up as y plunging.
const FLOOR_FALL_LIMIT: float = -0.5

## Ground is 44x44 centred on the origin, so its edge is at 22 on both axes. Past this the player is
## off the map even if it has not started falling yet.
const GROUND_EDGE: float = 22.0

const ALL_ACTIONS: Array[StringName] = [
	&"run", &"move_forward", &"move_back", &"move_left", &"move_right",
]

var village: Node3D
var player: CharacterBody3D

func before_each() -> void:
	village = VILLAGE.instantiate()
	add_child(village)
	player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame

func after_each() -> void:
	for action in ALL_ACTIONS:
		Input.action_release(action)
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(village):
		village.free()

func test_cannot_walk_off_the_north_edge_through_the_shore_exit_gap() -> void:
	# Start inside the gap's mouth, on the story path to the shore exit.
	player.global_position = Vector3(0.0, 1.0, -18.0)
	await get_tree().physics_frame

	var lowest_y: float = player.global_position.y
	var furthest_north: float = player.global_position.z

	Input.action_press(&"run")
	Input.action_press(&"move_forward")
	for _i in range(300):
		await get_tree().physics_frame
		lowest_y = minf(lowest_y, player.global_position.y)
		furthest_north = minf(furthest_north, player.global_position.z)

	assert_gt(lowest_y, FLOOR_FALL_LIMIT,
		"player fell off the north edge through the shore-exit gap; lowest y was %f (final %s)" % [lowest_y, player.global_position])
	assert_gt(furthest_north, -GROUND_EDGE,
		"player walked past the ground edge at z=-22; reached z=%f" % furthest_north)
	# Prove the run actually made it to the barrier rather than passing for the wrong reason —
	# a player that never moved would not fall either.
	assert_lt(furthest_north, -19.5,
		"player never reached the north barrier, so the seal is untested; got only to z=%f" % furthest_north)

func test_all_four_edges_hold() -> void:
	# start position, action driving outward, axis to watch, human-readable edge name
	var edges: Array = [
		[Vector3(0.0, 1.0, -18.0), &"move_forward", "z", "north"],
		[Vector3(3.0, 1.0, 18.0), &"move_back", "z", "south"],
		[Vector3(18.0, 1.0, 3.0), &"move_right", "x", "east"],
		[Vector3(-18.0, 1.0, 3.0), &"move_left", "x", "west"],
	]

	for edge in edges:
		var start: Vector3 = edge[0]
		var action: StringName = edge[1]
		var axis: String = edge[2]
		var edge_name: String = edge[3]

		player.velocity = Vector3.ZERO
		player.global_position = start
		await get_tree().physics_frame

		var lowest_y: float = player.global_position.y
		var furthest: float = 0.0

		Input.action_press(&"run")
		Input.action_press(action)
		for _i in range(240):
			await get_tree().physics_frame
			lowest_y = minf(lowest_y, player.global_position.y)
			var reach: float = absf(player.global_position.z if axis == "z" else player.global_position.x)
			furthest = maxf(furthest, reach)
		Input.action_release(action)
		Input.action_release(&"run")

		assert_gt(lowest_y, FLOOR_FALL_LIMIT,
			"player fell off the %s edge; lowest y was %f" % [edge_name, lowest_y])
		assert_lt(furthest, GROUND_EDGE,
			"player crossed the ground edge on the %s side; reached %f on %s" % [edge_name, furthest, axis])
