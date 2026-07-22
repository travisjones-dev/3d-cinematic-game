extends Control
## HUD — reacts to EventBus interaction signals to show/hide the interaction prompt. Purely
## a listener; it never reaches into gameplay nodes. More HUD elements (quest toasts, etc.)
## hang off EventBus here as they land.

@onready var _prompt_label: Label = $PromptLabel
@onready var _quest_toast_panel: Control = $QuestToastPanel
@onready var _quest_toast: Label = $QuestToastPanel/QuestToast
@onready var _flavor_label: Label = $FlavorLabel

## Bumped each time a transient message shows; a delayed hide only fires if it still owns the
## latest token, so a newer message isn't hidden early by an older one's timer.
var _toast_token: int = 0
var _flavor_token: int = 0
## Tracks the toast's active fade so a newer update can kill it before starting its own —
## otherwise two tweens would fight over the same modulate property.
var _toast_tween: Tween = null

func _ready() -> void:
	_prompt_label.visible = false
	_quest_toast_panel.visible = false
	_quest_toast_panel.modulate.a = 0.0
	_flavor_label.visible = false
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_lost.connect(_on_interaction_lost)
	# A zone swap frees the interactable without firing interaction_lost, so hide the
	# prompt on zone entry too — otherwise it lingers into the new zone.
	EventBus.zone_entered.connect(func(_zone: String) -> void: _prompt_label.visible = false)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.narration_requested.connect(_on_narration_requested)

func _on_narration_requested(text: String) -> void:
	_flavor_label.text = text
	_flavor_label.visible = true
	_flavor_token += 1
	var mine: int = _flavor_token
	await get_tree().create_timer(6.5).timeout
	if mine == _flavor_token:
		_flavor_label.visible = false

func _on_quest_updated(quest_id: String, _stage: int) -> void:
	if QuestManager.is_complete(quest_id):
		_quest_toast.text = "Quest complete: %s" % QuestManager.get_title(quest_id)
	else:
		_quest_toast.text = "%s — %s" % [QuestManager.get_title(quest_id), QuestManager.get_current_summary(quest_id)]
	_toast_token += 1
	var my_token: int = _toast_token

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_quest_toast_panel.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_property(_quest_toast_panel, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(6.0).timeout
	if my_token != _toast_token:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_quest_toast_panel, "modulate:a", 0.0, 0.6)
	await _toast_tween.finished
	if my_token == _toast_token:
		_quest_toast_panel.visible = false

func _on_interaction_available(target: Node) -> void:
	var label_text: String = "Interact"
	if target.has_method("get_prompt"):
		label_text = target.get_prompt()
	_prompt_label.text = "[E] %s" % label_text
	_prompt_label.visible = true

func _on_interaction_lost(_target: Node) -> void:
	_prompt_label.visible = false
