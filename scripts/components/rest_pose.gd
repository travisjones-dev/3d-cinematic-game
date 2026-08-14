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

@export_group("Seated")
## Sit the character down: thighs forward, knees bent. For Elder Mishka, whose dialogue has her
## on a bench throughout ("has not moved from her bench", "looks up from her bench"), so a
## standing model contradicts the writing as plainly as the wrong gender did.
@export var seated: bool = false
@export var thigh_bones: Array[StringName] = [&"thigh_l", &"thigh_r"]
@export var shin_bones: Array[StringName] = [&"calf_l", &"calf_r"]
## Thighs swing this far from vertical toward forward — 90 would be a perfectly square sit.
@export var hip_degrees: float = 84.0
## Knees bend back by the same amount so the shins return to vertical under the seat.
@export var knee_degrees: float = 84.0
## Arms hang closer to the body when seated.
@export var seated_arm_drop_degrees: float = 68.0


func _ready() -> void:
	var skeleton: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_warning("rest_pose: no Skeleton3D under %s" % name)
		return

	var drop: float = seated_arm_drop_degrees if seated else arm_drop_degrees
	for bone in arm_bones:
		_swing_toward(skeleton, bone, Vector3.DOWN, deg_to_rad(drop))
	for bone in forearm_bones:
		_swing_toward(skeleton, bone, Vector3.DOWN, deg_to_rad(forearm_drop_degrees))

	if not seated:
		return

	# Forward is read off the foot (heel -> toe) rather than assumed, so this works whichever way
	# the pack happens to author its characters.
	var forward: Vector3 = _facing(skeleton)
	for bone in thigh_bones:
		# Hip: swing the thigh from vertical out to horizontal-forward.
		var axis: Vector3 = _swing_toward(skeleton, bone, forward, deg_to_rad(hip_degrees))
		if axis == Vector3.ZERO:
			continue
		# Knee: rotate back about the SAME axis so the shin drops vertically again. It has to be
		# the same axis — the shin's own rest direction is already vertical, so asking it to swing
		# "toward down" is degenerate and would do nothing.
		var i: int = thigh_bones.find(bone)
		if i >= 0 and i < shin_bones.size():
			_rotate_bone(skeleton, shin_bones[i], axis, -deg_to_rad(knee_degrees))


## Heel-to-toe direction, i.e. which way the character faces.
func _facing(skeleton: Skeleton3D) -> Vector3:
	var heel: int = skeleton.find_bone(&"foot_l")
	var toe: int = skeleton.find_bone(&"ball_l")
	if heel < 0 or toe < 0:
		return Vector3.FORWARD
	var d: Vector3 = skeleton.get_bone_global_rest(toe).origin - skeleton.get_bone_global_rest(heel).origin
	d.y = 0.0
	return d.normalized() if d.length() > 0.0001 else Vector3.FORWARD


## Swings a bone's length toward `target`, returning the axis used so a child can undo it.
func _swing_toward(skeleton: Skeleton3D, bone_name: StringName, target: Vector3, angle: float) -> Vector3:
	var idx: int = skeleton.find_bone(bone_name)
	if idx < 0:
		push_warning("rest_pose: no bone '%s'" % bone_name)
		return Vector3.ZERO

	var children: PackedInt32Array = skeleton.get_bone_children(idx)
	if children.is_empty():
		return Vector3.ZERO

	var here: Transform3D = skeleton.get_bone_global_rest(idx)
	var there: Transform3D = skeleton.get_bone_global_rest(children[0])
	var direction: Vector3 = there.origin - here.origin
	if direction.length() < 0.0001:
		return Vector3.ZERO
	direction = direction.normalized()

	# If the bone already points at the target there is no sensible axis, so leave it alone.
	var axis: Vector3 = direction.cross(target)
	if axis.length() < 0.0001:
		return Vector3.ZERO
	axis = axis.normalized()

	_rotate_bone(skeleton, bone_name, axis, angle)
	return axis


## Applies a rotation expressed in SKELETON space to one bone's local pose.
##   desired_global = R * rest_global,  rest_global = parent_global * rest_local
##   => local = parent_global^-1 * R * parent_global * rest_local
## Working in skeleton space rather than guessing each bone's local axis is what makes this
## survive a rig whose bones are oriented differently from the last one.
func _rotate_bone(skeleton: Skeleton3D, bone_name: StringName, axis: Vector3, angle: float) -> void:
	var idx: int = skeleton.find_bone(bone_name)
	if idx < 0:
		push_warning("rest_pose: no bone '%s'" % bone_name)
		return
	var rotation := Basis(axis, angle)
	var parent: int = skeleton.get_bone_parent(idx)
	var parent_basis: Basis = Basis() if parent < 0 else skeleton.get_bone_global_rest(parent).basis
	var local: Basis = parent_basis.inverse() * rotation * parent_basis * skeleton.get_bone_rest(idx).basis
	skeleton.set_bone_pose_rotation(idx, local.get_rotation_quaternion())
