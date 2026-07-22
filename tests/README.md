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

Current: **15 tests, all passing.**

Required coverage per CLAUDE.md (save/load round-trip, quest stage transitions, flag-condition
evaluation) grows here as those systems land. Rendering, feel, and cinematics are human-tested.

### Note: the ~24 "Orphans" in the run summary
These come from the **Dialogic autoload** spawning subsystem nodes at startup, not from our
code — the count is identical even when running only `test_game_state.gd`, which never touches
our scenes. Not a leak in project code. Revisit if it grows when we integrate Dialogic in Phase C.
