---
name: blender-glb-export
description: >-
  Convert Blender files to Godot-ready .glb from the command line in this project, using
  tools/blender/export_glb.py. Use this WHENEVER the task involves Blender, exporting or
  converting a .blend/.fbx to .glb, an asset pack that ships .blend files, authoring geometry
  programmatically, or debugging imported models that render PURE WHITE with no textures.

  Leads with the white-material bug, because it is the highest-cost trap here: the export
  succeeds, the .glb is valid, every material name survives, and the models are blank — and the
  two obvious fixes both fail SILENTLY. Also covers the sRGB/linear conversion that silently
  brightens every asset ~10x, texture import settings Godot gets wrong by default, and two
  file-format traps (a UTF-8 BOM and a miscounted Transform3D) that make Godot hang or
  misreport rather than error.
---

# Blender → .glb for this project

## Setup facts
- **Blender 5.2.0 LTS**, `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
  **Not on PATH** — invoke by full path.
- It is **NOT a build dependency**. Nothing in the Godot project, the test suite or an export
  needs Blender; it produces `.glb` files that are committed, and the game builds from those.
- `assets/source/.gdignore` is **load-bearing** now that Blender exists: Godot's direct `.blend`
  import would otherwise *succeed* on this machine via an editor-only, machine-specific
  `blender_path`, and fail for every other clone and any headless run.

```powershell
$BLENDER = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $BLENDER -b <in.blend> -P tools/blender/export_glb.py -- <out.glb> [--palette]
& $BLENDER --background --factory-startup --python <script.py> -- <args>   # authoring
```

`tools/blender/export_glb.py` is the single authority on export settings (GLB, +Y up, apply
modifiers, no cameras/lights, no Draco) and hard-fails if the scene's unit scale isn't 1 m.

---

## 1. THE WHITE-MODEL BUG — read this before debugging textures

**Symptom:** imported models render pure white. No error anywhere. The `.glb` is valid, every
material name is correct, the mesh has UVs.

**Cause is not missing textures.** Pack materials often carry **two `Material Output` nodes plus
a stray `Diffuse BSDF`** (and frame nodes). Blender renders that fine; Godot's glTF exporter
can't make sense of it and silently emits a **default material**. The exported JSON is literally:

```json
{ "doubleSided": true, "name": "Plaster" }
```

— no `pbrMetallicRoughness` at all — while the real colours sit unused on the Principled node.

**Two narrower fixes that FAIL SILENTLY.** Do not retry them:
- Writing `bsdf.inputs["Base Color"].default_value` — ignored when the socket is **linked**. The
  re-export comes out byte-for-byte identical, which is a very confusing "no change".
- Re-pointing the active `Material Output` — the graphs vary too much; it fixed 1 material of 9.

**The fix that works: rebuild the material.** Read the colour off the existing Principled, clear
the node tree, and create one Principled wired to one active output. That is the only shape the
exporter reliably understands. Implemented as `rebuild_materials()` in `export_glb.py`, and it
runs on **every** export, not just palette ones.

**Diagnose it in one command** — dump the material JSON rather than trusting the material list:

```powershell
$b = [IO.File]::ReadAllBytes($glb); $len = [BitConverter]::ToUInt32($b,12)
$j = [Text.Encoding]::UTF8.GetString($b,20,$len) | ConvertFrom-Json
$j.materials[0] | ConvertTo-Json -Depth 6
```

If you see only `doubleSided` and `name`, it is this bug.

---

## 2. sRGB vs linear — the ~10× brightness trap

- **Godot `albedo_color` is sRGB.**
- **Blender's Base Color and glTF's `baseColorFactor` are LINEAR.**

The importer converts correctly in that direction, so a Blender material round-trips to the right
on-screen colour. The trap is the other way: copying this project's palette decimals
(`docs/ART_PIPELINE.md` §4) into Blender renders assets **about ten times too bright**.

- In the Blender GUI, use the colour picker's **HEX** field — it converts for you. §4 has a hex
  column for exactly this.
- In a script, convert explicitly:

```python
def srgb_hex_to_linear(hexcode):
    out = []
    for i in (0, 2, 4):
        c = int(hexcode[i:i+2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)
```

*Measured:* Blender linear `0.25` → Godot `albedo_color 0.5371` (`1.055 × 0.25^(1/2.4) − 0.055`).

`export_glb.py --palette` re-skins a pack's semantically-named materials (`Plaster`, `RoofTiles`,
`Stone`, `Windows`, `Bell`…) onto this project's palette. Not used by default — the 2026-08-14
decision was to accept the pack's own art direction — but it is the escape hatch if a pack's
colours fight the established hearth-gold identity.

---

## 3. Import settings Godot gets wrong by default

`.import` sidecars are plain text and committed. Godot rewrites them on import and **strips your
comments**, so record reasoning in the scene or commit message, not the sidecar.

| Setting | Default | Set it to | Why |
|---|---|---|---|
| `mipmaps/generate` | `false` | `true` | a ground tiled 22× shimmers badly at distance without them |
| `compress/normal_map` | `0` (Detect) | `1` (Enable) | Detect guesses wrong; normal maps pack differently |
| `nodes/root_scale` | `1.0` | measured | scale characters here, not on the instance node |
| `_subresources` | `{}` | per-clip `settings/loop_mode: 1` | many packs import every clip `loop_mode=0`, so an idle plays once and freezes mid-stride |

```
_subresources={
"animations": {
"Idle": {
"settings/loop_mode": 1
}
}
}
```

⚠️ **Godot writes `.import` sidecars asynchronously.** Running the test suite before the import
settles produces failures with nothing to do with your change — in this project it looked like
"Elder has no Trigger and no Mesh". Let `--import` finish, confirm the sidecar exists, then test.

---

## 4. Two file-format traps that don't error

**UTF-8 BOM breaks `.tscn`.** PowerShell 5.1's `Set-Content -Encoding utf8` writes a BOM, and
Godot rejects the file with `line 1 Parse Error: Expected '['` — baffling for a file whose line 1
is obviously correct. Write generated scenes BOM-less:

```powershell
[IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
```

**A `Transform3D` with the wrong argument count makes Godot HANG, not error.** Thirteen arguments
instead of twelve produced no parse error and no message — the headless run simply never
returned. Validate after hand-editing scenes:

```powershell
Select-String -Path <scene>.tscn -Pattern 'transform = Transform3D\(([^)]*)\)' | ForEach-Object {
  $n = ($_.Matches[0].Groups[1].Value -split ',').Count
  if ($n -ne 12) { "LINE $($_.LineNumber): $n args" } }
```

**Bracketed paths break PowerShell cmdlets.** Pack zips are often named `Something[Standard].zip`;
`[` and `]` are wildcards, so `Copy-Item`/`Expand-Archive`/`Get-ChildItem` silently match nothing
— `Copy-Item` even reports success. Use `-LiteralPath` for every one of them.

---

## 5. Authoring geometry from a script

Fully supported and preferable to a hand-modelled `.blend` where the shape is parametric: the
script is plain text, diffable and reproducible, which is closer to CLAUDE.md's core rule than a
binary ever gets. `tools/blender/author_home.py` is the worked example (a spec-exact house built
from `from_pydata` boxes with named material slots).

Conventions when authoring:
- **1 unit = 1 metre**; the exporter enforces it.
- **Base-pivoted**: apply location so geometry sits 0→h above the origin.
- **Blender is Z-up; glTF/Godot are Y-up.** The exporter's `export_yup` handles it in the vertex
  data with **no baked rotation** on the node — verified. But it means **Blender −Y becomes Godot
  +Z**, so a front face must be authored on −Y.
- `bpy.ops.object.shade_flat()` / `poly.use_smooth = False` for the flat-shaded style.
- Don't model collision; it stays hand-authored primitives in Godot.
