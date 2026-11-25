# Game Brief: Nightfall Hollow

## In your words
- "i wanna create a 2d pixel games like terraria and recommend me any engine suitable for it"
- Concept pick: "all of it"
- "2D pixel Terraria-like sandbox: dig procedural caves, craft tools, survive monsters at night, build a settlement that defends itself, and descend into a fresh procedural world each run"
- 1. What ends a run: "you pick"
- 2. Between runs: "you pick"
- 3. The settlement: "you pick"
- 4. Feel: "you pick"
- 5. Look: "you pick"
- 6. How hard: "you pick"
- 7. Goal: "you pick"
- 8. Slice or quick test: "you pick"

**Pitch:** Dig a fresh pixel world by day, craft what you find into tools and walls, and hold your shelter through the night. *(guessed)*

**Genre:** survival-crafting and mining, with a roguelite run on top (side view)

**Controls:** A/D to move, Space to jump, hold left mouse to dig or attack, right mouse to place a block, 1 to 9 to pick a hotbar slot, E to open crafting. *(guessed)*

**Question:** Is digging by day and holding a shelter you built by night fun for ten minutes? *(guessed)*

**Hooks:** The shelter that saves you at night is made from what you dug that day, in a world nobody has seen before. *(guessed)*

**Intent:**

## Look and references
- Look: modern 16-bit pixel *(provisional)*. Mood: a warm surface by day and a cold blue night. Scale: 16-pixel tiles at whole-number scale, with a camera that never moves in sub-pixels. Shapes: blocky world, a small rounded digger, sharp angular monsters. Palette: earth browns and moss green for the ground, cool grey stone, the player in warm orange, threats in sickly violet with bright eyes, ore as the glinting accent; shadows cooler, lights warmer. Rules: one pixel density, a dark one-pixel outline on figures only, flat shading with one highlight step. Signature: darkness that swallows the caves, with torchlight carving warm pools out of it. Every figure drawn, no emoji, no plain circles.
- References: Terraria (the side-view dig, build and night loop; not its art, names or characters).
- View: 2D · Camera: side view that follows the digger.

## First minute
You stand on grass under a low sun with a pickaxe in hand. Holding the mouse on dirt cracks it in steps and the bits fly to you. A tree gives wood and the crafting list lights up with a torch and wood walls, while greyed recipes say what they still need. An ore glint a few tiles down pulls you into the first cave, where it gets dark until you place a torch. Then the sky starts to turn. You climb out and wall yourself in as the first monster reaches the door. *(guessed)*

## Challenge
The first night comes about two minutes in. A basic walled shelter with a torch survives it. Monsters walk at you and chew through weak walls, so dirt holds briefly and stone holds longer. Dying drops what you carried where you fell and you wake at your bed. Each night brings more monsters and a new kind. *(provisional)*

## Core loop
- Dig and chop by day: blocks become materials, and deeper holds better ore.
- Craft: materials become a better pickaxe, a sword, torches and stronger walls.
- Build before dusk, then defend through the night.
- At dawn, repair, dig deeper and repeat. Winning or starting over makes a new world.
- Leads: mining leads the dig and the haul; survival leads recipes, the night threat and the base; the roguelite leads the run's shape (fresh world, nothing carried over).

## Goal & fail state
- Win: survive three nights. *(provisional)*
- Fail: soft. Dying drops your carried items and returns you to your bed; a new run makes a new world. *(provisional)*

## Features
- [x] A side-view world generated from a seed each run: surface, dirt, stone, caves, ore, trees
- [x] Digging that cracks blocks in steps, with harder rock deeper and rock that says what tool it needs
- [x] Ore that glints before you reach it, and pickups that fly to you
- [x] A craft list that shows what you can make now and what greyed recipes are missing
- [x] Block placing on a grid with a ghost preview, for walls, doors and torches
- [x] A day and night cycle with felt dusk, darkness and torchlight
- [x] 3 night monster kinds, each attacking differently (a walker that chews walls, a leaper, a flyer)

## Your systems
- dig procedural caves · in the slice
- craft tools · in the slice
- survive monsters at night · in the slice
- build a settlement that defends itself · thin stand-in *(guessed)*
- descend into a fresh procedural world each run · thin stand-in *(guessed)*

## Keep
-

## Avoid
- Terraria's name, art, characters and UI

## Out of scope
- Turrets and settlers that defend for you: add it as a feature
- Permanent upgrades between runs: add it as a feature
- Tool tiers that open new regions: grow it
- Bosses whose rewards open a new frontier: add it as a feature
- Hunger and other needs: add it as a feature
- Saving a world between sessions: grow it

## Build order
1. The slice: generated world, digging, three recipes, placing, one night with one monster, win and death.
2. The other two monster kinds and the rising nights.
3. Lighting, glints, crack steps and sound.

---
**Kill condition:** if digging still feels like a chore after two tuning rounds. *(guessed)*

**Who it's for / what they feel:** solo sandbox players who want the greedy pull of one more block before dark. *(guessed)*

**Games you love / don't:** Love Terraria.
