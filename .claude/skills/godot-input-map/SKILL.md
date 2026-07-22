---
name: godot-input-map
description: >-
  Define Godot input actions (WASD movement, run, interact, pause, etc.) as plain
  text in project.godot's [input] section, including the exact InputEventKey
  serialization and physical keycodes. Use this WHENEVER the task involves adding or
  changing key/mouse bindings, creating a named input action, wiring a control to a
  key, or debugging why Input.is_action_pressed / Input.get_vector returns nothing.
  Covers the fiddly Object(InputEventKey,...) format, a keycode cheat sheet, and the
  runtime InputMap fallback when the text form fights you.
---

# Defining input actions in project.godot ([input])

Bindings belong in `project.godot` so they're discoverable in Project Settings and version
with the repo. The serialization is fiddly — this skill has the exact format so you don't
re-derive it, plus a safer fallback.

## The format

Each action is a dict with a `deadzone` and an `events` array of serialized input events:

```
[input]

move_forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- **Use `physical_keycode`, not `keycode`.** Physical keycodes are layout-independent (W stays
  the physical W key on AZERTY/QWERTZ). Leave `keycode` at 0.
- Keep the full property list above — Godot writes all of them; a partial object can be
  rejected. Copy the line and change only `physical_keycode` (and the action name).
- One `Object(InputEventKey,...)` per bound key; add more entries to the `events` array for
  alternate bindings (e.g. arrow keys alongside WASD).

## Keycode cheat sheet (physical_keycode values)

| Key | Value | | Key | Value |
|-----|-------|-|-----|-------|
| A–Z | ASCII uppercase: A=65 … W=87 … Z=90 | | Space | 32 |
| 0–9 | ASCII: 0=48 … 9=57 | | Enter | 4194309 |
| Shift | 4194325 | | Escape | 4194305 |
| Ctrl | 4194326 | | Tab | 4194306 |
| Alt | 4194328 | | E | 69 |

WASD = W 87, A 65, S 83, D 68. To confirm any key, `grep` the addon or Godot source for the
`KEY_*` constant, or check `@GlobalScope` key enums.

Mouse buttons use `InputEventMouseButton` (`"button_index":1` left / `2` right / `3` middle)
instead of `InputEventKey` — note the different field set:
```
Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
```
An action's `events` array can mix event types (e.g. a mouse click AND a key) — that's how you
bind "advance" to both left-click and Space.

## Third-party addons may REQUIRE a specific action name
Some addons drive themselves off a named input action and assume the editor created it. The one
that bites here: **Dialogic advances dialogue only via an action literally named
`dialogic_default_action`** (project setting `dialogic/text/input_action`). If it's missing,
dialogue never advances AND the debugger floods with "action not found" errors — but only once
input actually fires, so a headless boot won't reveal it. Define it (mouse-left + Space) exactly
by that name. See `godot-dialogic-integration`. General rule: when wiring an addon by hand,
grep it for `input_action` / `is_action_pressed` and create any action names it expects.

## Reading the actions in code

```gdscript
# Two opposing axes at once (great for movement):
var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
# Held / just-pressed:
if Input.is_action_pressed("run"): ...
if event.is_action_pressed("interact"): ...   # in _unhandled_input
```

`get_vector(neg_x, pos_x, neg_y, pos_y)` returns a normalized-ish vector; forward mapped to
`neg_y` gives `y < 0`, which lines up with Godot's -Z forward (see `godot-thirdperson-controller`).

## Built-ins you get for free
`ui_accept` (Enter/Space), `ui_cancel` (Escape), `ui_up/down/left/right`. Fine for menus and
quick debug toggles, but bind **gameplay** to your own named actions — don't ship gameplay on
`ui_*`.

## Verify — and the fallback
A malformed `[input]` block is higher blast-radius than a bad script (it can make Godot log
errors on project load). After editing, run `--import` and scan for `ERROR:`/parse errors,
then boot and confirm the action works.

**If the text form keeps fighting you**, register at runtime instead — reliable, plain-text,
and reproducible (the Phantom Camera examples do exactly this):

```gdscript
func _ensure_action(action: StringName, physical_keycode: int) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action)
    var ev := InputEventKey.new()
    ev.physical_keycode = physical_keycode
    InputMap.action_add_event(action, ev)
```

Call these from an early `_ready()` (e.g. the persistent root). Trade-off: the bindings won't
show in Project Settings → Input Map. Prefer `project.godot` for discoverability; fall back to
runtime only when the serialization is being stubborn.
