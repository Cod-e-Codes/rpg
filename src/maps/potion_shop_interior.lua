local TileMap = require("src.core.tilemap")
local Interactable = require("src.entities.interactable")
local NPC = require("src.entities.npc")

local M = {}

function M.build(world)
    -- Potion Shop Interior: Magical apothecary with merchant behind counter
    local map = TileMap:new(20, 15, 32)
    
    -- Create wooden floor
    local ground = {}
    for y = 0, 14 do
        ground[y] = {}
        for x = 0, 19 do
            ground[y][x] = 6 -- Wooden floor (same as inn)
        end
    end
    
    -- Create walls and collision
    local collision = {}
    for y = 0, 14 do
        collision[y] = {}
        for x = 0, 19 do
            if x == 0 or x == 19 or y == 0 or y == 14 then
                collision[y][x] = 2 -- Wall
            else
                collision[y][x] = 0 -- Walkable
            end
        end
    end
    
    -- Door opening (south side, centered)
    collision[14][9] = 0
    collision[14][10] = 0
    
    -- Rock beside the door
    collision[14][10] = 2 -- Rock at tile (10, 14)
    
    map:loadFromData({ground = ground, collision = collision})
    world.maps["potion_shop_interior"] = map
    
    -- Add interactables
    world.interactables["potion_shop_interior"] = {}
    
    -- Exit door back to town
    table.insert(world.interactables["potion_shop_interior"],
        Interactable:new(9*32, 13.5*32, 32, 40, "door", {
            destination = "town",
            spawnX = 37*32,
            spawnY = 13*32
        })
    )
    
    -- Potion shelves and displays
    table.insert(world.interactables["potion_shop_interior"],
        Interactable:new(2*32, 2*32, 64, 96, "potion_shelf", { 
            potionTypes = {"health", "mana", "magic"},
            hasGlow = true
        })
    )
    
    table.insert(world.interactables["potion_shop_interior"],
        Interactable:new(15*32, 2*32, 64, 96, "potion_shelf", { 
            potionTypes = {"rare", "mystic", "elixir"},
            hasGlow = true
        })
    )
    
    -- Alchemy table with magical equipment
    table.insert(world.interactables["potion_shop_interior"],
        Interactable:new(3*32, 11*32, 96, 64, "alchemy_table", {
            hasMortar = true,
            hasBottles = true,
            hasHerbs = true,
            magical = true
        })
    )
    
    -- Magical ingredients storage
    table.insert(world.interactables["potion_shop_interior"],
        Interactable:new(14*32, 11*32, 64, 64, "ingredient_cabinet", {
            hasJars = true,
            hasCrystals = true,
            hasHerbs = true
        })
    )
    
    -- Enemies (none in shop)
    world.enemies["potion_shop_interior"] = {}
    
    -- NPCs - Move merchant here behind the counter near north wall
    world.npcs["potion_shop_interior"] = {}
    local merchant = NPC:new(10*32, 2*32, "merchant", {
        questState = "potion_merchant",
        shopType = "potions",
        behindCounter = true
    })
    table.insert(world.npcs["potion_shop_interior"], merchant)
end

return M
