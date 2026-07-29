---
name: godot-playable-space-audit
description: >-
  Diagnose and prevent the "visible but unusable / walkable but shouldn't be" class of bugs in this
  Godot project — the player falling out of the level through a doorway or map edge, an interaction
  prompt that won't fire while standing right at the thing, the wrong prompt appearing, or something
  placed where the player physically cannot stand. Use this WHENEVER a playtester reports falling
  into the void, an endless drop, walking through a gap in the map, "I was right in front of her and
  couldn't talk", a prompt for the wrong object, or a prop/NPC/secret that can't be reached. Also use
  it BEFORE placing any new interactable, secret, or zone exit, and when writing tests that validate
  authored scene geometry. Encodes the press-E-exits-are-not-sealed rule, the last-entered-wins
  prompt trap, the mesh-drifted-outside-its-own-trigger trap, headroom under the spiral stairs, and
  the SceneState/AABB test harness that guards all of them without instantiating a zone.
---

# Auditing the playable space

Five bugs in this project have been the same bug wearing different clothes: **the authored scene and
the space the player can actually occupy disagree.** Either the player can go somewhere the level
doesn't exist, or they can't use something that is plainly right there. Playtesters report these
constantly because they are invisible in the editor — everything *looks* correct.

This skill is the checklist and the test harness. Read it before placing anything the player is
meant to reach, and when triaging any "I couldn't…" or "I fell…" report.

## The four failure modes

### 1. A press-E exit is not a physical barrier — seal it yourself
`zone_exit.gd` extends `interactable.gd`, so leaving a zone is an **E-press on an Area3D**, not a
walk-through trigger. Nothing about that stops the player walking through the hole the exit sits in.
Both occurrences were the same shape:

- **Tower doorway** — the south wall is three pieces built *around* an aperture (`SouthLeft`
  x −4..−1, `SouthRight` x 1..4, `SouthLintel` x −1..1 but only y 2.5 up), leaving x −1..1, y 0..2.5
  with **nothing in it**. The `Floor` is 8×8 so its surface stops at exactly z=4.0 and there is no
  geometry beyond. The player walked out and fell to y = −102.
- **Village north edge** — `Barriers/North*` is deliberately two 18 m pieces (`NorthWest` x −22..−4,
  `NorthEast` x 4..22), leaving an **8 m gap** at x −4..4 where `ExitToShore` sits. Player fell to
  y = −79 at z = −44.

**Rule:** every zone exit aperture needs a collider filling it. Prefer a **visible closed door**
where the fiction supports one (it seals the hole *and* hides unmodelled exterior, and makes the
E-press read as opening the door); use an **invisible collision-only `StaticBody3D`** where an
opening must stay visually open, matching the village's `Barriers` convention.

Size the filler **slightly larger than the aperture** — 0.05 overlap onto each jamb/lintel/threshold
for a door, 0.2 onto each neighbour for a barrier. Exact-fit colliders leave hairline seams, and
coincident faces z-fight.

**Then check the exit trigger still reaches the player.** The blocker stops the capsule short, so the
player's new resting position must remain inside the exit's Area3D. Both worked because the triggers
are generous (`ExitToShore` is 10×4×6, spanning z −24..−18, and the player is stopped near z ≈ −20.2).

**And check spawn points against the new collider.** The tower spawn sat at z=3.5; with capsule
radius 0.4 **plus `safe_margin = 0.2`** the effective shell reaches 0.6, which overlapped the new
door at z 3.9..4.1 and would have shoved the player on arrival. Moved to z=2.9. Always compute
`radius + safe_margin`, not just radius.

### 2. Interaction prompts are LAST-ENTERED-WINS, not nearest-wins
`player.gd`:

```gdscript
func _on_interaction_available(target: Node) -> void:
    _current_interactable = target as Interactable      # last one to fire wins, unconditionally

func _on_interaction_lost(target: Node) -> void:
    if _current_interactable == target:                 # leaving a DIFFERENT one changes nothing
        _current_interactable = null
```

Two overlapping triggers therefore let the player stand at one object while the other's prompt shows,
and the state persists until they leave the one they happen to be latched onto. The blacksmith's
default 3.5 m trigger overlapped `StableInteract`, so you could stand at the blacksmith and be
offered "Greet your steed".

**Rule: no two interaction triggers may overlap.** Fix by shrinking the trigger and/or offsetting the
`Trigger` child (the blacksmith got a 3 m box offset +1.25 in z, keeping his mesh where it was).
Guarded by a test — see the harness below.

### 3. The visible body can drift outside its own trigger
An `Interactable` is an `Area3D` with a `Mesh` child and a `Trigger` child. If the `Trigger` has no
transform of its own it is centred on the Area3D — but the **`Mesh` can carry an offset**, and then
the art and the hitbox are in different places.

Aeia: Area3D at (−1.8, 9.9, −1.5), `Trigger` untransformed, `Mesh` offset by
(1.9418097, 0, 1.6561785). Her body was at x **+0.14** while her trigger ended at x **−0.05** — she
stood *outside her own trigger*, so talking to her worked from one angle and failed head-on.

Fractional offsets like that are the signature of an **editor hand-drag that moved the `Mesh` child
instead of the `Area3D`**. Fix by moving the Area3D to the real position and zeroing the mesh offset
— the visual position is unchanged, the trigger becomes centred.

### 4. Floor area is not standing room — check what is overhead
Under the tower's spiral, the obvious pocket is unusable. The player capsule is **2.0 m tall**
(centre rests 1.0 above the floor), and the steps overhead are lower than they look.

Step *n* sits at angle **(5 + 10n)°** with its surface at **y ≈ 0.0625 + 0.125n**; the tread is 0.3
thick, so its **underside is ≈ 0.15 below that**. Radially a tread spans r 2.5..3.5 (the 1.8 dimension
is *tangential*, not radial), so it covers most of the walkable ring.

| Position | angle | lowest step | underside | 2.0 m capsule fits? |
|---|---|---|---|---|
| North pocket | 180° | Step17, y 2.04 | ≈1.89 | **No** — player gets shoved |
| West pocket | 270° | Step27, y 3.29 | ≈3.14 | Yes, comfortably |

The watchman's-tally secret went on the **west** wall for exactly this reason. Before placing
anything under the spiral, compute the step directly overhead. See `godot-multisegment-terrain` for
the staircase itself — and do not modify stair, newel, or corner-fill geometry (closed saga).

## The test harness: validate authored scene data, don't instantiate

The guards live in `tests/test_interaction_alignment.gd`. It reads the `.tscn` through
`PackedScene.get_state()` rather than instantiating zones. **Two reasons, both learned the hard way:**

1. **GUT counts any engine error as a test failure.** Instantiating these zones headlessly raises
   `Parameter "material" is null` from `material_get_instance_shader_parameters` in the dummy
   renderer. That error is documented-benign, but it fails the test regardless — and stripping
   `GPUParticles3D` did *not* stop it, so don't burn time hunting the node.
2. **Trigger/mesh alignment is a static property of the file.** Composing `Transform3D`s by
   multiplication is exact and never touches basis internals, sidestepping the rows-vs-columns trap
   in `godot-scene-authoring`.

```gdscript
## Reads a .tscn into {node_path: {transform, has_script, shape}} without instantiating it.
func _read_scene(path: String) -> Dictionary:
    var state: SceneState = (load(path) as PackedScene).get_state()
    var nodes: Dictionary = {}
    for i in range(state.get_node_count()):
        var node_path: String = String(state.get_node_path(i))   # "." for root, "./Geometry/Floor" for children
        var entry: Dictionary = {"transform": Transform3D.IDENTITY, "has_script": false, "shape": null}
        for j in range(state.get_node_property_count(i)):
            match state.get_node_property_name(i, j):
                "transform": entry["transform"] = state.get_node_property_value(i, j)
                "script":    entry["has_script"] = state.get_node_property_value(i, j) != null
                "shape":     entry["shape"] = state.get_node_property_value(i, j)
        nodes[node_path] = entry
    return nodes

## Compose down from the root by multiplication.
func _global_of(nodes: Dictionary, path: String) -> Transform3D:
    var acc: Transform3D = (nodes["."] as Dictionary)["transform"] if nodes.has(".") else Transform3D.IDENTITY
    if path == ".": return acc
    var walked: String = ""
    for part: String in path.split("/"):
        walked = part if walked == "" else walked + "/" + part
        if nodes.has(walked):
            acc = acc * ((nodes[walked] as Dictionary)["transform"] as Transform3D)
    return acc
```

### ⚠️ Keys carry a leading `./` — this bites the moment you hardcode a path

`get_node_path()` returns `.` for the root but **`./Geometry/Floor`** for every child, so the
dictionary keys are `./`-prefixed. `test_interaction_alignment.gd` never trips on this because it
only ever *iterates its own keys* and appends (`path + "/Trigger"`), which stays self-consistent
whatever the prefix is. The first test that **hardcodes** a lookup gets a silent miss:

```gdscript
nodes.has("Geometry/Ceiling")      # false — always, however correct the scene is
nodes.has("./Geometry/Ceiling")    # true
```

It fails as *"the node is missing"*, which reads exactly like the scene bug you are testing for — so
the instinct is to go re-check the `.tscn`, where everything looks fine. Cost a full red run on
`test_tower_roof.gd` (2026-07-29). Put the prefix in a `const` so it cannot drift:

```gdscript
const CEILING: String = "./Geometry/Ceiling"
```

**If a `SceneState` lookup says a node is absent, print the real keys before believing it** — a
throwaway `-s` script that dumps `get_node_path(i)` for every node settles it in one run. (A bare
`SceneTree` script is fine here: loading resources and reading `SceneState` works even though live
`global_position` reads all-zero — see `godot-gut-headless-testing`.)

Two more things that make these assertions lie rather than fail loudly:

- **Compare flush geometry with an epsilon.** Anything authored to sit exactly flush serialises
  through float32: a wall top at `9.8` reads back as `10.2000007629395` once composed, so
  `assert_lte(top, 9.8)` fails on rounding, not on a gap. Use `9.8 + 0.01`.
- **Rotations can be negative.** Asserting a *signed* euler component fails on the sign when the
  authored lean happens to run the other way (the village crown leans **−9.85°**). Compare
  `absf(euler.z)` unless the direction is genuinely what you mean to pin down.

From there, build each `<node>/Trigger`'s world AABB and assert:

- **Alignment** — for every node with both a `Mesh` and a `Trigger`, `box.has_point(mesh_origin)`.
- **No overlap** — for every pair of *scripted* trigger boxes, `not a.intersects(b)`. Filter on
  `has_script` so scriptless Area3Ds are excluded: the shore's `ShoreTrigger` is a scriptless
  cutscene `body_entered` volume, not an `Interactable`, and legitimately overlaps things.

Reachability that genuinely needs physics (headroom, being shoved) still wants a real driven-player
test — see `tests/test_tower_secret.gd`, which places the player in the nook and asserts it neither
sinks nor drifts into the newel or wall.

## Triage checklist for a playtest report

| Report | Look at |
|---|---|
| "I fell into the void / fell forever" | Unsealed exit aperture or a gap in the edge barriers; compare floor extent against wall/barrier extent |
| "I walked off the edge of the map" | Barrier pieces that don't meet — check for a deliberate gap left for an exit |
| "I was right in front of it and couldn't interact" | `Mesh` offset vs `Trigger` position; is the body inside its own box? |
| "It offered me the wrong thing" | Two triggers overlapping; last-entered-wins |
| "I can't get to X" / player stuck near X | Headroom above X, and `radius + safe_margin` clearance around it |

## Verify the fix by breaking it again
Every guard here was confirmed by **temporarily disabling the fix** and watching the test fail with
the expected numbers — `disabled = true` on a new collider, or reinstating the bad offset. A passing
test proves nothing until you've seen it fail. See `godot-gut-headless-testing`.
