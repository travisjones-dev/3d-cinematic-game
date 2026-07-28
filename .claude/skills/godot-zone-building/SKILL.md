---
name: godot-zone-building
description: >-
  Build a story/content zone in this Godot game — the node-group structure, walkable
  collision + edge barriers, mood/lighting, spawn points, and populating it with
  interactables, NPCs, zone exits, and quests. Use this WHENEVER the task is building
  or editing a zone/level/area/map (a village, shore, dungeon, room), laying out its
  geometry, placing NPCs/props/exits in it, funneling the player, or wiring a zone to
  the quest/dialogue/cutscene systems. This is the recipe that composes the other Godot
  skills into a playable zone.
---

# Building a content zone

A zone is a `.tscn` under `scenes/zones/` that SceneDirector loads under `ZoneRoot`. This skill
is the assembly recipe; it leans on `godot-scene-authoring` (file format), `godot-interaction-system`
(interactables/NPCs/exits), `godot-dialogic-integration` (conversations), `godot-quest-system`,
and `godot-cutscene-tech`. **Every zone needs a one-paragraph Zone Design Law purpose first**
(`docs/zones/…md`) before geometry (CLAUDE.md).

## Node-group structure (keep it consistent across zones)
```
Zone01Village (Node3D, zone controller script)
├── Lighting        (DirectionalLight3D + WorldEnvironment — the mood)
├── Geometry        (ground + buildings, each a StaticBody3D + Mesh + CollisionShape3D)
├── Props           (visual-only MeshInstance3D clutter)
├── Interactables   (flavor_interactable / npc_interactable / zone_exit — Area3D + Trigger)
├── NPCs            (Area3D npc_interactable, or plain MeshInstance3D ambient capsules)
└── SpawnPoints     (Marker3D per entry: spawn_default, spawn_from_<otherzone>)
```
The **zone controller script** (`scripts/zones/<zone>.gd`) does zone-scoped setup — registering +
starting the zone's quest in `_ready` (safe on re-entry: `QuestManager.start` no-ops once begun).

## Walkable ground + edge barriers (or the player falls through the world)
- Ground and any solid building = `StaticBody3D` + `CollisionShape3D` (a bare `MeshInstance3D` has
  no collision — see `godot-scene-authoring`). A `CharacterBody3D` player needs this to stand.
- **Barrier the perimeter.** Put invisible walls at the zone edges so the player can't walk off the
  ground into the void: `StaticBody3D` + a tall `BoxShape3D` `CollisionShape3D`, **no mesh**, ringing
  the playable area.
- ### ⚠️ Do NOT leave a gap in the barrier at the exit
  An earlier version of this skill said to leave a gap where the exit is "so the player can leave."
  **That is wrong and it shipped a bug.** Zone exits are `zone_exit.gd` → `interactable.gd`, i.e. an
  **E-press**, so the player never needs a physical opening — but a gap lets them walk straight
  through and off the ground. The village's north barrier was split into two 18 m pieces around an
  8 m gap for `ExitToShore`; the player fell to `y = -79`. The barrier must be **continuous**, exit or
  not. Same rule for doorway apertures in walls. Full diagnosis, the door-vs-invisible-blocker choice,
  overlap sizing, and the `radius + safe_margin` spawn check are in
  **`godot-playable-space-audit`** — read it whenever you add an exit, and note that a barrier
  positioned to block still has to leave the player inside the exit's trigger volume.

## Mood (the one art investment in the slice — pillar #2)
`WorldEnvironment` + `Environment` (procedural sky, tonemap, subtle fog) + a coloured
`DirectionalLight3D`. Warm/golden = safe/home; cool/desaturated/heavy-fog = dread/loss. Mood is what
sells a graybox zone — invest here even when geometry is boxes.

## Placement & spawns
- Player is a center-origin capsule: a `spawn_default` Marker3D at `y = ground_top + 1.0` rests the
  feet on the ground. Add a `spawn_from_<zone>` for each way in.
- SceneDirector places the player at the named spawn on entry; `load_into` places at a saved transform.

## Populating (compose, don't invent nodes)
- **Examinable prop:** `flavor_interactable` (Area3D) with `flavor_text` (+ optional `discovers_flag`).
- **NPC to talk to:** `npc_interactable` (Area3D) with a `.dtl` `timeline`.
- **Exit to another zone:** `zone_exit` (Area3D) with `target_zone`/`target_spawn`, and `required_flag`
  + `blocked_text` to gate it behind story progress. See `godot-interaction-system`.
- All of these are Area3D + a `CollisionShape3D` trigger; they detect the player via the "player" group.

## Guiding the player (playtest lesson)
Players get lost in open graybox. **Funnel them:** ring the zone with trees/walls and leave a clear
**opening** toward the exit, so the way out reads visually. Make exit triggers **generous** (a wide
`BoxShape3D`) and place them **away from NPCs** so prompts don't fight. Distinct-coloured/emissive
markers help a prompt stand out.

## Wiring to the slice
- A zone exit gated on a quest-completion flag (`required_flag`) enforces story order.
- A zone's cutscene is a child rig triggered on arrival (a trigger Area3D → `Cutscene.play()`), see
  `godot-cutscene-tech`.
- Quest stage lives in GameState → save-safe; the zone controller just registers/starts it.

## Verify
`--import` (parse), the GUT suite (logic), and boot the game into the zone (`main.gd.start_zone` or a
transition) to catch runtime errors. Layout/mood/pathing are human-playtested — expect notes on
where players get lost and tune the funneling.
