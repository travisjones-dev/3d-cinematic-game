class_name Cutscene
extends Node
## Reusable cutscene controller. An AnimationPlayer is the conductor — it keyframes the Phantom
## Camera priority (to cut to a cinematic shot), the camera move, and a method-call cue that
## triggers a Dialogic line. This script gates the whole thing behind a GameState completion
## flag so it fires ONCE and is save-safe, announces itself on EventBus, and supports skipping.
##
## Scene wiring: put this on the cutscene root, point `animation_player` at the AnimationPlayer,
## set `animation_name` + `completion_flag` (+ optional `line_timeline`). In the animation, add a
## method-call track that calls `show_line()` when the line should appear. The end of the shot is
## detected via animation_finished — no end method track needed. Skipping seeks to the final
## keyframes (so the camera priority resolves back to gameplay) then finishes.

signal finished

@export var animation_player: AnimationPlayer
@export var animation_name: StringName = &"cutscene"
## The flag set on completion. Empty = always replays (spike/testing).
@export var completion_flag: String = ""
## Optional Dialogic timeline path shown mid-shot (called from show_line()).
@export var line_timeline: String = ""
@export var skip_action: StringName = &"ui_cancel"
@export var autoplay_on_ready: bool = true

var _playing: bool = false

func _ready() -> void:
	if autoplay_on_ready and not already_seen():
		play()

## True once the cutscene has been completed (or skipped) — so it never replays and survives saves.
func already_seen() -> bool:
	return completion_flag != "" and GameState.get_flag(completion_flag)

func play() -> void:
	if _playing or already_seen():
		return
	_playing = true
	EventBus.cutscene_started.emit(completion_flag)
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		animation_player.play(animation_name)
	else:
		finish()  # no animation to run — complete immediately

## Called by a method-call track partway through the shot.
func show_line() -> void:
	if line_timeline == "":
		return
	# Reach Dialogic through the tree rather than the `Dialogic` autoload global. This script
	# has a class_name, so the editor compiles it during its global-class scan — and the
	# uid-registered Dialogic autoload isn't reliably a known global at that point, which
	# fails with "Identifier not found: Dialogic" and cascades into autoloads not loading.
	var dialogic: Node = get_node_or_null(^"/root/Dialogic")
	if dialogic != null and dialogic.has_method(&"start"):
		dialogic.call(&"start", line_timeline)
	else:
		push_warning("Cutscene: Dialogic autoload unavailable; skipping line '%s'." % line_timeline)

## Ends the cutscene: sets the completion flag (fire-once, save-safe) and announces completion.
func finish() -> void:
	if not _playing:
		return
	_playing = false
	if completion_flag != "":
		GameState.set_flag(completion_flag)
	EventBus.cutscene_finished.emit(completion_flag)
	finished.emit()

## Jumps to the shot's final keyframes (resolving camera priority back to gameplay) and finishes.
func skip() -> void:
	if not _playing:
		return
	if animation_player != null and animation_player.is_playing():
		animation_player.seek(animation_player.current_animation_length, true)
		animation_player.stop()
	finish()

func _on_anim_finished(_anim_name: StringName) -> void:
	finish()

func _unhandled_input(event: InputEvent) -> void:
	if _playing and event.is_action_pressed(skip_action):
		skip()
