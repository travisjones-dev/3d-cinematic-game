---
name: godot-quest-system
description: >-
  Build or extend quests in this Godot project — QuestResource/QuestStage data
  (.tres), the QuestManager autoload that advances stages by reading GameState
  flags, and the HUD quest toast. Use this WHENEVER the task involves quests, quest
  stages/objectives, quest progression or completion, a quest log/journal, a quest
  update notification, or making a dialogue choice / world event advance a quest.
  Encodes the save-safe "stage index lives in GameState" design and how quests
  compose with the dialogue bridge for free.
---

# Quest system (data-driven, flag-advanced, save-safe)

Quests are the "minimum viable RPG" layer (CLAUDE.md pillar #4 — first to cut, so keep it
lean). The design keeps GameState as the single source of truth and reuses existing plumbing,
so quests are save-safe and dialogue-drivable with almost no new wiring. Proven in Phase C Spike 3.

## Architecture

- **Data (`.tres`):** `QuestResource` (`scripts/data/quest_resource.gd`) = `id`, `title`,
  `Array[QuestStage]`. `QuestStage` (`quest_stage.gd`) = `summary` (objective text),
  `complete_flag` (the GameState flag that finishes the stage), `set_flags_on_enter`. Both are
  `class_name` Resources authored as `.tres` under `data/quests/` (see the typed-array note in
  `godot-scene-authoring`). Narrative text (`title`/`summary`) is a human-writing-pass item.
- **Logic (`QuestManager` autoload):** advances registered quests as flags change. **Quest logic
  reads flags only — never world state** (CLAUDE.md).
- **State (GameState):** the live **stage index lives in `GameState.quests`** via
  `get/set_quest_stage`. That means quests are **save-safe for free** (SaveManager already
  serializes GameState), and `set_quest_stage` **already emits `EventBus.quest_updated`** — no new
  signal needed.

Stage-index convention: `-1` not started · `0..count-1` active stage · `>= count` complete.

## QuestManager essentials

```gdscript
func register(quest: QuestResource) -> void        # make known (load the .tres, pass it)
func start(quest_id: String) -> void                # set stage 0 + apply enter-flags
func is_active(id) -> bool
func is_complete(id) -> bool                         # stage index >= stage_count()
func get_current_summary(id) -> String
```

Advancement is driven by a single `EventBus.flag_changed` handler that re-checks each quest:

```gdscript
func _on_flag_changed(_flag, _value) -> void:
    for quest_id in _quests:
        _try_advance(quest_id)

# advance through EVERY stage whose complete_flag is now set, in one pass:
func _try_advance(quest_id) -> void:
    var quest := _quests[quest_id]
    while true:
        var idx := GameState.get_quest_stage(quest_id)
        if idx < 0 or idx >= quest.stage_count(): return   # not started / complete
        var stage := quest.get_stage(idx)
        if stage and stage.complete_flag != "" and GameState.get_flag(stage.complete_flag):
            GameState.set_quest_stage(quest_id, idx + 1)    # emits quest_updated
            if idx + 1 < quest.stage_count(): _enter_stage(quest_id, idx + 1)
        else:
            return
```
The `while` loop matters: if several completion flags are already set (e.g. after a load), the
quest catches up through all of them in one pass instead of stalling one stage behind.

## It composes for free

Because advancement keys off `flag_changed` and GameState is the shared truth:
- **Dialogue advances quests with zero extra code.** A timeline that sets a stage's
  `complete_flag` (via the signal bridge — `[signal arg="set_flag act1/reached_shore"]`, see
  `godot-dialogic-integration`) makes QuestManager advance automatically. The DialogueBridge also
  has a direct `quest <id> <stage>` command.
- **Any system** (a zone-exit interactable, a cutscene finishing) that sets a flag can complete a
  quest stage. Don't special-case quests — just set the flag.

## HUD toast

The HUD listens to `EventBus.quest_updated(id, stage)` and shows a label
(`QuestManager.get_title` + `get_current_summary`, or a "Quest complete" line), then auto-hides.
Use a **token guard** so overlapping updates don't hide a newer toast early:
```gdscript
_toast_token += 1
var mine := _toast_token
await get_tree().create_timer(3.5).timeout
if mine == _toast_token: _quest_toast.visible = false
```

## Testing (headless)
QuestManager logic is fully unit-testable (the toast is human-tested): load the `.tres`, `start`,
set a stage's `complete_flag`, assert the stage advanced and `quest_updated` emitted, assert
completion, and assert an unrelated flag does nothing. `QuestManager` is an autoload that persists
across tests — `register()` is idempotent and `GameState.reset()` in `before_each` clears stage
indices, so tests stay isolated. See `godot-gut-headless-testing`.
