---
name: godot-character-assembly
description: >-
  Build and animate an imported character in this project — assembling a body from modular
  packs (base body + clothing + hair), driving it from the shared Universal Animation Library,
  or hand-posing a rig that has no clips. Use this WHENEVER the task involves an NPC or player
  model, a character standing in a T-POSE, a character missing its HEAD, an animation that
  won't play or plays once and freezes, sitting/seating a character on furniture, retargeting,
  or matching a clip to a different rig.

  Front-loads the two structural surprises that cost the most time: Quaternius splits one
  character across THREE packs (an outfit alone is a headless set of clothes), and a seated
  animation MOVES the pelvis, so furniture must be placed against the animated pose rather than
  the model's rest pose.
---

# Assembling and animating characters

## Which rig am I on? (decide this first — it gates everything)

Two incompatible naming conventions are in this project. Check before planning any animation work:

| Convention | Bone names | Packs | Animation source |
|---|---|---|---|
| **Blender-style** | `UpperArm.L`, `LowerArm.L`, `Neck`, `Fist.L` | Quaternius **RPG Character Pack** (Warrior, Cleric, Ranger, Wizard, Monk, Rogue) | each character's **own** 13 clips (Idle/Walk/Run/attacks) |
| **Unreal-style** | `upperarm_l`, `lowerarm_l`, `neck_01`, `thigh_l`, full finger chains | **Universal Base Characters**, **Modular Character Outfits** | the shared **Universal Animation Library** (43 clips) |

**Clips do not cross between them.** No track binds; nothing errors, nothing moves. If a character
needs sitting/talking clips it must be on the Unreal-style rig, because only the library has them.

```powershell
# Which convention is this file?
$j = [IO.File]::ReadAllText($gltf) | ConvertFrom-Json
($j.nodes | ForEach-Object { $_.name }) | Select-Object -First 20
```

---

## 1. A character is THREE packs, not one

The single biggest surprise here. Quaternius splits a character across packs:

| Layer | Pack | Contains |
|---|---|---|
| Body | **Universal Base Characters** | one mesh **including the head**, plus separate `Eyes` and `Eyebrows` |
| Clothing | **Modular Character Outfits** | `_Arms`, `_Body`, `_Legs`, `_Feet` — **no head** |
| Hair | **Universal Base Characters** → Hairstyles | `Hair_Buns`, `Hair_Long`, `Hair_SimpleParted`, … (use the *Rigged to Head Bone* variants) |

⚠️ **"Modular Character *Outfits*" is a clothing layer.** Used alone it is a headless set of
clothes — which is exactly how Elder Mishka first shipped. The give-away is that the pack
contains base-skin textures (`T_Regular_Female_*`) but no base mesh.

⚠️ The free tier ships only **Superhero** proportions (Regular and Teen are Pro). A base body is
1.775 m, so against this project's 2.0 m player it reads as a smaller adult with no scaling.

### Assembling them
`scripts/components/animated_character.gd` takes a `layers` array and re-parents each layer's
skinned meshes onto the character's own `Skeleton3D`:

```gdscript
piece.mesh = source.mesh
piece.skin = source.skin
skeleton.add_child(piece)
piece.skeleton = NodePath("..")   # relative to the MeshInstance3D
```

Take the **mesh and skin only, never the layer's own skeleton** — two skeletons means two things
to animate and only one gets driven. Godot binds a `Skin` to bones **by name**, which is why this
works across files at all, and why every layer must be on the same rig convention.

In the `.tscn`, typed arrays need the explicit form. A bare `[...]` fails to satisfy
`Array[PackedScene]`:

```
layers = Array[PackedScene]([ExtResource("27_outfit"), ExtResource("28_hair")])
```

**Import every layer at the same `root_scale`** (1.0 is simplest) or the clothing will not match
the body.

### Verify the bind, don't assume it
Attaching meshes is not enough — if the bind names don't resolve, the clothes stay in the bind
pose while the body animates, which looks worse than headless. Check in a probe:

```gdscript
var resolved := mi.get_node_or_null(mi.skeleton) == skel
var binds := mi.skin.get_bind_count()
# and: every skin.get_bind_name(i) exists in the skeleton
```
Expect `skeleton_ok=true`, a full bind count, `unresolved_bones=0` on every mesh.

---

## 2. The Universal Animation Library

`assets/models/characters/universal_animations.glb` — 43 clips, CC0. Driven by
`animated_character.gd`, which loads it **once per run** and shares it (deep-copying the clips so
the 7 MB mannequin isn't resident).

**No retargeting is needed when the rigs match.** The pack's own Godot instructions walk through
creating a `BoneMap` and `SkeletonProfileHumanoid` in the inspector — that is for mapping onto a
*different* rig. Here both sides are the same universal humanoid with the same
`Armature/Skeleton3D` node path that the clips' tracks address, so they bind directly. That also
avoids an **editor-GUI-only** step, which CLAUDE.md forbids as a dependency.

⚠️ **Godot strips the `_Loop` suffix** from imported clip names and converts it into the loop
mode. The library's `Sitting_Idle_Loop` is addressed as **`Sitting_Idle`** and already loops.
Looking up the name printed inside the `.glb` fails with "Animation not found".

Useful clips: `Idle`, `Idle_Talking`, `Sitting_Idle`, `Sitting_Talking`, `Sitting_Enter/Exit`,
plus locomotion, crouch, swim and emotes.

Set `AnimationPlayer.root_node` to the **character root**, not the player itself — tracks are
authored as `Armature/Skeleton3D:bone` relative to the library scene's root.

---

## 3. Seating a character on furniture

**A seated clip MOVES the pelvis.** `Sitting_Idle` carries the hips backward along the character's
own −Z and down. Consequences:

- Place furniture against the **animated** pose, not the rest pose. Measured here: pelvis went to
  y 0.542 and z 2.669 from an origin at z 3.0 — a bench centred on the node sat *in front of* her
  hips and slightly too high.
- **Which way the character faces decides which side of the furniture they land on.** Rotating the
  character 180° also moves where the bench has to be.
- **Move the furniture to meet the character, not the reverse.** Raising the character lifts their
  feet clear of the ground; sinking a bench a few cm into grass reads fine.

Target: hips **0.05–0.12 m above the seat top**, hips within the seat's z span, feet near y=0.

---

## 4. When a rig has NO clips: pose bones in skeleton space

Only if the library isn't an option. Do **not** guess each bone's local axis — rigs orient bones
differently. Work in skeleton space:

```gdscript
# swing a bone's length toward `target`
var direction := (child_rest.origin - here_rest.origin).normalized()
var axis := direction.cross(target).normalized()          # zero axis => already aligned, skip
# re-express a skeleton-space rotation as this bone's LOCAL pose:
#   local = parent_global_rest^-1 * R * parent_global_rest * rest_local
var local := parent_basis.inverse() * Basis(axis, angle) * parent_basis * skeleton.get_bone_rest(idx).basis
skeleton.set_bone_pose_rotation(idx, local.get_rotation_quaternion())
```

- Read **facing** from the foot: `foot_l → ball_l` is the toe direction. Never assume.
- For a knee, rotate about the **same axis the hip used**, negated. Asking the shin to "swing
  toward down" is degenerate — its rest direction is already vertical, so the axis is zero and it
  silently does nothing.
- Posing legs moves the **feet, not the hips** (the pelvis is the root of the chain), so the whole
  model must be lowered to meet a seat.

---

## 5. Verifying a pose — three ways to get a false negative

All three of these reported "nothing changed" when the code was fine:

1. **`get_bone_global_pose()` is stale** in a frameless `-s` script. Call
   `skeleton.force_update_all_bone_transforms()` first, or await real frames.
2. **`set_script()` at runtime does not fire `_ready`.** A probe that attaches the script itself
   tests nothing. Load the **real scene** so the `.tscn`'s `script =` runs normally.
3. **Bind-pose AABBs never move.** `MeshInstance3D.get_aabb()` on a skinned mesh returns the bind
   pose regardless of the animation. Measure **bone positions**, not mesh bounds, to check a pose.

---

## 6. The player is different
`player.gd` drives the character's **own** `AnimationPlayer` with crossfades, choosing
Idle/Walk/Run from **actual horizontal speed** (not input) so the stride survives the deceleration
ramp and a cutscene that zeroes velocity settles to Idle for free. Playback rate tracks speed
against each gait's nominal to cut foot-slide. See `godot-thirdperson-controller`.

Do not put `animated_character.gd` on the player — it is for NPCs that have no clips of their own.
