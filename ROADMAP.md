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

## Milestone 1 — Vertical Slice  ✅ COMPLETE (closed 2026-08-12)
*All phases A–E done. Slice is playable end to end: village → tower → shore, with dialogue, a branching choice, a quest chain, the One Cinematic Moment, and save/load — 65/65 tests green. **Milestone 2 is not scoped yet** (see "Beyond the slice" — sketch only, DO NOT BUILD). Next session starts with a scoping decision, not code.*

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
- [x] Friend playtest against success criteria *(human)* — **closed 2026-08-12 on user instruction.** No unprompted-world-question log was captured into the repo; if notes were taken they live outside it. Recorded this way so a future session doesn't go looking for findings that aren't here.
- [x] Bug fixes, with regression tests for anything touching GameState/quests/saves *(as found)* — closed with the milestone 2026-08-12; nothing outstanding was reported. The standing rule survives the milestone: any future bug touching GameState/quests/saves still gets a regression test.
- [x] **SCOPE ADDITION (human decision, 2026-07-27):** two optional flavor NPCs given dialogue — **Elder Mishka** and **the blacksmith**. Both were already placed in `zone_01_village.tscn` as bare meshes and already named in `docs/zones/zone_01_home_village.md`, so this completes written Gate-0 intent rather than inventing new scope. Mishka delivers first-hand the thick-mist warning that `friend.dtl` already lets the player quote second-hand, plus a darkness/foreshadowing beat. **Deliberately NOT wired into `village_quest.tres`** — optional world-building only, so the quest chain and its save-safe stage indices are untouched. New flags `act1/talked_to_elder`, `act1/talked_to_blacksmith`. Prose is Claude-drafted and **needs a human writing pass.**

### Explicit non-goals for this milestone (from GAME_PITCH.md)
No combat, no crafting/economy, no procedural terrain, no streaming, no voice acting, no multiplayer, no console ports. Placeholder art everywhere except lighting and mood.

---

## Milestone 2 — Zone 1 Art Pass  ⟵ CURRENT
**Scoped and approved 2026-08-12.** Goal, in the user's words: make the *first zone actually feel done* rather than accumulating more graybox zones. Aligns with the Zone Design Law (density over size) and pillar #2 (mood over fidelity).

**Decisions taken 2026-08-12 (were ART_PIPELINE.md's open questions 1–6):**
- **Style: low-poly flat-shaded.** Chosen because it *removes* the hardest beginner skills — no UV unwrapping, no PBR texture painting, no Substance — and because the existing 12-material palette transfers unchanged.
- **Environment: user-authored in Blender.** Buildings, trees, props.
- **Characters: Mixamo / one character pack.** Rigging + skinning + animating 5 humans and a quadruped as a beginner is months; this is the schedule risk that would strand the village in graybox. **One source only** — mixed sources are what make a game read as an asset flip.
- **Git LFS: yes, before the first binary.** Done in Phase 0.
- **CLAUDE.md plain-text rule: amended, scoped** to `assets/` (done in Phase 0).
- Pipeline: author `.blend` → export **`.glb`** → commit. Not direct `.blend` import (machine-specific editor setting, breaks headless).

### Phase 0 — Groundwork (plain text, no art required)
- [x] Git LFS initialised **repo-locally** (`--local`, global config untouched — this is a work laptop) + `.gitattributes` scoped to `assets/` so addon PNGs are left alone
- [x] `assets/models/` + `assets/source/` created, with `.gdignore` in `source/` so Godot never attempts a Blender conversion
- [x] CLAUDE.md hard-rule amendment + project-structure block updated
- [x] `assets/README.md` — spec, rules, and the collision prohibition at point of use
- [x] ROADMAP entry (this section)

### Phase 1 — Prove the pipeline with ONE throwaway asset ✅ COMPLETE (2026-08-13)
- [x] Push a trivial object (a Blender cube is fine) through export → `assets/models/` → import → swap **one** graybox mesh (the anvil) → verify scale/axis/pivot → tests → boot — **all clean: identity node transform (no baked axis correction), AABB exactly 1 m, base pivot, 65/65 tests, clean headless boot**
- [x] Confirm the `.import` sidecar is plain text and committed, and the `.glb` goes to LFS — verified via `git check-attr` / `git lfs ls-files`; sidecar carries no machine-specific paths
- *Rationale: catches Y-up/Z-up flips, metre-scale errors and wrong pivots on a disposable asset instead of after twenty buildings exist. Do not skip.*

**It paid for itself.** Geometry was clean, but the proof caught a **colour-space error in the docs**: `ART_PIPELINE.md` §4 described the palette as linear when it is **sRGB**. Blender's Base Color is linear, so copying those numbers across would have rendered every M2 asset ~10× too bright — silent, plausible-looking palette drift across the whole village, found only after the art was built. §4 now carries a hex column; §10 has the explanation. **This is the reason the phase existed.**

Also landed: `tools/blender/export_glb.py` (pins export settings; GUI equivalents documented), Blender 5.2.0 LTS recorded in §10 as explicitly **not** a build dependency, and the now-load-bearing `.gdignore` verified.

**Carried into Phase 2:** graybox `BoxMesh` primitives are centre-pivoted, imported assets are base-pivoted — expect to drop half the height off Y on every prop swap (the anvil went `y = 0.5` → `y = 0`).

*The anvil was reverted to graybox; `smoke_cube.glb` + sidecar stay committed as a reference example of a correct import, to be deleted when Phase 2's first real asset supersedes them.*

### Phase 2 — Environment (user authors, Claude integrates)
- [ ] One building type first, verified end-to-end, before the rest
- [ ] Homes → mill/stables → guard tower → trees → props (banners, anvil, carved heart)
- [ ] Update the AABB-based tests per asset (see risk below)

### Phase 3 — Characters + animation engineering
- [ ] Retarget one Mixamo source to the 2.0 m / feet-pivot spec; mount under the existing `Model` node
- [ ] **`AnimationPlayer`/`AnimationTree` driven by velocity (idle/walk/run), blend-tuned against foot-slide** — `player.tscn` has none today. This is engineering, not art, and does not arrive with the model.

### Hard rules for this milestone
- **Art swaps touch `MeshInstance3D` ONLY — never `CollisionShape3D`.** Collision stays hand-authored primitives. Deriving it from art meshes is how the capsule seam-freeze class returns (`godot-multisegment-terrain`).
- Character art mounts under the player's existing `Model` pivot so `godot-thirdperson-controller` keeps working untouched.
- Visual results are **human-verified**; Claude cannot judge them.

### Known risk, accepted going in
`test_interaction_alignment`, `test_tower_roof` and `test_village_boundaries` assert on **mesh AABBs** — they are the guard against the "visible but unusable" bug class. Swapping box meshes for imported geometry changes those AABBs and will break them. **The wrong fix is loosening assertions until they pass**; update them deliberately, per asset, keeping the guarantee intact.

### Explicit non-goals for M2
Not a second zone. Not the quest journal UI. Not the audio pass. Those return to the parking lot below until Zone 1 reads as finished.

---

## Beyond the slice — sketch only, DO NOT BUILD
Listed only so ideas have a parking spot. Nothing here is scoped or approved.
- **M2 leftovers (deferred until Zone 1 art lands):** second zone + interconnection, quest journal UI, ambient audio pass
- **M3:** third zone, faction/relationship flags, combat *only if the story demands it*
- **M4:** content complete for Act 1, options menu, accessibility pass
