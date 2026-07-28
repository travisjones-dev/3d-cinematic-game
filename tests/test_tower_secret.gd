extends GutTest
## The tower's optional discovery — a watchman's tally scratched into the west wall, tucked under the
## spiral where the stairs are high overhead. Added 2026-07-27 from friend-playtest feedback asking
## for more secrets; it also brings the tower into line with the Zone Design Law ("at least 1 optional
## discovery" per zone), which it previously failed since it had none.
##
## The point of this test is REACHABILITY, which is where the tower keeps going wrong: Aeia's dialogue
## box was placed where the player could not trigger it, and the first spot chosen for this secret
## (the north pocket, x~0 z~-3) turned out to be unusable because the lowest step overhead there is
## Step17 at y=2.04, putting its underside at y~1.89 against a 2.0m-tall player capsule — the player
## would have been shoved by the stairs above. The west side was used instead: at 270 degrees the
## lowest step overhead is Step27 at y=3.29 (underside ~3.14), leaving over a metre of headroom, and
## it sits off the climbing path so the find stays hidden.
##
## Guards that the nook is standable: the player must neither be squeezed by the stairs above nor
## pushed out of the trigger by the newel or wall.

const TOWER: PackedScene = preload("res://scenes/zones/zone_01_tower_interior.tscn")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")

## Where the player stands to read the tally — beside the west wall, outside the newel (radius 2.5).
const NOOK: Vector3 = Vector3(-3.0, 1.0, 0.2)

var tower: Node3D
var player: CharacterBody3D

func before_each() -> void:
	tower = TOWER.instantiate()
	add_child(tower)
	player = PLAYER.instantiate()
	add_child(player)
	player.global_position = NOOK
	await get_tree().physics_frame

func after_each() -> void:
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(tower):
		tower.free()

func test_player_can_stand_in_the_nook_without_being_squeezed_or_shoved() -> void:
	var lowest_y: float = player.global_position.y
	for _i in range(120):
		await get_tree().physics_frame
		lowest_y = minf(lowest_y, player.global_position.y)

	# Floor top is y=0 and the capsule centre rests 1.0 above it. Falling or being crushed downward
	# by the stairs above would drop this.
	assert_almost_eq(lowest_y, 1.0, 0.25,
		"player should stand upright in the tally nook; lowest y was %f" % lowest_y)
	# The newel (radius 2.5) and the west wall (interior face x=-3.8) bracket the pocket. Being
	# shoved by stair geometry overhead would show up as drifting out of it.
	assert_lt(player.global_position.x, -2.5,
		"player was pushed out of the nook toward the newel; ended at %s" % player.global_position)
	assert_gt(player.global_position.x, -3.8,
		"player was pushed into the west wall; ended at %s" % player.global_position)

func test_the_tally_is_inside_its_own_trigger_and_the_flag_is_namespaced() -> void:
	var tally: Node = tower.get_node("Interactables/WatchmanTally")
	var trigger: CollisionShape3D = tally.get_node("Trigger")
	var extents: Vector3 = (trigger.shape as BoxShape3D).size * 0.5
	var box: AABB = AABB(trigger.global_position - extents, extents * 2.0)

	assert_true(box.has_point(NOOK),
		"the standing spot %s must be inside the tally's trigger %s" % [NOOK, box])
	# The visual is a child of the wall, not of the Area3D, so check it lines up with the trigger too.
	var mark: Node3D = tower.get_node("Geometry/WestWall/Tally")
	assert_true(box.has_point(mark.global_position),
		"the scratches at %s must be inside the trigger %s the player uses to read them" % [mark.global_position, box])
	assert_string_contains(tally.discovers_flag, "act1/",
		"discovery flag must be namespaced per the story-flag convention")
