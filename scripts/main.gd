extends Node3D
## Main — the persistent root. Holds ZoneRoot, the Player, UI (HUD + pause menu), FadeLayer,
## and the Phantom Camera rig, none of which are destroyed across zone transitions. Registers
## the persistent nodes with SceneDirector, loads the opening zone, and owns the third-person
## camera look (mouse drives the Phantom Camera's spring-arm orbit).

@export var mouse_sensitivity: float = 0.05
@export var min_pitch: float = -60.0
@export var max_pitch: float = 45.0

## The zone the game opens into. (Swapped in-game via zone-exit interactables.)
@export var start_zone: String = "zone_01_village"

@onready var zone_root: Node3D = $ZoneRoot
@onready var player: Node3D = $Player
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var _pcam: PhantomCamera3D = $PlayerPhantomCamera3D

func _ready() -> void:
	SceneDirector.register_main(zone_root, player, fade_rect)
	SceneDirector.load_initial_zone(start_zone)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# During a conversation the cursor must be free to click choices; recapture it afterward
	# for camera look.
	EventBus.dialogue_started.connect(func(_t: String) -> void: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE))
	EventBus.dialogue_ended.connect(func(_t: String) -> void: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_orbit_camera(event as InputEventMouseMotion)

## Rotates the third-person spring arm around the player from mouse movement, clamping
## pitch so the camera can't flip over or under the target.
func _orbit_camera(motion: InputEventMouseMotion) -> void:
	var rot: Vector3 = _pcam.get_third_person_rotation_degrees()
	rot.x = clampf(rot.x - motion.relative.y * mouse_sensitivity, min_pitch, max_pitch)
	rot.y = wrapf(rot.y - motion.relative.x * mouse_sensitivity, 0.0, 360.0)
	_pcam.set_third_person_rotation_degrees(rot)
