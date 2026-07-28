---
name: godot-interaction-system
description: >-
  Build or extend the player interaction system in this Godot project — the
  reusable Interactable (Area3D) primitive, EventBus-mediated prompts, and
  composing new interactables (NPCs, props, zone exits, secrets). Use this
  WHENEVER the task involves the player interacting with something in the world:
  an "press E to …" prompt, a prop/NPC/exit/secret the player can activate, wiring
  an interaction to a behavior, showing/hiding the HUD prompt, or debugging why an
  interaction won't fire or a prompt lingers. This is the project's canonical
  "systems talk through EventBus, never direct references" pattern made concrete.
---

# The interaction system (Interactable + EventBus)

Per the project architecture (CLAUDE.md, EventBus), systems communicate through global
signals, not cross-scene node references. Interaction is the concrete example: a reusable
`Interactable` announces itself on EventBus; the player and HUD react without anyone holding
a direct reference to anyone else. Verified in Phase B (6/6 tests, playtest-confirmed).

## The primitive — `scripts/components/interactable.gd`

An `Area3D` with `class_name Interactable`, an exported `prompt`, and an `interacted` signal:

```gdscript
class_name Interactable
extends Area3D

signal interacted

@export var prompt: String = "Interact"
@export var enabled: bool = true

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func interact() -> void:
    if enabled:
        interacted.emit()

func get_prompt() -> String:
    return prompt

func _on_body_entered(body: Node3D) -> void:
    if enabled and body.is_in_group("player"):
        EventBus.interaction_available.emit(self)

func _on_body_exited(body: Node3D) -> void:
    if body.is_in_group("player"):
        EventBus.interaction_lost.emit(self)
```

Detection facts:
- The player is a `CharacterBody3D` **in the "player" group** (`add_to_group("player")` in its
  `_ready`). Area3D `body_entered` picks it up because their default collision layer/mask (1)
  overlap. If detection silently doesn't fire, check group membership and layer/mask overlap.
- Each Interactable needs a `CollisionShape3D` child to define its trigger volume.

## The player side — track by signal, never by reference

The player listens to EventBus and remembers the current interactable; the interact input
fires it. Crucially it also clears on `zone_entered` (see the gotcha):

```gdscript
var _current_interactable: Interactable = null

func _ready() -> void:
    add_to_group("player")
    EventBus.interaction_available.connect(func(t): _current_interactable = t as Interactable)
    EventBus.interaction_lost.connect(func(t): if _current_interactable == t: _current_interactable = null)
    EventBus.zone_entered.connect(func(_z): _current_interactable = null)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") \
            and _current_interactable != null and is_instance_valid(_current_interactable):
        _current_interactable.interact()
```

## The HUD side — a pure listener

```gdscript
func _ready() -> void:
    _prompt_label.visible = false
    EventBus.interaction_available.connect(_on_available)   # show "[E] " + target.get_prompt()
    EventBus.interaction_lost.connect(func(_t): _prompt_label.visible = false)
    EventBus.zone_entered.connect(func(_z): _prompt_label.visible = false)   # see gotcha
```

## ⚠️ The gotcha that bites: zone changes free the interactable silently

When SceneDirector swaps zones it frees the old zone — **`body_exited` does NOT fire for a
freed Area3D**, so `interaction_lost` never emits. Without mitigation, the player's
`_current_interactable` dangles (freed) and the HUD prompt lingers into the new zone. Fix, in
BOTH the player and the HUD:
- Also clear on `EventBus.zone_entered` (entering any zone wipes stale interaction state).
- Guard `interact()` calls with `is_instance_valid(_current_interactable)`.

This is the general lesson for any EventBus listener holding a node reference: a node can
disappear without its "leave"/"lost" signal firing — clear on the coarser lifecycle signal too.

## Composing new interactables

Build specific behaviors on the primitive. Extend by **path** (not class_name) to avoid any
class-registration ordering issues during a fresh import:

```gdscript
extends "res://scripts/components/interactable.gd"   # zone_exit.gd

@export var target_zone: String = ""
@export var target_spawn: String = "spawn_default"

func _ready() -> void:
    super()                       # keep the primitive's body_entered/exited wiring
    interacted.connect(_on_interacted)

func _on_interacted() -> void:
    if target_zone != "":
        SceneDirector.change_zone(target_zone, target_spawn)
```

In the `.tscn`, an interactable is an `Area3D` + its script + a `CollisionShape3D` trigger + a
visible marker/mesh (see `godot-scene-authoring`).

### The built variants (all extend interactable.gd by path)
- **`flavor_interactable.gd`** — an examinable prop. Exports `flavor_text` (shown via
  `EventBus.narration_requested` → a transient HUD line) and an optional `discovers_flag` set on
  first examine (used for the village's hidden carved heart).
- **`npc_interactable.gd`** — an NPC you talk to. Exports a `.dtl` `timeline`; on interact it opens
  it (via `get_node_or_null("/root/Dialogic").call("start", timeline)` — the tree lookup, not the
  global, to stay clear of the class_name/uid-autoload trap). Guards against re-opening while a
  conversation is running (`dialogic.get(&"current_timeline") != null`).
- **`zone_exit.gd`** — transitions zones (above), with **story gating**: `required_flag` +
  `blocked_text`. If the flag isn't set, it shows the blocked line instead of transitioning — how the
  village→shore exit stays locked until the quest is done.

### Placement lessons (from playtest)
Make exit/interaction triggers **generous** (a wide `BoxShape3D`) and keep them **away from NPCs** so
their prompts don't compete for the same spot. See `godot-zone-building` for funneling the player to
exits.

### ⚠️ "Keep them away from each other" is a hard requirement, not a preference
`_on_interaction_available` is **last-entered-wins, not nearest-wins** — it assigns
`_current_interactable` unconditionally, and `_on_interaction_lost` only clears when the node being
left is the current one. Two overlapping triggers therefore let the player stand at one object while
the other's prompt shows, and it sticks. This shipped: the blacksmith's default 3.5 m trigger
overlapped `StableInteract`, offering "Greet your steed" while standing at the blacksmith.

Equally: the `Trigger` child inherits the Area3D's position, but a **`Mesh` child can carry an
offset** — so the art and the hitbox can end up in different places. Aeia ended up standing *outside
her own trigger*, unreachable head-on.

Both are guarded by tests, and the diagnosis/fix procedure plus the SceneState+AABB harness live in
**`godot-playable-space-audit`**. Read it before placing any new interactable.

## Testing
Test the logic by calling the handlers directly with a stand-in node in the "player" group
and `watch_signals(EventBus)` — deterministic, no physics-frame overlap timing. See
`godot-gut-headless-testing` ("Testing EventBus / signal components").
