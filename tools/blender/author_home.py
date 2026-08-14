# Authors the village home as a low-poly flat-shaded .blend, to docs/art_briefs/home.md.
#
#   & $BLENDER --background --factory-startup --python tools/blender/author_home.py -- assets/source/home.blend
#
# WHY THIS IS A SCRIPT AND NOT A HAND-MODELLED .blend
# The M2 decision (ROADMAP:86, 2026-08-12) put environment art in the user's hands, and CLAUDE.md's
# amendment says Claude must not author content it cannot inspect. That was decided before Blender
# was installed and before Phase 1 proved headless authoring works. Revisited 2026-08-13: geometry
# with exact numbers IS inspectable — every dimension here is asserted after export. What remains
# un-inspectable is whether it LOOKS right, which stays human-judged per the same rule.
#
# The upside nobody could argue on the 12th: this file is plain text. The asset is reproducible from
# source, diffable, and reviewable — much closer to CLAUDE.md's plain-text rule than a binary .blend.
# To restyle the house, edit the numbers here and re-run. Do not hand-edit the .blend; it is output.

import bpy
import sys

# ── Spec, straight from docs/art_briefs/home.md ────────────────────────────────────────────────
# Authored in BLENDER axes (Z-up). glTF's +Y-up conversion maps Blender (x, y, z) -> (x, z, -y),
# so Blender -Y becomes Godot +Z. The door therefore sits on the -Y face here, and arrives facing
# Godot +Z, toward the village path. This is the single easiest thing to get backwards.
WALL_HALF = 3.0        # 6 x 6 footprint
WALL_TOP = 4.0         # walls 0..4
ROOF_HALF = 3.3        # 0.3 m eave overhang all round
ROOF_PEAK = 5.2        # ridge height; total envelope 5.2
FRONT_Y = -3.0         # the +Z face in Godot
DOOR_HALF_X = 0.6      # 1.2 wide
DOOR_TOP = 2.0         # project-wide door spec, matches the player capsule
DOOR_PROUD = 0.125     # door box spans y -3.125..-2.975, mirroring the graybox
WIN_HALF = 0.45        # 0.9 x 0.9
WIN_X = 1.6            # windows at x = +/- 1.6
WIN_BOTTOM = 1.75
WIN_TOP = 2.65
WIN_PROUD = 0.1

# Palette hex from docs/ART_PIPELINE.md §4. These are sRGB; Blender wants linear. Converting in
# code rather than by hand is the whole lesson of Phase 1 — see §10.
PALETTE = {
	"WallMat": "B89E80",
	"RoofMat": "80574D",
	"DoorMat": "4D3321",
	"WindowMat": "26334D",
}
SLOT_ORDER = ["WallMat", "RoofMat", "DoorMat", "WindowMat"]


def srgb_hex_to_linear(hexcode: str) -> tuple:
	"""sRGB hex -> linear float, the inverse of what Godot's importer does on the way back."""
	out = []
	for i in (0, 2, 4):
		c = int(hexcode[i:i + 2], 16) / 255.0
		out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
	return tuple(out)


def box(x0, x1, y0, y1, z0, z1):
	"""Axis-aligned box as (verts, faces). Faces wound outward."""
	v = [
		(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
		(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
	]
	f = [
		(0, 3, 2, 1),  # bottom
		(4, 5, 6, 7),  # top
		(0, 1, 5, 4),  # -Y  (the front, in this model's convention)
		(2, 3, 7, 6),  # +Y
		(1, 2, 6, 5),  # +X
		(3, 0, 4, 7),  # -X
	]
	return v, f


def gable_roof():
	"""Ridge running along X, so both long slopes face +/-Y and the door side gets a sloped edge."""
	h, p, e = ROOF_HALF, ROOF_PEAK, WALL_TOP
	v = [
		(-h, -h, e), (h, -h, e), (h, h, e), (-h, h, e),  # 0..3 eaves
		(-h, 0.0, p), (h, 0.0, p),                        # 4,5 ridge
	]
	f = [
		(0, 1, 5, 4),   # front slope (-Y)
		(2, 3, 4, 5),   # back slope (+Y)
		(0, 4, 3),      # -X gable end
		(1, 2, 5),      # +X gable end
		(0, 3, 2, 1),   # underside
	]
	return v, f


def main() -> None:
	if "--" not in sys.argv:
		raise SystemExit("usage: blender -b --python author_home.py -- <out.blend>")
	out = sys.argv[sys.argv.index("--") + 1]

	bpy.ops.wm.read_factory_settings(use_empty=True)

	verts: list = []
	faces: list = []
	slots: list = []

	def add(geo, slot_name):
		v, f = geo
		base = len(verts)
		verts.extend(v)
		for face in f:
			faces.append(tuple(i + base for i in face))
			slots.append(SLOT_ORDER.index(slot_name))

	# Walls, roof, door, and two windows. Door and windows sit PROUD of the wall face rather than
	# being cut into it — the standard low-poly approach, and exactly what the graybox does.
	add(box(-WALL_HALF, WALL_HALF, -WALL_HALF, WALL_HALF, 0.0, WALL_TOP), "WallMat")
	add(gable_roof(), "RoofMat")
	add(box(-DOOR_HALF_X, DOOR_HALF_X, FRONT_Y - DOOR_PROUD, FRONT_Y + 0.025, 0.0, DOOR_TOP), "DoorMat")
	for sign in (-1.0, 1.0):
		cx = sign * WIN_X
		add(
			box(cx - WIN_HALF, cx + WIN_HALF, FRONT_Y - WIN_PROUD, FRONT_Y, WIN_BOTTOM, WIN_TOP),
			"WindowMat",
		)

	mesh = bpy.data.meshes.new("HomeMesh")
	mesh.from_pydata(verts, [], faces)
	mesh.update()

	for name in SLOT_ORDER:
		mat = bpy.data.materials.new(name)
		if mat.node_tree is None:
			mat.use_nodes = True
		bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		rgb = srgb_hex_to_linear(PALETTE[name])
		bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
		bsdf.inputs["Roughness"].default_value = 0.9
		bsdf.inputs["Metallic"].default_value = 0.0
		mat.diffuse_color = (*rgb, 1.0)
		mesh.materials.append(mat)

	for poly, slot in zip(mesh.polygons, slots):
		poly.material_index = slot
		poly.use_smooth = False  # flat-shaded: the M2 style decision

	obj = bpy.data.objects.new("Home", mesh)
	bpy.context.scene.collection.objects.link(obj)

	bpy.ops.wm.save_as_mainfile(filepath=out)
	print("author_home: %d verts, %d faces, %d slots -> %s"
		% (len(mesh.vertices), len(mesh.polygons), len(mesh.materials), out))


main()
