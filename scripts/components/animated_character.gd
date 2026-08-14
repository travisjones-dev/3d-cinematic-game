extends Node3D
## Plays a clip from the shared Universal Animation Library on a character that ships without
## animations of its own.
##
## The Modular Character Outfits pack ships rigged models with ZERO animation clips — they are
## designed to be driven by Quaternius's separate Universal Animation Library, which is what this
## loads. Without it such a character stands in its bind pose (arms straight out), which reads as
## a broken model rather than an unanimated one.
##
## WHY NO RETARGETING IS NEEDED. The pack's own Godot instructions walk through creating a BoneMap
## and a SkeletonProfileHumanoid in the editor. That is for mapping the library onto a DIFFERENT
## rig. Here both the library and the character are Quaternius's universal humanoid: identical
## bone names (`pelvis`, `spine_02`, `upperarm_l`, …) and the same `Armature/Skeleton3D` node path
## that the clips' tracks address. So the clips bind directly. That also keeps this reproducible —
## the documented workflow is editor-GUI-only, which CLAUDE.md forbids as a dependency.
##
## Note Godot's importer strips the `_Loop` suffix from clip names and turns it into the loop mode,
## so the library's `Sitting_Idle_Loop` is addressed here as `Sitting_Idle` and already loops.

const LIBRARY_PATH: String = "res://assets/models/characters/universal_animations.glb"

## Clip to play. See the library for the full 43; useful ones here are `Idle`, `Idle_Talking`,
## `Sitting_Idle` and `Sitting_Talking`.
@export var clip: StringName = &"Idle"

## Offset playback by world position so a row of NPCs does not breathe in lockstep. Derived from
## position rather than randomised, so it is stable across save/load — an NPC visibly jumping to a
## different pose on reload would be worse than the synchronisation it fixes.
@export var stagger: bool = true

@export_group("Layers")
## Clothing and hair to fit onto this character's skeleton.
##
## Quaternius splits a character across packs: Universal Base Characters supplies the BODY (one
## mesh including the head, plus separate eyes and eyebrows), Modular Character Outfits supplies
## CLOTHING as separate arm/body/leg/foot meshes, and the hairstyles are separate again. An outfit
## on its own is a headless set of clothes — which is exactly what shipped here first.
##
## All of them are skinned to the same universal humanoid, so a layer's meshes can simply be
## re-parented onto this character's Skeleton3D and they deform with it. Godot binds a Skin to
## bones by NAME, which is what makes this work across files.
@export var layers: Array[PackedScene] = []

## The library is ~7 MB and shared by every character using it, so it is loaded once per run and
## reused rather than instantiated per NPC.
static var _library: AnimationLibrary = null


static func _shared_library() -> AnimationLibrary:
	if _library != null:
		return _library
	var packed: PackedScene = load(LIBRARY_PATH) as PackedScene
	if packed == null:
		push_error("animated_character: cannot load %s" % LIBRARY_PATH)
		return null
	var instance: Node = packed.instantiate()
	var source: AnimationPlayer = instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source != null:
		# Deep copy: the instance (and its mannequin mesh) is freed immediately below, and we only
		# want the clips, not 7 MB of geometry resident for the whole run.
		_library = source.get_animation_library(&"").duplicate(true)
	instance.free()
	return _library


func _ready() -> void:
	var skeleton: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_warning("animated_character: no Skeleton3D under %s" % name)
		return

	for layer in layers:
		_fit_layer(skeleton, layer)

	var library: AnimationLibrary = _shared_library()
	if library == null:
		return
	if not library.has_animation(clip):
		push_warning("animated_character: no clip '%s' in the library" % clip)
		return

	var player := AnimationPlayer.new()
	player.name = "LibraryAnimation"
	add_child(player)
	# Tracks are authored as `Armature/Skeleton3D:bone`, relative to the library scene's ROOT —
	# so the player's root must be this character's root, not the player itself.
	player.root_node = NodePath("..")
	player.add_animation_library(&"", library)
	player.play(clip)

	if stagger:
		var animation: Animation = library.get_animation(clip)
		var seed: float = absf(global_position.x * 7.31 + global_position.z * 3.77)
		player.seek(fmod(seed, animation.length), true)


## Re-parents a layer scene's skinned meshes onto this character's skeleton.
##
## Only the mesh + skin are taken, not the layer's own Armature/Skeleton3D — two skeletons would
## mean two things to animate, and only one of them would be driven. Because the Skin binds by
## bone name and every one of these packs uses the same universal humanoid, the transplanted mesh
## deforms with this character's skeleton for free.
func _fit_layer(skeleton: Skeleton3D, layer: PackedScene) -> void:
	if layer == null:
		return
	var instance: Node = layer.instantiate()
	var fitted: int = 0
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var source: MeshInstance3D = node
		var piece := MeshInstance3D.new()
		piece.name = source.name
		piece.mesh = source.mesh
		piece.skin = source.skin
		piece.transform = source.transform
		skeleton.add_child(piece)
		# NodePath is relative to the MeshInstance3D, so ".." is the skeleton it now hangs under.
		piece.skeleton = NodePath("..")
		fitted += 1
	instance.free()
	if fitted == 0:
		push_warning("animated_character: layer %s contributed no meshes" % layer.resource_path)
