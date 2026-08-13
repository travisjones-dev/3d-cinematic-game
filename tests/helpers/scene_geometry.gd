extends RefCounted
## Static geometry reader for authored .tscn files — measures scenes WITHOUT instantiating them.
##
## Shared by test_interaction_alignment.gd and test_tower_roof.gd, which both need to measure
## authored geometry and both previously carried their own copy of this logic. They were unified
## when M2's art pass made the measurement genuinely tricky (imported .glb assets), because two
## divergent copies of tricky code is how a guard quietly stops guarding.
##
## Why static reads rather than a live tree: geometry is a static property of the scene file, so
## instantiating buys nothing, and instantiating these zones headlessly raises the documented-benign
## `material_get_instance_shader_parameters` / `Parameter "material" is null` error from the dummy
## renderer, which GUT counts as a failure.
##
## No `class_name` on purpose — per tests/README.md, a new class_name requires an extra `--import`
## pass before GUT will run. Callers `preload()` this instead.
##
## ── M2 art-pass note ────────────────────────────────────────────────────────────────────────
## A graybox `MeshInstance3D` carries its mesh as an inline sub-resource, readable straight off
## SceneState. An imported `.glb` does NOT: it is an *instanced PackedScene*, and its geometry
## lives in a separate file that SceneState reports only as an instance reference. Code that
## looks only at the `mesh` property sees nothing at all for imported art.
##
## That is why `body_box()` resolves three shapes of node, and why it reports "nothing measurable"
## as a zero-SIZE AABB that callers must treat as a FAILURE rather than skipping. A skip here is
## indistinguishable from a pass, which is exactly how an art swap could silently disarm the
## "visible but unusable" guards.


## Reads a .tscn into {node_path: {transform, has_script, shape, mesh, instance}}.
static func read_scene(path: String) -> Dictionary:
	return _read_state((load(path) as PackedScene).get_state())


static func _read_state(state: SceneState) -> Dictionary:
	var nodes: Dictionary = {}
	for i in range(state.get_node_count()):
		var node_path: String = String(state.get_node_path(i))
		var entry: Dictionary = {
			"transform": Transform3D.IDENTITY,
			"has_script": false,
			"shape": null,
			"mesh": null,
			# Non-null for instanced sub-scenes — including every imported .glb asset.
			"instance": state.get_node_instance(i),
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
				"mesh":
					entry["mesh"] = value
		nodes[node_path] = entry
	return nodes


## Composes a node's transform down from the scene root by multiplication. Exact, unlike
## reconstructing from euler angles — that basis-convention trap caused the steed-facing bug.
static func global_of(nodes: Dictionary, path: String) -> Transform3D:
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


## World-space AABB of a node's visible geometry, resolving (in order):
##   1. the node's own inline `mesh`               — graybox MeshInstance3D
##   2. an instanced PackedScene                    — imported .glb art
##   3. a conventional "Mesh" child                 — StaticBody3D pieces
##
## Returns a ZERO-SIZE AABB when nothing is measurable. Callers must treat that as a failure:
## silently skipping is how this guard would stop guarding during the art pass.
##
## Note the AABB's own `position` is honoured rather than assuming the mesh is centred on its
## node. Primitives are centred so this is a no-op for graybox, but imported assets are authored
## base-pivoted (origin at the feet), where assuming centred is wrong by half the height.
static func body_box(nodes: Dictionary, path: String) -> AABB:
	if not nodes.has(path):
		return AABB()
	var entry: Dictionary = nodes[path]

	if entry["mesh"] != null:
		return global_of(nodes, path) * (entry["mesh"] as Mesh).get_aabb()

	if entry["instance"] != null:
		var local: AABB = packed_scene_box(entry["instance"] as PackedScene)
		if local.size != Vector3.ZERO:
			return global_of(nodes, path) * local

	if nodes.has(path + "/Mesh"):
		return body_box(nodes, path + "/Mesh")

	return AABB()


## Union of every mesh inside a PackedScene, in that scene's own local space. This is what makes
## an imported .glb measurable — its geometry is several MeshInstance3D nodes in a separate file.
static func packed_scene_box(packed: PackedScene, depth: int = 0) -> AABB:
	if packed == null or depth > 4:
		return AABB()
	var sub: Dictionary = _read_state(packed.get_state())
	var acc: AABB = AABB()
	var found: bool = false

	for node_path: String in sub:
		var entry: Dictionary = sub[node_path]
		var box: AABB = AABB()

		if entry["mesh"] != null:
			box = global_of(sub, node_path) * (entry["mesh"] as Mesh).get_aabb()
		elif entry["instance"] != null:
			var nested: AABB = packed_scene_box(entry["instance"] as PackedScene, depth + 1)
			if nested.size == Vector3.ZERO:
				continue
			box = global_of(sub, node_path) * nested
		else:
			continue

		acc = box if not found else acc.merge(box)
		found = true

	return acc if found else AABB()


## World-space AABB of a node's "Trigger" child, or a zero-size AABB if it has no box trigger.
static func trigger_box(nodes: Dictionary, path: String) -> AABB:
	var trigger_path: String = path + "/Trigger"
	if not nodes.has(trigger_path):
		return AABB()
	var shape: Variant = (nodes[trigger_path] as Dictionary)["shape"]
	if not shape is BoxShape3D:
		return AABB()
	var extents: Vector3 = (shape as BoxShape3D).size * 0.5
	var centre: Vector3 = global_of(nodes, trigger_path).origin
	return AABB(centre - extents, extents * 2.0)
