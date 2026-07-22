---
name: godot-hud-feedback
description: >-
  Add or fix on-screen HUD feedback in this Godot project — quest toasts, flavor/
  narration lines, pickup or objective notifications, any transient message that
  appears then auto-clears. Use this WHENEVER the task involves a message popping up
  on the HUD, styling such a message for readability over the 3D scene, fading one
  in/out, or debugging one that vanishes too soon, lingers, "flies away," or gets
  clobbered when a second message arrives. Encodes the EventBus-listener design, the
  token-guard that stops a stale timer from hiding a newer message, and the tween
  handle that stops two fades fighting over the same property.
---

# HUD feedback: transient on-screen messages

The HUD (`scenes/ui/hud.tscn` + `scripts/ui/hud.gd`) is a **pure EventBus listener** — it
shows/hides UI in response to signals and never reaches into gameplay nodes (matching the
project's "systems talk through EventBus" rule). New feedback elements hang off new signals
here as they land. Three already live: the interaction prompt (see `godot-interaction-system`),
the quest toast (`quest_updated`), and flavor/narration lines (`narration_requested`, also used
for cutscene beats — see `godot-cutscene-tech`).

## The token-guard: the non-obvious part
A transient message shows, waits N seconds, then hides. The trap: if a **second** message
arrives before the first's timer expires, the first timer will fire and hide the *second*
message early. Guard every auto-hide with a monotonic token:

```gdscript
var _toast_token: int = 0

func _on_quest_updated(...) -> void:
    _toast.text = ...
    _toast_token += 1
    var my_token: int = _toast_token          # capture THIS message's id
    # ... show it ...
    await get_tree().create_timer(6.0).timeout
    if my_token != _toast_token:               # a newer message took over — stand down
        return
    # ... hide it ...
```

Each transient element gets its **own** token counter (`_toast_token`, `_flavor_token`) so they
don't interfere. This pattern is already used twice in `hud.gd`; reuse it verbatim for any new
transient element rather than inventing a per-element `Timer` node.

## Fade in/out without tweens fighting
An instant show/hide reads as abrupt ("flies away"). Fade via a `Tween` on `modulate:a`, but
hold a handle and **kill the old tween before starting a new one** — otherwise a fade-in and a
fade-out (or two rapid updates) both animate the same property and stutter:

```gdscript
var _toast_tween: Tween = null
# ...
if _toast_tween != null and _toast_tween.is_valid():
    _toast_tween.kill()
_panel.visible = true
_toast_tween = create_tween()
_toast_tween.tween_property(_panel, "modulate:a", 1.0, 0.4)   # fade in
await get_tree().create_timer(6.0).timeout
# ... (token check) ...
if _toast_tween != null and _toast_tween.is_valid():
    _toast_tween.kill()
_toast_tween = create_tween()
_toast_tween.tween_property(_panel, "modulate:a", 0.0, 0.6)   # fade out
await _toast_tween.finished
```

Initialize hidden **and** transparent in `_ready()` (`visible = false`, `modulate.a = 0.0`) so
the first fade-in starts from zero.

## Readability over a 3D scene (styling in .tscn, plain text)
A bare `Label` on top of the game world is low-contrast and easy to miss — the opening quest
prompt was reported unreadable for exactly this reason. Make an important message prominent:

- Wrap the `Label` in a **`Panel`** with a `StyleBoxFlat` sub-resource: semi-opaque dark
  `bg_color` (e.g. `Color(0.05, 0.05, 0.08, 0.8)`), rounded `corner_radius_*`, and
  `content_margin_*` for padding. This is the background the text sits on.
- On the `Label`: `theme_override_font_sizes/font_size` (~26), a `theme_override_colors/
  font_outline_color` + `theme_override_constants/outline_size` (~4) for contrast, and
  `autowrap_mode = 2` so long lines wrap inside the panel.
- Anchor a toast as a band near the top (a Panel spanning ~0.22–0.78 width); center flavor/
  narration lower-middle. Default engine font (no custom font file) is fine — font-size and
  outline overrides need no binary asset, keeping it plain-text per project rules.

## Duration is coupled to whatever drives the message
The on-screen hold time isn't free to pick in isolation. For cutscene narration, the beat
spacing on the AnimationPlayer must be **≥ the HUD display duration** or each line is replaced
before it can be read — the coupling is owned by `godot-cutscene-tech`, but the display timer
lives here (`_on_narration_requested`, currently 6.5s). If you retune one, check the other.

## Verify
Logic is headless-testable via GUT by emitting the EventBus signal and asserting the label text
/ visibility (see `godot-gut-headless-testing`); the token-guard is worth a test (fire two
updates quickly, assert the second still shows after the first's timer would have elapsed). The
fade *look* and readability are human-tested.
