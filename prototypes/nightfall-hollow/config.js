// PROTOTYPE - NOT FOR PRODUCTION
// Question: Is digging by day and holding a shelter you built by night fun for ten minutes?
// Date: 2026-11-25
// Every tuning value lives here, each with value, min, max and step. The game reads them live
// through tune.<name> (index.html); the tweak panel, an add-on, writes them back here.
window.CONFIG = {
  seed: 1, // every gameplay random call reads rng(), seeded from this (or ?seed= in the address)
  volume: { value: 0.5, min: 0, max: 1, step: 0.05 },

  // The digger
  moveSpeed: { value: 105, min: 60, max: 220, step: 5 },      // px per second
  jumpSpeed: { value: 290, min: 200, max: 420, step: 10 },    // px per second, upward
  gravity: { value: 900, min: 400, max: 1600, step: 50 },     // px per second squared
  reach: { value: 4.5, min: 2, max: 8, step: 0.5 },           // tiles the digger can dig or place from
  playerHp: { value: 100, min: 20, max: 300, step: 10 },
  regen: { value: 3, min: 0, max: 20, step: 0.5 },            // hp per second while near a torch
  regenRange: { value: 4, min: 1, max: 8, step: 1 },          // tiles from a torch that count as near
  playerLight: { value: 7, min: 0, max: 15, step: 1 },        // the helmet lamp's light level
  invuln: { value: 0.8, min: 0.1, max: 2, step: 0.1 },        // seconds safe after a hit

  // Digging: seconds to break one block with the starting pickaxe
  digDirt: { value: 0.4, min: 0.1, max: 2, step: 0.05 },
  digWood: { value: 0.55, min: 0.1, max: 2, step: 0.05 },
  digStone: { value: 1.0, min: 0.2, max: 4, step: 0.1 },
  digOre: { value: 1.4, min: 0.2, max: 4, step: 0.1 },
  digDeep: { value: 2.0, min: 0.4, max: 6, step: 0.1 },       // needs the copper pickaxe
  digIron: { value: 2.4, min: 0.4, max: 6, step: 0.1 },       // needs the copper pickaxe
  pickPowerCopper: { value: 1.8, min: 1, max: 4, step: 0.1 }, // how much faster the copper pickaxe digs
  glintRange: { value: 7, min: 2, max: 14, step: 1 },         // tiles at which ore starts to glint

  // Recipes: what each costs and gives
  torchWood: { value: 1, min: 1, max: 5, step: 1 },
  torchYield: { value: 2, min: 1, max: 6, step: 1 },
  wallWood: { value: 1, min: 1, max: 5, step: 1 },
  wallYield: { value: 2, min: 1, max: 6, step: 1 },
  doorWood: { value: 3, min: 1, max: 10, step: 1 },
  swordWoodCost: { value: 5, min: 1, max: 15, step: 1 },
  pickCopperWood: { value: 3, min: 1, max: 10, step: 1 },
  pickCopperOre: { value: 6, min: 1, max: 20, step: 1 },
  swordCopperWood: { value: 2, min: 1, max: 10, step: 1 },
  swordCopperOre: { value: 5, min: 1, max: 20, step: 1 },
  swordIronWood: { value: 2, min: 1, max: 10, step: 1 },
  swordIronOre: { value: 5, min: 1, max: 20, step: 1 },

  // Day and night, in seconds
  dayLength: { value: 105, min: 30, max: 300, step: 5 },
  duskLength: { value: 15, min: 5, max: 60, step: 1 },        // the first night starts at dayLength + duskLength
  nightLength: { value: 70, min: 20, max: 200, step: 5 },
  nightsToWin: { value: 3, min: 1, max: 10, step: 1 },
  nightLight: { value: 5, min: 0, max: 15, step: 1 },         // sky light level at night (15 is full day)
  torchLight: { value: 14, min: 4, max: 15, step: 1 },

  // The night's ramp
  spawnFirst: { value: 3, min: 0, max: 20, step: 1 },         // seconds into a night before the first monster
  spawnInterval: { value: 7, min: 1, max: 20, step: 0.5 },    // seconds between monsters on night 1
  spawnIntervalStep: { value: 1.5, min: 0, max: 5, step: 0.5 }, // seconds shaved off each later night
  spawnIntervalMin: { value: 2.5, min: 0.5, max: 10, step: 0.5 },
  monsterCap: { value: 3, min: 1, max: 12, step: 1 },         // alive at once on night 1
  monsterCapStep: { value: 2, min: 0, max: 5, step: 1 },      // more alive at once each later night

  // Gnawer: walks at you and chews through walls
  gnawerSpeed: { value: 45, min: 10, max: 120, step: 5 },     // px per second
  gnawerHp: { value: 30, min: 5, max: 100, step: 5 },
  gnawerDamage: { value: 10, min: 1, max: 50, step: 1 },
  gnawerHop: { value: 230, min: 100, max: 400, step: 10 },    // clears one block, never two
  chewDirt: { value: 2, min: 0.5, max: 10, step: 0.5 },       // seconds for a gnawer to chew through
  chewWood: { value: 5, min: 0.5, max: 20, step: 0.5 },
  chewStone: { value: 9, min: 0.5, max: 30, step: 0.5 },

  // Leaper: jumps over low walls
  leaperSpeed: { value: 120, min: 40, max: 240, step: 10 },
  leaperJump: { value: 330, min: 200, max: 500, step: 10 },   // clears three blocks
  leaperRest: { value: 0.9, min: 0.2, max: 3, step: 0.1 },    // seconds between leaps
  leaperHp: { value: 20, min: 5, max: 100, step: 5 },
  leaperDamage: { value: 12, min: 1, max: 50, step: 1 },

  // Duskwing: flies in over any wall that has no roof
  flyerSpeed: { value: 62, min: 20, max: 160, step: 2 },
  flyerHp: { value: 14, min: 5, max: 100, step: 1 },
  flyerDamage: { value: 8, min: 1, max: 50, step: 1 },

  // Fighting back
  pickDamage: { value: 5, min: 1, max: 30, step: 1 },
  swordWood: { value: 10, min: 1, max: 60, step: 1 },
  swordCopper: { value: 16, min: 1, max: 60, step: 1 },
  swordIron: { value: 24, min: 1, max: 60, step: 1 },
  swingTime: { value: 0.35, min: 0.1, max: 1, step: 0.05 },   // seconds between swings
  swingRange: { value: 28, min: 12, max: 60, step: 2 },       // px in front of the digger
  knockback: { value: 160, min: 0, max: 400, step: 10 },      // px per second

  // The world
  caves: { value: 46, min: 0, max: 120, step: 2 },            // cave tunnels carved per world
  copperVeins: { value: 70, min: 0, max: 200, step: 5 },
  ironVeins: { value: 40, min: 0, max: 200, step: 5 },
  treeChance: { value: 0.14, min: 0, max: 0.5, step: 0.01 },  // chance of a tree on each surface column
};
