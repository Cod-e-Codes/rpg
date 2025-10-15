local TileMap = require("tilemap")
local Interactable = require("interactable")

local M = {}

function M.build(world)
    -- Defense Trials: Elemental hazards, resistance spell, and healing strategy selection
    -- Two-part level: puzzle section with hazards + combat arena
    local TileMap = require("tilemap")
    local map = TileMap:new(30, 40, 32)
    
    -- Create stone floor
    local ground = {}
    for y = 0, 39 do
        ground[y] = {}
        for x = 0, 29 do
            ground[y][x] = 3 -- Stone floor
        end
    end
    
    -- Create walls and structure
    local collision = {}
    for y = 0, 39 do
        collision[y] = {}
        for x = 0, 29 do
            -- Outer walls
            if x == 0 or x == 29 or y == 0 or y == 39 then
                collision[y][x] = 2 -- Wall
            else
                collision[y][x] = 0 -- Walkable
            end
        end
    end
    
    -- Entrance hallway (South, y=35-38)
    for y = 35, 38 do
        for x = 12, 17 do
            collision[y][x] = 0
        end
    end
    
    -- Puzzle maze section (Middle, y=10-34)
    -- Main path with hazard zones
    for y = 10, 34 do
        for x = 8, 21 do
            collision[y][x] = 0
        end
    end
    
    -- Scroll room connection (left branch at y=15-20)
    for y = 15, 20 do
        for x = 4, 8 do  -- Extended to x=8 to connect with main path
            collision[y][x] = 0
        end
    end
    
    -- Connection to arena (y=9)
    for x = 8, 21 do
        collision[9][x] = 0
    end
    
    -- Combat Arena (North, y=2-9)
    -- Large chamber for skeleton fight
    for y = 2, 8 do
        for x = 6, 23 do
            collision[y][x] = 0
        end
    end
    
    -- Store hazards in map data
    local hazards = {}
    
    -- Fire hazards (damage zones in puzzle section)
    table.insert(hazards, {type="fire_zone", x=12*32, y=28*32, width=4*32, height=2*32, damage=5})
    table.insert(hazards, {type="fire_zone", x=14*32, y=20*32, width=3*32, height=2*32, damage=5})
    
    -- Ice hazards (slowing fields)
    table.insert(hazards, {type="ice_zone", x=10*32, y=24*32, width=5*32, height=2*32, damage=3})
    table.insert(hazards, {type="ice_zone", x=15*32, y=16*32, width=4*32, height=2*32, damage=3})
    
    -- Lightning traps (periodic damage)
    table.insert(hazards, {type="lightning_trap", x=14*32, y=26*32, interval=2, damage=10})
    table.insert(hazards, {type="lightning_trap", x=12*32, y=18*32, interval=2, damage=10})
    table.insert(hazards, {type="lightning_trap", x=17*32, y=22*32, interval=2, damage=10})
    
    -- Earth hazards (rock fall zones)
    table.insert(hazards, {type="earth_zone", x=11*32, y=30*32, width=6*32, height=2*32, damage=4})
    table.insert(hazards, {type="earth_zone", x=13*32, y=14*32, width=4*32, height=2*32, damage=4})
    
    map:loadFromData({ground = ground, collision = collision, hazards = hazards})
    world.maps["defense_trials"] = map
    
    -- Add interactables
    world.interactables["defense_trials"] = {}
    
    -- Entrance from ancient path (south entrance)
    table.insert(world.interactables["defense_trials"], 
        Interactable:new(14*32, 37*32, 32, 48, "door", {
            destination = "overworld",
            spawnX = 40*32,
            spawnY = 8*32
        })
    )
    
    -- Entrance sign
    table.insert(world.interactables["defense_trials"],
        Interactable:new(13*32, 36*32, 32, 32, "sign", {
            message = "Face the elemental trials ahead...\nFind the resistance scroll to survive!"
        })
    )
    
    -- Resistance spell scroll (left branch)
    table.insert(world.interactables["defense_trials"],
        Interactable:new(5*32, 17*32, 32, 32, "scroll", {
            spell = "resistance" -- Will be element-specific
            -- No questRequired - always visible
        })
    )
    
    -- Scroll room sign
    table.insert(world.interactables["defense_trials"],
        Interactable:new(7*32, 17*32, 32, 32, "sign", {
            message = "← Resistance Scroll"
        })
    )
    
    -- Arena entrance sign
    table.insert(world.interactables["defense_trials"],
        Interactable:new(14*32, 11*32, 32, 32, "sign", {
            message = "Prepare yourself... The trial begins ahead."
        })
    )
    
    -- Combat trigger chest (center of arena) - no item, just triggers fight
    table.insert(world.interactables["defense_trials"],
        Interactable:new(14*32, 5*32, 32, 32, "chest", {
            id = "trial_chest",
            triggersSkeletons = true
        })
    )
    
    -- Strategy Selection Icons (appear after combat)
    table.insert(world.interactables["defense_trials"],
        Interactable:new(9*32, 5*32, 64, 64, "strategy_icon", {
            strategy = "armor",
            strategyName = "Tank",
            description = "Fortify your defenses",
            questRequired = "skeletons_defeated"
        })
    )
    table.insert(world.interactables["defense_trials"],
        Interactable:new(14*32, 5*32, 64, 64, "strategy_icon", {
            strategy = "drain",
            strategyName = "Lifesteal",
            description = "Drain life from your foes",
            questRequired = "skeletons_defeated"
        })
    )
    table.insert(world.interactables["defense_trials"],
        Interactable:new(19*32, 5*32, 64, 64, "strategy_icon", {
            strategy = "necromancer",
            strategyName = "Soul Reaper",
            description = "Harvest souls for power",
            questRequired = "skeletons_defeated"
        })
    )
    
    -- Exit portal (appears after strategy selection)
    table.insert(world.interactables["defense_trials"],
        Interactable:new(14*32, 3*32, 64, 64, "portal", {
            destination = "overworld",
            spawnX = 40*32,
            spawnY = 8*32,
            questRequired = "strategy_selected"
        })
    )
    
    world.enemies["defense_trials"] = {}
    world.npcs["defense_trials"] = {}
end

return M


