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


def main() -> None:
	if "--" not in sys.argv:
		raise SystemExit("usage: blender -b <in.blend> -P export_glb.py -- <out.glb>")
	argv = sys.argv[sys.argv.index("--") + 1:]
	if len(argv) != 1:
		raise SystemExit("usage: blender -b <in.blend> -P export_glb.py -- <out.glb>")

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
