---
name: godot-pause-menu
description: >-
  Build or modify a pause menu / in-game menu in this Godot project that works
  while the tree is paused, and wire its Save/Load/Quit to SaveManager and
  SceneDirector. Use this WHENEVER the task involves pausing the game, a pause or
  options menu, resume/quit-to-desktop, save or load buttons, or a UI that must
  keep responding while gameplay is frozen. Covers the process_mode = ALWAYS
  requirement, mouse-mode handling, and restoring a save to an exact position.
---

# Pause menu (works while paused) + save/load wiring

A menu that pauses the game must keep running while everything else is frozen — the classic
Godot trip-up. This is the working pattern from Phase B (playtest-confirmed).

## The one non-negotiable: process_mode = ALWAYS

`get_tree().paused = true` freezes every node whose `process_mode` is the default (PAUSABLE),
which would freeze the pause menu itself — its buttons and input would go dead. The menu (and
anything that must work while paused) needs `process_mode = 3` (ALWAYS). Set it in the `.tscn`:

```
[node name="PauseMenu" type="Control"]
process_mode = 3            # Node.PROCESS_MODE_ALWAYS — runs even while the tree is paused
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("...")
```

Because it's ALWAYS, its `_unhandled_input` fires whether the game is paused or not — so the
SAME handler both opens (when running) and closes (when paused) the menu:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        if visible: _resume() else: _open()
```

## Pause + mouse-mode handshake

If the game captures the mouse for camera control (see `godot-phantom-camera`), the pause
menu must free it so the player can click buttons, then recapture on resume:

```gdscript
func _open() -> void:
    visible = true
    get_tree().paused = true
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume() -> void:
    visible = false
    get_tree().paused = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
```

A hidden Control still receives `_unhandled_input` (visibility gates GUI/mouse input, not the
node input callbacks), so hiding it doesn't stop it from catching the pause key to reopen.

## Save / Load wiring

Save grabs the live zone + player transform; load restores them to the *exact* position, not
a spawn point — that's why SceneDirector has `load_into(zone, transform)` (see
`godot-gut-headless-testing` / the SceneDirector source):

```gdscript
const SLOT: int = 0   # single quick-save slot for the slice

func _on_save() -> void:
    var xform: Transform3D = Transform3D.IDENTITY
    if SceneDirector.player != null:
        xform = SceneDirector.player.global_transform
    SaveManager.save_game(SLOT, SceneDirector.get_current_zone_name(), xform)

func _on_load() -> void:
    if not SaveManager.has_save(SLOT):
        return
    var data: Dictionary = SaveManager.load_game(SLOT)     # restores GameState (flags/quests)
    var zone: String = data.get("zone", "")
    var xform: Transform3D = SaveManager.array_to_transform(data.get("player_transform", []))
    if zone != "":
        SceneDirector.load_into(zone, xform)
    _resume()

func _on_quit() -> void:
    get_tree().quit()
```

- **`SaveManager.load_game` already restores GameState** (flags/quests/world vars). The menu's
  extra job is only to put the player back in the right zone + transform via `load_into`.
- **Disable Load when there's no save** so the button can't do nothing: set
  `LoadButton.disabled = not SaveManager.has_save(SLOT)` in `_ready` and each `_open`.

## Scene shape
`Control` (ALWAYS, full-rect) → a dim `ColorRect` (`Color(0,0,0,0.55)`) → a `CenterContainer`
→ `VBoxContainer` with a Title label + Resume/Save/Load/Quit `Button`s. Instance it under the
persistent UI `CanvasLayer` (see `godot-scene-authoring`). Connect button `pressed` signals in
`_ready`.

## Testing
Button clicks / layout are human-tested. The underlying logic IS testable headlessly: assert
`SceneDirector.load_into` places the player at the saved transform and `SaveManager` round-trips
GameState. Keep pause-specific UI checks (does it actually freeze, is the mouse freed) for the
playtest.
