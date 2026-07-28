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
## zones. Trigger/mesh alignment is a static property of the scene file, so a live tree buys nothing,
## and instantiating these zones headlessly raises the documented-benign
## `material_get_instance_shader_parameters` / `Parameter "material" is null` error from the dummy
## renderer, which GUT counts as a failure. Composing transforms with Transform3D multiplication is
## also exact, avoiding the basis-convention trap that caused the steed-facing bug.

const ZONES: Dictionary = {
	"village": "res://scenes/zones/zone_01_village.tscn",
	"tower": "res://scenes/zones/zone_01_tower_interior.tscn",
	"shore": "res://scenes/zones/zone_02_shore.tscn",
}

func test_every_interactable_body_sits_inside_its_own_trigger() -> void:
	var checked: int = 0

	for zone_name: String in ZONES:
		var nodes: Dictionary = _read_scene(ZONES[zone_name])
		for path: String in nodes:
			var trigger_box: AABB = _trigger_box(nodes, path)
			if trigger_box.size == Vector3.ZERO:
				continue
			if not nodes.has(path + "/Mesh"):
				continue

			var body: Vector3 = _global_of(nodes, path + "/Mesh").origin
			assert_true(trigger_box.has_point(body),
				"%s/%s: visible body at %s is outside its own trigger %s — the player cannot interact while standing at it" \
					% [zone_name, path, body, trigger_box])
			checked += 1

	assert_gt(checked, 0, "should have found interactables with both a Mesh and a Trigger")

func test_no_two_triggers_overlap_in_any_zone() -> void:
	# player.gd:_on_interaction_available is LAST-ENTERED-WINS, not nearest-wins, so two overlapping
	# triggers let the player stand at one interactable while the other's prompt shows.
	for zone_name: String in ZONES:
		var nodes: Dictionary = _read_scene(ZONES[zone_name])
		var boxes: Array = []
		for path: String in nodes:
			# A script filters out scriptless Area3Ds like the shore's cutscene ShoreTrigger, which
			# is not an Interactable and legitimately overlaps nothing.
			if not (nodes[path] as Dictionary)["has_script"]:
				continue
			var box: AABB = _trigger_box(nodes, path)
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

## Reads a .tscn into {node_path: {transform, has_script, shape}} without instantiating it.
func _read_scene(path: String) -> Dictionary:
	var state: SceneState = (load(path) as PackedScene).get_state()
	var nodes: Dictionary = {}
	for i in range(state.get_node_count()):
		var node_path: String = String(state.get_node_path(i))
		var entry: Dictionary = {
			"transform": Transform3D.IDENTITY,
			"has_script": false,
			"shape": null,
		}
		for j in range(state.get_node_property_count(i)):
			var prop: String = state.get_node_property_name(i, j)
			var value: Variant = state.get_node_property_value(i, j)
			match prop:
				"transform":
					entry["transform"] = value
				"script":
					entry["has_script"] = value != null
				"shape":
					entry["shape"] = value
		nodes[node_path] = entry
	return nodes

## Composes a node's transform down from the scene root by multiplication.
func _global_of(nodes: Dictionary, path: String) -> Transform3D:
	var acc: Transform3D = Transform3D.IDENTITY
	if nodes.has("."):
		acc = (nodes["."] as Dictionary)["transform"]
	if path == ".":
		return acc
	var walked: String = ""
	for part: String in path.split("/"):
		walked = part if walked == "" else walked + "/" + part
		if nodes.has(walked):
			acc = acc * ((nodes[walked] as Dictionary)["transform"] as Transform3D)
	return acc

## World-space AABB of a node's "Trigger" child, or a zero-size AABB if it has no box trigger.
func _trigger_box(nodes: Dictionary, path: String) -> AABB:
	var trigger_path: String = path + "/Trigger"
	if not nodes.has(trigger_path):
		return AABB()
	var shape: Variant = (nodes[trigger_path] as Dictionary)["shape"]
	if not shape is BoxShape3D:
		return AABB()
	var extents: Vector3 = (shape as BoxShape3D).size * 0.5
	var centre: Vector3 = _global_of(nodes, trigger_path).origin
	return AABB(centre - extents, extents * 2.0)
