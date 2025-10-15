-- World/Map Management
local TileMap = require("tilemap")
local Interactable = require("interactable")
local NPC = require("npc")
local Enemy = require("enemy")

local World = {}

function World:new()
    local world = {
        maps = {},
        currentMap = nil,
        interactables = {},
        npcs = {}, -- NPCs per map
        enemies = {}, -- Enemies per map
        gameState = nil, -- Reference to game state for quest filtering
        decorations = {} -- Quest-conditional decorations per map
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
    
    -- Northern border at archway location (x=1230-1330, tiles 38-41)
    -- Visible rocks before class selection, invisible barrier after
    -- Row -1 allows player to walk up to y=0 before hitting barrier
    collision[-1] = collision[-1] or {}
    for x = 38, 41 do
        collision[-1][x] = 2 -- Rocks that will be replaced with invisible barrier
        -- Also clear row 0 rocks in this area - they'll be managed dynamically
        collision[0][x] = 0 -- No collision at row 0 (will add back if no class)
    end
    
    -- Eastern border at path location (tiles 27-31, y coordinates)
    -- Visible rocks before eastern path reveal, removed after trials completion
    for y = 27, 31 do
        collision[y][79] = 2 -- Rocks on eastern edge that will be removed
        collision[y][78] = 0 -- Keep row 78 clear for path opening
    end
    
    -- Invisible eastern barrier (prevents going east of column 80)
    for y = 27, 31 do
        collision[y][80] = 1 -- Invisible collision barrier
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
        {26, 46}, {50, 52}, {68, 46}, {20, 25},
        {10, 38}, {42, 44}
        -- Removed {56, 20} and {54, 12} - they block house entrance
    }
    
    for _, pos in ipairs(bushPlaces) do
        local bx, by = pos[1], pos[2]
        -- Check if on paths or water
        local onHorizontalPath = (by >= 28 and by <= 31)
        local onVerticalPath = (bx >= 38 and bx <= 41)
        local onWater = (bx >= 15 and bx <= 19)
        -- Also avoid house area (door at 55, 18)
        local nearHouse = (bx >= 50 and bx <= 60 and by >= 18 and by <= 22)
        
        -- Only place if no collision exists and not on paths/water/house
        if collision[by] and collision[by][bx] == 0 and not onHorizontalPath and not onVerticalPath and not onWater and not nearHouse then
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
    
    -- Add a door to house (at bottom wall center) - LOCKED initially
    -- Position it ON the bottom wall (y=18) so it's clearly visible
    table.insert(self.interactables["overworld"], 
        Interactable:new(55*32, 18*32 - 16, 32, 48, "door", {
            destination = "house_interior",
            spawnX = 7*32,
            spawnY = 9*32,  -- Spawn inside, away from walls
            isHouseDoor = true -- Mark as the house door for lock checking
        })
    )
    
    -- Add a sign
    table.insert(self.interactables["overworld"], 
        Interactable:new(35*32, 25*32, 32, 32, "sign", {
            message = "Welcome, traveler. Many secrets lie hidden in this land..."
        })
    )
    
    -- Add cave entrance (appears after completing sword quest)
    -- Large entrance on west wall with two staggered boulders
    table.insert(self.interactables["overworld"],
        Interactable:new(0, 26*32, 160, 192, "cave", {
            id = "mysterious_cave", -- Unique ID for special handling
            targetMap = "cave_level1",
            spawnX = 3*32,  -- Spawn on west side inside cave
            spawnY = 9*32,  -- Align with cave entrance at y=9
            questMinimum = "sword_collected" -- Appears after getting sword and stays visible
        })
    )
    
    -- Add northern path entrance (appears after class selection)
    -- Ancient stone archway with magical barrier - aligned with vertical path
    -- Position: 35% wider, centered at x=1280
    table.insert(self.interactables["overworld"],
        Interactable:new(1211, -182, 139, 192, "ancient_path", {
            targetMap = "defense_trials",
            spawnX = 14*32,
            spawnY = 35*32,
            questMinimum = "has_class" -- Custom quest check for having chosen a class
        })
    )
    
    -- Add eastern path to town (appears after defense trials completion)
    -- Bridge centered at tile (80, 30) - same size as sanctuary village bridge
    table.insert(self.interactables["overworld"],
        Interactable:new(80*32 - 32, 30*32 - 32, 64, 64, "eastern_path", {
            targetMap = "town",
            spawnX = 24*32,
            spawnY = 37*32,
            questMinimum = "east_path_revealed" -- Only visible after eastern path reveal
        })
    )
    
    -- Add merchant NPC near the house (southwest of the front door)
    self.npcs["overworld"] = {}
    table.insert(self.npcs["overworld"],
        NPC:new(53*32, 21*32, "merchant", {})
    )
    
    -- Add villager NPC with patrol route (wider path avoiding sign area)
    local villagerPatrol = {
        {x = 22*32, y = 18*32}, -- Start: Far west near trees
        {x = 30*32, y = 18*32}, -- East (before sign area)
        {x = 30*32, y = 28*32}, -- South (avoiding sign)
        {x = 48*32, y = 28*32}, -- Far east
        {x = 48*32, y = 38*32}, -- South
        {x = 22*32, y = 38*32}, -- Back west
        {x = 22*32, y = 18*32}  -- North to start
    }
    local villager = NPC:new(25*32, 20*32, "villager", {
        useAnimations = true,
        patrolRoute = villagerPatrol
    })
    -- Villager has collision like merchant
    table.insert(self.npcs["overworld"], villager)
    
    -- Add skeleton enemies
    self.enemies["overworld"] = {}
    
    -- Skeleton 1: Patrol western forest area (dangerous area)
    local skeleton1Patrol = {
        {x = 8*32, y = 30*32},
        {x = 12*32, y = 30*32},
        {x = 12*32, y = 35*32},
        {x = 8*32, y = 35*32}
    }
    table.insert(self.enemies["overworld"],
        Enemy:new(10*32, 32*32, "skeleton", {
            id = "overworld_skeleton_1",
            patrolRoute = skeleton1Patrol,
            aggroRange = 120,
            deaggroRange = 200
        })
    )
    
    -- Skeleton 2: Patrol northwest clearing (further west)
    local skeleton2Patrol = {
        {x = 10*32, y = 12*32},
        {x = 14*32, y = 12*32},
        {x = 14*32, y = 16*32},
        {x = 10*32, y = 16*32}
    }
    table.insert(self.enemies["overworld"],
        Enemy:new(12*32, 14*32, "skeleton", {
            id = "overworld_skeleton_2",
            patrolRoute = skeleton2Patrol,
            aggroRange = 100,
            deaggroRange = 180
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
    
    -- Chest inside house (Magic Sword reward)
    table.insert(self.interactables["house_interior"], 
        Interactable:new(7*32, 2*32, 32, 32, "chest", {
            id = "house_chest",
            item = "Magic Sword"
        })
    )
    
    -- Merchant will also be inside the house after quest progression
    self.npcs["house_interior"] = {}
    table.insert(self.npcs["house_interior"],
        NPC:new(7*32, 6*32, "merchant", {})
    )
end

function World:createCaveLevel1()
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
    self.maps["cave_level1"] = map
    
    -- Interactables
    self.interactables["cave_level1"] = {}
    
    -- Glowing scroll in center (teaches Illumination spell)
    table.insert(self.interactables["cave_level1"], 
        Interactable:new(12*32, 6*32, 32, 32, "scroll", {
            spell = "Illumination"
        })
    )
    
    -- Cave entrance (leads back to overworld)
    table.insert(self.interactables["cave_level1"], 
        Interactable:new(0*32, 9*32, 64, 64, "cave_exit", {
            destination = "overworld",
            spawnX = 7*32 + 32,
            spawnY = 31*32
        })
    )
    
    -- Cave exit (leads to class selection)
    table.insert(self.interactables["cave_level1"], 
        Interactable:new(23*32, 9*32, 64, 64, "cave_exit", {
            destination = "class_selection",
            spawnX = 3*32,
            spawnY = 15*32
        })
    )
    
    -- Single chest as reward
    table.insert(self.interactables["cave_level1"], 
        Interactable:new(23*32, 10*32, 32, 32, "chest", {
            id = "cave_chest_1",
            item = "Health Potion"
        })
    )
    
    -- Just ONE skeleton enemy for flavor
    self.enemies["cave_level1"] = {}
    local skeleton1Patrol = {
        {x = 12*32, y = 12*32},
        {x = 12*32, y = 6*32}
    }
    table.insert(self.enemies["cave_level1"],
        Enemy:new(12*32, 10*32, "skeleton", {
            id = "cave_skeleton_1",
            patrolRoute = skeleton1Patrol,
            aggroRange = 100,
            deaggroRange = 180
        })
    )
    
    self.npcs["cave_level1"] = {}
end

function World:createClassSelection()
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
    self.maps["class_selection"] = map
    
    -- Add interactables
    self.interactables["class_selection"] = {}
    
    -- Cave exit on west side (return to cave)
    table.insert(self.interactables["class_selection"], 
        Interactable:new(1*32, 8*32, 96, 96, "cave_exit", {
            destination = "cave_level1",
            spawnX = 23*32 + 32,  -- Near the east exit where they came from
            spawnY = 9*32
        })
    )
    
    -- Sign pointing to cave (left arrow)
    table.insert(self.interactables["class_selection"],
        Interactable:new(6*32, 9*32, 32, 32, "sign", {
            message = "<- Mysterious cave",
            arrow = "left"
        })
    )
    
    -- Portal on eastern border (return to overworld) - only available after class selection
    table.insert(self.interactables["class_selection"],
        Interactable:new(27*32, 9*32, 64, 64, "portal", {
            destination = "overworld",
            spawnX = 30*32,  -- Spawn player safely in overworld
            spawnY = 30*32,
            questRequired = "class_selected"  -- Only visible after choosing a class
        })
    )
    
    -- Sign pointing to portal (right arrow) - only visible after class selection
    table.insert(self.interactables["class_selection"],
        Interactable:new(24*32, 9*32, 32, 32, "sign", {
            message = "Back to Overworld ->",
            arrow = "right",
            questRequired = "class_selected"  -- Only visible after choosing a class
        })
    )
    
    -- Class Selection Icons (elemental spells)
    -- Fire Mage
    table.insert(self.interactables["class_selection"],
        Interactable:new(8*32, 6*32, 64, 64, "class_icon", {
            element = "fire",
            className = "Fire Mage",
            description = "Master of flames and destruction"
        })
    )
    
    -- Ice Mage
    table.insert(self.interactables["class_selection"],
        Interactable:new(14*32, 6*32, 64, 64, "class_icon", {
            element = "ice",
            className = "Ice Mage",
            description = "Controller of frost and cold"
        })
    )
    
    -- Lightning Mage
    table.insert(self.interactables["class_selection"],
        Interactable:new(8*32, 12*32, 64, 64, "class_icon", {
            element = "lightning",
            className = "Storm Mage",
            description = "Wielder of thunder and lightning"
        })
    )
    
    -- Earth Mage
    table.insert(self.interactables["class_selection"],
        Interactable:new(14*32, 12*32, 64, 64, "class_icon", {
            element = "earth",
            className = "Earth Mage",
            description = "Master of stone and earth"
        })
    )
    
    self.enemies["class_selection"] = {}
    self.npcs["class_selection"] = {}
end

function World:createDefenseTrials()
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
    self.maps["defense_trials"] = map
    
    -- Add interactables
    self.interactables["defense_trials"] = {}
    
    -- Entrance from ancient path (south entrance)
    table.insert(self.interactables["defense_trials"], 
        Interactable:new(14*32, 37*32, 32, 48, "door", {
            destination = "overworld",
            spawnX = 40*32,
            spawnY = 8*32
        })
    )
    
    -- Entrance sign
    table.insert(self.interactables["defense_trials"],
        Interactable:new(13*32, 36*32, 32, 32, "sign", {
            message = "Face the elemental trials ahead...\nFind the resistance scroll to survive!"
        })
    )
    
    -- Resistance spell scroll (left branch)
    table.insert(self.interactables["defense_trials"],
        Interactable:new(5*32, 17*32, 32, 32, "scroll", {
            spell = "resistance" -- Will be element-specific
            -- No questRequired - always visible
        })
    )
    
    -- Scroll room sign
    table.insert(self.interactables["defense_trials"],
        Interactable:new(7*32, 17*32, 32, 32, "sign", {
            message = "← Resistance Scroll"
        })
    )
    
    -- Arena entrance sign
    table.insert(self.interactables["defense_trials"],
        Interactable:new(14*32, 11*32, 32, 32, "sign", {
            message = "Prepare yourself... The trial begins ahead."
        })
    )
    
    -- Combat trigger chest (center of arena) - no item, just triggers fight
    table.insert(self.interactables["defense_trials"],
        Interactable:new(14*32, 5*32, 32, 32, "chest", {
            id = "trial_chest",
            triggersSkeletons = true
            -- No item - just triggers skeleton spawn
        })
    )
    
    -- Strategy Selection Icons (appear after combat)
    -- Tank (Armor)
    table.insert(self.interactables["defense_trials"],
        Interactable:new(9*32, 5*32, 64, 64, "strategy_icon", {
            strategy = "armor",
            strategyName = "Tank",
            description = "Fortify your defenses",
            questRequired = "skeletons_defeated"
        })
    )
    
    -- Lifesteal (Drain)
    table.insert(self.interactables["defense_trials"],
        Interactable:new(14*32, 5*32, 64, 64, "strategy_icon", {
            strategy = "drain",
            strategyName = "Lifesteal",
            description = "Drain life from your foes",
            questRequired = "skeletons_defeated"
        })
    )
    
    -- Necromancer
    table.insert(self.interactables["defense_trials"],
        Interactable:new(19*32, 5*32, 64, 64, "strategy_icon", {
            strategy = "necromancer",
            strategyName = "Soul Reaper",
            description = "Harvest souls for power",
            questRequired = "skeletons_defeated"
        })
    )
    
    -- Exit portal (appears after strategy selection)
    table.insert(self.interactables["defense_trials"],
        Interactable:new(14*32, 3*32, 64, 64, "portal", {
            destination = "overworld",
            spawnX = 40*32,
            spawnY = 8*32,
            questRequired = "strategy_selected"
        })
    )
    
    self.enemies["defense_trials"] = {}
    self.npcs["defense_trials"] = {}
end

function World:createTown()
    -- Trading Town: Village marketplace with merchants and shops
    local TileMap = require("tilemap")
    local map = TileMap:new(50, 40, 32)
    
    -- Create ground layer (grass with variation + stone paths)
    local ground = {}
    for y = 0, 39 do
        ground[y] = {}
        for x = 0, 49 do
            -- Add natural variation to grass
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
    
    -- Central plaza (circular-ish stone area with fountain)
    for y = 15, 28 do
        for x = 18, 31 do
            ground[y][x] = 2
        end
    end
    
    -- Paths to shops
    -- West shop row
    for y = 18, 25 do
        for x = 10, 17 do
            ground[y][x] = 2
        end
    end
    
    -- East shop row
    for y = 18, 25 do
        for x = 32, 39 do
            ground[y][x] = 2
        end
    end
    
    -- North market area
    for y = 8, 14 do
        for x = 20, 29 do
            ground[y][x] = 2
        end
    end
    
    -- Create collision layer
    local collision = {}
    for y = 0, 39 do
        collision[y] = {}
        for x = 0, 49 do
            collision[y][x] = 0 -- Walkable by default
        end
    end
    
    -- Outer walls/fences (invisible barriers at edges)
    for x = 0, 49 do
        collision[0][x] = 1 -- North wall (invisible barrier)
        collision[39][x] = 1 -- South wall (invisible barrier, but we'll open entrance)
    end
    for y = 0, 39 do
        collision[y][0] = 1 -- West wall (invisible barrier)
        collision[y][49] = 1 -- East wall (invisible barrier)
    end
    
    -- Entrance opening (south) - but with invisible barrier to prevent going further south
    for x = 22, 27 do
        collision[39][x] = 1 -- Invisible collision barrier (prevents going south of entrance)
    end
    
    -- Add visible fence decorations just inside the invisible barriers
    for x = 1, 48 do
        if x < 22 or x > 27 then  -- Don't block entrance
            collision[38][x] = 2 -- South fence
        end
        collision[1][x] = 2 -- North fence
    end
    for y = 1, 38 do
        collision[y][1] = 2 -- West fence
        collision[y][48] = 2 -- East fence
    end
    
    -- Buildings/Shops (doors face toward paths for easy access)
    
    -- General Store (west side) - Door faces east (toward plaza)
    for y = 10, 16 do
        for x = 8, 14 do
            if y == 10 or x == 8 then
                collision[y][x] = 2 -- North and west walls
            elseif y == 16 then
                collision[y][x] = 2 -- South wall
            elseif x == 14 and y ~= 13 then
                collision[y][x] = 2 -- East wall except door
            end
        end
    end
    
    -- Potion Shop (east side) - Door faces west (toward plaza)
    for y = 10, 16 do
        for x = 35, 41 do
            if y == 10 or x == 41 then
                collision[y][x] = 2 -- North and east walls
            elseif y == 16 then
                collision[y][x] = 2 -- South wall
            elseif x == 35 and y ~= 13 then
                collision[y][x] = 2 -- West wall except door
            end
        end
    end
    
    -- Weapon/Armor Shop (north west) - Door faces east
    for y = 3, 9 do
        for x = 10, 16 do
            if y == 3 or x == 10 then
                collision[y][x] = 2 -- North and west walls
            elseif y == 9 then
                collision[y][x] = 2 -- South wall
            elseif x == 16 and y ~= 6 then
                collision[y][x] = 2 -- East wall except door
            end
        end
    end
    
    -- Inn/Tavern (north east) - Door faces west
    for y = 3, 9 do
        for x = 33, 39 do
            if y == 3 or x == 39 then
                collision[y][x] = 2 -- North and east walls
            elseif y == 9 then
                collision[y][x] = 2 -- South wall
            elseif x == 33 and y ~= 6 then
                collision[y][x] = 2 -- West wall except door
            end
        end
    end
    
    -- Central fountain with water
    for y = 20, 23 do
        for x = 23, 26 do
            collision[y][x] = 1 -- Invisible barrier (can't walk through water)
        end
    end
    
    -- Stone border around fountain (rectangular blocks)
    -- North side stones
    for x = 22, 27 do
        collision[19][x] = 2
    end
    -- South side stones
    for x = 22, 27 do
        collision[24][x] = 2
    end
    -- West side stones (excluding corners already covered)
    for y = 20, 23 do
        collision[y][22] = 2
    end
    -- East side stones (excluding corners already covered)
    for y = 20, 23 do
        collision[y][27] = 2
    end
    
    -- Decorative obstacles (trees, benches, etc.)
    -- Trees around perimeter
    local treePositions = {
        {5, 5}, {5, 35}, {45, 5}, {45, 35},
        {8, 20}, {41, 20}, {15, 30}, {34, 30},
        {18, 8}, {31, 8}
    }
    for _, pos in ipairs(treePositions) do
        collision[pos[2]][pos[1]] = 2
    end
    
    -- Benches in plaza (decorative collision)
    local benchPositions = {
        {19, 19}, {30, 19}, {19, 24}, {30, 24}
    }
    for _, pos in ipairs(benchPositions) do
        collision[pos[2]][pos[1]] = 2
    end
    
    -- Create roofs layer
    local roofs = {}
    for y = 0, 39 do
        roofs[y] = {}
        for x = 0, 49 do
            roofs[y][x] = 0
        end
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
    
    -- Create water layer for fountain
    local water = {}
    for y = 0, 39 do
        water[y] = {}
        for x = 0, 49 do
            water[y][x] = 0
        end
    end
    
    -- Add water to fountain
    for y = 20, 23 do
        for x = 23, 26 do
            water[y][x] = 5 -- Water tile
        end
    end
    
    map:loadFromData({ground = ground, collision = collision, roofs = roofs, water = water})
    self.maps["town"] = map
    
    -- Add interactables
    self.interactables["town"] = {}
    
    -- Southern path exit back to overworld (same as entrance)
    table.insert(self.interactables["town"],
        Interactable:new(24*32, 38*32, 64, 64, "eastern_path", {
            targetMap = "overworld",
            spawnX = 78*32,  -- East side of overworld at eastern path (tile 78)
            spawnY = 29*32  -- Align with eastern path bridge (tile 29)
        })
    )
    
    -- Inn door (The Restful Inn) - Door faces west at x=33, y=6
    table.insert(self.interactables["town"],
        Interactable:new(33*32, 6*32, 32, 48, "door", {
            destination = "inn_interior",
            spawnX = 10*32,
            spawnY = 12*32,
            isSideDoor = true -- Mark as side-of-building door for isometric drawing
        })
    )
    
    -- Welcome sign near entrance (moved west to avoid spawn collision)
    table.insert(self.interactables["town"],
        Interactable:new(24*32 - 100, 36*32, 32, 32, "sign", {
            message = "Welcome to Sanctuary Village!\nTraders welcome, danger is left at the gate."
        })
    )
    
    -- Fountain sign (decorative, away from fountain)
    table.insert(self.interactables["town"],
        Interactable:new(24*32, 18*32, 32, 32, "sign", {
            message = "Sanctuary Fountain\nMay your travels be safe."
        })
    )
    
    -- Shop signs (positioned as specified)
    -- General Store sign
    table.insert(self.interactables["town"],
        Interactable:new(15*32, 11*32, 32, 32, "sign", {
            message = "General Store\n(Coming Soon)"
        })
    )
    
    -- Potion Shop sign
    table.insert(self.interactables["town"],
        Interactable:new(34*32, 11*32, 32, 32, "sign", {
            message = "Potion Shop\nHealthy choices inside!"
        })
    )
    
    -- Weapon/Armor Shop sign
    table.insert(self.interactables["town"],
        Interactable:new(17*32, 4*32, 32, 32, "sign", {
            message = "Weapon & Armor\n(Coming Soon)"
        })
    )
    
    -- Inn/Tavern sign
    table.insert(self.interactables["town"],
        Interactable:new(32*32, 4*32, 32, 32, "sign", {
            message = "The Restful Inn\nWarm beds & cold drinks!"
        })
    )
    
    self.enemies["town"] = {}
    self.npcs["town"] = {}
    
    -- Add town greeter NPC (near entrance, will trigger welcome cutscene)
    table.insert(self.npcs["town"],
        NPC:new(24*32, 32*32, "village_quest_giver", {
            questState = "town_greeter",
            useAnimations = true  -- Use animated quest giver
        })
    )
    
    -- Add potion merchant (inside potion shop, adjusted for new door position)
    table.insert(self.npcs["town"],
        NPC:new(37*32, 13*32, "merchant", {
            questState = "potion_merchant",
            shopType = "potions"
        })
    )
end

function World:createInnInterior()
    -- The Restful Inn: Cozy interior with tables, candles, and inn keeper
    local TileMap = require("tilemap")
    local NPC = require("npc")
    local Interactable = require("interactable")
    
    -- Larger than house interior (20x15 tiles)
    local map = TileMap:new(20, 15, 32)
    
    -- Create wooden floor
    local ground = {}
    for y = 0, 14 do
        ground[y] = {}
        for x = 0, 19 do
            ground[y][x] = 4 -- Wooden floor
        end
    end
    
    -- Create walls and collision
    local collision = {}
    for y = 0, 14 do
        collision[y] = {}
        for x = 0, 19 do
            -- Outer walls
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
    
    -- Add rock at tile (10, 14) on southern wall
    collision[14][10] = 2 -- Rock on southern wall
    
    map:loadFromData({ground = ground, collision = collision})
    self.maps["inn_interior"] = map
    
    -- Add interactables
    self.interactables["inn_interior"] = {}
    
    -- Exit door (back to town) - positioned like house interior door
    table.insert(self.interactables["inn_interior"],
        Interactable:new(9*32, 13.5*32, 32, 40, "door", {
            destination = "town",
            spawnX = 33*32,
            spawnY = 6*32
        })
    )
    
    -- Tables with candles and mugs (custom interactable type)
    -- Table 1 (top-left area)
    table.insert(self.interactables["inn_interior"],
        Interactable:new(4*32, 3*32, 64, 64, "inn_table", {
            hasCandle = true,
            hasMug = true
        })
    )
    
    -- Table 2 (top-right area)
    table.insert(self.interactables["inn_interior"],
        Interactable:new(14*32, 3*32, 64, 64, "inn_table", {
            hasCandle = true,
            hasMug = true
        })
    )
    
    -- Table 3 (middle-left)
    table.insert(self.interactables["inn_interior"],
        Interactable:new(4*32, 7*32, 64, 64, "inn_table", {
            hasCandle = true,
            hasMug = true
        })
    )
    
    -- Table 4 (middle-right)
    table.insert(self.interactables["inn_interior"],
        Interactable:new(14*32, 7*32, 64, 64, "inn_table", {
            hasCandle = true,
            hasMug = true
        })
    )
    
    -- Chests side by side (back wall)
    -- Chest 1: Mana Potion
    table.insert(self.interactables["inn_interior"],
        Interactable:new(8*32, 2*32, 32, 32, "chest", {
            id = "inn_chest_mana",
            item = "Mana Potion"
        })
    )
    
    -- Chest 2: 100 Gold
    table.insert(self.interactables["inn_interior"],
        Interactable:new(11*32, 2*32, 32, 32, "chest", {
            id = "inn_chest_gold",
            item = "Gold",
            goldAmount = 100
        })
    )
    
    self.enemies["inn_interior"] = {}
    self.npcs["inn_interior"] = {}
    
    -- Add inn keeper NPC with wandering behavior
    local innKeeper = NPC:new(10*32, 8*32, "inn_keeper", {
        questState = "inn_keeper",
        useAnimations = true,
        wandering = true,
        wanderRadius = 128,
        wanderPauseMin = 2,
        wanderPauseMax = 5
    })
    table.insert(self.npcs["inn_interior"], innKeeper)
end

function World:loadMap(mapName)
    self.currentMap = self.maps[mapName]
    
    -- Update northern archway collision based on class selection
    if mapName == "overworld" and self.currentMap and self.gameState then
        local collision = self.currentMap.layers.collision
        collision[-1] = collision[-1] or {} -- Ensure row -1 exists
        if self.gameState.playerClass then
            -- Player has class: invisible barrier at row -1, no rocks anywhere
            for x = 38, 41 do
                collision[-1][x] = 1 -- Invisible barrier
                collision[0][x] = 0 -- No visible rocks
            end
        else
            -- No class yet: visible rocks at both rows to block passage
            for x = 38, 41 do
                collision[-1][x] = 2 -- Visible rocks at barrier
                collision[0][x] = 2 -- Visible rocks at ground level
            end
        end
        
        -- Update eastern path collision based on trials completion
        if self.gameState.eastPathRevealed then
            -- Remove rocks at eastern border to reveal path
            for y = 27, 31 do
                collision[y][79] = 0 -- Remove rocks
                collision[y][78] = 0 -- Ensure path is clear
            end
        else
            -- Keep rocks blocking the path
            for y = 27, 31 do
                collision[y][79] = 2 -- Visible rocks blocking path
            end
        end
    end
    
    return self.currentMap
end

function World:getCurrentInteractables()
    for mapName, interactables in pairs(self.interactables) do
        if self.maps[mapName] == self.currentMap then
            -- Filter interactables based on quest requirements
            local filtered = {}
            for _, obj in ipairs(interactables) do
                local shouldShow = true
                
                -- Check if this interactable requires an exact quest state
                if obj.data.questRequired and self.gameState then
                    -- Special case: east_path_revealed checks if eastern path has been revealed
                    if obj.data.questRequired == "east_path_revealed" then
                        shouldShow = (self.gameState.eastPathRevealed == true)
                    else
                        shouldShow = (self.gameState.questState == obj.data.questRequired)
                    end
                end
                
                -- Check if this interactable requires a minimum quest state (unlocked and stays visible)
                if obj.data.questMinimum and self.gameState then
                    -- Special case: has_class checks if player has chosen a class
                    if obj.data.questMinimum == "has_class" then
                        shouldShow = (self.gameState.playerClass ~= nil)
                    -- Special case: east_path_revealed checks if eastern path has been revealed
                    elseif obj.data.questMinimum == "east_path_revealed" then
                        shouldShow = (self.gameState.eastPathRevealed == true)
                    else
                        -- Define quest progression order
                        local questOrder = {"initial", "sword_collected", "cave_completed", "final"}
                        local currentIndex = 1
                        local minimumIndex = 1
                        
                        for i, q in ipairs(questOrder) do
                            if q == self.gameState.questState then
                                currentIndex = i
                            end
                            if q == obj.data.questMinimum then
                                minimumIndex = i
                            end
                        end
                        
                        shouldShow = (currentIndex >= minimumIndex)
                    end
                end
                
                -- Special case: Hide mysterious cave after class selection
                if obj.data.id == "mysterious_cave" and self.gameState and self.gameState.mysteriousCaveHidden then
                    shouldShow = false
                end
                
                if shouldShow then
                    table.insert(filtered, obj)
                end
            end
            return filtered
        end
    end
    return {}
end

function World:getCurrentHazards()
    -- Get hazards for current map (stored in map data)
    if self.currentMap and self.currentMap.layers.hazards then
        return self.currentMap.layers.hazards
    end
    return {}
end

function World:getCurrentNPCs()
    local npcs = {}
    for mapName, npcList in pairs(self.npcs) do
        if self.maps[mapName] == self.currentMap then
            -- Filter NPCs based on quest state
            for _, npc in ipairs(npcList) do
                local shouldShow = true
                
                if npc.npcType == "merchant" and self.gameState then
                    if mapName == "overworld" then
                        -- Show merchant outside only before entering house
                        shouldShow = (self.gameState.questState ~= "inside_house" and 
                                     self.gameState.questState ~= "sword_collected")
                    elseif mapName == "house_interior" then
                        -- Show merchant inside only after entering house
                        shouldShow = (self.gameState.questState == "inside_house" or 
                                     self.gameState.questState == "sword_collected")
                    end
                end
                
                if shouldShow then
                    table.insert(npcs, npc)
                end
            end
            return npcs
        end
    end
    return {}
end

function World:getCurrentEnemies()
    for mapName, enemies in pairs(self.enemies) do
        if self.maps[mapName] == self.currentMap then
            -- Filter out killed enemies if gameState is available
            if self.gameState then
                local aliveEnemies = {}
                for _, enemy in ipairs(enemies) do
                    if not self.gameState:isEnemyKilled(enemy.id) then
                        table.insert(aliveEnemies, enemy)
                    end
                end
                return aliveEnemies
            end
            return enemies
        end
    end
    return {}
end

function World:setGameState(gs)
    self.gameState = gs
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

