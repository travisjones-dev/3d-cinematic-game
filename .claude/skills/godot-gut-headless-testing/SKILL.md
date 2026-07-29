---
name: godot-gut-headless-testing
description: >-
  Run this project's GUT unit tests headlessly on Windows, and write GUT tests
  that cover autoloads, save/load, and scene transitions. Use this WHENEVER the
  task involves running the Godot tests, adding or fixing a GUT test, verifying a
  GDScript change didn't break anything, or debugging a headless Godot test run —
  even if the request is just "run the tests" or "does this still pass". Encodes
  the exact commands plus the gotchas that waste time: the import-first class_name
  error, the addon-driven orphan-count red herring, JSON int→float on load, and
  booting a scene headless to catch runtime errors.
---

# Running & writing GUT tests headless (Windows)

GUT (Godot Unit Test) is this project's test framework. Per CLAUDE.md, required
coverage is GameState save/load round-trip, quest stage transitions, and
flag-condition evaluation; rendering/feel/cinematics are human-tested. This skill
is the reliable way to run those tests from the CLI and the patterns for writing
new ones — including the failures that look alarming but aren't.

## Environment
- Godot is portable, not on PATH. Use the full `_console.exe` path, e.g.
  `C:\Users\TravisJones\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe`
- Project root: `C:\Users\TravisJones\3d-cinematic-game`. Tests in `res://tests/`.
- The canonical, always-current command lives in `tests/README.md` — check there too.

## Running the suite — TWO steps, and the first is not optional on a fresh state

```powershell
$godot = "C:\Users\TravisJones\Downloads\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe"
$proj  = "C:\Users\TravisJones\3d-cinematic-game"

# Step 1 — import (only needed on a fresh checkout, or after adding a new class_name)
& $godot --headless --path $proj --import

# Step 2 — run all tests
& $godot --headless --path $proj -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
"exit: $LASTEXITCODE"   # 0 = all passed
```

`-gexit` makes GUT quit instead of hanging. Without it a headless run never returns.

### Gotcha: "Some GUT class_names have not been imported"
On a fresh checkout or right after adding a script with a new `class_name`, GUT aborts
with this error and a list of missing `Gut*` classes. It is NOT a broken install — the
import cache is empty. Run Step 1 (`--import`) once and it resolves. The editor does
this automatically on open, which is why it only bites headless-first runs.

### Gotcha: the "N Orphans" line is (almost always) not your code
GUT's summary reports orphan nodes. On this project that count comes from the **Dialogic
autoload** spawning subsystem nodes at startup, not from test code. Confirm before
chasing it: run a single test that touches no scenes and see if the count is unchanged —

```powershell
& $godot --headless --path $proj -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_state.gd -gexit
```

If orphans are identical to the full run, it's the addons — ignore it. Only investigate
if the number *grows* when you add scene-based tests (that would be a real leak).

## Writing tests — patterns that hold up

### Autoloads
Autoloads are globals; reference them by name directly. Reset state in `before_each`
so tests don't leak into each other:

```gdscript
func before_each() -> void:
    GameState.reset()
```

### Save/load — JSON turns ints into floats
`JSON.parse_string` returns every number as a float. A quest stage saved as `2` loads
back as `2.0`. Coerce on load (GameState.from_dict already does `int(...)` for quest
stages), and in tests assert on stable types — prefer a String world-var for a clean
round-trip assertion over an int that may compare float-vs-int.

### Scene / transition integration tests
Instantiate the scene, add it, let `_ready` run, drive the system, free it cleanly:

```gdscript
const MAIN: PackedScene = preload("res://scenes/main.tscn")
var main: Node3D

func before_each() -> void:
    SceneDirector.fade_duration = 0.0          # kill fades so coroutines resolve fast/deterministically
    main = MAIN.instantiate()
    add_child(main)
    await get_tree().process_frame              # let _ready register + load the opening zone

func after_each() -> void:
    SceneDirector.zone_root = null              # drop autoload refs into the about-to-free tree
    SceneDirector.player = null
    SceneDirector.fade_rect = null
    SceneDirector._current_zone = null
    if is_instance_valid(main):
        main.free()                             # immediate free keeps the orphan count honest
```

Rules that prevent flakiness:
- **Await the coroutine directly**, don't race its signal:
  `await SceneDirector.change_zone("graybox_b")` — awaiting a function that awaits waits
  for it to finish. Awaiting `transition_finished` instead risks missing a fast emit.
- **Zero out any tween/fade duration** in the test so the await completes in a couple of
  frames rather than real seconds.
- **Don't assert exact positions on physics bodies.** A `CharacterBody3D` settles onto the
  floor once `_physics_process`/gravity ticks, so its Y drifts a hair after placement.
  Assert the deterministic axes tightly and give the settling axis a wide tolerance:
  `assert_almost_eq(player.global_position, Vector3(0, 1.25, 3), Vector3(0.05, 0.3, 0.05))`
  — tight X/Z (spawn placement is what you're really checking), loose Y. A tight Y tolerance
  here is the classic source of a test that passes locally and flakes in CI.

### Testing EventBus / signal components (don't simulate physics)
Components like `Interactable` (see `godot-interaction-system`) detect the player via Area3D
`body_entered`, which only fires after a physics frame with real overlap — slow and flaky to
set up in a unit test. Instead, **call the handler directly with a stand-in node** and watch
the bus:

```gdscript
func test_player_entering_announces_on_eventbus() -> void:
    var it: Interactable = Interactable.new()
    add_child_autofree(it)
    var stand_in := Node3D.new()
    stand_in.add_to_group("player")     # the thing the handler actually checks
    add_child_autofree(stand_in)
    watch_signals(EventBus)
    it._on_body_entered(stand_in)       # call the handler, don't stage a physics overlap
    assert_signal_emitted_with_parameters(EventBus, "interaction_available", [it])
```

This tests the real logic (group check, which signal, what payload) deterministically. Save
"does the Area3D actually detect an overlapping body" for the human playtest — that's engine
behavior, not your logic. `watch_signals(EventBus)` works on the autoload; assert with
`assert_signal_emitted` / `assert_signal_emitted_with_parameters` / `assert_signal_not_emitted`.

## Boot-testing a scene at runtime (catches what --import can't)

`--import` only parses scripts; it never runs `_ready`. To catch runtime errors (null
`@onready` refs, bad `look_at`, autoload wiring), boot the actual main scene for a few
frames and quit:

```powershell
& $godot --headless --path $proj --quit-after 45 *> "<scratchpad>\boot.log"
Select-String -Path "<scratchpad>\boot.log" -Pattern "SCRIPT ERROR|ERROR:|null instance|not found" | Select-Object -ExpandProperty Line
```

**The signal that matters is exit 0 + no SCRIPT ERROR / null-instance / missing-node lines.**

### Boot's blind spot: input-triggered errors
`--quit-after` runs frames but sends **no input**, so any error that only fires on
input — an `_input`/`_unhandled_input` handler calling `Input.is_action_pressed("undefined_action")`,
a click handler on a nonexistent node — will NOT appear in a headless boot even though it floods
the editor at runtime. (This is exactly how a missing `dialogic_default_action` hid from every
boot while spamming thousands of errors the moment a real key was pressed.) So: a clean boot is
necessary, not sufficient. For anything input-driven, get the **in-editor Debugger/Output** from
the human — that's the source of truth for input-time errors. Ask them to paste it rather than
diagnosing input issues blind from source code.

## ⚠️ A new test proves nothing until you have watched it FAIL

The habit that has caught real mistakes here: after writing a regression test, **temporarily break
the fix and confirm the test fails with the numbers you expect**, then revert. Cheap ways to do it:

- `disabled = true` on a newly added `CollisionShape3D`
- reinstate the bad offset/transform you just corrected

Worked examples: disabling the tower door produced a fall to `y = -102`; disabling the village's
`NorthGap` barrier produced `y = -79` at `z = -44.6`; restoring Aeia's mesh offset reported her body
at x `+0.14` against a trigger ending at x `-0.05`. Each confirmed the test was measuring the real
defect rather than passing incidentally. Report the observed failure numbers — they are the evidence
the guard works.

### Assert on shape and content, not just counts
`assert_gt(tl.events.size(), 0)` passes on a **silently misparsed** file. A Dialogic line whose
opening token was eaten as a speaker name still yields events, so the count test sails through while
the dialogue is wrong. When validating parsed or generated data, assert the **event types and text**
(dump them with `gut.p` first to see what you actually got). See `godot-dialogic-integration`.

## ⚠️ GUT fails a test on ANY engine error — including documented-benign ones

GUT reports engine errors raised during a test as `Unexpected Errors` and fails it, even when the
error is known-harmless. The one that bites here:

```
ERROR: Parameter "material" is null.
   at: material_get_instance_shader_parameters (servers/rendering/dummy/storage/material_storage.cpp:265)
```

It comes from the **headless dummy renderer** when zone scenes are instantiated in a test. It is
benign at runtime, but it fails the test regardless.

**Do not burn time hunting the offending node** — stripping every `GPUParticles3D` did not stop it,
and excluding the shore did not either. Instead pick the right tool:

- Validating **authored scene data** (positions, shapes, node structure)? Don't instantiate at all —
  read the `.tscn` via `PackedScene.get_state()` and compose transforms by multiplication. Fast,
  exact, no renderer. Harness in `godot-playable-space-audit` — **read its `./`-prefix warning before
  hardcoding any node path**, or your test fails claiming the node is missing when the scene is fine.
- Genuinely need **physics** (can the player stand here, can they be shoved)? Instantiate a *single*
  zone plus the player — `test_tower_stairs.gd`, `test_tower_doorway.gd` and `test_tower_secret.gd`
  all do this successfully. Looping several zones in one test is what tipped it over.

### Getting real world positions in a test
`global_position` is only meaningful once the node is in a tree **and a frame has passed**:

```gdscript
add_child(zone)
await get_tree().process_frame     # without this, everything reads (0, 0, 0)
```

A bare `extends SceneTree` script reports **all-zero** global transforms no matter what you do —
use `GutTest`. A throwaway measurement test is the fastest way to settle any "which way is it
facing / where actually is it" question; delete it afterwards.

### Expected noise on --quit-after: leak warnings are NOT bugs
`--quit-after` force-quits before the scene tree unwinds cleanly, so Godot prints
`WARNING: ObjectDB instances leaked at exit` and `ERROR: N resources still in use at
exit`. With addons like Dialogic holding resources, this is normal for a forced quit —
it does not indicate a fault in project code. Judge the boot by script errors, not these.
