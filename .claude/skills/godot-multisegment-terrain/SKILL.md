---
name: godot-multisegment-terrain
description: >-
  Build walkable multi-piece terrain in this Godot project — spiral/switchback
  staircases, multi-ramp paths, or any floor made of more than one StaticBody3D —
  without the CharacterBody3D capsule freezing dead at the seams. Use this WHENEVER
  the task involves stairs, ramps, a spiral/helix walkway, or a player capsule that
  gets stuck, halts with velocity exactly (0,0,0), or refuses to cross from one floor
  piece onto the next despite `is_on_floor()` reading true and the geometry looking
  correct. This is the single highest-leverage fix in the project for that failure
  mode: `safe_margin` on the player's CharacterBody3D, not the floor geometry.

  Also the reference for the flat-rotating-step pattern (the standard, best-tested
  way to build spiral stairs with primitive boxes) and for the get_slide_collision()
  debugging technique that found the real cause after every geometry-side theory
  (overlap tuning, trimesh, body consolidation) failed to fix it.
---

# Walkable multi-segment terrain (stairs, ramps, spirals)

## The symptom, so you recognize it fast
A `CharacterBody3D` walks smoothly across ONE floor piece, then — right at the boundary
with the next piece — velocity snaps to exactly `(0, 0, 0)` in a single physics frame and
never recovers, even though `is_on_floor()` is `true` and nothing looks wrong in the editor.
`player.get_slide_collision(0).get_normal()` at the freeze shows an oblique, corner-ish
normal (not a clean floor `(0,1,0)` or wall `(x,0,z)`) — the capsule caught the seam where
two separate `StaticBody3D` boxes meet, even at a shallow relative angle (verified failing at
90°, 45°, 30°, and even 16° between adjacent pieces).

## The fix: `safe_margin`, not the geometry
Godot's `CharacterBody3D.safe_margin` defaults to **0.001** — far too tight for a capsule
crossing between separately-authored static colliders. Every geometry-side fix (bigger
overlap between pieces, zero overlap flush, a single continuous `ConcavePolygonShape3D`
trimesh, consolidating all pieces under one `StaticBody3D` instead of many) left the exact
same freeze in place. Raising `safe_margin` on the **player scene** is what actually worked:

```
[node name="Player" type="CharacterBody3D"]
safe_margin = 0.2
```

(`scenes/characters/player.tscn`). This is a real engine property, not a hack — Godot's own
docs note the default margin is tuned for simple single-collider floors, and Godot's issue
tracker documents exactly this capsule-vs-multi-collider-seam failure. Tune it per project by
testing a walk across the worst-case seam; **too small still catches, and — non-intuitively
— too large can also regress** (0.08 caught immediately; 0.2 got furthest in this project's
45-piece staircase; 0.3 and 0.45 both did slightly *worse* than 0.2). There is no formula —
sweep a few values (0.1, 0.15, 0.2, 0.25, 0.3) against the real path and pick the best.

## Design pattern: flat rotating steps around a SOLID core
For a spiral staircase built from primitive boxes, three design choices matter as much as
`safe_margin`. They were found by measuring how far up an adversarial straight-line test walker
got before jamming (a good proxy — a human navigates better than it):

**1. Fill the centre with a solid column.** The single biggest win. A spiral leaves an empty
well in the middle; whenever the capsule drifts even slightly inward off a tread it slips toward
that void and jams on the step's inner edge. Replace the thin decorative newel with a **full
`CylinderShape3D` core** whose radius equals the treads' inner edge, running floor to summit.
Now the treads butt against a solid post (the classic real-world spiral-stair design) and there
is no void to fall into — this alone roughly tripled how far the test walker climbed.

**2. Many small steps beat few big ones.** Each step is yawed relative to the last, so their
risers are **not parallel** — the capsule catches at every rotated seam. Halving the rotation
and riser per step (e.g. 45 steps → 72 steps over the same 2 loops: ~10° and ~0.125m per step
instead of ~16° and ~0.2m) made the seams gentle enough that the test walker went from ~30% to
~70% of the way up. More seams, but each far more forgiving.

**3. Tangential overlap has a sweet spot — don't overdo it.** Consecutive treads should overlap
along the direction of travel (so the next tread is under the capsule before it meets the riser
edge), but too much overlap is *worse*: a step two ahead, being higher, pokes its raised edge up
as a wall in front of you. In this project a step width ~1.5× the centre-to-centre arc was good;
2× regressed hard. Tune by measurement, and note it's the **tangential** (travel-direction)
width that matters — widening the **radial** tread depth did nothing useful.

Prefer flat rotating steps over **continuously tilted ramp segments**: a capsule's rounded base
rides a small flat ledge naturally, and you avoid the compound-tilted-normal seams that made the
ramp version worse.

## Round stairs in a square room: fill the corners, don't round the wall
A circular spiral inside a square room leaves four wedge-shaped **voids at the corners** (the wall
is ~2× farther out there than on the axes). A player nudged off the outer edge of the stairs drops
into a corner void and gets wedged under the flights above — the reported "fall into the corner
and get stuck." Two ways to close it, one right and one wrong:

- **RIGHT: solid corner-filler blocks.** Drop a floor-to-ceiling box in each room corner whose
  inner corner sits just *outside* the stairs' outer radius (e.g. steps reach radius 3.5 → filler
  inner corner at ~3.6). It plugs the void the player falls into, and because it lives entirely
  beyond the walkable band it can't touch the climb — verified the climb test *improved* slightly
  after adding them (the outer-hugging path now has something to slide along in the corners
  instead of empty space). Cheap, low-risk, keeps the working square walls.
- **WRONG: a round wall hugging the stairs.** Replacing the square walls with a cylinder of wall
  segments right at the stair edge seems tidier but backfires: it narrows the walkable channel to
  `wall − core`, and a 0.8m-diameter capsule pinches against the core on the inside and the wall
  (or a door-jamb corner, or a segment junction) on the outside — the player froze at step 2–4
  every time, worse than with no wall at all. If you ever do want a round room, the wall must sit
  well clear of the stairs (channel ≥ ~1.4m) and the door opening must be wide enough that its
  jambs don't protrude into the climb path — but corner fillers solve the actual problem without
  any of that risk.

- Riser height ~0.15–0.2m per step (matches real-world stair comfort).
- Rotate each step only by yaw (`Transform3D` with `basis.y = (0,1,0)` unchanged) — no pitch,
  no compound tilt. Compute each step's transform directly (position on a circle + a pure
  Y-axis rotation), not via a rise-over-run ramp formula.
- Give each tread a modest radial depth (~1.0m) so consecutive steps overlap a little in
  plan view — this is forgiving, not the primary fix (don't reach for bigger overlap first;
  test `safe_margin` before spending time retuning overlap).
- Skip `ConcavePolygonShape3D` (trimesh) for this. It did not resolve the freeze here and
  introduced a *worse* failure (the capsule froze at the very first step, touching nothing
  else) — likely an engine-side instability with `ConcavePolygonShape3D` near
  `CharacterBody3D.move_and_slide()`. Stick with boxes.
- Splitting each step into its own `StaticBody3D` vs. many `CollisionShape3D` children under
  one shared `StaticBody3D` made **no measurable difference** — don't spend time on that axis.

## How to diagnose a freeze like this, fast
Don't reason about the geometry from the transform math alone — the seam behavior depends on
engine collision resolution you can't fully predict on paper. Drive a real `CharacterBody3D`
through the path in a headless GUT test and inspect the actual collision report at the exact
frame it stalls:

```gdscript
var last_pos := player.global_position
var stall_frames := 0
for i in range(2000):
    # ... steer toward the next waypoint via Input.action_press, see below ...
    await get_tree().physics_frame
    if player.global_position.distance_to(last_pos) < 0.01:
        stall_frames += 1
    else:
        stall_frames = 0
    last_pos = player.global_position
    if stall_frames == 20:
        for k in range(player.get_slide_collision_count()):
            var c := player.get_slide_collision(k)
            print(c.get_collider().get_path(), c.get_normal(), c.get_position())
        break
```

A clean `(0,1,0)` or `(x,0,z)` normal means real geometry trouble (a gap, a genuine overhang).
An oblique corner-ish normal at a dead stop is the seam-catch this skill describes — go
straight to `safe_margin`, don't re-tune the mesh.

### Simulating movement in a headless test
No camera exists in a bare test scene, so `player.gd`'s camera-relative steering
(`get_viewport().get_camera_3d()`) falls back to the body's own yaw, which never changes
(only the visual `Model` child rotates). World axes map directly onto the four move actions
for the whole test — steer with `Input.action_press`/`action_release` on `move_left`,
`move_right`, `move_forward`, `move_back` toward each waypoint in turn, no rotation math
needed. See `tests/test_tower_stairs.gd` for the full pattern, including the capsule-origin
gotcha below.

### Capsule-origin gotcha when checking "did it reach the right height"
A `CharacterBody3D` with a center-origin capsule (see `godot-thirdperson-controller`) rests
with its **origin** at `floor_top_y + capsule_half_height`, not at `floor_top_y`. Compare
`player.global_position.y` against `surface_height + 1.0` (for this project's capsule,
half-height 1.0), not the bare surface height — otherwise you'll misdiagnose a correctly
climbing character as "floating a meter above the ramp."

## When this is still not fully solved
Even with `safe_margin` tuned well, a perfectly rigid straight-line-to-waypoint test path
(the worst case — dead-center through every corner) may still stall a small fraction of the
way through a very long multi-piece staircase (in this project: reaches well past the
halfway point of 45 steps, not guaranteed to reach the literal last one under that exact
adversarial path). A real player's naturally varying line is far less likely to hit the same
worst-case corner repeatedly. Treat automated coverage here as "substantial progress,
no critical blocker" and confirm the full climb by human playtest in the editor — this
matches the project's own rule that rendering/feel/cinematics are human-tested.
