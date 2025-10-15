local TileMap = require("src.core.tilemap")
local Interactable = require("src.entities.interactable")
local NPC = require("npc")

local M = {}

function M.build(world)
    local map = TileMap:new(15, 12, 32)
    
    -- Simple interior floor
    local ground = {}
    for y = 0, 11 do
        ground[y] = {}
        for x = 0, 14 do
            ground[y][x] = 3 -- Stone floor
        end
    end
    
    -- Walls (using 2 for visible walls)
    local collision = {}
    for y = 0, 11 do
        collision[y] = {}
        for x = 0, 14 do
            if x == 0 or x == 14 or y == 0 or y == 11 then
                collision[y][x] = 2  -- Visible wall
            else
                collision[y][x] = 0
            end
        end
    end
    
    -- Door opening at bottom center
    collision[11][7] = 0
    
    map:loadFromData({ground = ground, collision = collision})
    world.maps["house_interior"] = map
    
    -- Interior objects
    world.interactables["house_interior"] = {}
    
    -- Exit door (at bottom wall, overlapping) - match original behavior
    table.insert(world.interactables["house_interior"], 
        Interactable:new(7*32, 10.5*32, 32, 40, "door", {
            destination = "overworld",
            spawnX = 55*32,
            spawnY = 20*32  -- Spawn outside house door
        })
    )
    
    -- Chest inside house (Magic Sword reward)
    table.insert(world.interactables["house_interior"], 
        Interactable:new(7*32, 2*32, 32, 32, "chest", {
            id = "house_chest",
            item = "Magic Sword"
        })
    )
    
    -- Merchant will also be inside the house after quest progression
    world.npcs["house_interior"] = {}
    table.insert(world.npcs["house_interior"],
        NPC:new(7*32, 6*32, "merchant", {})
    )
end

return M


