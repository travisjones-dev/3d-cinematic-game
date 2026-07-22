class_name QuestStage
extends Resource
## One stage of a quest. Data only — quest progression reads these against GameState flags;
## it never queries world state directly (CLAUDE.md). Authored in .tres files under data/quests/.

## Objective text shown to the player for this stage.
@export var summary: String = ""

## The GameState flag whose truth completes this stage and advances the quest. Namespaced,
## e.g. "act1/reached_shore". Empty = a terminal/manual stage that never auto-advances.
@export var complete_flag: String = ""

## Flags set the moment this stage becomes active (e.g. to unlock a door, mark a beat seen).
## Keep these from being another stage's complete_flag unless an instant chain is intended.
@export var set_flags_on_enter: Array[String] = []
