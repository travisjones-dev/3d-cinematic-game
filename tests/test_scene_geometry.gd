extends GutTest
## Proves the measurement harness can see IMPORTED art, not just graybox primitives.
##
## Why this test exists: test_interaction_alignment.gd and test_tower_roof.gd are the guards against
## the "visible but unusable" bug class, and both work by measuring geometry read statically out of
## .tscn files. A graybox MeshInstance3D carries its mesh inline, so that reads trivially. An
## imported .glb does not — it is an instanced PackedScene whose geometry lives in another file.
##
## So the M2 art pass has a nasty property: it changes what the guards can SEE. Without this test,
## the first real building would be the thing that discovers whether the guards still work — and the
## failure mode is a silent skip, which looks exactly like a pass.
##
## Measured against `assets/models/smoke_cube.glb`, the Phase 1 pipeline-proof asset: a 1 m cube,
## base-pivoted (origin at the base, geometry 0..1 above it). Its numbers are known exactly, which
## makes it a precise instrument. This is also what earns that file its place in the repo.

const SG := preload("res://tests/helpers/scene_geometry.gd")

const CUBE: String = "res://assets/models/smoke_cube.glb"
const PROBE: String = "res://tests/fixtures/imported_asset_probe.tscn"
## Placement of "Prop" inside the probe fixture.
const PLACED_AT: Vector3 = Vector3(5.0, 0.0, -3.0)
const EPS: float = 0.001

func test_an_imported_glb_can_be_measured_at_all() -> void:
	var packed: PackedScene = load(CUBE) as PackedScene
	assert_not_null(packed, "the Phase 1 reference asset is missing — %s" % CUBE)
	if packed == null:
		return

	var box: AABB = SG.packed_scene_box(packed)
	assert_ne(box.size, Vector3.ZERO,
		"an imported .glb measured as nothing — every AABB-based guard is now blind to art")

	# 1 m cube, base-pivoted. If this drifts, either the asset was re-exported differently or the
	# importer's axis/scale handling changed; both matter more than this test.
	assert_almost_eq(box.size, Vector3.ONE, Vector3.ONE * EPS,
		"imported cube is not 1 m — a scale error in the pipeline")
	assert_almost_eq(box.position, Vector3(-0.5, 0.0, -0.5), Vector3.ONE * EPS,
		"imported cube is not base-pivoted — pivot convention broken (see assets/README.md)")

func test_body_box_resolves_an_instanced_asset_and_its_placement() -> void:
	# The real-world case: an art asset instanced into a zone at some position. body_box() must
	# compose the asset's internal geometry with the placing node's transform.
	var nodes: Dictionary = SG.read_scene(PROBE)
	assert_true(nodes.has("./Prop"), "probe fixture is missing its Prop node")
	if not nodes.has("./Prop"):
		return

	var box: AABB = SG.body_box(nodes, "./Prop")
	assert_ne(box.size, Vector3.ZERO,
		"body_box could not measure an instanced .glb — this is the silent-skip failure mode")
	assert_almost_eq(box.size, Vector3.ONE, Vector3.ONE * EPS, "instanced asset measured at the wrong size")
	assert_almost_eq(box.position, PLACED_AT + Vector3(-0.5, 0.0, -0.5), Vector3.ONE * EPS,
		"instanced asset measured at the wrong place — transform composition is wrong")

func test_base_pivoted_art_is_not_assumed_to_be_centred() -> void:
	# The specific arithmetic bug this harness had to avoid. The old code took only a mesh's SIZE and
	# centred it on the node origin, which is right for centred primitives and wrong for imported
	# art. A base-pivoted 1 m cube placed at y=0 occupies y 0..1, NOT y -0.5..0.5.
	var nodes: Dictionary = SG.read_scene(PROBE)
	var box: AABB = SG.body_box(nodes, "./Prop")

	assert_almost_eq(box.position.y, 0.0, EPS,
		"imported art measured as starting below the ground — the centred-mesh assumption is back")
	assert_almost_eq(box.position.y + box.size.y, 1.0, EPS,
		"imported art measured with the wrong top — the centred-mesh assumption is back")

func test_missing_geometry_reports_as_zero_rather_than_guessing() -> void:
	# The contract every caller relies on: "nothing measurable" is a zero-SIZE AABB, which callers
	# must treat as a failure. If this ever returned a plausible-looking box instead, the guards
	# would pass on art that is not there.
	var nodes: Dictionary = SG.read_scene(PROBE)
	assert_eq(SG.body_box(nodes, "./NoSuchNode").size, Vector3.ZERO,
		"body_box invented geometry for a node that does not exist")
	assert_eq(SG.body_box(nodes, ".").size, Vector3.ZERO,
		"body_box invented geometry for a bare Node3D with no mesh")
