# assets/ — binary art assets

Added 2026-08-12 (Milestone 2, Phase 0). Permitted under the scoped amendment to
CLAUDE.md's plain-text rule; see `docs/ART_PIPELINE.md` for the full pipeline.

```
assets/
  models/     # .glb — the assets Godot imports. Committed via Git LFS.
  source/     # .blend working files. LFS'd, and HIDDEN FROM GODOT (.gdignore).
```

## The rules that matter

- **Format is glTF 2.0 `.glb`.** One file carries mesh + materials + animations.
- **Export `.glb` from Blender and commit that — do not rely on Godot importing
  `.blend` directly.** Direct `.blend` import makes Godot shell out to Blender via
  an *editor-only, machine-specific* setting (`filesystem/import/blender/blender_path`),
  which breaks the reproducibility rule and any headless/CI run. `.glb` imports with
  no external dependency at all.
- **`assets/source/` contains a `.gdignore`** so Godot never tries to import the
  `.blend` files. **Since Blender was installed (2026-08-13) this file is
  load-bearing:** the direct-`.blend` conversion now *succeeds* on this machine
  instead of failing, so nothing but `.gdignore` stops a machine-specific import
  path sneaking in that would break every other clone and any headless run.
  Verified holding 2026-08-13. Do not delete that file.
- **`.import` sidecars are plain text and ARE committed.** They carry the import
  settings, so an art swap stays reproducible even though the asset is binary.
- **Swaps touch `MeshInstance3D` only — NEVER `CollisionShape3D`.** Collision is
  hand-authored primitives and stays that way. Deriving collision from art meshes
  is how the capsule seam-freeze bug class comes back (see `godot-multisegment-terrain`).

## Spec (full sheet in docs/ART_PIPELINE.md §4)

| Spec | Value |
|---|---|
| Units | 1 unit = 1 metre |
| Up / forward | Y-up, −Z forward |
| Character height | 2.0 m, pivot at the feet, centred |
| Collision | do NOT supply |
| Style | **low-poly flat-shaded** (decided 2026-08-12) |

The palette is already established by the shipped materials — hearth gold against
the shore's cold desaturation. `docs/ART_PIPELINE.md` §4 lists all 12 values.
Honour it rather than replacing it.

⚠️ **Enter palette colours in Blender via the HEX field, not the decimal values.**
Godot's `albedo_color` is sRGB; Blender's Base Color is linear. Typing the decimal
numbers in makes assets render ~10× too bright. §4 has a hex column; §10 has the
full explanation and the measured proof.
