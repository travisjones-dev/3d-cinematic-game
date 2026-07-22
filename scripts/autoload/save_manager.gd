extends Node
## SaveManager — serializes GameState plus an envelope (version, zone, player
## transform) to user:// as JSON. Save-safe by construction: story state is just
## GameState's dicts, so any new flag is persisted automatically.

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves"

func _save_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

## Writes a save. Returns true on success.
func save_game(slot: int, zone: String, player_transform: Transform3D) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"zone": zone,
		"player_transform": _transform_to_array(player_transform),
		"state": GameState.to_dict(),
	}
	var f: FileAccess = FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open save for writing: %s" % _save_path(slot))
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	EventBus.save_completed.emit(slot)
	return true

## Loads a save into GameState and returns the full payload dict (empty on failure).
func load_game(slot: int) -> Dictionary:
	var path: String = _save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: no save at slot %d" % slot)
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SaveManager: cannot open save for reading: %s" % path)
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: corrupt save at slot %d" % slot)
		return {}
	var data: Dictionary = parsed
	GameState.from_dict(data.get("state", {}))
	EventBus.load_completed.emit(slot)
	return data

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_save_path(slot))

func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_save_path(slot))

# --- Transform (de)serialization: 12 floats, basis then origin ---

func _transform_to_array(t: Transform3D) -> Array:
	return [
		t.basis.x.x, t.basis.x.y, t.basis.x.z,
		t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z,
		t.origin.x, t.origin.y, t.origin.z,
	]

static func array_to_transform(a: Array) -> Transform3D:
	if a.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(
		Basis(
			Vector3(a[0], a[1], a[2]),
			Vector3(a[3], a[4], a[5]),
			Vector3(a[6], a[7], a[8])),
		Vector3(a[9], a[10], a[11]))
