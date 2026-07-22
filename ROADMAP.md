# ROADMAP — [Working Title]

> This file is the source of truth for **milestone discipline** (see CLAUDE.md Hard Rules).
> If a task isn't listed under the CURRENT milestone, it doesn't get built — flag it instead.
> Check items off as they land. Reordering within a phase is fine; adding scope requires a human decision recorded here.

## Pinned decisions
- Godot 4.6.3-stable (decided 2026-07-14) — chosen over the installed 4.7 because Dialogic 2's latest release explicitly maxes at Godot 4.6.x; 4.6.3 is the newest version all three addons support (Dialogic 2, GUT 9.6.x/9.7.x, Phantom Camera 4.4+)
- 3D, third-person cinematic camera via Phantom Camera
- Addons: Dialogic 2, Phantom Camera, GUT — exact versions pinned in CLAUDE.md at install
- Prior `frostfell.html` web prototype is scrapped; nothing carries over

---

## Milestone 1 — Vertical Slice  ⟵ CURRENT

**Goal:** the smallest playable thing that proves the story pillar (see GAME_PITCH.md, "Vertical Slice Definition").
**Done when:** a friend plays 10 minutes, unprompted asks a question about the world, and wants to know what happens next.

### Gate 0 — Writing prerequisites (human, blocks Phases D–E)
- [x] GAME_PITCH.md ✍️ Premise (2–3 sentences)
- [x] GAME_PITCH.md ✍️ Core Loop (one sentence)
- [x] GAME_PITCH.md ✍️ "X meets Y" (three references)
- [x] GAME_PITCH.md ✍️ The One Cinematic Moment — scoped to slice target: boats emerge from mist + friend drops sword (decided 2026-07-14)
- [x] Zone 01 story purpose written in one paragraph — see docs/zones/zone_01_home_village.md (2026-07-14)

*Phases A–C are engineering and proceed in parallel with Gate 0.*

### Phase A — Foundations
- [x] Godot project scaffold per CLAUDE.md Project Structure; versions pinned in CLAUDE.md *(Pass 1)*
- [x] Install + pin addons: GUT 9.6.1 *(Pass 1)*; Dialogic 2 2.0-alpha-19 + Phantom Camera 0.11.0.2 *(Pass 2)* — all verified loading clean on 4.6.3
- [x] Four autoloads registered in dependency order: EventBus → GameState → SaveManager → SceneDirector
- [x] GUT headless run working; exact command recorded in tests/README.md *(Pass 1)*
- [x] Tests: flag set/get/namespacing; GameState save/load round-trip *(Pass 1)*
- [x] main.tscn persistent root (ZoneRoot, Player slot, UI, FadeLayer) *(Pass 2)*
- [x] SceneDirector transition flow (fade → swap zone → spawn-point placement → fade) proven with two graybox test zones *(Pass 2 — 5/5 integration tests green)*

*Phase A complete. Two TEMP verification aids in main.tscn (fixed Camera3D + Enter/Space zone-toggle in main.gd) are Phase-B removals — search "TEMP".*

### Phase B — Player & interaction
- [x] Third-person player controller: walk/run, graybox capsule, Phantom Camera follow rig *(Pass 1)*
- [x] Interactable component + HUD interaction prompt (via EventBus) *(Pass 2 — Interactable + zone_exit compose it; 6/6 tests)*
- [x] Pause menu: save / load / quit wired to SaveManager *(Pass 2 — SceneDirector.load_into restores exact position)*
- [x] Feel pass: acceleration, turn smoothing, camera damping — validated in playtest (grounded & weighty)

*Phase B COMPLETE — machine-verified (22/22 tests, clean boot) and human playtest-verified (movement/camera feel, interaction prompt, pause/save/load all confirmed). TEMP scaffolds removed (real zone-exit interactables replace the debug toggle).*

### Phase C — Dialogue & quest tech (spikes before content)
- [x] SPIKE: Dialogic 2 ↔ GameState flag bridge — conditions/choices read GameState directly; choices write via DialogueBridge (signal → GameState). 8/8 tests, **human playtest-verified** (flag flips on choice; options gate on flag). Gotchas captured in godot-dialogic-integration skill.
- [x] SPIKE: cutscene tech — AnimationPlayer keyframes Phantom Camera priority (cut) + camera push + a method-track cue that fires a Dialogic line; reusable Cutscene controller is skippable + fire-once via a GameState flag. 4/4 tests, **human playtest-verified** (cut + push + line + skip). Gotcha captured: class_name script referencing the uid-autoload Dialogic must use get_node, not the global.
- [x] QuestResource / QuestStage resources (.tres) + QuestManager autoload that advances stages by reading GameState flags; stage index lives in GameState (save-safe). 6/6 tests.
- [x] Quest notification toast in HUD (quest_updated via EventBus) — appears on stage advance/complete, auto-hides. **human playtest-verified.**

*Phase C COMPLETE — all three spikes machine + human verified (40/40 tests). Story tech ready: Dialogic↔GameState bridge, AnimationPlayer+Phantom Camera cutscenes (skippable/fire-once), and flag-driven quests, all via GameState + EventBus.*

### Phase D — Content (blocked on Gate 0)
- [x] Zone 01 graybox: layout serves the story paragraph (square/mill/stables/guard tower/homes) *(D1 — pending human walkthrough)*
- [x] 3+ environmental-storytelling setups (wedding prep, stables+steed, cracked guard tower) as flavor Interactables *(D1)*
- [x] 1 optional discovery: carved heart behind the mill, off the main path (sets act1/found_carved_heart) *(D1)*
- [x] Lighting & mood pass — warm golden-hour sun, warm sky, subtle fog *(D1 — pending human eyeball)*
- [x] One NPC with a branching conversation: the friend, with a real choice (promise to protect) that sets a flag paying off in the shore cutscene *(D2 — pending human playtest)*
- [x] One micro-quest: "The Last Afternoon" — talk to friend → farewell to Elin → return to friend (QuestResource + flags, toast) *(D2)*
- [x] The One Cinematic Moment as an in-zone cutscene — shore zone + gated village→shore exit; AnimationPlayer cuts to the cinematic push as the boats emerge, narration reflects the friend-promise; skippable, fire-once *(D3 — pending human playtest)*
- *All narrative content drafted by Claude gets flagged for a human writing pass (CLAUDE.md hard rule).*

*Phase D content complete (D1 village + D2 friend/quest + D3 shore/cutscene), machine-verified (47/47 tests). Pending full-slice human playtest → then Phase E closeout.*

### Phase E — Slice closeout
- [x] Save / quit / load preserves all story flags, quest state, and player position from any point — test_save_load_slice.gd (mid-quest reload + fire-once cutscene survives), 49/49 tests
- [x] Full-slice playthrough test: automated flag/quest/save chain green (test_village_quest + test_save_load_slice + test_cutscene/shore); human end-to-end playthrough confirmed 2026-07-21 (tower climb, dialogue toast timing, camera framing, quest-toast readability, village visual fixes, writing pass all checked)
- [ ] Friend playtest against success criteria; log every unprompted world question they ask *(human)*
- [ ] Bug fixes, with regression tests for anything touching GameState/quests/saves *(as found)*

### Explicit non-goals for this milestone (from GAME_PITCH.md)
No combat, no crafting/economy, no procedural terrain, no streaming, no voice acting, no multiplayer, no console ports. Placeholder art everywhere except lighting and mood.

---

## Beyond the slice — sketch only, DO NOT BUILD
Listed only so ideas have a parking spot. Nothing here is scoped or approved.
- **M2:** second zone + interconnection, quest journal UI, ambient audio pass
- **M3:** third zone, faction/relationship flags, combat *only if the story demands it*
- **M4:** content complete for Act 1, options menu, accessibility pass
