# Credits — third-party assets

Every asset listed here is **CC0 / public domain**, which means attribution is *not legally
required*. It is given anyway, deliberately: these artists released substantial work for free, and
a credits scene costs us nothing.

**Keep this file current as assets land.** It is the source for an in-game credits scene if the
project ever ships. Adding an asset without adding it here means the artist quietly goes
uncredited — by the time anyone builds that scene, nobody will remember where a `.glb` came from.

For each entry: what it is, who made it, where it came from, and **what it is actually used for**,
so an unused pack can be dropped from the credits rather than crediting art that never shipped.

---

## In the game now

| Asset | Artist | Source | Used for |
|---|---|---|---|
| **RPG Character Pack** | Quaternius | [quaternius.com](https://quaternius.com/packs/rpgcharacters.html) | The whole cast — Warrior (player), Cleric (Aeia), Ranger (the friend), Wizard (Elder Mishka), Monk (the blacksmith). Rig + Idle/Walk/Run drive `player.tscn` |
| **Medieval Village Pack** | Quaternius | [quaternius.com](https://quaternius.com/packs/medievalvillage.html) | Village buildings — both homes, the mill, the stables, the guard tower |
| **Stylized Nature MegaKit** | Quaternius | via [Poly Pizza](https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm) | Trees (`tree.tscn` + pine/twisted variants), the 156-tree outer forest, and the grass/fern/bush/flower/rock ground cover |
| **Sparse Grass** (texture) | Poly Haven | [polyhaven.com/a/sparse_grass](https://polyhaven.com/a/sparse_grass) | Village ground diffuse + normal |
| **Dirt Floor** (texture) | Poly Haven | [polyhaven.com/a/dirt_floor](https://polyhaven.com/a/dirt_floor) | The dirt path through the village centre |

## Downloaded, staged for use

| Asset | Artist | Source | Intended for |
|---|---|---|---|
| **Medieval Village MegaKit** | Quaternius | [quaternius.com](https://quaternius.com/packs/medievalvillagemegakit.html) | Set dressing: chimneys, wagon, crates, fences, vines |
| **Medieval Village Pack — props** | Quaternius | [quaternius.com](https://quaternius.com/packs/medievalvillage.html) | Well, cart, barrels, hay, bonfire, market stands, fences |

---

## Licence notes

- **CC0 1.0 Universal (public domain)** covers every asset above: free for commercial use,
  modification and redistribution, with no attribution requirement and no share-alike clause.
- **Quaternius** — CC0 across the packs used here. Patreon-supported; the free tier is what we use.
- **Poly Haven** — CC0, no login required. Fetched through their public API
  (`api.polyhaven.com`), so the exact file is reproducible rather than a hand-downloaded blob.
- **Poly Pizza** is a *distributor*, not the author. Credit the artist (Quaternius) and mention
  Poly Pizza as the source, which is how the user asked for it to be recorded.

Because everything is CC0, there is **no licence text we are obliged to ship** and no per-file
notice to preserve. If a non-CC0 asset is ever added, that changes — it would need its licence
recorded here *and* its terms checked against distributing a compiled game.

## Not third-party
Everything under `scripts/`, `scenes/`, `dialogue/`, `data/`, `tests/` and `tools/` is this
project's own work, as is all narrative content. `addons/` carries its own upstream licences
(Dialogic, Phantom Camera, GUT) and is not covered by this file.
