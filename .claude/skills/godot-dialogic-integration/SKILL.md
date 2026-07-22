---
name: godot-dialogic-integration
description: >-
  Wire Dialogic 2 (alpha-19) into this Godot project — author .dtl timelines as
  plain text, branch/choose on GameState flags, write flags back from dialogue, and
  start timelines from code. Use this WHENEVER the task touches dialogue, Dialogic,
  timelines, conversations, NPC lines, dialogue choices/branching, or cutscene text.
  Front-loads the three setup gotchas that cost hours the first time: choices inside
  if/else branches don't show, the choice layout/style must be set explicitly, and
  the `dialogic_default_action` input action must be created by hand or dialogue can
  never advance (and the debugger floods with errors).
---

# Dialogic 2 (alpha-19) integration

Dialogic drives all dialogue and cutscene text — the sacred story pillar (CLAUDE.md). This
skill is the working setup for the installed version, verified in the Phase C Spike 1. The
whole thing is plain-text and CLI-verifiable; the on-screen dialogue itself is human-tested.

## ⚠️ Read this first — the three setup gotchas

These are silent or misleading failures. Check them before debugging anything else.

1. **`dialogic_default_action` input action MUST exist.** Dialogic advances text only when the
   input action named `dialogic_default_action` fires (`Modules/Text/node_input.gd`). The
   Dialogic *editor* normally creates it for you; a hand-authored project has to add it to
   `project.godot [input]` (bind mouse-left + Space). **Missing it = dialogue never advances,
   AND the debugger spams thousands of "action not found" errors — but only once real input
   happens, so a `--headless` boot with no input WON'T surface it.** See `godot-input-map`.
2. **Set a style that has choice buttons.** `Dialogic.start()` loads the style from the
   `dialogic/layout/default_style` project setting; if choices don't appear, set it explicitly
   to the bundled VN style:
   `dialogic/layout/default_style="res://addons/dialogic/Modules/DefaultLayoutParts/Style_VN_Default/default_vn_style.tres"`
   (that style includes the `Layer_VN_Choices` layer; a bare/fallback layout may not show choices).
3. **Don't nest choices inside an `if/else` branch.** Dialogic's "is the next event a question?"
   check doesn't reliably see choices across a condition-branch boundary, so the buttons never
   trigger. Put choices at the **top level** and gate each one with its own `[if …]` instead
   (see the pattern below). This is cleaner anyway.

**Debugging rule:** when a Dialogic feature silently misbehaves, get the in-editor **Debugger/
Output** error list from the human first — input-triggered errors (like #1) never appear in a
headless boot, so the running editor is the source of truth for those.

## The bridge: GameState is the single source of truth

Dialogic evaluates conditions/expressions with every autoload bound as an input
(`Modules/Core/subsystem_expression.gd`), so timelines call our singletons directly. No
mirroring/syncing — flags live only in GameState (CLAUDE.md).

- **READ (needs no glue):** a condition or a choice gate calls GameState:
  `GameState.get_flag("act1/x") == true`
- **WRITE (thin bridge):** a timeline emits Dialogic's `signal` event; the `DialogueBridge`
  autoload (`scripts/dialogue/dialogic_bridge.gd`) translates it to a GameState call:
  - `[signal arg="set_flag act1/x"]`        → `GameState.set_flag("act1/x", true)`
  - `[signal arg="set_flag act1/x false"]`  → `GameState.set_flag("act1/x", false)`
  - `[signal arg="clear_flag act1/x"]`      → `GameState.clear_flag("act1/x")`
  - `[signal arg="quest act1/rescue 2"]`    → `GameState.set_quest_stage("act1/rescue", 2)`

DialogueBridge is an autoload registered AFTER Dialogic (it connects `Dialogic.signal_event`
in `_ready`). To add commands, extend its `match` in `_handle_command`.

## Authoring .dtl timelines (plain text, tab-indented)

`.dtl` files are pure text — one event per line, **tabs** for nesting. A `ResourceFormatLoader`
turns them into `DialogicTimeline` at load; Dialogic also auto-registers hand-written `.dtl`
files into `project.godot [dialogic] directories/dtl_directory` on import (so you can start
them by name).

Event syntax:
- **Narration:** a bare line of text (avoid colons — `Name: text` is parsed as a speaker line).
- **Speaker line:** `Elder: Welcome home, lad.` (needs a `.dch` character; skip for spikes).
- **Choice:** `- Take the sword` with an optional gate `- Take the sword [if <expr>]`; the chosen
  branch's events are indented one tab under it.
- **Condition block:** `if <expr>:` / `elif <expr>:` / `else:` with an indented body.
- **Signal (write a flag):** `[signal arg="set_flag act1/x"]`

**Canonical pattern — conditional choices reading + writing GameState (avoids gotcha #3):**
```
A cracked pedestal holds an old sword.
- Take the sword [if GameState.get_flag("act1/spike_sword_taken") == false]
	[signal arg="set_flag act1/spike_sword_taken"]
	Your fingers close around the hilt.
- Leave it [if GameState.get_flag("act1/spike_sword_taken") == false]
	You let it rest.
- (The pedestal is bare.) [if GameState.get_flag("act1/spike_sword_taken") == true]
	Nothing remains to take.
```
Use `== false` / `== true` rather than a `not`/`!` prefix — the Godot `Expression` class the
condition runs through is picky about the negation keyword; the comparison form is reliable.

## Starting a timeline from code
```gdscript
Dialogic.start("res://dialogue/spikes/bridge_test.dtl")   # full path, always works
Dialogic.start("bridge_test")                             # by name, once registered in dtl_directory
```
`Dialogic.start()` auto-loads the configured layout (see gotcha #2). Connect
`Dialogic.timeline_started` / `Dialogic.timeline_ended` to react.

**⚠️ Don't reference `Dialogic` by its global name inside a `class_name` script.** Dialogic is
registered as an autoload via a `uid://` path; the editor compiles `class_name` (global) scripts
during its startup scan, before that uid global is reliably available, so it fails with
`Compile Error: Identifier not found: Dialogic` — which cascades into *every* autoload appearing
"not found" and looks like the whole project is broken. Reach it through the tree instead:
```gdscript
var dialogic: Node = get_node_or_null(^"/root/Dialogic")
if dialogic != null and dialogic.has_method(&"start"):
    dialogic.call(&"start", timeline_path)
```
Plain (non-`class_name`) scripts and autoloads can use the `Dialogic` global directly — only
`class_name` scripts hit this. After such a cascade, reload the project to clear the broken
editor state. Full detail in `godot-cutscene-tech`.

## Testing the bridge headlessly
Dialogue *display* needs rendering (human-tested), but the bridge logic is unit-testable
(`tests/test_dialogue_bridge.gd`):
```gdscript
# WRITE path — emit Dialogic's signal, assert GameState changed:
Dialogic.emit_signal("signal_event", "set_flag act1/x")
assert_true(GameState.get_flag("act1/x"))

# READ path — evaluate a condition against GameState:
GameState.set_flag("act1/z", true)
assert_true(Dialogic.Expressions.execute_condition('GameState.get_flag("act1/z")'))

# Timeline is well-formed:
var tl := load("res://dialogue/spikes/bridge_test.dtl")
tl.process()
assert_gt(tl.events.size(), 0)
```

## Context-aware NPC dialogue (branch on progress) — jump/label, not nested branches
An NPC that says different things depending on story progress must NOT put its choices inside the
condition branches (gotcha #3). Instead, guard with top-level `if …: … jump end` blocks that skip to
a `label end`, and keep the first-meeting choices at the top level:
```
if GameState.get_flag("act1/ready_to_leave") == true:
	He waves you on toward the trees.
	jump end
if GameState.get_flag("act1/talked_to_friend") == true:
	Elin is still waiting up at the tower. Go on.
	jump end
Your friend claps your shoulder. Walk with me down to the shore?
- Race you there.
	He laughs.
- Stay close out there.
	[signal arg="set_flag act1/promised_to_protect"]
	Always, brother.
He nods toward the tower. But say goodbye to Elin first.
[signal arg="set_flag act1/talked_to_friend"]
label end
```
`jump <label>` / `label <name>`. This gives re-greetings that reflect what you've done, with the
first-visit choices safely top-level. Avoid colons in narration lines (a colon is parsed as
`Speaker: text`); a leading `"` is also misparsed, so open lines with prose, not a quote.

### ⚠️ Place a quest-advancing flag at the END of the timeline, not after the first line
A `[signal arg="set_flag …"]` fires the instant the timeline reaches it. If that flag is what a
quest watches to advance (see `godot-quest-system`), putting it right after the opening line makes
the "next objective" toast pop **mid-conversation** — the NPC is still talking and the toast
already says "go to the tower." Put the advancing flag on the **last beat before `label end`**, so
the quest only advances once the player has actually heard the whole exchange. (Choice-local flags
like `promised_to_protect` above are fine where they are — they record *what was said*, they don't
advance the quest.) This bit both the friend and Elin timelines in Act 1.

## Coordinating dialogue with gameplay (freeze movement, free the mouse)
Starting a conversation while the player is walking needs a handshake, or they keep moving and the
cursor stays captured (can't click choices). Route it through EventBus so gameplay never touches
Dialogic:
- `DialogueBridge` re-emits `Dialogic.timeline_started/ended` as `EventBus.dialogue_started/ended`.
- The **player** suspends movement + interaction on `dialogue_started`, resumes on `dialogue_ended`.
- **main** sets the mouse `VISIBLE` on `dialogue_started`, `CAPTURED` on `dialogue_ended`.

**Cutscene corollary:** a Dialogic line inside a cutscene *also* fires `timeline_started` (suspending
the player) and won't end until advanced — during a non-interactive cutscene nobody advances, so it
hangs the coordination. For cutscene text, prefer **timed HUD narration** (`EventBus.narration_requested`,
auto-clearing) rather than a Dialogic conversation. See `godot-cutscene-tech`.

## Verify
Run `--import` (Dialogic parses .dtl and registers it; scan for parse errors), then the GUT
suite, then **have a human run the scene** and watch a flag flip when a choice is made and the
option list change on replay. Remember: the `dialogic_default_action` failure is invisible to
headless — confirm advancing works on screen or via the editor Debugger.
