local TileMap = require("src.core.tilemap")
local Interactable = require("src.entities.interactable")
local NPC = require("npc")
local Enemy = require("enemy")

local M = {}

function M.build(world)
    -- Create a simple example map (much larger world)
    local map = TileMap:new(80, 60, 32)
    
    -- Ground layer
    local ground = {}
    for y = 0, 59 do
        ground[y] = {}
        for x = 0, 79 do
            if (x + y) % 7 == 0 then ground[y][x] = 4 else ground[y][x] = 1 end
        end
    end
    for y = 28, 31 do for x = 0, 79 do ground[y][x] = 2 end end
    for x = 38, 41 do for y = 0, 59 do ground[y][x] = 2 end end
    
    -- Collision layer
    local collision = {}
    for y = 0, 59 do
        collision[y] = {}
        for x = 0, 79 do collision[y][x] = 0 end
    end
    -- House
    for y = 10, 18 do for x = 50, 60 do
        if y == 10 or y == 18 or x == 50 or x == 60 then collision[y][x] = 2 end
    end end
    -- Edges
    for x = 0, 79 do collision[0][x] = 2; collision[59][x] = 2 end
    for y = 0, 59 do collision[y][0] = 2; collision[y][79] = 2 end
    -- Northern border setup
    collision[-1] = collision[-1] or {}
    for x = 38, 41 do
        collision[-1][x] = 2
        collision[0][x] = 0
    end
    -- Eastern border rocks and clear row
    for y = 27, 31 do collision[y][79] = 2; collision[y][78] = 0 end
    -- Invisible eastern barrier
    for y = 27, 31 do collision[y][80] = 1 end
    
    -- Random rocks
    for i = 1, 30 do
        local tx = math.random(5, 75)
        local ty = math.random(5, 55)
        local onPath = (ty >= 28 and ty <= 31) or (tx >= 38 and tx <= 41)
        local onWater = (tx >= 15 and tx <= 19)
        local onHouse = (tx >= 50 and tx <= 60 and ty >= 10 and ty <= 18)
        if not onPath and not onWater and not onHouse then collision[ty][tx] = 2 end
    end
    
    -- Roofs layer
    local roofs = {}
    for y = 0, 59 do roofs[y] = {}; for x = 0, 79 do roofs[y][x] = 0 end end
    for y = 10, 18 do for x = 50, 60 do roofs[y][x] = 1 end end
    
    -- Water layer (river + bridge)
    local water = {}
    for y = 0, 59 do water[y] = {}; for x = 0, 79 do water[y][x] = 0 end end
    for y = 0, 59 do for x = 15, 19 do water[y][x] = 1; collision[y][x] = 1 end end
    for y = 28, 31 do for x = 15, 19 do water[y][x] = 2; collision[y][x] = 0 end end
    
    -- Decorations
    local decorations = {}
    for y = 0, 59 do decorations[y] = {}; for x = 0, 79 do decorations[y][x] = 0 end end
    local treePlaces = { {25,10},{30,8},{48,5},{65,7},{8,20},{72,22},{25,35},{48,38},{10,48},{35,52},{58,50},{72,54} }
    for _, pos in ipairs(treePlaces) do
        local tx, ty = pos[1], pos[2]
        if collision[ty][tx] == 0 and not (ty >= 28 and ty <= 31) and not (tx >= 38 and tx <= 41) and not (tx >= 15 and tx <= 19) then
            decorations[ty][tx] = 1; collision[ty][tx] = 2
        end
    end
    local bushPlaces = { {23,6},{44,10},{63,8},{33,16},{70,18},{7,22},{27,34},{50,40},{60,44},{13,50},{26,46},{50,52},{68,46},{20,25},{10,38},{42,44} }
    for _, pos in ipairs(bushPlaces) do
        local bx, by = pos[1], pos[2]
        local onHorizontalPath = (by >= 28 and by <= 31)
        local onVerticalPath = (bx >= 38 and bx <= 41)
        local onWater = (bx >= 15 and bx <= 19)
        local nearHouse = (bx >= 50 and bx <= 60 and by >= 18 and by <= 22)
        if collision[by] and collision[by][bx] == 0 and not onHorizontalPath and not onVerticalPath and not onWater and not nearHouse then
            decorations[by][bx] = 2; collision[by][bx] = 2
        end
    end
    
    map:loadFromData({ground = ground, collision = collision, roofs = roofs, water = water, decorations = decorations})
    world.maps["overworld"] = map
    
    -- Interactables
    world.interactables["overworld"] = {}
    table.insert(world.interactables["overworld"], Interactable:new(20*32, 15*32, 32, 32, "chest", {id = "chest_1", item = "Gold Key"}))
    table.insert(world.interactables["overworld"], Interactable:new(45*32, 35*32, 32, 32, "chest", {id = "chest_2", item = "Health Potion"}))
    table.insert(world.interactables["overworld"], Interactable:new(55*32, 18*32 - 16, 32, 48, "door", {destination = "house_interior", spawnX = 7*32, spawnY = 9*32, isHouseDoor = true}))
    table.insert(world.interactables["overworld"], Interactable:new(35*32, 25*32, 32, 32, "sign", {message = "Welcome, traveler. Many secrets lie hidden in this land..."}))
    table.insert(world.interactables["overworld"], Interactable:new(0, 26*32, 160, 192, "cave", {id = "mysterious_cave", targetMap = "cave_level1", spawnX = 3*32, spawnY = 9*32, questMinimum = "sword_collected"}))
    table.insert(world.interactables["overworld"], Interactable:new(1211, -182, 139, 192, "ancient_path", {targetMap = "defense_trials", spawnX = 14*32, spawnY = 35*32, questMinimum = "has_class"}))
    table.insert(world.interactables["overworld"], Interactable:new(80*32 - 32, 30*32 - 32, 64, 64, "eastern_path", {targetMap = "town", spawnX = 24*32, spawnY = 37*32, questMinimum = "east_path_revealed"}))
    
    -- NPCs
    world.npcs["overworld"] = {}
    table.insert(world.npcs["overworld"], NPC:new(53*32, 21*32, "merchant", {}))
    local villagerPatrol = { {x=22*32,y=18*32},{x=30*32,y=18*32},{x=30*32,y=28*32},{x=48*32,y=28*32},{x=48*32,y=38*32},{x=22*32,y=38*32},{x=22*32,y=18*32} }
    local villager = NPC:new(25*32, 20*32, "villager", {useAnimations = true, patrolRoute = villagerPatrol})
    table.insert(world.npcs["overworld"], villager)
    
    -- Enemies
    world.enemies["overworld"] = {}
    local skeleton1Patrol = { {x=8*32,y=30*32},{x=12*32,y=30*32},{x=12*32,y=35*32},{x=8*32,y=35*32} }
    table.insert(world.enemies["overworld"], Enemy:new(10*32, 32*32, "skeleton", {id = "overworld_skeleton_1", patrolRoute = skeleton1Patrol, aggroRange = 120, deaggroRange = 200}))
    local skeleton2Patrol = { {x=10*32,y=12*32},{x=14*32,y=12*32},{x=14*32,y=16*32},{x=10*32,y=16*32} }
    table.insert(world.enemies["overworld"], Enemy:new(12*32, 14*32, "skeleton", {id = "overworld_skeleton_2", patrolRoute = skeleton2Patrol, aggroRange = 100, deaggroRange = 180}))
end

return M


