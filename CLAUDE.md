# CLAUDE.md — [Working Title]

Story-rich, cinematic medieval fantasy RPG. Godot 4.x, GDScript. Handcrafted interconnected zones that feel open. Built in vertical slices.

## Pillar Hierarchy (the tiebreaker for ALL scope and design decisions)
1. **Story / World — sacred.** When two approaches conflict, choose the one that serves narrative delivery.
2. Visuals / Atmosphere — mood and lighting over fidelity.
3. Gameplay feel — solid and unobtrusive; never innovative at the cost of schedule.
4. Systems depth — minimum viable RPG; first thing cut under time pressure.

## Hard Rules
- **Milestone discipline:** do not build any feature not listed in the current milestone (see ROADMAP.md). If a task seems to require an unplanned feature, stop and flag it instead of building it.
- **Narrative is data, not code.** All dialogue, quest definitions, and story flags live in data files (Dialogic timelines / custom Resources), never hardcoded in scripts. Claude may draft and edit narrative data files, but flag all story-content changes clearly in the summary so they get a human writing pass.
- **Two-phase workflow for anything structural:** propose a plan first (files to touch, scene changes, risks), wait for approval, then implement. Small bug fixes are exempt.
- **Plain text everything, with one scoped exception:** prefer .tscn/.tres/.gd. No solutions that require editor-only GUI steps Claude can't reproduce or verify.
  - **AMENDED 2026-08-12 (Milestone 2 art pass):** **binary art assets are permitted under `assets/`**, with their plain-text `.import` sidecars committed and the binaries tracked in Git LFS. Everything else stays plain-text and Claude-verifiable: scenes, import settings, material overrides, shaders, animation state machines. **The visual result of a binary asset is human-verified** — consistent with the existing rule that rendering, feel and cinematics are human-tested. Claude must not be asked to author or judge model/texture content it cannot inspect.
  - Still forbidden: machine-specific editor settings as a dependency. Author `.glb` from Blender and commit that; do **not** rely on Godot's direct `.blend` import, which needs an editor-only `blender_path` and breaks headless runs.

## Stack & Conventions
- Godot 4.6.3-stable (verified installed 2026-07-14, build `4.6.3.stable.official`; chosen over 4.7 because Dialogic 2's latest release maxes at 4.6.x — see ROADMAP pinned decisions), GDScript with static typing (`var health: int = 10`), tabs per Godot style guide.
- Perspective: 3D, third-person cinematic camera via Phantom Camera (decided 2026-07-14).
- Addons (all installed 2026-07-14, plain-text extract into `addons/`, verified loading on 4.6.3): Dialogic 2 **2.0-alpha-19** (dialogue/cutscene timelines; latest release, maxes at Godot 4.6.x); Phantom Camera **0.11.0.2** (cinematic cameras); GUT **9.6.1** (tests; 9.6.x line targets Godot 4.6).
- Naming: snake_case files and node paths; PascalCase class_name; one scene per .tscn; scripts named after their scene.

## Project Structure
```
project/
  scenes/
    zones/          # one folder per zone: geometry, lighting, props
    characters/     # player, NPCs
    ui/
    cutscenes/
  scripts/
    autoload/       # singletons — see below
    components/     # reusable node behaviors
  dialogue/         # Dialogic timelines + characters
  data/
    quests/         # QuestResource .tres files
    items/
  assets/           # binary art (Git LFS) — added 2026-08-12, see assets/README.md
    models/         # .glb imported by Godot; .import sidecars are plain text + committed
    source/         # .blend working files; carries .gdignore so Godot skips it
  tests/            # GUT tests
```

## Core Singletons (autoloads)
- `GameState` — story flags, quest states, world variables. The single source of truth. All narrative branching reads/writes here.
- `EventBus` — global signals (quest_updated, cutscene_started, zone_entered). Systems communicate through it, never by direct node references across scenes.
- `SaveManager` — serializes GameState + player position. Every new story flag must be save-safe by default.
- `SceneDirector` — zone transitions with fades; owns the loading flow.

## Story Architecture
- Story flags: namespaced strings (`"act1/miller_betrayed"`), stored in GameState. Never boolean fields scattered on nodes.
- Quests: custom `QuestResource` (.tres) with stages, each stage defining objectives + flags it sets. Quest logic reads flags; it does not query world state directly.
- Dialogue: Dialogic timelines reference GameState flags for conditions. One timeline per conversation; branching via flags, not duplicated timelines.
- Cutscenes: AnimationPlayer-driven scenes triggered through EventBus; Phantom Camera for shots. Cutscenes set flags on completion so they're skippable and save-safe.

## Zone Design Law
Density over size. Each zone: 2–4 minutes to cross, minimum 3 environmental-storytelling setups, at least 1 optional discovery. No zone gets built before its story purpose is written in one paragraph.

## Testing
- GUT via `godot --headless -s addons/gut/gut_cmdln.gd` (exact command in tests/README once configured).
- Required coverage: save/load round-trip of GameState, quest stage transitions, flag-condition evaluation. Rendering, feel, and cinematics are human-tested.
- Every bug fix gets a regression test if the bug touched GameState, quests, or saves.

## Session Etiquette for Claude Code
- Start structural work by reading GAME_PITCH.md and ROADMAP.md.
- End every session summary with: files changed, flags/quests added, anything needing a human writing pass, and any milestone-scope concerns.
