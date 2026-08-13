# Art brief — Village Home (M2 Phase 2, first building type)

The first real asset. Everything here is measured off the existing graybox in
`scenes/zones/zone_01_village.tscn`, so a model built to this spec drops in without
moving anything else. Two homes use it: `Geometry/Home1` and `Geometry/Home2`.

**Deliver:** `assets/source/home.blend` → exported to `assets/models/home.glb`.

---

## Dimensions (metres — 1 Blender unit = 1 m)

Build it **base-pivoted**: origin at `(0, 0, 0)`, geometry sitting entirely above it.
The graybox is centre-pivoted, so I adjust the transform on integration — you don't
need to compensate.

| Part | Size | Sits at (height above ground) |
|---|---|---|
| Wall body | **6.0 × 6.0** footprint, **4.0** tall | 0.0 → 4.0 |
| Roof | **6.6 × 6.6** (0.3 m eave overhang all round), **1.2** tall | 4.0 → 5.2 |
| Door | **1.2 wide × 2.0 tall** | 0.0 → 2.0, centred on the front face |
| Windows ×2 | **0.9 × 0.9** | 1.75 → 2.65, at **x = ±1.6** on the front face |

**Total height 5.2 m.** Footprint 6 × 6 with a 6.6 × 6.6 roof.

The 2.0 m door height is a project-wide spec (`ART_PIPELINE.md` §4) — it matches the
player capsule. Keep it even if you restyle the door.

### Which way is "front"
The front face (door + both windows) must end up facing **Godot +Z**.

⚠️ **In Blender that means the door faces −Y.** glTF's +Y-up conversion maps
Blender `(x, y, z)` → glTF `(x, z, −y)`, so Blender −Y becomes Godot +Z. Getting this
backwards puts both homes' doors facing away from the village path.

*Check after export:* the door should be on the **+Z** side. I verify this on integration.

---

## Materials — 4 slots, named exactly

Give the mesh **four material slots**. They come through as four surfaces, which lets me
re-apply Godot-side properties (the window glow) per surface without splitting the model.

| Slot name | **Blender hex** | Notes |
|---|---|---|
| `WallMat` | `B89E80` | warm plaster/daub |
| `RoofMat` | `80574D` | weathered tile |
| `DoorMat` | `4D3321` | dark timber |
| `WindowMat` | `26334D` | dark glass — **I add the emissive glow in Godot**, don't bake it |

🔴 **Enter these via Blender's HEX field, not by typing decimals into Base Color.**
Godot's `albedo_color` is sRGB; Blender's Base Color is linear. Typing decimal palette
values renders ~10× too bright. This is the trap Phase 1 caught — see `ART_PIPELINE.md` §10.

The windows currently glow warm at golden hour (`emission 808C59`, energy 0.6) and that
glow is part of the village's established mood. **Leave it to me** — authored emission
through glTF is harder to tune than a Godot material property.

---

## Style and constraints

- **Low-poly, flat-shaded.** The M2 style decision. Use *Shade Flat*; no smoothing groups.
- **No UV unwrapping, no textures.** Flat colour per material slot only. This is deliberate —
  it's why low-poly was chosen (`ROADMAP.md`, M2 decisions).
- **🔴 Do NOT model collision.** No collision proxies, no extra bodies. Collision stays
  hand-authored primitives in Godot. Supplying it is how the capsule seam-freeze bug class
  returns (`godot-multisegment-terrain`). The existing `6 × 4 × 6` box collision is unchanged
  by this swap — meaning **the player still collides with a plain 6×4×6 box**, so keep the
  silhouette close to that. Deep porches or bay windows would let the player clip visually.
- **No cameras, no lights.** Lighting is authored in Godot (pillar #2: mood over fidelity).
  The export script strips these anyway.
- Keep it modest — a handful of hundred triangles is plenty at this style.

## Freedom you do have
Silhouette detail within the 6×6×5.2 envelope: roof pitch, timber framing, a chimney,
window mullions, door planking, slight asymmetry. The measurements above are the
*interface*; the character of the building is yours.

Worth remembering what this zone is for: it's the last ordinary afternoon before
everything changes. Lived-in and warm beats grand.

---

## Export

```powershell
$BLENDER = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $BLENDER -b assets/source/home.blend -P tools/blender/export_glb.py -- assets/models/home.glb
```

Then hand it to me and I'll integrate, verify, and update the tests.

**On integration I check:** base pivot, 6×6×5.2 envelope, door on +Z, 4 surfaces in the
right order, no baked axis rotation, no collision, palette match — then tests + boot.
**You verify how it looks** — that's human-judged by milestone rule; I can't see it.
