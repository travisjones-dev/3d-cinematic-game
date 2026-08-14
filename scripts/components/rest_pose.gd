extends Node3D
## Swings a T-posed character's arms down into a neutral standing pose.
##
## Why this exists: the Modular Character Outfits pack ships rigged models with NO animations —
## they are designed to be driven by Quaternius's separate Universal Animation Library. Imported
## as-is, the character stands in its bind pose with both arms straight out, which reads as a
## broken model rather than an unanimated one.
##
## `idle_animator.gd` cannot help here: it plays an existing clip, and there is none. And the RPG
## pack's Idle cannot be borrowed — that rig uses Blender-style names (`UpperArm.L`, `Neck`) while
## this one uses Unreal-style (`upperarm_l`, `neck_01`) with full finger chains, so the tracks
## would not bind.
##
## ⚠️ This is a STOPGAP, not a substitute for animation. It produces a still, standing figure.
## The proper fix is the Universal Animation Library, which is built for exactly this rig.
##
## The rotation is computed in SKELETON space rather than by guessing each bone's local axis: take
## the bone's rest direction, build the axis that swings it toward world-down, and rotate about
## that. This works regardless of how the rig orients individual bones, which hand-picked local
## axes do not.

## Bones to swing downward — the upper arms.
@export var arm_bones: Array[StringName] = [&"upperarm_l", &"upperarm_r"]
## How far to swing them down from the T-pose. 90 would pin them flat to the sides; slightly less
## keeps a little daylight under the arms, which reads more natural.
@export var arm_drop_degrees: float = 72.0
## A gentler follow-through on the forearms so the arms are not perfectly straight.
@export var forearm_bones: Array[StringName] = [&"lowerarm_l", &"lowerarm_r"]
@export var forearm_drop_degrees: float = 12.0


func _ready() -> void:
	var skeleton: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_warning("rest_pose: no Skeleton3D under %s" % name)
		return
	for bone in arm_bones:
		_swing_down(skeleton, bone, deg_to_rad(arm_drop_degrees))
	for bone in forearm_bones:
		_swing_down(skeleton, bone, deg_to_rad(forearm_drop_degrees))


## Rotates one bone so its length swings toward world-down by `angle`, leaving the rest of the
## rig untouched (children follow, as they should).
func _swing_down(skeleton: Skeleton3D, bone_name: StringName, angle: float) -> void:
	var idx: int = skeleton.find_bone(bone_name)
	if idx < 0:
		push_warning("rest_pose: no bone '%s'" % bone_name)
		return

	var children: PackedInt32Array = skeleton.get_bone_children(idx)
	if children.is_empty():
		return

	var here: Transform3D = skeleton.get_bone_global_rest(idx)
	var there: Transform3D = skeleton.get_bone_global_rest(children[0])
	var direction: Vector3 = (there.origin - here.origin)
	if direction.length() < 0.0001:
		return
	direction = direction.normalized()

	# Axis that rotates `direction` toward straight down. If the bone already points down there is
	# nothing sensible to rotate about, so leave it.
	var axis: Vector3 = direction.cross(Vector3.DOWN)
	if axis.length() < 0.0001:
		return
	axis = axis.normalized()

	# Re-express a skeleton-space rotation as this bone's LOCAL pose:
	#   desired_global = R * rest_global,  and  rest_global = parent_global * rest_local
	#   => local = parent_global^-1 * R * parent_global * rest_local
	var rotation := Basis(axis, angle)
	var parent: int = skeleton.get_bone_parent(idx)
	var parent_basis: Basis = Basis() if parent < 0 else skeleton.get_bone_global_rest(parent).basis
	var local: Basis = parent_basis.inverse() * rotation * parent_basis * skeleton.get_bone_rest(idx).basis

	skeleton.set_bone_pose_rotation(idx, local.get_rotation_quaternion())
