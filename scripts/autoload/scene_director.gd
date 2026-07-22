extends Node
## SceneDirector — owns zone transitions: fade out -> free old zone -> instantiate
## new zone under ZoneRoot -> move player to the named SpawnPoint -> fade in. This
## is the only code that touches the scene tree for zone swaps.
##
## main.tscn calls register_main() once its persistent tree exists. Zones are
## loaded by name from res://scenes/zones/<name>.tscn and must contain a
## SpawnPoints group with a Node3D named after the requested spawn point.

signal transition_started(to_zone: String)
signal transition_finished(to_zone: String)

const ZONE_DIR: String = "res://scenes/zones"
const DEFAULT_SPAWN: String = "spawn_default"

@export var fade_duration: float = 0.4

var zone_root: Node3D = null
var player: Node3D = null
var fade_rect: ColorRect = null

var _current_zone: Node = null
var _current_zone_name: String = ""
var _transitioning: bool = false

## Called by main.tscn's root script once the persistent tree exists.
func register_main(p_zone_root: Node3D, p_player: Node3D, p_fade_rect: ColorRect) -> void:
	zone_root = p_zone_root
	player = p_player
	fade_rect = p_fade_rect

func is_ready_for_transitions() -> bool:
	return zone_root != null and player != null

func is_transitioning() -> bool:
	return _transitioning

func get_current_zone_name() -> String:
	return _current_zone_name

## Loads the opening zone with no fade-out (screen starts clear).
func load_initial_zone(zone_name: String, spawn_point: String = DEFAULT_SPAWN) -> void:
	if not is_ready_for_transitions():
		push_warning("SceneDirector: not registered; cannot load zone '%s'." % zone_name)
		return
	_swap_zone(zone_name, spawn_point)
	if fade_rect != null:
		fade_rect.color.a = 0.0

## Fades out, swaps to the named zone, places the player at spawn_point, fades in.
func change_zone(zone_name: String, spawn_point: String = DEFAULT_SPAWN) -> void:
	if _transitioning:
		return
	if not is_ready_for_transitions():
		push_warning("SceneDirector: not registered; cannot change to '%s'." % zone_name)
		return
	_transitioning = true
	transition_started.emit(zone_name)
	await _fade_to(1.0)
	_swap_zone(zone_name, spawn_point)
	await _fade_to(0.0)
	_transitioning = false
	transition_finished.emit(zone_name)

# --- internals ---

func _zone_path(zone_name: String) -> String:
	return "%s/%s.tscn" % [ZONE_DIR, zone_name]

## Loads a zone and drops the player at an explicit transform (used by save-load, which
## restores the exact position rather than a spawn point). No fade — caller decides.
func load_into(zone_name: String, player_transform: Transform3D) -> void:
	if not is_ready_for_transitions():
		push_warning("SceneDirector: not registered; cannot load_into '%s'." % zone_name)
		return
	if not _instantiate_zone(zone_name):
		return
	player.global_transform = player_transform
	if fade_rect != null:
		fade_rect.color.a = 0.0
	EventBus.zone_entered.emit(zone_name)

func _swap_zone(zone_name: String, spawn_point: String) -> void:
	if not _instantiate_zone(zone_name):
		return
	_place_player(_current_zone, spawn_point)
	EventBus.zone_entered.emit(zone_name)

## Frees the current zone and mounts the named one under ZoneRoot. Returns false if the
## zone scene couldn't be loaded. Does NOT place the player or emit zone_entered — callers
## do that, so both spawn-point and explicit-transform placement share this.
func _instantiate_zone(zone_name: String) -> bool:
	# Free immediately (not deferred) so the new zone is alone in ZoneRoot when searched.
	if _current_zone != null and is_instance_valid(_current_zone):
		zone_root.remove_child(_current_zone)
		_current_zone.free()
	_current_zone = null

	var path: String = _zone_path(zone_name)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("SceneDirector: could not load zone at %s" % path)
		return false
	_current_zone = packed.instantiate()
	zone_root.add_child(_current_zone)
	_current_zone_name = zone_name
	return true

func _place_player(zone: Node, spawn_point: String) -> void:
	var spawn: Node = zone.find_child(spawn_point, true, false)
	if spawn is Node3D:
		player.global_transform = (spawn as Node3D).global_transform
	else:
		push_warning("SceneDirector: spawn point '%s' not found in zone '%s'." % [spawn_point, _current_zone_name])

func _fade_to(target_alpha: float) -> void:
	if fade_rect == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, fade_duration)
	await tween.finished

## Slowly fades the screen to black over `duration` seconds — for endings/scene closeouts,
## independent of the quick transition fade. Leaves the screen black (no auto fade-in).
func fade_to_black(duration: float = 2.0) -> void:
	if fade_rect == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	await tween.finished
