local TileMap = require("tilemap")
local Interactable = require("interactable")

local M = {}

function M.build(world)
    -- Class Selection: Choose your wizard class
    local TileMap = require("tilemap")
    local map = TileMap:new(30, 20, 32)
    
    -- Simple grassy ground
    local ground = {}
    for y = 0, 19 do
        ground[y] = {}
        for x = 0, 29 do
            ground[y][x] = 1 -- Grass
        end
    end
    
    -- Basic perimeter walls
    local collision = {}
    for y = 0, 19 do
        collision[y] = {}
        for x = 0, 29 do
            if x == 0 or x == 29 or y == 0 or y == 19 then
                collision[y][x] = 2 -- Wall
            else
                collision[y][x] = 0 -- Walkable
            end
        end
    end
    
    map:loadFromData({ground = ground, collision = collision})
    world.maps["class_selection"] = map
    
    -- Add interactables
    world.interactables["class_selection"] = {}
    
    -- Cave exit on west side (return to cave)
    table.insert(world.interactables["class_selection"], 
        Interactable:new(1*32, 8*32, 96, 96, "cave_exit", {
            destination = "cave_level1",
            spawnX = 23*32 + 32,  -- Near the east exit where they came from
            spawnY = 9*32
        })
    )
    
    -- Sign pointing to cave (left arrow)
    table.insert(world.interactables["class_selection"],
        Interactable:new(6*32, 9*32, 32, 32, "sign", {
            message = "<- Mysterious cave",
            arrow = "left"
        })
    )
    
    -- Portal on eastern border (return to overworld) - only available after class selection
    table.insert(world.interactables["class_selection"],
        Interactable:new(27*32, 9*32, 64, 64, "portal", {
            destination = "overworld",
            spawnX = 30*32,  -- Spawn player safely in overworld
            spawnY = 30*32,
            questRequired = "class_selected"  -- Only visible after choosing a class
        })
    )
    
    -- Sign pointing to portal (right arrow) - only visible after class selection
    table.insert(world.interactables["class_selection"],
        Interactable:new(24*32, 9*32, 32, 32, "sign", {
            message = "Back to Overworld ->",
            arrow = "right",
            questRequired = "class_selected"  -- Only visible after choosing a class
        })
    )
    
    -- Class Selection Icons (elemental spells)
    -- Fire Mage
    table.insert(world.interactables["class_selection"],
        Interactable:new(8*32, 6*32, 64, 64, "class_icon", {
            element = "fire",
            className = "Fire Mage",
            description = "Master of flames and destruction"
        })
    )
    
    -- Ice Mage
    table.insert(world.interactables["class_selection"],
        Interactable:new(14*32, 6*32, 64, 64, "class_icon", {
            element = "ice",
            className = "Ice Mage",
            description = "Controller of frost and cold"
        })
    )
    
    -- Lightning Mage
    table.insert(world.interactables["class_selection"],
        Interactable:new(8*32, 12*32, 64, 64, "class_icon", {
            element = "lightning",
            className = "Storm Mage",
            description = "Wielder of thunder and lightning"
        })
    )
    
    -- Earth Mage
    table.insert(world.interactables["class_selection"],
        Interactable:new(14*32, 12*32, 64, 64, "class_icon", {
            element = "earth",
            className = "Earth Mage",
            description = "Master of stone and earth"
        })
    )
    
    world.enemies["class_selection"] = {}
    world.npcs["class_selection"] = {}
end

return M


