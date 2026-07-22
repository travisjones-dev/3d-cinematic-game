extends Node
## EventBus — global signal relay. Systems communicate through these signals,
## never by direct cross-scene node references. No state lives here (that is
## GameState's job); this node only declares and forwards signals.

# --- Story flags ---
signal flag_changed(flag: String, value: Variant)

# --- Quests ---
signal quest_updated(quest_id: String, stage: int)

# --- Dialogue ---
signal dialogue_started(timeline: String)
signal dialogue_ended(timeline: String)

# --- Cutscenes ---
signal cutscene_started(id: String)
signal cutscene_finished(id: String)

# --- Zones / transitions ---
signal zone_transition_requested(target_zone: String, spawn_point: String)
signal zone_entered(zone_name: String)

# --- Interaction ---
signal interaction_available(target: Node)
signal interaction_lost(target: Node)

# --- Flavor / examine text (environmental storytelling shown as a transient line) ---
signal narration_requested(text: String)

# --- Save / load ---
signal save_completed(slot: int)
signal load_completed(slot: int)
