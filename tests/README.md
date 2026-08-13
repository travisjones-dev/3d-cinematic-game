# Tests (GUT)

GUT (Godot Unit Test) **9.6.1**, targeting Godot **4.6.3-stable**. Tests live in `res://tests/`.

## Running the suite (headless, Windows)

The Godot editor binary lives outside the project (portable install). Adjust the path
if you move it:

```
$GODOT = "C:\Users\TravisJones\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe"
```

Two steps. **Step 1 (import) is only needed the first time, or after adding a script
with a new `class_name`** (GUT registers its own `class_name`s this way):

```powershell
& $GODOT --headless --path . --import
```

Step 2 — run all tests:

```powershell
& $GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Exit code is `0` on success. `--gexit` makes GUT quit after the run instead of hanging.

### Gotcha (why step 1 exists)
On a fresh checkout GUT errors with *"Some GUT class_names have not been imported"*.
That is the import cache being empty, not a broken install. Run the `--import` pass once
and it resolves. In the editor, this happens automatically on open.

## What's covered (Phase A)
- `test_game_state.gd` — flag set/get, defaults, clearing, namespacing, quest-stage default, `flag_changed` signal
- `test_save_manager.gd` — GameState save/load round-trip, player-transform round-trip, empty-slot handling
- `test_scene_director.gd` — loads `main.tscn`, verifies zone swap, spawn-point placement, fade clearing, `zone_entered` signal
- `test_scene_geometry.gd` — proves the AABB harness can measure **imported `.glb` art**, not just
  graybox primitives: size, base pivot, transform composition, and that missing geometry reports as
  zero rather than a plausible-looking guess

Current: **70 tests, 274 asserts, all passing** (re-verified 2026-08-13).

## Shared helpers and fixtures (added 2026-08-13, M2 art pass)
- `tests/helpers/scene_geometry.gd` — static geometry reader for authored `.tscn` files. Measures
  scenes **without instantiating them**, and resolves an inline mesh, an **instanced `.glb`**, or a
  `Mesh` child. Shared by `test_interaction_alignment.gd` and `test_tower_roof.gd`, which each used
  to carry their own copy.
  - **No `class_name` on purpose** — see the gotcha above; a new `class_name` forces an extra
    `--import` pass before GUT will run. Callers `preload()` it instead.
  - Contract: "nothing measurable" is a **zero-size AABB**, and callers must treat that as a
    failure. Skipping is indistinguishable from passing, which is how an art swap could quietly
    disarm the guards.
- `tests/fixtures/imported_asset_probe.tscn` — instances the Phase 1 reference `.glb` at an offset,
  so `test_scene_geometry.gd` can prove the harness measures imported art and composes placement
  correctly. Neither directory is collected by GUT: it only picks up `test_`-prefixed scripts.

Required coverage per CLAUDE.md (save/load round-trip, quest stage transitions, flag-condition
evaluation) grows here as those systems land. Rendering, feel, and cinematics are human-tested.

### Note: the 24 "Orphans" in the run summary — fully accounted for
An *orphan* is a Node that is alive but not in the scene tree. Nodes are not reference-counted
(only `RefCounted`/`Resource` are), so a Node that is never parented and never freed leaks for
the life of the process. GUT reports the count because a **rising** count is the clearest signal
a test leaked memory.

All 24 are Dialogic's, and they **are** real leaks — just harmless ones. The cause is a
static-typing idiom in `addons/dialogic/Core/DialogicGameHandler.gd` (line ~105 onward), repeated
once per subsystem:

```gdscript
var Animations := preload("res://addons/dialogic/Modules/Core/subsystem_animation.gd").new():
	get: return get_subsystem("Animations")
```

The initializer allocates a Node purely so `:=` infers a static type (so `Dialogic.Animations.x()`
type-checks). The getter **never returns it** — it always redirects to the real subsystem, which
`_collect_subsystems()` adds as a child of the autoload. The allocated node is unreachable the
instant construction ends, and nothing frees it.

The arithmetic works out exactly:
- **18** such properties (Animations, Audio, Backgrounds, Choices, Expressions, Glossary, History,
  Inputs, Jump, PortraitContainers, Portraits, Save, Settings, Styles, Text, TextInput, VAR, Voice)
- **+ 6** nodes those orphaned copies allocate in their own member initializers: 2× `Node` in
  `subsystem_audio.gd:23,25`, `Timer` in `subsystem_choices.gd:41`, `subsystem_input.gd:23`,
  `subsystem_save.gd:468`, and `AudioStreamPlayer` in `subsystem_voice.gd:41`
- **= 24.** The run summary even prints them in that order — `subsystem_audio` is immediately
  followed by its two bare `[<Node>]` children.

The real (in-tree) subsystems allocate the same member nodes, but those get `add_child`-ed during
`post_install()`, so they are in the tree and are not counted.

Why it's safe to ignore: it is **bounded** (24, allocated once at autoload init — not per-frame,
not per-conversation), **constant** (the number never grows), and **not our code**. That constancy
is what makes it a usable baseline: a count of 27 means three orphans are ours.

The related shutdown line `N resources still in use at exit` is largely downstream of this — each
unfreed Node holds a reference to its script, and a script is a `Resource`, so the resource cache
can't fully drain. (In general that message means either something unfreed holds a reference, as
here, or a **reference cycle**: resource A refers to B and B back to A, so neither refcount ever
reaches zero. Worth knowing — it's easy to create accidentally with interlinked `.tres` files.)

**Standard for our own code: zero orphans.** Use GUT's `autofree()` / `add_child_autofree()`, or
free explicitly. Investigate immediately if the count exceeds 24.
