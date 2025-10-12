-- World/Map Management
local TileMap = require("tilemap")
local Interactable = require("interactable")

local World = {}

function World:new()
    local world = {
        maps = {},
        currentMap = nil,
        interactables = {}
    }
    setmetatable(world, {__index = self})
    return world
end

function World:createExampleOverworld()
    -- Create a simple example map (much larger world)
    local map = TileMap:new(80, 60, 32)
    
    -- Create ground layer (1 = grass, 2 = path, 3 = stone, 4 = grass variant)
    local ground = {}
    for y = 0, 59 do
        ground[y] = {}
        for x = 0, 79 do
            -- Add variation to grass with simple pattern
            if (x + y) % 7 == 0 then
                ground[y][x] = 4 -- Grass variant
            else
                ground[y][x] = 1 -- Normal grass
            end
        end
    end
    
    -- Add dirt paths (horizontal and vertical)
    for y = 28, 31 do
        for x = 0, 79 do
            ground[y][x] = 2
        end
    end
    for x = 38, 41 do
        for y = 0, 59 do
            ground[y][x] = 2
        end
    end
    
    -- Create collision layer (1 = solid, 0 = walkable, 2 = wall to draw)
    local collision = {}
    for y = 0, 59 do
        collision[y] = {}
        for x = 0, 79 do
            collision[y][x] = 0
        end
    end
    
    -- Add a house (solid walls) - larger and more visible
    for y = 10, 18 do
        for x = 50, 60 do
            if y == 10 or y == 18 or x == 50 or x == 60 then
                collision[y][x] = 2 -- Wall (visible and solid)
            end
        end
    end
    -- Door location - keep wall solid, door object handles interaction
    -- Door will be at (55, 18) - bottom center
    
    -- Add trees/walls around the world edges
    for x = 0, 79 do
        collision[0][x] = 2
        collision[59][x] = 2
    end
    for y = 0, 59 do
        collision[y][0] = 2
        collision[y][79] = 2
    end
    
    -- Add some scattered rocks/obstacles
    for i = 1, 30 do
        local tx = math.random(5, 75)
        local ty = math.random(5, 55)
        -- Don't place on paths, water, or house
        local onPath = (ty >= 28 and ty <= 31) or (tx >= 38 and tx <= 41)
        local onWater = (tx >= 15 and tx <= 19)
        local onHouse = (tx >= 50 and tx <= 60 and ty >= 10 and ty <= 18)
        
        if not onPath and not onWater and not onHouse then
            collision[ty][tx] = 2
        end
    end
    
    -- Create roof layer for the house
    local roofs = {}
    for y = 0, 59 do
        roofs[y] = {}
        for x = 0, 79 do
            roofs[y][x] = 0
        end
    end
    
    -- Add roof over the house interior
    for y = 10, 18 do
        for x = 50, 60 do
            roofs[y][x] = 1 -- Roof tile
        end
    end
    
    -- Create water layer (river)
    local water = {}
    for y = 0, 59 do
        water[y] = {}
        for x = 0, 79 do
            water[y][x] = 0
        end
    end
    
    -- Add a river (vertical) with animated water
    for y = 0, 59 do
        for x = 15, 19 do
            water[y][x] = 1 -- Water tile
            collision[y][x] = 1 -- Can't walk through water
        end
    end
    
    -- Add a bridge (walkable over the river)
    for y = 28, 31 do  -- Where the horizontal path crosses
        for x = 15, 19 do
            water[y][x] = 2 -- Bridge tile
            collision[y][x] = 0 -- Can walk on bridge
        end
    end
    
    -- Create decorations layer (trees and bushes)
    local decorations = {}
    for y = 0, 59 do
        decorations[y] = {}
        for x = 0, 79 do
            decorations[y][x] = 0
        end
    end
    
    -- Add trees (scattered around, away from paths and rocks)
    local treePlaces = {
        {25, 10}, {30, 8}, {48, 5}, {65, 7},
        {8, 20}, {72, 22}, {25, 35}, {48, 38},
        {10, 48}, {35, 52}, {58, 50}, {72, 54}
    }
    
    for _, pos in ipairs(treePlaces) do
        local tx, ty = pos[1], pos[2]
        -- Check if on paths or water
        local onHorizontalPath = (ty >= 28 and ty <= 31)
        local onVerticalPath = (tx >= 38 and tx <= 41)
        local onWater = (tx >= 15 and tx <= 19)
        
        -- Only place if no collision exists and not on paths/water
        if collision[ty][tx] == 0 and not onHorizontalPath and not onVerticalPath and not onWater then
            decorations[ty][tx] = 1 -- Tree
            collision[ty][tx] = 2 -- Trees block movement
        end
    end
    
    -- Add bushes (scattered in grass, checking for clear space)
    local bushPlaces = {
        {23, 6}, {44, 10}, {63, 8}, {33, 16}, {70, 18},
        {7, 22}, {27, 34}, {50, 40}, {60, 44}, {13, 50},
        {26, 46}, {50, 52}, {68, 46}, {20, 25}, {56, 20},
        {10, 38}, {42, 44}, {54, 12}
    }
    
    for _, pos in ipairs(bushPlaces) do
        local bx, by = pos[1], pos[2]
        -- Check if on paths or water
        local onHorizontalPath = (by >= 28 and by <= 31)
        local onVerticalPath = (bx >= 38 and bx <= 41)
        local onWater = (bx >= 15 and bx <= 19)
        
        -- Only place if no collision exists and not on paths/water
        if collision[by] and collision[by][bx] == 0 and not onHorizontalPath and not onVerticalPath and not onWater then
            decorations[by][bx] = 2 -- Bush
            collision[by][bx] = 2 -- Bushes now block movement
        end
    end
    
    map:loadFromData({ground = ground, collision = collision, roofs = roofs, water = water, decorations = decorations})
    self.maps["overworld"] = map
    
    -- Add interactable objects
    self.interactables["overworld"] = {}
    
    -- Add a chest
    table.insert(self.interactables["overworld"], 
        Interactable:new(20*32, 15*32, 32, 32, "chest", {
            id = "chest_1",
            item = "Gold Key"
        })
    )
    
    -- Add another chest
    table.insert(self.interactables["overworld"], 
        Interactable:new(45*32, 35*32, 32, 32, "chest", {
            id = "chest_2",
            item = "Health Potion"
        })
    )
    
    -- Add a door to house (at bottom wall center)
    -- Position it ON the bottom wall (y=18) so it's clearly visible
    table.insert(self.interactables["overworld"], 
        Interactable:new(55*32, 18*32 - 16, 32, 48, "door", {
            destination = "house_interior",
            spawnX = 7*32,
            spawnY = 9*32  -- Spawn inside, away from walls
        })
    )
    
    -- Add a sign
    table.insert(self.interactables["overworld"], 
        Interactable:new(35*32, 25*32, 32, 32, "sign", {
            message = "Welcome, traveler. Many secrets lie hidden in this land..."
        })
    )
end

function World:createHouseInterior()
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
    
    -- Door exit at bottom center
    collision[11][7] = 0
    
    map:loadFromData({ground = ground, collision = collision})
    self.maps["house_interior"] = map
    
    -- Interior objects
    self.interactables["house_interior"] = {}
    
    -- Exit door (at bottom wall, overlapping)
    table.insert(self.interactables["house_interior"], 
        Interactable:new(7*32, 10.5*32, 32, 40, "door", {
            destination = "overworld",
            spawnX = 55*32,
            spawnY = 20*32  -- Spawn outside house door
        })
    )
    
    -- Chest inside house
    table.insert(self.interactables["house_interior"], 
        Interactable:new(7*32, 2*32, 32, 32, "chest", {
            id = "house_chest",
            item = "Magic Sword"
        })
    )
end

function World:loadMap(mapName)
    self.currentMap = self.maps[mapName]
    return self.currentMap
end

function World:getCurrentInteractables()
    for mapName, interactables in pairs(self.interactables) do
        if self.maps[mapName] == self.currentMap then
            return interactables
        end
    end
    return {}
end

function World:draw(camera, gameTime)
    if self.currentMap then
        self.currentMap:draw(camera, gameTime)
        
        -- Draw interactables
        local interactables = self:getCurrentInteractables()
        for _, obj in ipairs(interactables) do
            obj:draw()
        end
    end
end

function World:drawDecorations(camera)
    if self.currentMap then
        self.currentMap:drawDecorations(camera)
    end
end

function World:drawRoofs(camera, playerX, playerY)
    if self.currentMap then
        self.currentMap:drawRoofs(camera, playerX, playerY)
    end
end

return World

