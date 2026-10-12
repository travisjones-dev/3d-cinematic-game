# One-Page Pitch

## Pillar Hierarchy
The tiebreaker for every scope argument.
1. **Story / World** — SACRED. If this is mediocre, the game has failed.
2. Visuals / Atmosphere — in service of the story. Mood over fidelity.
3. Gameplay feel — must never *undermine* the story (janky movement breaks immersion), but "solid" is the bar, not "innovative."
4. Systems depth — minimum viable RPG. Cut first when time runs short.

## Genre & Frame
Medieval fantasy RPG. Handcrafted interconnected zones that *feel* open — freedom of order and density of discovery, not acreage. Story-rich, cinematic presentation.

## Premise
The Player is a young knight. The story starts with the young knight in his home village, talking with local villagers who love him, eyeing the girl of his dreams who flirts with him, meeting up with his bestfriend, another young knight. The player travels with his bestfriend through the woods, away from the village, down to the shore line, where the water stretches out endlessly but is shrouded in a thick mist. Suddenly large boats come into view....raiders....your village is no match. It's the end of the world. Your friend looks on at the approaching boats and drops his sword in disbelief, accepting his fate. You run for your life. As your friend drops to his knees, awaiting his inevitable demise. Your village is decimated. Your girl of your dreams does manage to escape but you dont find this out until later. Your bestfriend and your family are murdered. You will seek vengeance, but first you must get stronger.

## Core Loop
Explore an area -> progress through the story, meet new people, learn a skill -> make choices that impact the entire world or a relationship and the overall outcome at the end -> visually see the consequences, good or bad.

## References
Dishonored style graphics and impactful story. Kingdom Deliverance medieval vibe. Character relationship development like Mass Effect 1 or Fable 3.

## The One Cinematic Moment
The premise is the first cinematic scene of the game. It sets the tone for the rest of the game. Beginning scene: The story starts with the young knight in his home village, talking with local villagers who love him, eyeing the girl of his dreams who flirts with him, meeting up with his bestfriend, another young knight. The player travels with his bestfriend through the woods, away from the village, down to the shore line, where the water stretches out endlessly but is shrouded in a thick mist. Suddenly large boats come into view....raiders....your village is no match. It's the end of the world. Your friend looks on at the approaching boats and drops his sword in disbelief, accepting his fate. You run for your life. As your friend drops to his knees, awaiting his inevitable demise.

**Slice cutscene-tech target (decided 2026-07-14):** The full sequence above is canonical and built later. For the vertical slice, the cutscene-tech target is *one beat*: **the boats emerge from the mist and the friend drops his sword** — camera pushes past the two figures out over the misted water, the raider hulls resolve out of the fog, cut to the friend's hand opening, sword falling to the sand, him sinking to his knees as the player is pulled into a run. This single beat exercises Phantom Camera move + AnimationPlayer + Dialogic line + completion flag, and nothing more.

## Vertical Slice Definition (Milestone 1)
The smallest playable thing that proves the *story pillar*, not the systems:
- One zone (~2–4 minutes to cross), dense: 3+ environmental storytelling setups, 1 secret
- One NPC with a branching conversation (a real choice with a visible consequence)
- One complete micro-quest: hook → choice → consequence
- One scripted cinematic moment (camera move + animation + dialogue)
- Player controller that feels solid (walk/run, interact) — no combat yet unless the story demands it
- Save / quit / load preserving story flags
- Placeholder art everywhere except lighting and mood — atmosphere is pillar #2, so lighting IS allowed in the slice

## Explicit Non-Goals (weeks/months scope)
- No procedural terrain, no seamless streaming world
- No deep combat, crafting, or economy systems in the slice
- No voice acting pipeline (text-first; leave hooks for later)
- No multiplayer, no console ports

## Success Criteria for the Slice
A friend plays 10 minutes, unprompted asks a question about the world ("wait, who was—?"), and wants to know what happens next. That's the story pillar proving itself.
