# Art pipeline — how real art would get into this game

**Status: ✅ APPROVED AND IN PROGRESS — Milestone 2, scoped 2026-08-12.**
Written 2026-07-28 as research and parked. Its own timing gate ("close the friend playtest, then make
art an explicit M2 decision") was satisfied 2026-08-12, and the decisions were taken the same day.

**§9's six open questions are all answered now** — see ROADMAP.md "Milestone 2 — Zone 1 Art Pass" for
the authoritative record. In short: **low-poly flat-shaded**, environment authored by the user in
Blender, **characters from Mixamo/one pack**, Git LFS **yes** (done), CLAUDE.md amendment **adopted as
written in §7**, scope is **Zone 1 only**.

Everything below remains accurate as the technical reference — the spec sheet (§4), the palette, the
asset list, and the two "not free" items (§7) especially. §8's *wait* recommendation is now historical;
it has been acted on.

---

## 1. The mental model

Nothing gets "rendered into" the game. You author assets in external tools, export them to an
interchange format, drop them in the project, and the engine renders them at runtime. Graybox boxes
get swapped for models; nothing else changes.

A prop is simpler than people expect. A character is harder. A character needs six things:

| # | Thing | What it is |
|---|---|---|
| 1 | **Mesh** | the polygons |
| 2 | **UV map** | how a flat texture wraps onto the 3D surface |
| 3 | **Textures** | PBR: base colour, normal, roughness, metallic, sometimes ambient occlusion |
| 4 | **Rig / skeleton** | the bones (an "armature") |
| 5 | **Skinning weights** | which vertices follow which bones, and how much |
| 6 | **Animations** | idle, walk, run, … |

Environment props usually need only 1–3. **Items 4–6 hold nearly all the difficulty and cost**, which
is why "a village full of buildings" is a smaller job than "one convincing person who walks".

## 2. How it gets into Godot

**Format: glTF 2.0, specifically `.glb`.** Modern standard, Godot's best-supported path, and a single
`.glb` bundles mesh + materials + textures + animations in one file.

- `.blend` imports directly **if Blender is installed** (Godot silently calls Blender to convert to glTF).
- FBX works via conversion — historically fiddlier, and it handles axis conversion less cleanly.
- `.obj` is static only: no rig, no animation.

Workflow:

1. Drop `character.glb` into `res://assets/models/`. **`assets/` does not exist yet** — it is not in the
   CLAUDE.md project structure and would need adding.
2. Godot auto-imports and writes a **plain-text `.import` sidecar** beside the asset, plus a binary
   cache under `.godot/imported/` (already gitignored).
3. The `.glb` becomes instanceable as a scene. A character arrives as a `Node3D` containing
   `MeshInstance3D` + `Skeleton3D` + `AnimationPlayer`.
4. Instance it where the graybox currently sits.

**Relevant to the plain-text rule:** `.import` files **are** plain text and get committed. The binary
asset is the only genuinely binary artefact.

## 3. What this project already gets right

Two structural properties make the swap much cheaper than it could be. **Preserve both.**

- **Collision is hand-authored and separate from visuals.** Every `StaticBody3D` carries its own
  primitive `CollisionShape3D`; nothing derives collision from a render mesh. **An art swap must touch
  `MeshInstance3D` nodes only, never `CollisionShape3D`.** Auto-generating collision from art meshes is
  slower, buggier, and is exactly how the capsule-seam class of bug (see
  `godot-multisegment-terrain`) would come back.
- **The player has a `Model` Node3D child** that rotates to face travel. Character art slots under that
  pivot and `godot-thirdperson-controller` keeps working untouched.

## 4. Technical spec sheet — hand this to an artist or check any pack against it

| Spec | Value | Why |
|---|---|---|
| Engine | Godot **4.6.3-stable** | pinned; see ROADMAP |
| Format | **glTF 2.0 `.glb`** | one file, best supported |
| Units | **1 unit = 1 metre** | Godot default |
| Up axis / forward | **Y-up, −Z forward** | Blender is Z-up; glTF converts cleanly, FBX often doesn't |
| Character height | **2.0 m** | matches `player.tscn` capsule (radius 0.4, height 2.0) |
| Character pivot | **at the feet**, centred | drops straight onto the `Model` node |
| Door / interior clearance | **2.0 m doors**, tower interior walls 9.8 m, stable walls 3.5 m | existing geometry |
| Collision | **do NOT supply** | authored separately as primitives in-engine |
| Textures | PBR set; keep resolution modest | stylised target, not realism |

### Scale references already in the world
Village ground **44 × 44 m**; stables **9 wide × 6 deep**; tower interior **8 × 8**, walls 9.8 m tall;
tree trunk 0.8 × 4 m with a 3.5 × 3 m canopy; guard tower 3.5 × 9 m.

### The established colour identity (from the shipped materials)
This is the game's existing palette — an art bible should honour it, not replace it. Values are Godot
linear `Color(r, g, b)`.

| Material | Value | Reads as |
|---|---|---|
| `GroundMat` | 0.46, 0.50, 0.36 | olive-sage grass |
| `PathMat` | 0.56, 0.48, 0.38 | dry earth path |
| `WallMat` | 0.72, 0.62, 0.50 | warm plaster/daub |
| `RoofMat` | 0.50, 0.34, 0.30 | weathered tile |
| `TowerStoneMat` | 0.55, 0.56, 0.58 | cold grey stone |
| `DoorMat` | 0.30, 0.20, 0.13 | dark timber |
| `BannerMat` | 0.86, 0.74, 0.40 | **hearth gold — the village's warm accent** |
| `FlowerMat` | 0.90, 0.50, 0.62 | wedding-prep pink |
| `HeartMat` | 0.80, 0.30, 0.36 | the carved heart (emissive, capped 0.4) |
| `SteedMat` | 0.36, 0.26, 0.20 | horse brown |
| `AnvilMat` | 0.25, 0.25, 0.28 | iron |
| `CrackMat` | 0.05, 0.05, 0.05 | the tower's fracture |

Character placeholder tints, useful as costume direction: Friend `0.50, 0.60, 0.82` (blue), Aeia
`0.86, 0.60, 0.70` (rose), Elder Mishka `0.60, 0.60, 0.68` (pale grey), Blacksmith
`0.40, 0.34, 0.34` (soot), Player `0.90, 0.85, 0.30` (yellow).

The central visual tension to protect: **warm village gold against the shore's cold desaturation.**

### Asset list (what actually needs making)
**Characters (5 humanoid + 1 animal):** Player (young knight), Friend, Aeia, Elder Mishka, Blacksmith,
and the steed. All five humans are currently `CapsuleMesh`.

**Environment:** village buildings (homes, mill, stables, guard tower), the enterable tower interior
(spiral steps, newel, platform), shore terrain, trees, and props (banners, flowers, anvil, carved
heart).

**Swap surface — `MeshInstance3D` nodes per scene:** village 42, tower interior 86, shore 18, player 2,
tree 2. The tower interior's 86 is mostly the 72 stair treads, which are a single repeated mesh — treat
it as one asset, not 72.

## 5. The four paths

### A. Buy asset packs — fastest, best fit for the pillar hierarchy
Story is pillar #1 and visuals are explicitly "mood over fidelity", so bought art is the right
compromise rather than a compromise at all.

- **Free / CC0:** Quaternius and Kenney (low-poly, genuinely usable, no attribution burden), Poly Haven
  (HDRIs, textures).
- **Paid / indie:** itch.io has many cheap coherent 3D kits; Sketchfab, CGTrader, TurboSquid for
  individual models.
- **Characters:** Mixamo gives free rigged humanoids plus a large animation library. Retargeting onto
  your rig is the main work.

> **The single biggest failure mode: buy ONE coherent set, not individual models from ten artists.**
> Mixed styles is what makes a game read as an asset flip.

**Track licences.** CC0, CC-BY, "commercial use allowed" and "redistribution inside a game allowed" are
different things, and it matters if this is ever sold.

### B. Commission an artist
ArtStation, Polycount, r/gameDevClassifieds, game-dev Discords. Rough and highly variable: a simple
prop in the tens of dollars, a stylised rigged character several hundred to low thousands.

Success here is determined by the brief, not the budget. Supply the art bible (references, the palette
above, scale, poly budget) **and** section 4's spec sheet. Without them you get beautiful assets at the
wrong scale with the pivot in the wrong place.

### C. Learn it yourself
**Blender** — free, industry-viable, huge tutorial ecosystem, direct Godot integration. Texturing:
Krita or GIMP free; **Substance 3D Painter** is the paid industry standard.

Honest timelines: simple low-poly props are days. A decent rigged, animated character as a beginner is
weeks to months. The pragmatic sweet spot for a solo story-first dev is learning enough Blender for
environment props and simple stylised characters, and buying the rest.

### D. AI-generated 3D
Real, improving quickly, still immature for production characters. Meshy, Luma Genie, Tripo,
Hunyuan3D and similar do text/image-to-3D.

Honest assessment: good for static props, blockouts, and especially **concept art to brief a human
artist**. Topology and UVs tend to be messy; rigging usually needs manual cleanup. Provenance and
commercial licensing are murkier than a bought pack — check terms.

## 6. Recommended approach for this project

1. **Characters:** Mixamo, or one stylised character pack.
2. **Environment:** one coherent low-poly village kit, CC0 if possible.
3. **Keep the grayboxes as scale references** — replace box meshes in place, one at a time, verifying
   as you go rather than in one big swap.

Your atmosphere work makes this easier: fog, glow and volumetric lighting already carry most of the
mood, and **simple geometry plus strong lighting is far more forgiving for a solo dev than realism.**

## 7. Two things that are NOT free

### Character animation is engineering, not art
`player.tscn` currently has **no `AnimationPlayer` at all** — it is a capsule with a nose box. Real
character art means adding an `AnimationPlayer`/`AnimationTree` and driving idle/walk/run from velocity,
with blend timing tuned so it doesn't foot-slide. That is a work item to scope, and it does not arrive
with the model.

### CLAUDE.md needs a scoped amendment
The current hard rule is: *"Plain text everything… No solutions that require binary assets or
editor-only GUI steps Claude can't reproduce or verify."* Real art breaks this. Proposed replacement,
scoped rather than blanket:

> **Binary art assets are permitted under `assets/`**, with their plain-text `.import` sidecars
> committed. Everything else stays plain-text and Claude-verifiable: scenes, import settings, material
> overrides, shaders, animation state machines. **The visual result of a binary asset is human-verified**
> — consistent with the existing rule that rendering, feel and cinematics are human-tested. Claude must
> not be asked to author or judge model/texture content it cannot inspect.

### Also decide before the repo grows
Art and textures bloat git badly, and git handles binaries poorly. **Consider Git LFS before adding
assets, not after** — retrofitting means rewriting history.

## 8. Timing — the recommendation is to WAIT

Art appears nowhere in ROADMAP.md, including the M2/M3/M4 sketches, so under the milestone-discipline
hard rule it needs a recorded human decision before any of it is built.

More importantly, **Milestone 1 has exactly one item left: the friend playtest**, whose entire purpose
is finding out whether the *story* lands. Two risks in starting art first:

1. It is the most effective way to accidentally delay that validation by months.
2. Playtest feedback may change which zones and characters even exist, wasting anything commissioned.

**Recommendation: close the friend playtest, then make art an explicit M2 decision** alongside the
CLAUDE.md amendment and the Git LFS call.

---

## 9. Discussion record (2026-07-28) — for re-review

Preserved so this can be picked up cold rather than re-derived.

**What prompted it:** signing off the atmosphere pass. Verdict was *"the atmosphere is ok — I think it
will come together more when the art design actually comes into play and we have real player models."*
Recorded as **accepted at graybox fidelity, re-judge with real art**, so fog density, water shimmer and
particle drift are open questions for *this* phase, not settled ones.

**Stated position:** no prior experience with game art — neither the tools nor how assets reach the
engine. Hence this document leading with the mental model rather than tool recommendations.

**Open questions for you, when you return to this:**

1. **Which path** — buy a pack, commission, learn Blender, or a hybrid? (Recommendation: buy for
   environment, Mixamo for characters, commission only hero assets if at all.)
2. **Budget**, which mostly decides between paths A and B.
3. **Style commitment** — low-poly flat-shaded, stylised hand-painted, or semi-realistic? Decide once,
   up front; it constrains every later purchase and is the thing that keeps a bought-asset game
   coherent.
4. **Git LFS: yes or no**, before any binaries land.
5. **Approve the CLAUDE.md amendment** in section 7 as written, or tighten it.
6. **Scope**: full art pass, or characters only first? Characters would change the game's read the
   most, and are also the most expensive and the only ones needing animation engineering.

**Nothing in this document has been actioned.** No `assets/` folder, no amendment, no ROADMAP entry.
