---
name: godot-environment-scatter
description: >-
  Populate a zone with many placed props — a forest that hides the edge of the world, grass and
  rocks scattered for life, a treeline, ground cover. Use this WHENEVER the task involves adding
  lots of instances of props to a zone, making a level feel less empty or less obviously bounded,
  "the world visibly ends", repetitive-looking scenery, or generating scene nodes programmatically
  rather than placing them by hand.

  Covers generating .tscn scenes deterministically, the square-vs-circular ring mistake that
  plants trees inside the village, keep-out rectangles that stop scatter swallowing an
  interactable, and why none of it may carry collision.
---

# Scattering props across a zone

## Shape of the solution
Hundreds of placed nodes do not belong in the zone file. Generate **separate scenes**
(`scenes/props/forest_ring.tscn`, `scenes/props/ground_cover.tscn`) and instance each once in the
zone. The zone file stays readable and the scatter can be regenerated without touching it.

Generate with a **fixed-seed LCG**, so re-running produces a byte-identical scene and the diff is
empty unless parameters changed:

```powershell
$script:seed = 20260814
function Rand() {
    $script:seed = ($script:seed * 1103515245 + 12345) % 2147483648
    return $script:seed / 2147483648.0
}
```

Record the seed and parameters in the generated file's header comment, and say that reshaping it
means changing the generator and regenerating — not hand-editing 150 nodes.

---

## 1. ⚠️ Square play area needs SQUARE rings

The mistake that plants a forest inside the village: distributing trees on a **circular** ring of
radius 25 around a play area bounded by **square** barriers at ±21. At the diagonals the ring
falls to x = z = 17.7 — well inside the village.

Walk the square perimeter instead, `t` in [0,1):

```powershell
function SquareRing([double]$t, [double]$r) {
    $t = $t % 1.0
    if ($t -lt 0.25) { return @((-$r + ($t / 0.25) * 2 * $r), -$r) }   # top edge
    if ($t -lt 0.5)  { return @($r, (-$r + (($t - 0.25) / 0.25) * 2 * $r)) }
    if ($t -lt 0.75) { return @(($r - (($t - 0.5) / 0.25) * 2 * $r), $r) }
    return @(-$r, ($r - (($t - 0.75) / 0.25) * 2 * $r))
}
```

Add a **belt-and-braces bounds check** after jitter — `max(|x|,|z|) < limit → skip` — so no amount
of random offset can drop a tree into the play space. Then assert it afterwards:

```powershell
# must print 0
Select-String -Path forest_ring.tscn -Pattern 'Transform3D\(([^)]+)\)' | ForEach-Object {
  $p = $_.Matches[0].Groups[1].Value -split ',\s*'
  if ([Math]::Max([Math]::Abs([double]$p[9]), [Math]::Abs([double]$p[11])) -lt 22.0) { "INSIDE" } }
```

---

## 2. Hiding the edge of the world

A treeline at the barrier still shows the ground ending behind it. Two changes together:

- **Widen the VISUAL ground** (this project: `GroundMesh` 44 → 110 m) while leaving the
  **collision** mesh and the `Barriers` exactly as they were. The playable space and
  `test_village_boundaries` are untouched; the player simply can no longer see the edge.
  Re-tile the material to match (`uv1_scale` 22 → 55 keeps one tile per 2 m).
- **Plant several rings outward** (25 / 31 / 38 / 46) with per-tree jitter, rotation and scale
  variation, so it reads as depth rather than a wall.

**Leave a gap where the story sends the player.** A deliberate opening on the shore side
(x −7…7 beyond z −24) reads as a way out instead of a wall the player is expected to walk into.

---

## 3. Keep-out rectangles are part of the generator, not an afterthought

Scatter must avoid building footprints, paths, every NPC's standing spot, and — most
importantly — **anything the player is meant to find or interact with**. A bush swallowing an
optional discovery is the visible-but-unusable bug class (`godot-playable-space-audit`).

```powershell
$blocked = @(
    @(6.9, 15.1, 5.6, 12.4),     # Home1 (x0,x1,z0,z1)
    @(-2.6, 2.6, -21.0, 21.0),   # the dirt path
    @(-18.0, -15.0, -9.5, -6.5)  # carved heart — keep the discovery clear
)
```

**Regenerate whenever a building moves or is rescaled.** The rectangles reference footprints; a
resized house leaves grass growing inside it. This has needed re-running after every building
change in this project.

---

## 4. No collision on scatter — ever

Trees, grass, bushes, rocks and benches here are **visual only**:

- The player must be able to walk over grass and up to an NPC.
- Collision on a bench can block that NPC's own interaction trigger.
- Scatter colliders are exactly the many-small-static-bodies case that snags the
  `CharacterBody3D` capsule (`godot-multisegment-terrain`).
- The `Barriers` remain the **only** thing bounding the play space
  (`tests/test_village_boundaries.gd:17` documents this).

---

## 5. Variety, cheaply

- **Several source scenes, weighted.** One swapped model still gives N identical trees; three
  variants (broadleaf / pine / twisted, plus dead) at different weights breaks the repetition.
- **Vary Y rotation and scale per instance** (0.85–1.35 for trees, 0.7–1.5 for ground cover).
  Rotation alone does most of the work.
- Build the transform directly — for uniform scale `s` and yaw `θ`:
  `Transform3D(c, 0, -sn, 0, s, 0, sn, 0, c, x, y, z)` where `c = cos(θ)*s`, `sn = sin(θ)*s`.
- Format floats **invariantly** (`v.ToString("0.####", InvariantCulture)`) so a comma-decimal
  locale can't emit a broken `.tscn`.

---

## 6. Writing the file
Write BOM-less UTF-8 — PowerShell 5.1's `Set-Content -Encoding utf8` adds a BOM and Godot rejects
the scene with `line 1 Parse Error: Expected '['`:

```powershell
[IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
```

Then `--import`, run GUT, and boot headlessly. Density and whether it reads as a forest are
human-judged.
