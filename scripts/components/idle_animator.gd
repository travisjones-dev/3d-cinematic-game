extends Node3D
## Plays a looping idle on an imported character.
##
## Without this, an imported .gltf character renders in its BIND POSE — arms straight out in a
## T-pose — because nothing is driving its AnimationPlayer. The model looks broken rather than
## merely unanimated, which reads as a bug to anyone watching.
##
## Attached to the instanced character node inside an NPC scene, so NPCs get an idle without each
## one needing its own script. The player does not use this: player.gd drives its AnimationPlayer
## from velocity instead (idle/walk/run).

## Which clip to loop. Every character in the pack ships an "Idle".
@export var clip: StringName = &"Idle"

## Characters standing in the same village all playing the same idle in lockstep reads as
## artificial. The offset is derived from world position rather than randomised, so it is stable
## across save/load and between runs — an NPC that visibly jumps to a different pose on reload
## would be worse than the synchronisation it fixes.
@export var stagger: bool = true


func _ready() -> void:
	var player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_warning("idle_animator: no AnimationPlayer under %s" % name)
		return
	if not player.has_animation(clip):
		push_warning("idle_animator: no '%s' clip on %s" % [clip, name])
		return

	# The pack ships every clip with loop_mode 0, so an idle would play once and freeze. The
	# .import sidecars set this too; doing it here as well keeps a re-imported asset from
	# silently regressing to a one-shot idle.
	var animation: Animation = player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_LINEAR

	player.play(clip)

	if stagger:
		var seed: float = absf(global_position.x * 7.31 + global_position.z * 3.77)
		player.seek(fmod(seed, animation.length), true)
