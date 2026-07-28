---
name: godot-scene-authoring
description: >-
  Author Godot .tscn scenes and .tres resources by hand as plain text — the
  format, node headers, resources, instancing, exported NodePaths, collision,
  materials, and addon (custom-typed) nodes. Use this WHENEVER you need to create
  or edit a Godot scene or resource file without the editor GUI — building a
  player/NPC/zone/UI scene, adding a node or collision shape, wiring an exported
  NodePath, instancing a sub-scene, or placing an addon node like PhantomCamera3D.
  This project mandates plain-text, editor-reproducible assets (CLAUDE.md), so this
  is the default way scenes get built here — reach for it even for "just add a node".
---

# Authoring Godot scenes/resources as plain text

CLAUDE.md forbids editor-only GUI steps: every scene must be a `.tscn`/`.tres` you can
write and diff as text. This skill is the format plus the patterns that come up
constantly. It's verifiable — after writing, run `--import` and a headless boot to
catch parse errors (see `godot-gut-headless-testing`).

## File skeleton

```
[gd_scene load_steps=N format=3]

[ext_resource type="Script" path="res://scripts/foo.gd" id="1_foo"]
[ext_resource type="PackedScene" path="res://scenes/bar.tscn" id="2_bar"]

[sub_resource type="BoxMesh" id="SomeMesh"]
size = Vector3(1, 2, 1)

[node name="Root" type="Node3D"]
script = ExtResource("1_foo")

[node name="Child" type="MeshInstance3D" parent="."]
mesh = SubResource("SomeMesh")
```

- `format=3` for Godot 4.x. `.tres` uses `[gd_resource type="X" load_steps=N format=3]`.
- **`load_steps` is a tolerant hint** (roughly ext+sub resources + 1). If it's off, Godot
  fixes it on next save — a wrong count won't break loading. Don't agonize over it.
- **Omit the scene `uid=`** on hand-written files. Godot assigns one on first import and
  writes a `.tscn.uid` sidecar. Don't invent uids — collisions cause pain.
- `parent="."` = the root; `parent="Child"` = nested; `parent="Child/GrandChild"` for deeper.
  Node order in the file is sibling order in the tree.

## Node transforms
`Transform3D(a,b,c, d,e,f, g,h,i, ox,oy,oz)` — first 9 are the basis, last 3 the origin.
Identity basis + a position: `Transform3D(1,0,0, 0,1,0, 0,0,1, X, Y, Z)`.

### ⚠️ The 9 basis floats are ROWS, not columns — the axes are the *diagonals* of the triples
This is the single easiest way to silently get a rotation backwards, and it cost a whole
debugging cycle on the village steed (2026-07-27). Earlier versions of this skill wrongly said
the triples were "x-axis, y-axis, z-axis columns". They are **rows**, matching Godot's own
9-float `Basis(xx,xy,xz, yx,yy,yz, zx,zy,zz)` constructor, which also takes rows:

```
Transform3D( a, b, c,      row 0
             d, e, f,      row 1
             g, h, i, … )  row 2

X axis = (a, d, g)   <-- first element of EACH triple, not the first triple
Y axis = (b, e, h)
Z axis = (c, f, i)
```

So to point a model's local **+X** at world **+Z**, the X axis must be `(0,0,1)`, i.e.
`a=0, d=0, g=1` → `Transform3D(0,0,-1, 0,1,0, 1,0,0, …)`. Reading the triples as columns gives
you `Transform3D(0,0,1, 0,1,0, -1,0,0, …)`, which is the **transpose** — the same rotation with
the opposite sign. Symmetric cases (a 45° tilt, a 180° flip) look identical either way, so the
mistake hides until you hit an asymmetric one and the model faces backwards.

**A 180° flip about Y is safe under either reading** — it negates the X and Z rows *and*
columns identically — so `Transform3D(a,b,c,d,e,f,g,h,i)` → negate a,c,g,i. Useful when a
playtester says "it's facing the wrong way": you can flip without resolving the convention.

### Measure, don't derive
When orientation matters, do not reason it out — **measure it in the engine**. Cheapest reliable
method is a throwaway GUT test that prints real world positions:

```gdscript
var zone: Node3D = load("res://scenes/zones/my_zone.tscn").instantiate()
add_child(zone)
await get_tree().process_frame                 # required — transforms are not resolved before this
var part: Node3D = zone.get_node("Props/Horse/Head")
gut.p("head: %s" % part.global_position)       # then compare against the containing geometry
```

A bare `SceneTree` script reports **all-zero** global transforms, so use GutTest (or await a frame
in a real tree). To validate *authored* transforms without instantiating anything, read the
`.tscn` through `PackedScene.get_state()` and compose with `Transform3D` multiplication, which is
exact and never touches basis internals — see `godot-playable-space-audit`.

For a rotation you can hand-write, a 45° tilt about X is
`Transform3D(1,0,0, 0,0.707107,-0.707107, 0,0.707107,0.707107, 0,0,0)`. When the math gets hairy,
set an identity transform in the file and orient it in code with `look_at()` in `_ready()`.

### Check a prop's built axis against the geometry that contains it
Box-composed props here are commonly authored facing **+X** (body long axis on X, head/neck at
+X), while the structures that hold them open along **Z**. Placing one without rotating it puts
the prop broadside across its container — the steed's head clipped through a stall divider into
the neighbouring stall. Before placing, check which way the prop was built *and* which way its
container opens.

## Instancing a sub-scene
Compose scenes from other scenes rather than duplicating nodes:

```
[ext_resource type="PackedScene" path="res://scenes/characters/player.tscn" id="2_player"]

[node name="Player" parent="." instance=ExtResource("2_player")]
```

Override the instance's exported props right under that node line. The instance keeps its
own internal nodes; you address it by the name you gave here.

## Exported NodePaths — the `node_paths` header
If a node's script has an exported `NodePath`/node reference, the assignment goes in the
node header's `node_paths` list AND as a property line:

```
[node name="Cam" type="Node3D" parent="." node_paths=PackedStringArray("follow_target")]
follow_target = NodePath("../Player")
```

Miss the `node_paths=` part and Godot won't resolve the reference. `../` walks up to a sibling.

## Addon / custom-typed nodes (e.g. PhantomCamera3D)
A node type registered by an addon via `class_name` / `add_custom_type` is written as its
**base type plus the script**, NOT as the custom type name:

```
[ext_resource type="Script" path="res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd" id="3_pcam"]

[node name="PlayerPhantomCamera3D" type="Node3D" parent="." node_paths=PackedStringArray("follow_target")]
script = ExtResource("3_pcam")
follow_mode = 6
follow_target = NodePath("../Player")
```

To discover an addon node's real property names/values, read the addon's own example
`.tscn` files (`addons/<name>/examples/`) — they are the ground truth for the installed
version. (See `godot-phantom-camera` for the worked example.)

## Collision — bodies need a shape or things fall through
A visual `MeshInstance3D` has no collision. For a walkable floor / solid prop, wrap it in a
`StaticBody3D` with a `CollisionShape3D`; the player is a `CharacterBody3D` + `CollisionShape3D`.

```
[sub_resource type="BoxMesh" id="FloorMesh"]
size = Vector3(20, 0.5, 20)
[sub_resource type="BoxShape3D" id="FloorShape"]
size = Vector3(20, 0.5, 20)

[node name="Floor" type="StaticBody3D" parent="Geometry"]
[node name="Mesh" type="MeshInstance3D" parent="Geometry/Floor"]
mesh = SubResource("FloorMesh")
[node name="Collision" type="CollisionShape3D" parent="Geometry/Floor"]
shape = SubResource("FloorShape")
```

Mesh and shape are separate resources — keep their sizes in sync by hand.

## Materials
```
[sub_resource type="StandardMaterial3D" id="Mat"]
albedo_color = Color(0.3, 0.45, 0.75, 1)

[node name="Mesh" type="MeshInstance3D" parent="."]
mesh = SubResource("SomeMesh")
surface_material_override/0 = SubResource("Mat")
```
`surface_material_override/0` targets the first surface (a BoxMesh/CapsuleMesh has one).

## Environment/lighting quickstart (so a scene renders as more than black)
`WorldEnvironment` + an `Environment` with a procedural sky gives instant ambient + sky:

```
[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]
[sub_resource type="Sky" id="Sky"]
sky_material = SubResource("SkyMat")
[sub_resource type="Environment" id="Env"]
background_mode = 2
sky = SubResource("Sky")
tonemap_mode = 2

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")
```
Add a `DirectionalLight3D` for direct light + shadows.

## Expect the editor to rewrite your file
On open/import Godot reformats: rewrites script paths to `uid://...`, tidies comments, and
may add addon-owned sections. This is normal and means things loaded. **Re-read the file
from disk (PowerShell `Get-Content` if the Read tool shows a stale cache) before your next
edit** — the editor's version is now the source of truth.

## .tres data resources (custom Resource classes + typed arrays)
Data like quests/items are custom `class_name` Resources authored as `.tres`. The header names
the script class; nested resources are `sub_resource`s with the child script; and a typed array
of a custom class serializes as `Array[ClassName]([...])`:

```
[gd_resource type="Resource" script_class="QuestResource" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/quest_resource.gd" id="1_quest"]
[ext_resource type="Script" path="res://scripts/data/quest_stage.gd" id="2_stage"]

[sub_resource type="Resource" id="Stage_0"]
script = ExtResource("2_stage")
summary = "Flee to the shore."
complete_flag = "act1/reached_shore"
set_flags_on_enter = Array[String]([])

[resource]
script = ExtResource("1_quest")
id = "act1/spike_quest"
stages = Array[QuestStage]([SubResource("Stage_0")])
```
- `script_class="QuestResource"` on the header + `script = ExtResource(...)` on `[resource]` are
  both needed. The custom `class_name`s must be registered (they are after `--import`).
- Empty typed array: `Array[String]([])`. Array of nested custom resources:
  `Array[QuestStage]([SubResource("Stage_0"), ...])`.
- `load()`/`preload()` returns the typed resource; verify with `--import` (parses the `.tres`).

## Always verify after writing
Hand-written scenes are easy to typo. Run `--import` and scan for `SCRIPT ERROR|Parse
Error|ERROR:`, then boot with `--quit-after` to catch runtime `_ready` errors. Details in
the `godot-gut-headless-testing` skill.
