local TileMap = require("src.core.tilemap")
local Interactable = require("src.entities.interactable")
local NPC = require("src.entities.npc")

local M = {}

function M.build(world)
    -- The Restful Inn: Cozy interior with tables, candles, and inn keeper
    local map = TileMap:new(20, 15, 32)
    
    -- Create wooden floor
    local ground = {}
    for y = 0, 14 do
        ground[y] = {}
        for x = 0, 19 do
            ground[y][x] = 6 -- Wooden floor (tile ID 6)
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
    collision[14][10] = 2 -- Rock on southern wall
    
    map:loadFromData({ground = ground, collision = collision})
    world.maps["inn_interior"] = map
    
    -- Add interactables
    world.interactables["inn_interior"] = {}
    table.insert(world.interactables["inn_interior"],
        Interactable:new(9*32, 13.5*32, 32, 40, "door", {
            destination = "town",
            spawnX = 33*32,
            spawnY = 6*32
        })
    )
    table.insert(world.interactables["inn_interior"],
        Interactable:new(4*32, 3*32, 64, 64, "inn_table", { hasCandle = true, hasMug = true })
    )
    table.insert(world.interactables["inn_interior"],
        Interactable:new(14*32, 3*32, 64, 64, "inn_table", { hasCandle = true, hasMug = true })
    )
    table.insert(world.interactables["inn_interior"],
        Interactable:new(4*32, 7*32, 64, 64, "inn_table", { hasCandle = true, hasMug = true })
    )
    table.insert(world.interactables["inn_interior"],
        Interactable:new(14*32, 7*32, 64, 64, "inn_table", { hasCandle = true, hasMug = true })
    )
    table.insert(world.interactables["inn_interior"],
        Interactable:new(8*32, 2*32, 32, 32, "chest", { id = "inn_chest_mana", item = "Mana Potion" })
    )
    table.insert(world.interactables["inn_interior"],
        Interactable:new(11*32, 2*32, 32, 32, "chest", { id = "inn_chest_gold", item = "Gold", goldAmount = 100 })
    )
    
    world.enemies["inn_interior"] = {}
    world.npcs["inn_interior"] = {}
    local innKeeper = NPC:new(10*32, 8*32, "inn_keeper", {
        questState = "inn_keeper",
        useAnimations = true,
        wandering = true,
        wanderRadius = 128,
        wanderPauseMin = 2,
        wanderPauseMax = 5
    })
    table.insert(world.npcs["inn_interior"], innKeeper)
end

return M


