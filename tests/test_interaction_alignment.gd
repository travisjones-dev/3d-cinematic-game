extends GutTest
## Every Interactable's visible body must sit inside its own detection trigger, and no two triggers
## may overlap.
##
## Regression test for the friend playtest report (2026-07-27) that Aeia's dialogue box was "off to
## the side of Aeia", and that standing directly in front of her sometimes would not let you talk.
##
## The cause was structural, not tuning: the `Aeia` Area3D sat at (-1.8, 9.9, -1.5) and its `Trigger`
## child had no transform of its own, so the detection box was centred there — but the `Mesh` child
## carried a (1.9418097, 0, 1.6561785) offset, putting her visible body at
## (0.1418097, 9.9, 0.1561785). Her trigger spanned x -3.55..-0.05, so at x=+0.14 she stood just
## OUTSIDE her own trigger. The fractional offsets look like an editor hand-drag that moved the Mesh
## child instead of the Area3D. Fixed by moving the Area3D to her real position and zeroing the Mesh
## offset, leaving her visual position identical.
##
## This guards the class, not just Aeia: any interactable whose art drifts from its hitbox produces
## the same "I am standing right there and nothing happens" bug.
##
## Implementation note — this reads the authored .tscn via SceneState rather than instantiating the
## zones (see tests/helpers/scene_geometry.gd for why, and for the shared measurement code).
##
## ── HARDENED 2026-08-13, before M2 Phase 2's first art swap ─────────────────────────────────
## This test used to `continue` past any interactable with no "Mesh" child. That made it capable of
## disarming ITSELF during the art pass: an imported .glb is an instanced PackedScene, not a
## MeshInstance3D named "Mesh", so swapping art would have dropped interactables out of the checked
## set one by one — silently, with the suite still green, since the only count assertion was
## `checked > 0`. The guard against "I was standing right in front of her and couldn't talk" would
## have evaporated across the village without a single failing test.
##
## Now a trigger-bearing node with no measurable body is a FAILURE unless it is named in
## BODYLESS_BY_DESIGN below. Skipping is a reviewed decision, not an accident.

const SG := preload("res://tests/helpers/scene_geometry.gd")

const ZONES: Dictionary = {
	"village": "res://scenes/zones/zone_01_village.tscn",
	"tower": "res://scenes/zones/zone_01_tower_interior.tscn",
	"shore": "res://scenes/zones/zone_02_shore.tscn",
}

## Interactables with a trigger but no measurable body. Keyed "zone:node_path". Split into two
## lists because the two reasons are NOT equally healthy, and collapsing them would hide the second.
##
## Do NOT add an entry to silence a failure on something that IS supposed to have its own art —
## that is the wrong fix the ROADMAP warns about, and it re-opens the bug this file prevents.

## (A) Genuinely invisible volumes: you walk into them, there is nothing to look at. Correct as-is.
const INVISIBLE_BY_DESIGN: Array = [
	"village:./ExitToShore",     # press-E zone exit at the north gap; no art by design
	"tower:./ExitToVillage",     # press-E zone exit in the tower doorway; no art by design
	"shore:./ShoreTrigger",      # cutscene trigger volume, not an Interactable the player examines
]

## (B) ⚠️ KNOWN COVERAGE GAP, not a clean bill of health. These DO have visible bodies — but the
## geometry is a SIBLING under Props/Geometry, not a "Mesh" child, so this test cannot associate
## the two and therefore cannot check alignment. They were silently skipped before 2026-08-13 too;
## naming them here makes the gap visible instead of invisible.
##
## Spot-checked 2026-08-13 and currently fine, e.g. SecretHeart's trigger at (-16.4, 1.5, -8) spans
## y 0..3 around Props/CarvedHeart centred at y=2. But nothing HOLDS that — and these are exactly
## the props M2 Phase 2 swaps (banners, the anvil, the carved heart), so the drift this file exists
## to catch is unguarded precisely where the art pass will move things.
##
## Closing it needs an explicit interactable→geometry mapping. Deliberately not built here: it is
## new scope, not in the M2 Phase 2 list. Flagged for a scope decision.
const BODY_IS_SIBLING_GEOMETRY: Array = [
	"village:./Interactables/WeddingSetup",    # banners + flowers under Props
	"village:./Interactables/StableInteract",  # the steed + stable structure
	"village:./Interactables/TowerInteract",   # the GuardTower building itself
	"village:./Interactables/SecretHeart",     # Props/CarvedHeart
	"tower:./Interactables/WatchmanTally",     # tally marks on the tower wall
]

## Every node allowed to have no measurable body, for whichever reason.
static func _bodyless_allowlist() -> Array:
	return INVISIBLE_BY_DESIGN + BODY_IS_SIBLING_GEOMETRY

func test_every_interactable_body_sits_inside_its_own_trigger() -> void:
	var checked: int = 0

	for zone_name: String in ZONES:
		var nodes: Dictionary = SG.read_scene(ZONES[zone_name])
		for path: String in nodes:
			var trigger: AABB = SG.trigger_box(nodes, path)
			if trigger.size == Vector3.ZERO:
				continue

			var key: String = "%s:%s" % [zone_name, path]
			var body: AABB = SG.body_box(nodes, path)

			if body.size == Vector3.ZERO:
				assert_true(_bodyless_allowlist().has(key),
					("%s has a detection trigger but NO measurable visible body.\n" \
					+ "  If it is genuinely invisible (a walk-in exit volume), add it to " \
					+ "INVISIBLE_BY_DESIGN with a reason.\n" \
					+ "  If its art is a sibling node rather than a Mesh child, add it to " \
					+ "BODY_IS_SIBLING_GEOMETRY — and read that constant's warning first.\n" \
					+ "  If it is supposed to have its OWN art, an art swap has renamed or " \
					+ "replaced its Mesh child and this guard is no longer watching it — fix the " \
					+ "scene, not this test.") % key)
				continue

			# Centre of the visible geometry, not the node origin: imported assets are
			# base-pivoted (origin at the feet), so the origin alone is a poor stand-in for
			# "where the player sees this thing".
			var body_point: Vector3 = body.get_center()
			assert_true(trigger.has_point(body_point),
				"%s: visible body centred at %s is outside its own trigger %s — the player cannot interact while standing at it" \
					% [key, body_point, trigger])
			checked += 1

	assert_gt(checked, 0, "should have found interactables with both a body and a Trigger")

func test_bodyless_allowlist_has_not_gone_stale() -> void:
	# An allowlist entry for a node that no longer exists is dead weight that would silently cover
	# for a future node of the same name. Every entry must still name a real trigger-bearing node.
	for key: String in _bodyless_allowlist():
		var parts: PackedStringArray = key.split(":")
		assert_eq(parts.size(), 2, "malformed allowlist entry %s — expected 'zone:path'" % key)
		if parts.size() != 2:
			continue

		var zone_name: String = parts[0]
		var path: String = parts[1]
		assert_true(ZONES.has(zone_name), "allowlist names unknown zone %s" % zone_name)
		if not ZONES.has(zone_name):
			continue

		var nodes: Dictionary = SG.read_scene(ZONES[zone_name])
		assert_true(nodes.has(path), "allowlist entry %s no longer exists — remove it" % key)
		if not nodes.has(path):
			continue

		assert_ne(SG.trigger_box(nodes, path).size, Vector3.ZERO,
			"allowlist entry %s no longer has a box trigger — remove it" % key)
		assert_eq(SG.body_box(nodes, path).size, Vector3.ZERO,
			("%s now HAS its own measurable body, so it is no longer bodyless — remove it from " \
			+ "the allowlist so it gets alignment-checked like everything else.") % key)

func test_no_two_triggers_overlap_in_any_zone() -> void:
	# player.gd:_on_interaction_available is LAST-ENTERED-WINS, not nearest-wins, so two overlapping
	# triggers let the player stand at one interactable while the other's prompt shows.
	for zone_name: String in ZONES:
		var nodes: Dictionary = SG.read_scene(ZONES[zone_name])
		var boxes: Array = []
		for path: String in nodes:
			# A script filters out scriptless Area3Ds like the shore's cutscene ShoreTrigger, which
			# is not an Interactable and legitimately overlaps nothing.
			if not (nodes[path] as Dictionary)["has_script"]:
				continue
			var box: AABB = SG.trigger_box(nodes, path)
			if box.size == Vector3.ZERO:
				continue
			boxes.append({"name": path, "aabb": box})

		for i in range(boxes.size()):
			for j in range(i + 1, boxes.size()):
				var a: Dictionary = boxes[i]
				var b: Dictionary = boxes[j]
				assert_false((a["aabb"] as AABB).intersects(b["aabb"] as AABB),
					"%s: %s and %s triggers overlap; last-entered-wins would show the wrong prompt" \
						% [zone_name, a["name"], b["name"]])
