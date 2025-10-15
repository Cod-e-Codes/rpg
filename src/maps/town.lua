local TileMap = require("tilemap")
local Interactable = require("interactable")
local NPC = require("npc")

local M = {}

function M.build(world)
    -- Trading Town: Village marketplace with merchants and shops
    local TileMap = require("tilemap")
    local map = TileMap:new(50, 40, 32)
    
    -- Create ground layer (grass with variation + stone paths)
    local ground = {}
    for y = 0, 39 do
        ground[y] = {}
        for x = 0, 49 do
            if (x + y) % 6 == 0 then
                ground[y][x] = 4 -- Grass variant
            else
                ground[y][x] = 1 -- Normal grass
            end
        end
    end
    
    -- Main stone path from entrance (south) to central plaza
    for y = 30, 39 do
        for x = 22, 27 do
            ground[y][x] = 2 -- Path
        end
    end
    
    -- Central plaza (rectangular stone area with fountain)
    for y = 15, 28 do
        for x = 18, 31 do
            ground[y][x] = 2
        end
    end
    
    -- Paths to shops
    for y = 18, 25 do
        for x = 10, 17 do ground[y][x] = 2 end
    end
    for y = 18, 25 do
        for x = 32, 39 do ground[y][x] = 2 end
    end
    for y = 8, 14 do
        for x = 20, 29 do ground[y][x] = 2 end
    end
    
    -- Create collision layer
    local collision = {}
    for y = 0, 39 do
        collision[y] = {}
        for x = 0, 49 do
            collision[y][x] = 0
        end
    end
    
    -- Outer fences and barriers
    for x = 0, 49 do
        collision[0][x] = 1
        collision[39][x] = 1
    end
    for y = 0, 39 do
        collision[y][0] = 1
        collision[y][49] = 1
    end
    for x = 22, 27 do collision[39][x] = 1 end
    for x = 1, 48 do
        if x < 22 or x > 27 then collision[38][x] = 2 end
        collision[1][x] = 2
    end
    for y = 1, 38 do
        collision[y][1] = 2
        collision[y][48] = 2
    end
    
    -- Building collisions (same layout as original)
    for y = 10, 16 do for x = 8, 14 do
        if y == 10 or x == 8 or y == 16 or (x == 14 and y ~= 13) then collision[y][x] = 2 end
    end end
    for y = 10, 16 do for x = 35, 41 do
        if y == 10 or x == 41 or y == 16 or (x == 35 and y ~= 13) then collision[y][x] = 2 end
    end end
    for y = 3, 9 do for x = 10, 16 do
        if y == 3 or x == 10 or y == 9 or (x == 16 and y ~= 6) then collision[y][x] = 2 end
    end end
    for y = 3, 9 do for x = 33, 39 do
        if y == 3 or x == 39 or y == 9 or (x == 33 and y ~= 6) then collision[y][x] = 2 end
    end end
    
    -- Fountain water and stones (collision only stored here)
    for y = 20, 23 do for x = 23, 26 do collision[y][x] = 1 end end
    for x = 22, 27 do collision[19][x] = 2 end
    for x = 22, 27 do collision[24][x] = 2 end
    for y = 20, 23 do collision[y][22] = 2 end
    for y = 20, 23 do collision[y][27] = 2 end
    
    -- Decorations
    local treePositions = {
        {5,5},{5,35},{45,5},{45,35},{8,20},{41,20},{15,30},{34,30},{18,8},{31,8}
    }
    for _, pos in ipairs(treePositions) do collision[pos[2]][pos[1]] = 2 end
    local benchPositions = { {19,19},{30,19},{19,24},{30,24} }
    for _, pos in ipairs(benchPositions) do collision[pos[2]][pos[1]] = 2 end
    
    -- Layers
    local roofs = {}
    for y = 0, 39 do
        roofs[y] = {}
        for x = 0, 49 do roofs[y][x] = 0 end
    end
    -- Add roofs to buildings
    -- General Store roof
    for y = 10, 16 do
        for x = 8, 14 do
            roofs[y][x] = 1
        end
    end
    -- Potion Shop roof
    for y = 10, 16 do
        for x = 35, 41 do
            roofs[y][x] = 1
        end
    end
    -- Weapon/Armor Shop roof
    for y = 3, 9 do
        for x = 10, 16 do
            roofs[y][x] = 1
        end
    end
    -- Inn/Tavern roof
    for y = 3, 9 do
        for x = 33, 39 do
            roofs[y][x] = 1
        end
    end
    
    -- Water layer (for fountain)
    local water = {}
    for y = 0, 39 do
        water[y] = {}
        for x = 0, 49 do water[y][x] = 0 end
    end
    for y = 20, 23 do
        for x = 23, 26 do
            water[y][x] = 5 -- Fountain water tile id
        end
    end
    
    map:loadFromData({ground = ground, collision = collision, roofs = roofs, water = water})
    world.maps["town"] = map
    
    -- Interactables
    world.interactables["town"] = {}
    table.insert(world.interactables["town"],
        Interactable:new(24*32, 38*32, 64, 64, "eastern_path", {
            targetMap = "overworld",
            spawnX = 78*32,
            spawnY = 29*32
        })
    )
    
    -- Inn door (The Restful Inn) - Door faces west at x=33, y=6
    table.insert(world.interactables["town"],
        Interactable:new(33*32, 6*32, 32, 48, "door", {
            destination = "inn_interior",
            spawnX = 10*32,
            spawnY = 12*32,
            isSideDoor = true
        })
    )
    table.insert(world.interactables["town"],
        Interactable:new(24*32 - 100, 36*32, 32, 32, "sign", {
            message = "Welcome to Sanctuary Village!\nTraders welcome, danger is left at the gate."
        })
    )
    table.insert(world.interactables["town"],
        Interactable:new(24*32, 18*32, 32, 32, "sign", {
            message = "Sanctuary Fountain\nMay your travels be safe."
        })
    )
    table.insert(world.interactables["town"],
        Interactable:new(15*32, 11*32, 32, 32, "sign", { message = "General Store\n(Coming Soon)" })
    )
    table.insert(world.interactables["town"],
        Interactable:new(34*32, 11*32, 32, 32, "sign", { message = "Potion Shop\nHealthy choices inside!" })
    )
    table.insert(world.interactables["town"],
        Interactable:new(17*32, 4*32, 32, 32, "sign", { message = "Weapon & Armor\n(Coming Soon)" })
    )
    table.insert(world.interactables["town"],
        Interactable:new(32*32, 4*32, 32, 32, "sign", { message = "The Restful Inn\nWarm beds & cold drinks!" })
    )
    
    -- NPCs
    world.enemies["town"] = {}
    world.npcs["town"] = {}
    table.insert(world.npcs["town"],
        NPC:new(24*32, 32*32, "village_quest_giver", { questState = "town_greeter", useAnimations = true })
    )
    table.insert(world.npcs["town"],
        NPC:new(37*32, 13*32, "merchant", { questState = "potion_merchant", shopType = "potions" })
    )
end

return M


