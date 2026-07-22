---
name: godot-cutscene-tech
description: >-
  Build a cutscene in this Godot project — an AnimationPlayer conducting a Phantom
  Camera shot (priority cut + camera move) plus timed Dialogic lines, made skippable
  and fire-once. Use this WHENEVER the task involves a cutscene, cinematic, scripted
  camera sequence, in-engine "trailer" moment, or an AnimationPlayer driving cameras/
  dialogue. Covers hand-authoring Animation/AnimationLibrary in .tscn, the reusable
  Cutscene controller, and the class_name-script-referencing-a-uid-autoload trap that
  breaks the whole project with a misleading cascade of errors.
---

# Cutscene tech (AnimationPlayer + Phantom Camera + Dialogic)

Cutscenes are how the story pillar lands its big beats (e.g. the opening "boats + dropped
sword"). The pattern, proven in Phase C Spike 2: an **AnimationPlayer is the conductor** — it
keyframes the camera cut, the camera move, and a cue that fires a dialogue line — wrapped in a
reusable controller that makes it skippable and save-safe.

## ⚠️ The trap that cost the most: class_name script + uid-registered autoload

`cutscene.gd` has `class_name Cutscene` and originally called `Dialogic.start(...)` by the
autoload's global name. That compiled and ran headless — but in the **editor** it failed with
`Compile Error: Identifier not found: Dialogic`, which then cascaded into `PhantomCameraManager`
and every other autoload "not found," making the whole scene look broken.

Why: the editor compiles `class_name` (global) scripts during its startup scan; the `Dialogic`
autoload is registered by a **`uid://` path**, and that global isn't reliably available that
early, so the class fails to compile → the global-class table breaks → autoloads don't
instantiate. (Our own `res://`-path autoloads like `GameState`/`EventBus` resolve fine — only
the uid one bites, and only from a `class_name` script.)

**Rule:** in a `class_name` script, don't reference a uid-registered autoload by its global
name. Reach it through the tree at runtime:
```gdscript
var dialogic: Node = get_node_or_null(^"/root/Dialogic")
if dialogic != null and dialogic.has_method(&"start"):
    dialogic.call(&"start", timeline_path)
```
And when a compile error has already cascaded, **Project → Reload Current Project** (or restart
Godot) to clear the broken state — the code fix alone won't un-break the running editor session.
The first error line in the debugger is the root; everything under it is cascade — fix that one.

## The reusable controller — `scripts/components/cutscene.gd`

`class_name Cutscene extends Node`. Responsibilities: gate on a completion flag (fire-once +
save-safe), announce on EventBus, support skipping. The AnimationPlayer does the actual
choreography; the controller coordinates lifecycle.

- `completion_flag` (GameState flag) → `already_seen()` blocks replay; `finish()` sets it. This
  is what makes a cutscene fire once and survive saves.
- `play()` emits `EventBus.cutscene_started`, plays the animation, and connects
  `animation_finished` (ONE_SHOT) → `finish()`. No animation? It finishes immediately.
- `show_line()` is called from a method track (see below) to trigger a Dialogic line.
- `skip()` seeks to the animation's final keyframes (so the camera priority resolves back to
  gameplay) then `finish()`s — bound to an input action in `_unhandled_input`.
- `finish()` is idempotent (guarded by an `_playing` flag) so an end method-track and
  `animation_finished` can't double-fire it.

Wire it in the scene via exported `animation_player` (NodePath), `animation_name`,
`completion_flag`, `line_timeline`.

## AnimationPlayer as conductor — hand-authoring the Animation in .tscn

An AnimationPlayer needs an `AnimationLibrary` holding named `Animation`s. Three track kinds
cover a cutscene:

```
[sub_resource type="Animation" id="Anim_cutscene"]
resource_name = "cutscene"
length = 4.0
; VALUE track — cut by animating a PhantomCamera3D's priority (setter notifies the host):
tracks/0/type = "value"
tracks/0/path = NodePath("CutscenePcam:priority")
tracks/0/interp = 1
tracks/0/keys = {"times": PackedFloat32Array(0, 4),"transitions": PackedFloat32Array(1, 1),"update": 1,"values": [30, 0]}
; VALUE track — the camera move (continuous interp):
tracks/1/type = "value"
tracks/1/path = NodePath("CutscenePcam:position")
tracks/1/interp = 1
tracks/1/keys = {"times": PackedFloat32Array(0, 4),"transitions": PackedFloat32Array(1, 1),"update": 0,"values": [Vector3(0, 3, 6), Vector3(0, 1.8, -2)]}
; METHOD track — cue a dialogue line (or any callback) at a time:
tracks/2/type = "method"
tracks/2/path = NodePath(".")
tracks/2/keys = {"times": PackedFloat32Array(0.4),"transitions": PackedFloat32Array(1),"values": [{"args": [],"method": &"show_line"}]}

[sub_resource type="AnimationLibrary" id="AnimLib"]
_data = {&"cutscene": SubResource("Anim_cutscene")}

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {&"": SubResource("AnimLib")}
```
Key points:
- `update`: `0` continuous (smooth moves), `1` discrete (stepped, e.g. int priority). `interp`:
  `0` nearest / `1` linear / `2` cubic.
- **Method-track paths resolve relative to the AnimationPlayer's `root_node`** (default `..` =
  its parent). `NodePath(".")` targets that parent — put the controller script there so
  `show_line` resolves.
- **Cut via priority:** the cutscene PhantomCamera3D starts at low priority; keying it above the
  gameplay pcam makes the host cut to it (its `set_priority` setter notifies the manager). Key it
  back down at the end so skip/finish resolve to the gameplay camera. See `godot-phantom-camera`.
- Cutscene cameras use `follow_mode = 0` (none) so their transform IS the shot, animatable directly.

## Pacing a multi-beat cutscene (let it breathe)
A single push + one line reads as rushed. Build the shot as timed beats on one longer Animation
(the shore cutscene is ~32s): establish → reveal → break → run. Techniques:
- **Multiple position keys** on the pcam for distinct framings per beat (drift in, hold on the
  reveal, move to the subject, pull back), linear interp.
- **A `visible` value track (discrete)** to make things *appear* on cue — the raider boats start
  `visible = false` and flip true at the reveal beat, so they emerge rather than being there the
  whole time.
- **A `rotation` value track** to animate a graybox actor "breaking" — e.g. tip the friend capsule
  forward (`rotation` → `Vector3(-1.3, 0, 0)`) as he drops to his knees.
- **One method track with several keys**, each passing a beat index:
  `{"method": &"_narrate", "args": [0]}`, `[1]`, `[2]`, `[3]` at spaced times. The zone's
  `_narrate(beat)` picks the line (and can branch on a flag, e.g. the friend-promise).

### ⚠️ Beat spacing MUST be ≥ the HUD line display duration
The readability bug playtesters hit: beats were spaced ~4s apart while each HUD narration line
wanted ~5.5s on screen, so every line was *replaced by the next beat before it could be read*.
Each `_narrate` beat replaces the on-screen line, so the gap between beats is the actual reading
window. Rule: **space beats ≥ the HUD display duration, plus a small buffer.** Current working
values — beats ~7–7.5s apart, HUD narration hold 6.5s (`hud.gd:_on_narration_requested`, see
`godot-hud-feedback`). If a cutscene reads too fast, this coupling is the first thing to check.

**To slow an existing cutscene, scale ALL keyframe times proportionally** (every track: camera
positions, `visible`/`rotation` cues, and the method beats) plus the animation `length` — not
just the beat times — or the camera moves and reveals desync from the narration. The shore
cutscene was slowed from 16s → 32s by scaling everything ×2 and widening the beat gaps.

- **Give the player the approach.** Let them walk (with control) up to the moment, then a trigger
  Area3D fires the cutscene — the calm before lands the shock. Don't cut straight in on load.

Use **HUD narration** (`EventBus.narration_requested`) for cutscene lines, not a Dialogic timeline —
a Dialogic line mid-cutscene fires `timeline_started` (suspends the player) and won't end without an
advance, hanging the dialogue coordination (see `godot-dialogic-integration`).

## Verify
Import (parse-checks the hand-authored Animation), run the controller's logic tests (fire-once
flag, EventBus emits, already-seen gating — all headless-safe), and boot the scene for more
frames than the animation length to confirm the method track fires with no runtime errors. The
shot's *look* and the skip are human-tested — and remember the editor-only class_name trap above
won't show in a headless boot.
