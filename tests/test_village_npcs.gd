extends GutTest
## Elder Mishka and the blacksmith — the two optional flavor NPCs in the village.
##
## Both were already placed in the zone as bare MeshInstance3D props and are named in
## docs/zones/zone_01_home_village.md; this covers turning them into talkable NPCs. Their beats are
## deliberately NOT wired into village_quest.tres (human decision 2026-07-27, recorded in ROADMAP) —
## they are optional world-building, so the tested quest chain and its save-safe stage indices are
## untouched.
##
## Mishka delivers first-hand the mist warning that friend.dtl already lets the player quote
## second-hand ("Elder Mishka said a thick mist is creeping in"), plus the darkness foreshadowing.
## Both land in the FIRST conversation so they cannot be missed; repeat visits get a shorter,
## bleaker restatement gated on act1/talked_to_elder.

const VILLAGE: PackedScene = preload("res://scenes/zones/zone_01_village.tscn")

const NPCS: Dictionary = {
	"Elder": "res://dialogue/act1/elder.dtl",
	"Blacksmith": "res://dialogue/act1/blacksmith.dtl",
}

func after_each() -> void:
	GameState.clear_flag("act1/talked_to_elder")
	GameState.clear_flag("act1/talked_to_blacksmith")

func test_new_timelines_parse() -> void:
	for path: String in NPCS.values():
		var tl: Resource = load(path)
		assert_not_null(tl, "%s loads" % path)
		tl.process()
		assert_gt(tl.events.size(), 0, "%s parsed into events" % path)

func test_both_npcs_are_talkable_and_point_at_their_timeline() -> void:
	var village: Node3D = VILLAGE.instantiate()
	add_child(village)
	await get_tree().process_frame

	for npc_name: String in NPCS:
		var npc: Node = village.get_node("NPCs/%s" % npc_name)
		assert_true(npc is Area3D, "%s must be an Area3D to detect the player" % npc_name)
		assert_true(npc is Interactable, "%s must compose the Interactable primitive" % npc_name)
		assert_eq(npc.timeline, NPCS[npc_name], "%s points at its own timeline" % npc_name)
		assert_ne(npc.get_prompt(), "", "%s has an interaction prompt" % npc_name)
		assert_not_null(npc.get_node_or_null("Trigger"), "%s has a detection shape" % npc_name)
		assert_not_null(npc.get_node_or_null("Mesh"), "%s kept its visual mesh" % npc_name)

	village.free()

func test_elder_repeat_visit_branch_is_gated_on_her_flag() -> void:
	# The escalation depends on the flag actually gating the branch, so prove the timeline reads it.
	var source: String = FileAccess.get_file_as_string("res://dialogue/act1/elder.dtl")
	assert_string_contains(source, 'GameState.get_flag("act1/talked_to_elder")',
		"elder.dtl must branch on her own flag for the repeat-visit line")
	assert_string_contains(source, "set_flag act1/talked_to_elder",
		"elder.dtl must set her flag so the repeat-visit branch can ever trigger")
	# Per the standing convention (human playtest 2026-07-21), a conversation's flag write belongs at
	# the END of the conversation, not mid-line.
	var lines: PackedStringArray = source.strip_edges().split("\n")
	var set_flag_line: int = -1
	for i in range(lines.size()):
		if lines[i].contains("set_flag act1/talked_to_elder"):
			set_flag_line = i
	assert_gt(set_flag_line, lines.size() - 4,
		"the set_flag should sit in the last beats of elder.dtl, not mid-conversation")

func test_mishka_delivers_the_mist_and_foreshadowing_beats() -> void:
	# These two beats are the entire reason she is talkable (user direction 2026-07-27). Guard them
	# so a later writing pass cannot quietly drop one. Deliberately loose keyword matching so the
	# prose stays free to change.
	var source: String = FileAccess.get_file_as_string("res://dialogue/act1/elder.dtl").to_lower()
	assert_string_contains(source, "mist", "Mishka must warn about the mist")
	assert_true(source.contains("darkness") or source.contains("something feels off"),
		"Mishka must deliver the foreshadowing beat")

func test_no_two_interaction_triggers_overlap() -> void:
	# player.gd:_on_interaction_available is LAST-ENTERED-WINS, not nearest-wins, so two overlapping
	# triggers let you stand at one NPC while showing the other's prompt. Guard the whole class.
	var village: Node3D = VILLAGE.instantiate()
	add_child(village)
	await get_tree().process_frame

	var boxes: Array = []
	for node in _find_interactables(village):
		var shape_node: CollisionShape3D = node.get_node_or_null("Trigger")
		if shape_node == null or not shape_node.shape is BoxShape3D:
			continue
		var extents: Vector3 = (shape_node.shape as BoxShape3D).size * 0.5
		var centre: Vector3 = shape_node.global_position
		boxes.append({
			"name": String(node.name),
			"aabb": AABB(centre - extents, extents * 2.0),
		})

	assert_gt(boxes.size(), 4, "should have found the village's interaction triggers")
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			assert_false((a["aabb"] as AABB).intersects(b["aabb"] as AABB),
				"%s and %s triggers overlap; last-entered-wins would show the wrong prompt" % [a["name"], b["name"]])

	village.free()

func _find_interactables(root: Node) -> Array:
	var found: Array = []
	for child in root.get_children():
		if child is Interactable:
			found.append(child)
		found.append_array(_find_interactables(child))
	return found
