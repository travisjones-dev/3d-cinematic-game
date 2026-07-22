# Playtest Fixes Plan (for the next builder)

Fixes from the first village playtest. All are in `scenes/zones/zone_01_village.tscn` unless noted.
Use skills `godot-zone-building`, `godot-scene-authoring`, `godot-interaction-system`. Still graybox —
approximate with primitives + materials (no textures/models; that's a later art pipeline).
After building: `--import`, run GUT (`godot-gut-headless-testing`), boot the game, re-playtest.

Reference — village ground is `BoxMesh(44,0.5,44)` at `(0,-0.25,0)` → playable x/z roughly ±22, top y=0.

---

## 1. Guard tower + Elin (she's unreachable / phased inside)
**Diagnosis:** `GuardTower` StaticBody is at `(-14,4.5,7)` with a `(3.5,9,3.5)` box → it occupies
x[-15.75,-12.25], z[5.25,8.75]. `LoveInterest` is at `(-13,1,8)` — **inside that footprint**, so the
player (who collides with the tower) can't reach her, and she looks embedded.
**Do:**
- Move `NPCs/LoveInterest` to `(-11, 1, 7)` (just east of the tower face, in the open, reachable).
- Move `Interactables/TowerInteract` to ~`(-11.5, 1.5, 6)` (out of the tower footprint).
- Restyle the tower to read as cracked stone: new `StandardMaterial3D` grey stone
  `albedo Color(0.55,0.56,0.58)`, `roughness 0.9`; apply to the tower mesh + cracked top.
  Approximate brick courses with 3–4 stacked box "bands" (slightly varied grey) OR keep one box and
  add a **crack**: a thin dark box `~(0.15, 6, 0.25)`, near-black, rotated a few degrees, laid on the
  +Z face running top-to-bottom. Optionally slim/heighten the tower to `(3,10,3)`.
- (Entering the tower interior is out of slice scope — the fix is making Elin *at* the tower reachable.)

## 2. Homes need roofs + windows
Home1 `(11,2,9)` and Home2 `(-9,2,11)` already have flat box roofs. Add detail:
- New materials: `WindowMat` (dark blue-grey, small `emission` so they read as lit) and `DoorMat`
  (dark brown). Small `BoxMesh`es: window `(0.9,0.9,0.1)`, door `(1.2,2,0.15)`.
- On each home's +Z (front) face (z = center+3.0), add 2 window MeshInstances (e.g. x offset ±1.6,
  y≈2.2) and 1 door (centered, y≈1). Push them ~0.05 proud of the wall to avoid z-fighting.
- Optional: make roofs peaked (two boxes angled into an A, or a scaled box) and add a 3rd home for
  density. Keep it graybox.

## 3. The horse (currently one box, barely visible)
**Diagnosis:** `Props/Steed` is a `(1,1.6,2.6)` box at `(13,0.8,-3)`, tucked at the stable's front
edge. **Do:** replace it with a `Horse` `Node3D` built from brown primitive boxes and move it into the
open in front of the stables, ~`(13, 0, 0)`:
- Body `(2.6,1.2,1.0)` at y≈1.3; Neck `(0.5,1.1,0.5)` angled up-forward off the front; Head
  `(0.8,0.5,0.5)` atop the neck; 4 Legs `(0.22,1.3,0.22)` at the body corners (y≈0.65). One brown
  `StandardMaterial3D`. It only needs to read as horse-shaped at graybox fidelity.

## 4. Shore exit prompt is hard to find (too close to the friend, tiny radius)
**Diagnosis:** `ExitToShore` is at `(0,1.5,-17)` (friend is at `(0,1,-13)`) with a small shared
`(3.5,3,3.5)` trigger. **Do:**
- Move `ExitToShore` to the north edge `(0, 1.5, -21)`, well clear of the friend.
- Give it its own larger trigger: new `BoxShape3D` `(10,4,6)` (don't resize the shared `TriggerShape`
  used by other interactables — make a separate `ExitTriggerShape`).
- Place it in the tree-wall opening from fix 5 so it's visually obvious. Keep `required_flag`
  `act1/ready_to_leave` + `blocked_text`.

## 5. Surround the village with trees, with a clear opening toward the shore
Funnels the player to the exit (see `godot-zone-building` "guiding the player").
- **Make a reusable `scenes/props/tree.tscn`** (Node3D → Trunk box `(0.8,4,0.8)` brown at y=2 +
  Canopy box `(3.5,3,3.5)` dark green at y=5). Instance it many times (cleaner than inline nodes; the
  shore's inline trees can later be swapped to instance this too).
- Add a `Perimeter` node with ~24 tree instances ringing the playable edge (x≈±20 along z, z≈±20
  along x), **leaving a gap at the north** (skip trees for x in [-4,4] at z≈-20) aligned with the
  ExitToShore — that gap is the visible "way out."

## 6. Village barrier (stop falling off the world)
Invisible collision walls at the perimeter (see `godot-zone-building` "edge barriers").
- Add a `Barriers` node with `StaticBody3D` + `BoxShape3D` `CollisionShape3D` segments (NO mesh),
  tall (y 0→6), thin (0.5): East x=21, West x=-21, South z=21 (each ~44 long), and North split into
  two segments (x[-22,-4] and x[4,22] at z=-21) leaving the exit gap.

---

## Notes
- None of this touches GameState/quests/saves, so existing tests should stay green; still run them.
- Keep narrative/prompt text as `[PLACEHOLDER — writing pass]` where applicable.
- The end-of-slice fade-to-black is already implemented (SceneDirector.fade_to_black, called from
  zone_02_shore.gd). Don't re-add.
