extends GutTest
## The tower's top chamber must be enclosed overhead, with real headroom above a standing character.
##
## Regression test for the playtest report (2026-07-29) that reaching the top of the tower left you
## "looking out into the void". The cause was not a missing roof alone: the top platform's walkable
## surface is at y=8.9 while the original walls stopped at y=9.8, so a 2.0 m character standing there
## had head and shoulders ABOVE the wall line with open sky around them. Both Aeia and the player
## stood in that gap, which is why the farewell beat read as happening in mid-air.
##
## Fix was two parts: four `*WallUpper` pieces carrying the walls from y=9.8 to y=12.6, and a
## `Ceiling` slab whose underside sits flush on that new wall top. A `RoofCone` above the slab gives
## the exterior silhouette, matched (same material, same height:radius proportion) by a `Roof` cone on
## the village's `GuardTower/CrackedTop` so the tower reads the same from outside as it does inside.
##
## Guarded here rather than left to eyeball because both failure modes are invisible in a screenshot
## taken from the wrong spot: a ceiling that clears the centre of the room but not its edges, and a
## wall extension that leaves a hairline clerestory band of sky at the old wall top.
##
## Implementation note — reads the authored .tscn via SceneState rather than instantiating the zone:
## enclosure is a static property of the scene file, and instantiating these zones headlessly raises
## the documented-benign dummy-renderer `Parameter "material" is null` error, which GUT counts as a
## failure. The measurement code lives in tests/helpers/scene_geometry.gd, shared with
## test_interaction_alignment.gd.
##
## ── M2 art-pass note (2026-08-13) ───────────────────────────────────────────────────────────
## These assertions are the guard against "the top of the tower is open to the void", and they will
## come under real pressure when the tower interior gets its art pass — the ceiling and upper walls
## are on the swap list. `SG.body_box()` measures imported .glb assets as well as graybox primitives,
## so a swap should keep these tests meaningful rather than breaking them. If one DOES break, the
## fix is to re-check the geometry against the numbers below, NOT to relax the constant.

const SG := preload("res://tests/helpers/scene_geometry.gd")

const TOWER: String = "res://scenes/zones/zone_01_tower_interior.tscn"
const VILLAGE: String = "res://scenes/zones/zone_01_village.tscn"

## Walkable surface of the top platform, and the standing height of a 2.0 m capsule on it.
const PLATFORM_SURFACE_Y: float = 8.9
const HEAD_Y: float = PLATFORM_SURFACE_Y + 2.0
## The steps spiral out to r 2.5..3.5 and the walls' inner faces sit at 3.8, so this covers every
## radius the player can actually occupy at the top, not just the platform disc.
const REACHABLE_RADIUS: float = 3.8
## SceneState reports node paths with a leading "./", so hardcoded lookups need it too.
const CEILING: String = "./Geometry/Ceiling"
## The wall extension is authored to sit exactly flush against both the old wall top and the ceiling,
## so these comparisons are on a float knife-edge; tolerate a millimetre of transform rounding.
const EPS: float = 0.01

func test_ceiling_clears_a_standing_characters_head_across_the_whole_top() -> void:
	var nodes: Dictionary = _read_scene(TOWER)
	assert_true(nodes.has(CEILING), "the top chamber has no Ceiling — you would see sky")
	if not nodes.has(CEILING):
		return

	var box: AABB = _mesh_box(nodes, CEILING)
	var underside: float = box.position.y

	assert_gt(underside, HEAD_Y + 1.0,
		"ceiling underside at y=%.2f gives only %.2f m over a head at y=%.2f — cramped" \
			% [underside, underside - HEAD_Y, HEAD_Y])

	# A slab that clears the head but not the room's full width would still crush the player at the
	# edges, where the top steps run.
	var half_x: float = box.size.x * 0.5
	var half_z: float = box.size.z * 0.5
	assert_gte(minf(half_x, half_z), REACHABLE_RADIUS,
		"ceiling spans %.1f x %.1f but the player reaches r=%.1f — the edges of the top are open" \
			% [box.size.x, box.size.z, REACHABLE_RADIUS])

func test_upper_walls_close_the_gap_between_old_wall_top_and_ceiling() -> void:
	# The original walls span y 0..9.8. If the extension does not start at or below 9.8 and reach the
	# ceiling underside, a band of sky is left around the whole perimeter.
	var nodes: Dictionary = _read_scene(TOWER)
	var ceiling_underside: float = _mesh_box(nodes, CEILING).position.y
	var checked: int = 0

	for name: String in ["NorthWallUpper", "SouthWallUpper", "EastWallUpper", "WestWallUpper"]:
		var path: String = "./Geometry/" + name
		assert_true(nodes.has(path), "%s is missing — that side of the top is open to the sky" % name)
		if not nodes.has(path):
			continue

		var box: AABB = _mesh_box(nodes, path)
		assert_lte(box.position.y, 9.8 + EPS,
			"%s starts at y=%.2f, above the old wall top of 9.8 — leaves a band of sky" \
				% [name, box.position.y])
		assert_gte(box.position.y + box.size.y, ceiling_underside - EPS,
			"%s tops out at y=%.2f but the ceiling starts at y=%.2f — leaves a band of sky" \
				% [name, box.position.y + box.size.y, ceiling_underside])
		checked += 1

	assert_eq(checked, 4, "should have checked all four upper walls")

func test_village_guard_tower_has_a_matching_roof() -> void:
	# The interior now reads as a roofed tower, so the prop you see from the village must agree.
	var nodes: Dictionary = _read_scene(VILLAGE)
	var path: String = "./Geometry/GuardTower/CrackedTop/Roof"
	assert_true(nodes.has(path), "the village GuardTower has no Roof — it contradicts the interior")
	if not nodes.has(path):
		return

	# Parented to CrackedTop so it inherits the crown's lean; a roof standing upright on a leaning
	# ruin would read as a mistake. The crown leans about -9.85 degrees, so compare the magnitude —
	# asserting a positive euler.z would fail on the sign, not on the geometry.
	var lean: Basis = _global_of(nodes, path).basis
	assert_gt(absf(lean.get_euler().z), 0.05,
		"the village tower roof is upright but the cracked crown leans — it should inherit the lean")

## Reads a .tscn without instantiating it. See tests/helpers/scene_geometry.gd.
func _read_scene(path: String) -> Dictionary:
	return SG.read_scene(path)

## Composes a node's transform down from the scene root by multiplication.
func _global_of(nodes: Dictionary, path: String) -> Transform3D:
	return SG.global_of(nodes, path)

## World-space AABB of a node's visible geometry — its own mesh, its "Mesh" child, or an imported
## .glb instanced under it. Fails loudly rather than returning a silently-empty box, because every
## caller here compares heights: a zero AABB reads as "y=0", which would make an open roof look
## enclosed and pass this test for the worst possible reason.
func _mesh_box(nodes: Dictionary, path: String) -> AABB:
	var box: AABB = SG.body_box(nodes, path)
	assert_ne(box.size, Vector3.ZERO, "%s has no measurable mesh — cannot verify enclosure" % path)
	return box
