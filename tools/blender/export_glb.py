# Export a .blend to the project's .glb spec — headless, reproducible.
#
# Usage (Blender is NOT on PATH; see docs/ART_PIPELINE.md for the path):
#   & $BLENDER -b assets/source/foo.blend -P tools/blender/export_glb.py -- assets/models/foo.glb
#
# Why a script instead of clicking File > Export in the GUI: CLAUDE.md forbids
# pipeline steps that can't be reproduced or verified without an editor. The
# GUI-equivalent settings are listed in docs/ART_PIPELINE.md so hand-exporting
# stays possible — this file is the authority on what those settings must be.

import bpy
import os
import sys

# ── Optional palette re-skin (--palette) ───────────────────────────────────────────────────────
# The Quaternius village pack ships UV-mapped models whose colour lives in a texture ATLAS. The
# Blends-only download carries no textures, so those materials export with no baseColorFactor and
# no image — i.e. the buildings render pure white.
#
# Rather than chase the pack's atlas, we re-skin its semantically-named materials onto THIS
# PROJECT'S palette (docs/ART_PIPELINE.md §4). That turns a missing-texture problem into a win:
# the buildings end up on the established hearth-gold identity instead of the pack's art
# direction, which is what ART_PIPELINE:113 calls "the central visual tension to protect".
#
# Values are sRGB hex — the same column the palette table uses — converted to linear below,
# because Blender's Base Color is linear. That conversion is the Phase 1 lesson (§10).
PALETTE = {
	# Walls and timber
	"Plaster": "B89E80",      # WallMat — warm plaster/daub
	"Beige": "C9B394",        # lighter plaster, same family
	"Wood": "4D3321",         # DoorMat — dark timber
	"DarkWood": "3A2619",     # darker beam
	"Wood_Side": "6B4F35",    # mid timber
	"Wood_Light": "8A6A45",   # light timber
	# Stone
	"Stone": "8C8F94",        # TowerStoneMat — cold grey stone
	"Stone_Dark": "5E6166",
	"Stone_Light": "A8ABB0",
	# Roofs
	"RoofTiles": "80574D",    # RoofMat — weathered tile
	"RoofTiles_Red": "8E4A3C",
	# Accents
	"Windows": "26334D",      # WindowMat — dark glass
	"Metal": "404047",        # AnvilMat — iron
	"Bell": "DBBD66",         # BannerMat — hearth gold, the village's warm accent
	"Green": "75805C",        # GroundMat — olive-sage
}


def srgb_hex_to_linear(hexcode: str) -> tuple:
	"""sRGB hex -> linear float. Godot's albedo is sRGB; Blender/glTF are linear."""
	out = []
	for i in (0, 2, 4):
		c = int(hexcode[i:i + 2], 16) / 255.0
		out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
	return tuple(out)


def fix_active_output() -> int:
	"""Point every material's ACTIVE Material Output at its Principled BSDF.

	Why this exists — the Quaternius village blends ship each material with TWO
	`Material Output` nodes: one fed by a Principled BSDF (carrying the real colours) and one fed
	by a Diffuse BSDF. The Diffuse-fed output is the ACTIVE one. glTF export follows the active
	output, finds a Diffuse BSDF it cannot express, and emits a default WHITE material — so every
	building imports pure white while the colour sits right there on the unused Principled node.

	The symptom is maddening precisely because nothing errors: the export succeeds, the .glb is
	valid, the material names are all correct, and the models are simply blank.

	Runs on every export, palette or not — a material whose active output is a Diffuse BSDF is
	broken for our purposes regardless.
	"""
	fixed = 0
	for mat in bpy.data.materials:
		if mat.node_tree is None:
			continue
		principled = None
		outputs = []
		for node in mat.node_tree.nodes:
			if node.type == "BSDF_PRINCIPLED" and principled is None:
				principled = node
			elif node.type == "OUTPUT_MATERIAL":
				outputs.append(node)
		if principled is None or not outputs:
			continue

		target = None
		for out in outputs:
			surface = out.inputs.get("Surface")
			if surface is not None and surface.links \
					and surface.links[0].from_node == principled:
				target = out
				break
		if target is None:
			target = outputs[0]
			mat.node_tree.links.new(principled.outputs["BSDF"], target.inputs["Surface"])

		if not target.is_active_output:
			fixed += 1
		for out in outputs:
			out.is_active_output = (out == target)
	return fixed


def rebuild_materials(use_palette: bool) -> None:
	"""Replace each material's node graph with a clean Principled BSDF -> Material Output.

	WHY THIS IS A REBUILD AND NOT AN EDIT — the Quaternius village blends carry, per material,
	TWO `Material Output` nodes, a stray `Diffuse BSDF`, and frame nodes. Blender renders them
	fine; the glTF exporter cannot make sense of them and silently emits a DEFAULT material. The
	exported material JSON is literally `{"doubleSided": true, "name": "Plaster"}` — no
	pbrMetallicRoughness at all — so every building imports pure WHITE.

	Nothing errors. The export succeeds, the .glb is valid, the material names all survive, and
	the models are simply blank. Two narrower fixes were tried first and both failed silently:
	writing `default_value` (ignored on a linked socket) and re-pointing the active output (the
	graphs are inconsistent enough that this did not catch every case).

	Rebuilding is decisive: whatever the pack authored, the exporter is handed one Principled
	BSDF wired to one active output, which is the only shape it reliably understands.

	The pack's OWN colour is preserved by reading it off the existing Principled first — the
	2026-08-14 decision was to accept the pack's art direction. `--palette` overrides that and
	re-skins onto this project's palette instead.
	"""
	unmapped = []
	for mat in bpy.data.materials:
		if mat.node_tree is None:
			mat.use_nodes = True

		# Read whatever colour the pack authored, before discarding the graph.
		existing = (0.8, 0.8, 0.8)
		for node in mat.node_tree.nodes:
			if node.type == "BSDF_PRINCIPLED":
				socket = node.inputs.get("Base Color")
				if socket is not None and not socket.links:
					existing = tuple(socket.default_value)[:3]
				break

		if use_palette:
			if mat.name in PALETTE:
				rgb = srgb_hex_to_linear(PALETTE[mat.name])
			else:
				unmapped.append(mat.name)
				rgb = existing
		else:
			rgb = existing

		mat.node_tree.nodes.clear()
		bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
		out = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
		out.is_active_output = True
		mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

		bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
		bsdf.inputs["Roughness"].default_value = 0.85
		bsdf.inputs["Metallic"].default_value = 0.0
		mat.diffuse_color = (*rgb, 1.0)

	if unmapped:
		print("export_glb: WARNING no palette entry, kept pack colour: %s"
			% ", ".join(sorted(set(unmapped))))


def main() -> None:
	if "--" not in sys.argv:
		raise SystemExit("usage: blender -b <in.blend> -P export_glb.py -- <out.glb> [--palette]")
	argv = sys.argv[sys.argv.index("--") + 1:]
	use_palette = "--palette" in argv
	argv = [a for a in argv if a != "--palette"]
	if len(argv) != 1:
		raise SystemExit("usage: blender -b <in.blend> -P export_glb.py -- <out.glb> [--palette]")

	out = os.path.abspath(argv[0])
	if not out.lower().endswith(".glb"):
		raise SystemExit("output must be .glb (glTF 2.0 binary) — see assets/README.md")
	os.makedirs(os.path.dirname(out), exist_ok=True)

	# Scene must be in metres, 1 unit = 1 m (assets/README.md spec sheet).
	unit = bpy.context.scene.unit_settings
	if unit.system != "NONE" and abs(unit.scale_length - 1.0) > 1e-6:
		raise SystemExit(
			"scene unit scale is %r, expected 1.0 — 1 unit must be 1 metre"
			% unit.scale_length
		)

	rebuild_materials(use_palette)

	bpy.ops.export_scene.gltf(
		filepath=out,
		export_format="GLB",     # one file: mesh + materials + animation
		export_yup=True,         # Blender is Z-up, glTF/Godot are Y-up
		export_apply=True,       # apply modifiers; what you see is what ships
		export_cameras=False,    # scenes own their cameras, not assets
		export_lights=False,     # lighting is authored in Godot (pillar #2)
		export_materials="EXPORT",
		export_draco_mesh_compression_enable=False,  # low-poly: not worth the import cost
	)

	print("export_glb: wrote %s (%d bytes)" % (out, os.path.getsize(out)))


main()
