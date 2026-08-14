---
name: godot-asset-pack-integration
description: >-
  Drop third-party art (a Quaternius/KayKit/Kenney-style pack, or any imported .glb)
  into this project's hand-authored graybox scenes without breaking the playable space.
  Use this WHENEVER the task involves swapping a graybox MeshInstance3D for real art,
  placing an imported model in a zone, picking or evaluating an asset pack, or debugging
  imported art that is the wrong size, floating, sunk, facing backwards, white/untextured,
  T-posing, or that the player clips through.

  Encodes the failure modes that produce a VALID asset which is visibly wrong — none of
  them raise an error — plus the measure-don't-assume rules for scale, pivot, facing and
  centring, and the rule that growing one building displaces its neighbours, the player's
  walkable routes, and its own interaction trigger.
---

# Integrating a third-party asset pack

## The thing to internalise first
Every failure in this file produces a **valid asset that imports without error**. The `.glb`
is well-formed, the material names survive, the tests pass, and the model is silently wrong.
So **measure everything; assume nothing** — and prefer a numeric check in a throwaway probe
script over looking at it, because half of these are invisible from the wrong camera angle.

The one thing you cannot measure is **how it looks**. That stays human-verified (CLAUDE.md).

---

## 1. Pack scale — measure it, never guess

Packs are authored at wildly different scales, **including two packs by the same artist**:

| Pack | Needed scale | How it was determined |
|---|---|---|
| Quaternius Medieval Village | **1.8×** | at 1.8 the stable (8.46 × 4.48 × 5.99), bell tower (3.49 × 8.57 × 4.01) and mill all landed on their graybox envelopes — three independent matches |
| Quaternius Stylized Nature | **1.0×** | authored 1:1 — a 9.44 m broadleaf, 8.72 m pine, 13.28 m dead tree are plausible real heights |
| Quaternius RPG Characters | **0.687×** | 2.911 m to the top of the head vs the project's 2.0 m spec |

**Method:** measure the imported AABB, compare against something whose real size you know
(a graybox envelope, or the 2.0 m player). Look for two or three independent agreements before
committing — one match is a coincidence, three is the pack's scale.

**Weapons and props inflate a character's bounding box.** The Warrior measured 3.406 m raw but
2.914 m of body — the rest was a sword. Deriving a per-character scale from raw bounds gives a
cast of different heights. Measure one character properly, then apply that factor to all of them.

**Scale characters at IMPORT** (`nodes/root_scale` in the `.import`), not on the instance node.
A scaled instance leaves stride length in the original units and reintroduces foot-slide.

---

## 2. Pivots — imported art is base-pivoted, this project's nodes are centre-pivoted

This mismatch has bitten on every single character and building:

- `player.tscn`'s `CapsuleShape3D` height 2.0 is **centred on the body origin**, so the player's
  origin sits **1.0 m above the ground** (`test_village_boundaries.gd:27` depends on this).
- NPC `Area3D`s sit at `y = 1` for the same reason.
- Imported characters and buildings are **feet/base-pivoted**.

⇒ Mount imported art with a **negative Y offset equal to the node's height above ground**
(`-1` for the player and NPCs, `-2` for a `StaticBody3D` at y=2, `-4.5` at y=4.5). Without it the
model floats exactly that far in the air.

The offset is in the PARENT's space, so it survives a rescale unchanged.

---

## 3. Facing — a bounding box cannot tell you which way a model faces

**This was got wrong twice.** Do not repeat it:

- The Warrior's AABB extended further in −Z, which read as "the face points −Z". It was the
  **helmet tail behind the head**. He walked backwards until a human looked at him.
- house_2's doorway was located by ray-casting (a real 1.70-wide recess on its +Z face), and the
  houses were still rotated backwards — the probe found *where an opening was*, not *which way
  the model considers front*.

**Ray-casting DOES reliably find an opening** (see §7), which is enough to align collision with
art. It is not enough to decide facing. Rotate, then have a human confirm, and leave a comment
naming the exact edit to flip it 180°.

---

## 4. Art is not necessarily centred on its own origin

Measured in this project: `house_2`'s visual sat **1.05 m** off its node, the stable **2.35 m**.
Scaling multiplies the error. The symptom is the player walking through a visible wall on one
side and hitting an invisible one on the other.

**Check:** compare the instanced art's world AABB centre against the node's origin. Correct with
an X/Z offset on the *Mesh* node, not by moving the parent (the parent's position is what every
trigger, spawn and test refers to).

---

## 5. Collision: refit by hand, never derive from the art

ROADMAP's rule is "art swaps touch `MeshInstance3D` only, never `CollisionShape3D`". What that
rule actually guards is collision **derived from art meshes** — auto-generated trimesh collision
is what brings back the capsule seam-freeze (`godot-multisegment-terrain`). Hand-resizing a
`BoxShape3D` to match new art is still hand-authored primitives and is the correct fix when the
art's proportions differ from the graybox. Flag it; don't do it silently.

**Keep openings open.** The stable's graybox was deliberately open at the front, with
`StableInteract` *inside* the footprint. Collapsing it to one tidy box would have sealed the
front and made "Greet your steed" physically unreachable — the visible-but-unusable class
(`godot-playable-space-audit`). Before simplifying collision, check what sits inside it.

**Match the opening to the art.** The stable model opens −X while its inherited collision opened
+Z, so the player walked through a visible wall and was blocked across the real opening. Find the
opening by ray-cast, then build collision to agree with it.

---

## 6. Growing a building is never only a scale change

Scaling the guard tower 1.8 → 4.0 displaced, in order:

1. **A neighbour** — its collision overlapped Home2's, so the tower moved.
2. **A walkable route** — the new position put it a metre from the west barrier, and
   `test_village_boundaries` failed instantly: its west run starts the player at x = −18, now
   *inside* the tower, so the player was ejected through the barrier and fell to y = −80.
3. **Its own entrance** — `TowerInteract` ended up inside the tower's collision, making "Enter
   the tower" unreachable.

After any rescale or reposition, re-check: neighbour overlaps, the boundary tests' start
positions, every interaction trigger that belongs to the building, and any scatter keep-out
rectangles that referenced the old footprint.

---

## 7. Finding a model's opening (doorway) by ray-cast

Per-material centroids are useless here — pack materials wrap the whole building, so every
centroid sits at the origin. "Does the ray hit anything" is also useless: a ray through a doorway
still hits the far wall, so every face scores identically and you are measuring the silhouette.

**Measure distance to FIRST hit.** A wall stops the ray at the near face; a doorway lets it
through to the far one. Fire a fan of rays at door height across each face, take the median
first-hit distance as the wall, and count samples significantly deeper than it.

```gdscript
func _first_hit(tris: PackedVector3Array, from: Vector3, dir: Vector3) -> float:
    var best := -1.0
    for i in range(0, tris.size(), 3):
        var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, tris[i], tris[i+1], tris[i+2])
        if hit == null:
            continue
        var d: float = from.distance_to(hit as Vector3)
        if best < 0.0 or d < best:
            best = d
    return best
```

Collect triangles with `mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]` + `ARRAY_INDEX`, transformed
by each `MeshInstance3D.global_transform`.

⚠️ When sweeping upward to find a doorway's HEIGHT, seed the reference wall distance from a ray
**off** the door (near the face edge). Seeding it from a ray that goes through the doorway makes
every later ray look flush and reports a height of zero.

---

## 8. Keep the swapped child named `Mesh`

`tests/helpers/scene_geometry.gd` resolves a body through its `Mesh` child. Renaming it during a
swap makes `test_interaction_alignment` **silently skip** that interactable — it stays green while
covering nothing. Instance the art as `[node name="Mesh" parent="..." instance=ExtResource(...)]`.

---

## 9. Verification probe worth re-writing each time

A temporary `SceneTree` script under `tools/` that loads the real zone and prints:

- every building's visual world AABB vs its node origin (catches §4)
- pairwise x/z overlaps between buildings (catches §6.1)
- whether each interaction trigger is inside its own building's footprint (catches §6.3)
- any prop-vs-character contact you care about (e.g. hips vs a bench seat)

Delete it once the numbers are right. Do not leave probes in `tools/` — and delete the `.uid`
Godot generates beside them, or it gets committed on its own.

---

## Checklist for one asset swap
1. Import; measure AABB; derive scale from a known reference (§1).
2. Mount with the right negative Y offset (§2).
3. Check the art is centred on its node; offset the Mesh if not (§4).
4. Ray-cast for the opening; make collision agree (§5, §7).
5. Refit collision by hand to the new proportions; keep openings open (§5).
6. Re-check neighbours, boundary-test start positions, triggers, scatter keep-outs (§6).
7. Keep the node named `Mesh` (§8).
8. Run GUT + a headless boot; then have a human look at it for facing and style (§3).
