local TileMap = require("src.core.tilemap")
local Interactable = require("src.entities.interactable")
local Enemy = require("src.entities.enemy")

local M = {}

function M.build(world)
    -- Simple introductory cave for learning the spell system
    local map = TileMap:new(25, 18, 32)
    
    -- Cave floor (dark stone - tile 5)
    local ground = {}
    for y = 0, 17 do
        ground[y] = {}
        for x = 0, 24 do
            ground[y][x] = 5 -- Dark stone
        end
    end
    
    -- Simple layout - wide corridors, easy to navigate
    --[[
    E = Entrance (west, y=9)
    S = Scroll (center area)
    X = Exit (east, y=9)
    C = Chest
    # = Wall
    ]]
    
    local mazeLayout = {
        "#########################",
        "#                       #",
        "#   ##             ##   #",
        "#   ##             ##   #",
        "#                       #",
        "#                       #",
        "#           S           #",
        "#                       #",
        "#                       #",
        "                         ",
        "#                     C #",
        "#                       #",
        "#   ##             ##   #",
        "#   ##             ##   #",
        "#                       #",
        "#                       #",
        "#                       #",
        "#########################"
    }
    
    local collision = {}
    for y = 0, 17 do
        collision[y] = {}
        for x = 0, 24 do
            if y < #mazeLayout and x < string.len(mazeLayout[y + 1]) then
                local char = string.sub(mazeLayout[y + 1], x + 1, x + 1)
                if char == '#' then
                    collision[y][x] = 2 -- Wall
                elseif char == 'S' or char == 'C' then
                    collision[y][x] = 0 -- Special locations
                else
                    collision[y][x] = 0 -- Walkable
                end
            else
                collision[y][x] = 0
            end
        end
    end
    
    map:loadFromData({ground = ground, collision = collision})
    world.maps["cave_level1"] = map
    
    -- Interactables
    world.interactables["cave_level1"] = {}
    
    -- Glowing scroll in center (teaches Illumination spell)
    table.insert(world.interactables["cave_level1"], 
        Interactable:new(12*32, 6*32, 32, 32, "scroll", {
            spell = "Illumination"
        })
    )
    
    -- Cave entrance (leads back to overworld)
    table.insert(world.interactables["cave_level1"], 
        Interactable:new(0*32, 9*32, 64, 64, "cave_exit", {
            destination = "overworld",
            spawnX = 7*32 + 32,
            spawnY = 31*32
        })
    )
    
    -- Cave exit (leads to class selection)
    table.insert(world.interactables["cave_level1"], 
        Interactable:new(23*32, 9*32, 64, 64, "cave_exit", {
            destination = "class_selection",
            spawnX = 3*32,
            spawnY = 15*32
        })
    )
    
    -- Single chest as reward
    table.insert(world.interactables["cave_level1"], 
        Interactable:new(23*32, 10*32, 32, 32, "chest", {
            id = "cave_chest_1",
            item = "Health Potion"
        })
    )
    
    -- Just ONE skeleton enemy for flavor
    world.enemies["cave_level1"] = {}
    local skeleton1Patrol = {
        {x = 12*32, y = 12*32},
        {x = 12*32, y = 6*32}
    }
    table.insert(world.enemies["cave_level1"],
        Enemy:new(12*32, 10*32, "skeleton", {
            id = "cave_skeleton_1",
            patrolRoute = skeleton1Patrol,
            aggroRange = 100,
            deaggroRange = 180
        })
    )
    
    world.npcs["cave_level1"] = {}
end

return M


