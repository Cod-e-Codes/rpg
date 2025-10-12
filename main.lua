-- Enhanced RPG with Tilemap, Collision, and Interactions
-- Controls: WASD/Arrows to move, E to interact, F3 for debug

-- Require modules
local GameState = require("gamestate")
local World = require("world")

-- Debug mode
DEBUG_MODE = false

-- Game state
local player = {
    x = 400,
    y = 300,
    speed = 150,
    direction = "south",
    isMoving = false,
    wasMoving = false,
    scale = 2,
    -- Collision box offsets (relative to player center)
    collisionLeft = -13,    -- Left edge of hitbox (negative = left of center)
    collisionRight = 13,    -- Right edge of hitbox (positive = right of center)
    collisionTop = -4,      -- Top edge of hitbox (negative = above center, small value = near feet)
    collisionBottom = 28,   -- Bottom edge of hitbox (positive = below center, at feet)
    -- Knockback state
    knockbackVelocityX = 0,
    knockbackVelocityY = 0,
    knockbackDecay = 0.88,  -- How quickly knockback fades (lower = faster fade)
    -- Immunity frames (invincibility after being hit)
    immunityTimer = 0,
    immunityDuration = 1.2  -- Seconds of immunity after being hit
}

local animations = {
    walk = {},
    idle = {}
}
local currentFrame = 1
local frameTimer = 0
local walkFrameDelay = 0.1
local idleFrameDelay = 0.15
local gameTime = 0  -- For water animation

local camera = {
    x = 0,
    y = 0
}

-- Game systems
local gameState
local world
local currentMessage = nil
local currentMessageItem = nil  -- Store item for message icon
local messageTimer = 0
local messageDuration = 3

-- UI state
local showInventory = false
local showHelp = false
local showDebugPanel = false

-- Cutscene state
local inCutscene = false
local cutsceneWalkTarget = nil
local cutsceneOnComplete = nil

-- Direction mappings
local directions = {
    "north", "north-east", "east", "south-east",
    "south", "south-west", "west", "north-west"
}

-- Forward declarations
local loadAnimations, getDirection, drawPlayer, drawUI, drawMessage
local checkInteraction, getNearestInteractable, getNearestNPC

function love.load()
    -- Set up window
    love.window.setTitle("RPG Adventure")
    love.window.setMode(800, 600, {resizable=false})
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Initialize game systems
    gameState = GameState:new()
    world = World:new()
    world:setGameState(gameState)
    
    -- Create example maps
    world:createExampleOverworld()
    world:createHouseInterior()
    world:loadMap("overworld")
    
    -- Sync all interactables with game state
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        obj:syncWithGameState(gameState)
    end
    
    -- Load animations
    loadAnimations()
    
    -- Set initial position (center of map)
    player.x = 40 * 32  -- Center of 80-tile wide map
    player.y = 30 * 32  -- Center of 60-tile tall map
    currentFrame = 1
end

function loadAnimations()
    -- Load walking animations (6 frames per direction)
    for _, direction in ipairs(directions) do
        animations.walk[direction] = {}
        for i = 0, 5 do
            local path = string.format("assets/player/animations/walk/%s/frame_%03d.png", direction, i)
            local success, image = pcall(love.graphics.newImage, path)
            if success then
                table.insert(animations.walk[direction], image)
            else
                print("Failed to load walk animation: " .. path)
            end
        end
    end
    
    -- Try to load breathing idle animations (4 frames per direction)
    for _, direction in ipairs(directions) do
        animations.idle[direction] = {}
        local foundIdleAnimation = false
        
        for i = 0, 3 do
            local path = string.format("assets/player/animations/breathing-idle/%s/frame_%03d.png", direction, i)
            local success, image = pcall(love.graphics.newImage, path)
            if success then
                table.insert(animations.idle[direction], image)
                foundIdleAnimation = true
            end
        end
        
        -- If no idle animation found, use first frame of walk animation
        if not foundIdleAnimation and #animations.walk[direction] > 0 then
            print("No idle animation found for " .. direction .. ", using walk frame 0")
            table.insert(animations.idle[direction], animations.walk[direction][1])
        end
    end
end

function love.update(dt)
    gameTime = gameTime + dt
    
    -- Update player immunity timer
    if player.immunityTimer > 0 then
        player.immunityTimer = player.immunityTimer - dt
    end
    
    -- Failsafe: Check if player is stuck in water/collision and teleport to safety
    if world.currentMap and not inCutscene then
        local boxLeft = player.x + player.collisionLeft
        local boxTop = player.y + player.collisionTop
        local boxWidth = player.collisionRight - player.collisionLeft
        local boxHeight = player.collisionBottom - player.collisionTop
        
        if world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight) then
            -- Player is stuck! Cancel all velocity first
            player.knockbackVelocityX = 0
            player.knockbackVelocityY = 0
            
            -- Try to find nearest safe position in all 8 directions
            local tileSize = world.currentMap.tileSize
            local directions = {
                {x = 0, y = -1},  -- North
                {x = 1, y = 0},   -- East
                {x = 0, y = 1},   -- South
                {x = -1, y = 0},  -- West
                {x = 1, y = -1},  -- NE
                {x = 1, y = 1},   -- SE
                {x = -1, y = 1},  -- SW
                {x = -1, y = -1}  -- NW
            }
            
            local found = false
            -- Try increasingly far distances in each direction
            for distance = 1, 5 do
                if found then break end
                for _, dir in ipairs(directions) do
                    local checkX = player.x + (dir.x * tileSize * distance)
                    local checkY = player.y + (dir.y * tileSize * distance)
                    local checkBoxLeft = checkX + player.collisionLeft
                    local checkBoxTop = checkY + player.collisionTop
                    
                    if not world.currentMap:isColliding(checkBoxLeft, checkBoxTop, boxWidth, boxHeight) then
                        player.x = checkX
                        player.y = checkY
                        found = true
                        if DEBUG_MODE then
                            print("Rescued player from collision at distance " .. distance .. " in direction " .. dir.x .. "," .. dir.y)
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- Update all NPCs
    local npcs = world:getCurrentNPCs()
    for _, npc in ipairs(npcs) do
        -- Provide collision checking for interactables
        npc.checkInteractableCollision = function(x, y)
            local npcLeft = x - 16
            local npcRight = x + 16
            local npcTop = y - 16
            local npcBottom = y + 16
            
            local interactables = world:getCurrentInteractables()
            for _, obj in ipairs(interactables) do
                -- Check collision with signs, chests, and closed doors
                local hasCollision = false
                if obj.type == "chest" or obj.type == "sign" then
                    hasCollision = true
                elseif obj.type == "door" then
                    hasCollision = (obj.openProgress == 0)
                end
                
                if hasCollision then
                    if npcLeft < obj.x + obj.width and
                       npcRight > obj.x and
                       npcTop < obj.y + obj.height and
                       npcBottom > obj.y then
                        return true
                    end
                end
            end
            
            return false
        end
        
        local npcResult = npc:update(dt, player.x, player.y)
        
        -- Handle NPC-triggered events
        if npcResult == "enter_house" and not inCutscene then
            -- Start cutscene: player walks to door, then transitions
            inCutscene = true
            cutsceneWalkTarget = {x = 55 * 32, y = 19 * 32} -- Door position
            cutsceneOnComplete = function()
                -- Transition to house interior
                gameState:changeMap("house_interior", 7*32, 9*32)
                world:loadMap(gameState.currentMap)
                player.x = gameState.playerSpawn.x
                player.y = gameState.playerSpawn.y
                
                currentMessage = "Inside the merchant's house..."
                currentMessageItem = nil
                messageTimer = 2
                
                inCutscene = false
                cutsceneWalkTarget = nil
                cutsceneOnComplete = nil
            end
            
            currentMessage = "Following the merchant inside..."
            currentMessageItem = nil
            messageTimer = 2
        end
    end
    
    -- Update all enemies
    local enemies = world:getCurrentEnemies()
    for _, enemy in ipairs(enemies) do
        -- Provide terrain collision checking (same method as player)
        enemy.checkTerrainCollision = function(x, y)
            if not world.currentMap then return false end
            
            -- Enemy collision box (32x32 centered on position)
            local boxLeft = x - 16
            local boxTop = y - 16
            local boxWidth = 32
            local boxHeight = 32
            
            -- Use the same isColliding method as the player
            return world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight)
        end
        
        -- Only check for hits if player doesn't have immunity
        local canBeHit = (player.immunityTimer <= 0)
        local enemyResult = enemy:update(dt, player.x, player.y, gameTime, canBeHit)
        
        -- Handle knockback
        if enemyResult and enemyResult.type == "knockback" and canBeHit then
            local knockDir = enemyResult.direction
            local distance = math.sqrt(knockDir.x * knockDir.x + knockDir.y * knockDir.y)
            
            if distance > 0 then
                -- Apply strong knockback velocity
                local knockbackSpeed = 750 -- Strong initial push
                player.knockbackVelocityX = (knockDir.x / distance) * knockbackSpeed
                player.knockbackVelocityY = (knockDir.y / distance) * knockbackSpeed
                
                -- Grant immunity frames
                player.immunityTimer = player.immunityDuration
            end
        end
    end
    
    -- Update all interactables (for animations)
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        local transitionResult = obj:update(dt, gameState)
        
        -- Handle delayed door transitions
        if transitionResult == "door_transition" then
            world:loadMap(gameState.currentMap)
            player.x = gameState.playerSpawn.x
            player.y = gameState.playerSpawn.y
            
            -- Reset all door animations in new map
            local newInteractables = world:getCurrentInteractables()
            for _, interactable in ipairs(newInteractables) do
                if interactable.type == "door" then
                    interactable.openProgress = 0
                    interactable.targetProgress = 0
                end
                -- Sync chest states
                interactable:syncWithGameState(gameState)
            end
            
            -- Better dialogue based on where we're going
            if gameState.currentMap == "overworld" then
                currentMessage = "Back outside..."
            elseif gameState.currentMap == "house_interior" then
                currentMessage = "Inside the house"
            else
                currentMessage = gameState.currentMap
            end
            currentMessageItem = nil  -- Clear item icon for door transitions
            messageTimer = 2
        end
    end
    
    local dx = 0
    local dy = 0
    
    -- Apply knockback velocity (smooth lerping with collision checking)
    if math.abs(player.knockbackVelocityX) > 1 or math.abs(player.knockbackVelocityY) > 1 then
        local oldX = player.x
        local oldY = player.y
        
        -- Calculate new position
        local newX = player.x + player.knockbackVelocityX * dt
        local newY = player.y + player.knockbackVelocityY * dt
        
        -- Check collision before moving
        local boxLeft = newX + player.collisionLeft
        local boxTop = newY + player.collisionTop
        local boxWidth = player.collisionRight - player.collisionLeft
        local boxHeight = player.collisionBottom - player.collisionTop
        
        if world.currentMap and world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight) then
            -- Would collide, stop knockback immediately
            player.knockbackVelocityX = 0
            player.knockbackVelocityY = 0
        else
            -- Safe to move
            player.x = newX
            player.y = newY
            
            -- Decay knockback velocity for smooth stopping
            player.knockbackVelocityX = player.knockbackVelocityX * player.knockbackDecay
            player.knockbackVelocityY = player.knockbackVelocityY * player.knockbackDecay
        end
    else
        -- Stop knockback if velocity is very small
        player.knockbackVelocityX = 0
        player.knockbackVelocityY = 0
    end
    
    -- Handle cutscene movement
    if inCutscene and cutsceneWalkTarget then
        -- Calculate direction to target
        local targetDx = cutsceneWalkTarget.x - player.x
        local targetDy = cutsceneWalkTarget.y - player.y
        local distance = math.sqrt(targetDx * targetDx + targetDy * targetDy)
        
        if DEBUG_MODE then
            print(string.format("Cutscene: Distance to door = %.2f, Target = (%.0f, %.0f), Player = (%.0f, %.0f)", 
                distance, cutsceneWalkTarget.x, cutsceneWalkTarget.y, player.x, player.y))
        end
        
        if distance < 20 then -- Increased threshold from 10 to 20
            -- Reached target, complete cutscene
            player.x = cutsceneWalkTarget.x
            player.y = cutsceneWalkTarget.y
            if cutsceneOnComplete then
                cutsceneOnComplete()
            end
        else
            -- Move towards target
            dx = targetDx / distance
            dy = targetDy / distance
        end
        player.isMoving = true
    else
        -- Normal player input (only when not in cutscene)
        if not inCutscene then
            if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
                dy = dy - 1
            end
            if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
                dy = dy + 1
            end
            if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
                dx = dx - 1
            end
            if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
                dx = dx + 1
            end
        end
        
        -- Determine if player is moving
        player.isMoving = (dx ~= 0 or dy ~= 0)
    end
    
    -- Reset animation frame when transitioning between states
    if player.isMoving ~= player.wasMoving then
        currentFrame = 1
        frameTimer = 0
    end
    player.wasMoving = player.isMoving
    
    if player.isMoving then
        -- Normalize diagonal movement
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0 then
            dx = dx / length
            dy = dy / length
        end
        
        -- Store old position for collision rollback
        local oldX = player.x
        local oldY = player.y
        
        -- Helper function to check if position has collision
        local function checkCollision(testX, testY)
            -- Disable collision during cutscenes
            if inCutscene then
                return false
            end
            
            -- Calculate collision box edges
            local boxLeft = testX + player.collisionLeft
            local boxRight = testX + player.collisionRight
            local boxTop = testY + player.collisionTop
            local boxBottom = testY + player.collisionBottom
            local boxWidth = boxRight - boxLeft
            local boxHeight = boxBottom - boxTop
            
            -- Check tilemap collision
            if world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight) then
                return true
            end
            
            -- Check collision with solid interactables
            local interactables = world:getCurrentInteractables()
            for _, obj in ipairs(interactables) do
                -- Chests and signs always have collision
                -- Doors only have collision when closed (openProgress == 0)
                local hasCollision = false
                if obj.type == "chest" or obj.type == "sign" then
                    hasCollision = true
                elseif obj.type == "door" then
                    -- Only collide with closed doors
                    hasCollision = (obj.openProgress == 0)
                end
                
                if hasCollision then
                    -- AABB collision check
                    if boxLeft < obj.x + obj.width and
                       boxRight > obj.x and
                       boxTop < obj.y + obj.height and
                       boxBottom > obj.y then
                        return true
                    end
                end
            end
            
            -- Check collision with NPCs
            local npcs = world:getCurrentNPCs()
            for _, npc in ipairs(npcs) do
                if npc.isSolid and npc:checkCollision(boxLeft, boxTop, boxWidth, boxHeight) then
                    return true
                end
            end
            
            -- Enemies don't block movement (you can walk through them)
            -- Only knockback affects player position
            
            return false
        end
        
        -- Try to move both X and Y
        local newX = player.x + dx * player.speed * dt
        local newY = player.y + dy * player.speed * dt
        
        if not checkCollision(newX, newY) then
            -- Full movement is clear
            player.x = newX
            player.y = newY
        else
            -- Try sliding along X axis only
            if not checkCollision(newX, oldY) then
                player.x = newX
            -- Try sliding along Y axis only
            elseif not checkCollision(oldX, newY) then
                player.y = newY
            end
            -- If both fail, player stays in place (fully blocked)
        end
        
        -- Determine direction
        player.direction = getDirection(dx, dy)
        
        -- Update walk animation frame
        frameTimer = frameTimer + dt
        if frameTimer >= walkFrameDelay then
            frameTimer = frameTimer - walkFrameDelay
            currentFrame = currentFrame + 1
            if currentFrame > #animations.walk[player.direction] then
                currentFrame = 1
            end
        end
    else
        -- Update breathing idle animation
        frameTimer = frameTimer + dt
        if frameTimer >= idleFrameDelay then
            frameTimer = frameTimer - idleFrameDelay
            currentFrame = currentFrame + 1
            if currentFrame > #animations.idle[player.direction] then
                currentFrame = 1
            end
        end
    end
    
    -- Update camera to follow player
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    camera.x = player.x - screenWidth / 2
    camera.y = player.y - screenHeight / 2
    
    -- Update message timer
    if currentMessage and messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then
            currentMessage = nil
            currentMessageItem = nil
        end
    end
end

function getDirection(dx, dy)
    local angle = math.atan2(dy, dx)
    local degrees = angle * (180 / math.pi)
    
    -- Normalize to 0-360
    if degrees < 0 then
        degrees = degrees + 360
    end
    
    -- Map angle to 8 directions
    if degrees >= 337.5 or degrees < 22.5 then
        return "east"
    elseif degrees >= 22.5 and degrees < 67.5 then
        return "south-east"
    elseif degrees >= 67.5 and degrees < 112.5 then
        return "south"
    elseif degrees >= 112.5 and degrees < 157.5 then
        return "south-west"
    elseif degrees >= 157.5 and degrees < 202.5 then
        return "west"
    elseif degrees >= 202.5 and degrees < 247.5 then
        return "north-west"
    elseif degrees >= 247.5 and degrees < 292.5 then
        return "north"
    else
        return "north-east"
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    
    -- Draw world (ground, water, walls)
    world:draw(camera, gameTime)
    
    -- Y-sort all entities (player, decorations, interactables)
    local entities = {}
    
    -- Add player (sort by feet position for proper depth)
    -- Player sprite is centered, so feet are at y + half the sprite height
    local playerSortY = player.y + 16 -- Approximate feet position
    table.insert(entities, {
        y = playerSortY,
        draw = drawPlayer
    })
    
    -- Add decorations (trees, bushes) - only visible ones
    if world.currentMap then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local startX = math.max(0, math.floor(camera.x / world.currentMap.tileSize) - 2)
        local endX = math.min(world.currentMap.width - 1, math.ceil((camera.x + screenWidth) / world.currentMap.tileSize) + 2)
        local startY = math.max(0, math.floor(camera.y / world.currentMap.tileSize) - 2)
        local endY = math.min(world.currentMap.height - 1, math.ceil((camera.y + screenHeight) / world.currentMap.tileSize) + 2)
        
        for y = startY, endY do
            for x = startX, endX do
                local deco = world.currentMap:getTile(x, y, "decorations")
                if deco > 0 then
                    local px = x * world.currentMap.tileSize
                    local py = y * world.currentMap.tileSize
                    -- Use bottom of decoration for sorting
                    local sortY = py + world.currentMap.tileSize
                    
                    table.insert(entities, {
                        y = sortY,
                        draw = function()
                            world.currentMap:drawSingleDecoration(x, y, deco)
                        end
                    })
                end
            end
        end
    end
    
    -- Add interactables
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        -- Use bottom of object for sorting
        local sortY = obj.y + obj.height
        table.insert(entities, {
            y = sortY,
            draw = function() obj:draw() end
        })
    end
    
    -- Add NPCs
    local npcs = world:getCurrentNPCs()
    for _, npc in ipairs(npcs) do
        -- Use bottom of NPC for sorting
        local sortY = npc.y + 16
        table.insert(entities, {
            y = sortY,
            draw = function() npc:draw() end
        })
    end
    
    -- Add Enemies
    local enemies = world:getCurrentEnemies()
    for _, enemy in ipairs(enemies) do
        -- Use bottom of enemy for sorting
        local sortY = enemy.y + 16
        table.insert(entities, {
            y = sortY,
            draw = function() enemy:draw() end
        })
    end
    
    -- Sort by Y position
    table.sort(entities, function(a, b) return a.y < b.y end)
    
    -- Draw in sorted order
    for _, entity in ipairs(entities) do
        entity.draw()
    end
    
    -- Draw roofs AFTER entities (but they won't draw if player is near)
    world:drawRoofs(camera, player.x, player.y)
    
    -- Debug: Draw collision boxes for interactables
    if DEBUG_MODE then
        local interactables = world:getCurrentInteractables()
        for _, obj in ipairs(interactables) do
            -- Check if this object has collision
            local hasCollision = false
            if obj.type == "chest" or obj.type == "sign" then
                hasCollision = true
            elseif obj.type == "door" then
                hasCollision = (obj.openProgress == 0) -- Only closed doors
            end
            
            if hasCollision then
                love.graphics.setColor(1, 0, 0, 0.3)
                love.graphics.rectangle("fill", obj.x, obj.y, obj.width, obj.height)
            else
                -- Draw open doors in different color
                love.graphics.setColor(0, 1, 0, 0.2)
                love.graphics.rectangle("fill", obj.x, obj.y, obj.width, obj.height)
            end
        end
        
        -- Debug: Draw collision boxes for NPCs
        local npcs = world:getCurrentNPCs()
        for _, npc in ipairs(npcs) do
            if npc.isSolid then
                love.graphics.setColor(1, 0.5, 0, 0.3)
                love.graphics.rectangle("fill", npc.x - 16, npc.y - 16, 32, 32)
            end
        end
        
        -- Debug: Draw collision boxes for enemies (distinct red color)
        local enemies = world:getCurrentEnemies()
        for _, enemy in ipairs(enemies) do
            if enemy.isSolid then
                -- Filled collision box
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.rectangle("fill", enemy.x - 16, enemy.y - 16, 32, 32)
                
                -- Thicker outline to distinguish from NPCs
                love.graphics.setColor(1, 0, 0, 0.8)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", enemy.x - 16, enemy.y - 16, 32, 32)
                love.graphics.setLineWidth(1)
            end
        end
        
        -- Debug: Draw collision boxes for tiles (trees, bushes, rocks, walls) - only visible
        if world.currentMap then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local startX = math.max(0, math.floor(camera.x / world.currentMap.tileSize) - 1)
            local endX = math.min(world.currentMap.width - 1, math.ceil((camera.x + screenWidth) / world.currentMap.tileSize) + 1)
            local startY = math.max(0, math.floor(camera.y / world.currentMap.tileSize) - 1)
            local endY = math.min(world.currentMap.height - 1, math.ceil((camera.y + screenHeight) / world.currentMap.tileSize) + 1)
            
            for y = startY, endY do
                for x = startX, endX do
                    local collision = world.currentMap:getTile(x, y, "collision")
                    
                    -- Draw all collision tiles (type 2 = walls/decorations)
                    if collision == 2 then
                        local px = x * world.currentMap.tileSize
                        local py = y * world.currentMap.tileSize
                        love.graphics.setColor(0.6, 0.3, 0, 0.3)
                        love.graphics.rectangle("fill", px, py, world.currentMap.tileSize, world.currentMap.tileSize)
                    end
                end
            end
        end
        
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw interaction indicator (on top of everything)
    local nearObj = getNearestInteractable()
    if nearObj then
        local ex = nearObj.x + nearObj.width/2 - 4
        local ey = nearObj.y - 20
        -- Subtle dark background
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", ex - 4, ey - 2, 16, 16, 3, 3)
        -- Drop shadow
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print("E", ex + 2, ey + 2)
        -- Yellow "E"
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("E", ex, ey)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw NPC interaction indicator
    local nearNPC = getNearestNPC()
    if nearNPC then
        local ex = nearNPC.x - 4
        local ey = nearNPC.y - 70
        -- Subtle dark background
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", ex - 4, ey - 2, 16, 16, 3, 3)
        -- Drop shadow
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print("E", ex + 2, ey + 2)
        -- Yellow "E"
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("E", ex, ey)
        love.graphics.setColor(1, 1, 1)
    end
    
    love.graphics.pop()
    
    -- Draw UI (screen space)
    drawUI()
    drawMessage()
end

function drawPlayer()
    local animationType = player.isMoving and "walk" or "idle"
    if animations[animationType][player.direction] and #animations[animationType][player.direction] > 0 then
        local image = animations[animationType][player.direction][currentFrame]
        local imageWidth = image:getWidth()
        local imageHeight = image:getHeight()
        
        -- Flash when immune (invincibility frames)
        if player.immunityTimer > 0 then
            -- Flash effect: alternate between visible and transparent
            local flashRate = 8 -- Flashes per second
            local flashCycle = (gameTime * flashRate) % 1
            if flashCycle < 0.5 then
                love.graphics.setColor(1, 1, 1, 0.4) -- Semi-transparent
            else
                love.graphics.setColor(1, 1, 1, 1) -- Normal
            end
        end
        
        love.graphics.draw(
            image,
            player.x,
            player.y,
            0,
            player.scale,
            player.scale,
            imageWidth / 2,
            imageHeight / 2
        )
        
        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Debug: draw collision box
    if DEBUG_MODE then
        love.graphics.setColor(0, 1, 0, 0.5)
        local boxLeft = player.x + player.collisionLeft
        local boxTop = player.y + player.collisionTop
        local boxWidth = player.collisionRight - player.collisionLeft
        local boxHeight = player.collisionBottom - player.collisionTop
        love.graphics.rectangle("line", boxLeft, boxTop, boxWidth, boxHeight)
        
        -- Draw center point
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("fill", player.x, player.y, 2)
        
        love.graphics.setColor(1, 1, 1)
    end
end

local function drawItemIcon(itemName, x, y, size, isHovered)
    -- Draw item icons with toon shading and outlines
    size = size or 32
    
    -- Simple white background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", x, y, 32, 32, 2, 2)
    
    if itemName == "Gold Key" then
        -- Redesigned smaller key
        -- Key head (ornate circle)
        love.graphics.setColor(0.90, 0.75, 0.20)
        love.graphics.circle("fill", x + 16, y + 10, 5)
        
        -- Inner circle (decorative)
        love.graphics.setColor(0.75, 0.60, 0.15)
        love.graphics.circle("fill", x + 16, y + 10, 2)
        
        -- Key shaft
        love.graphics.setColor(0.90, 0.75, 0.20)
        love.graphics.rectangle("fill", x + 14, y + 15, 4, 10)
        
        -- Key teeth (smaller, more detailed)
        love.graphics.rectangle("fill", x + 18, y + 22, 3, 3)
        love.graphics.rectangle("fill", x + 18, y + 19, 2, 2)
        
        -- Highlight (toon style)
        love.graphics.setColor(0.98, 0.92, 0.50)
        love.graphics.circle("fill", x + 14, y + 8, 2)
        
        -- Shadow side
        love.graphics.setColor(0.65, 0.52, 0.12)
        love.graphics.arc("fill", x + 16, y + 10, 5, math.pi * 0.3, math.pi * 1.3)
        
        -- Outline
        love.graphics.setColor(0.20, 0.15, 0.05)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x + 16, y + 10, 5)
        love.graphics.rectangle("line", x + 14, y + 15, 4, 10)
        love.graphics.setLineWidth(1)
        
    elseif itemName == "Health Potion" then
        -- Bottle (glass)
        love.graphics.setColor(0.7, 0.85, 0.9)
        love.graphics.rectangle("fill", x + 8, y + 10, 16, 18, 2, 2)
        
        -- Red liquid (toon shaded)
        love.graphics.setColor(0.85, 0.15, 0.15)
        love.graphics.rectangle("fill", x + 10, y + 14, 12, 12, 2, 2)
        
        -- Liquid highlight
        love.graphics.setColor(0.95, 0.35, 0.35)
        love.graphics.rectangle("fill", x + 11, y + 15, 4, 4)
        
        -- Cork
        love.graphics.setColor(0.55, 0.35, 0.25)
        love.graphics.rectangle("fill", x + 12, y + 6, 8, 6)
        
        -- Outline
        love.graphics.setColor(0.15, 0.10, 0.10)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 8, y + 10, 16, 18, 2, 2)
        love.graphics.rectangle("line", x + 12, y + 6, 8, 6)
        love.graphics.setLineWidth(1)
        
    elseif itemName == "Magic Sword" then
        -- Blade (silver with purple glow)
        love.graphics.setColor(0.75, 0.75, 0.85)
        love.graphics.polygon("fill", 
            x + 16, y + 4,   -- tip
            x + 14, y + 22,  -- left
            x + 18, y + 22)  -- right
        
        -- Blade highlight
        love.graphics.setColor(0.90, 0.90, 0.95)
        love.graphics.line(x + 15, y + 6, x + 15, y + 20)
        
        -- Magic glow (purple)
        love.graphics.setColor(0.6, 0.3, 0.9, 0.5)
        love.graphics.polygon("fill",
            x + 16, y + 2,
            x + 12, y + 20,
            x + 20, y + 20)
        
        -- Guard
        love.graphics.setColor(0.60, 0.55, 0.30)
        love.graphics.rectangle("fill", x + 10, y + 22, 12, 3)
        
        -- Handle
        love.graphics.setColor(0.45, 0.30, 0.20)
        love.graphics.rectangle("fill", x + 14, y + 25, 4, 6)
        
        -- Pommel
        love.graphics.setColor(0.60, 0.55, 0.30)
        love.graphics.circle("fill", x + 16, y + 31, 3)
        
        -- Outline
        love.graphics.setColor(0.10, 0.08, 0.08)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line",
            x + 16, y + 4,
            x + 14, y + 22,
            x + 18, y + 22)
        love.graphics.rectangle("line", x + 10, y + 22, 12, 3)
        love.graphics.rectangle("line", x + 14, y + 25, 4, 6)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.setColor(1, 1, 1)
end

function drawUI()
    -- Draw toggle hints at bottom
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("[I] Inventory  [H] Help  [F3] Debug", 10, love.graphics.getHeight() - 20)
    
    -- Draw help panel
    if showHelp then
        local screenWidth = love.graphics.getWidth()
        local panelWidth = 320
        local panelHeight = 210
        local panelX = 15
        local panelY = 15
        local headerHeight = 28
        local padding = 12
        
        -- Main background panel
        love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
        love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
        
        -- Outer border (gold)
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Header background
        love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
        love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth - 4, headerHeight - 2, 3, 3)
        
        -- Header text (centered)
        love.graphics.setColor(1, 0.95, 0.7)
        local headerText = "Controls"
        local textWidth = love.graphics.getFont():getWidth(headerText)
        love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, panelY + 7)
        
        -- Divider line below header
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(
            panelX + 8, panelY + headerHeight,
            panelX + panelWidth - 8, panelY + headerHeight
        )
        love.graphics.setLineWidth(1)
        
        -- Controls list
        love.graphics.setColor(1, 1, 1)
        local yPos = panelY + headerHeight + padding + 8
        local lineHeight = 20
        love.graphics.print("WASD/Arrows - Move", panelX + padding + 8, yPos)
        love.graphics.print("E - Interact", panelX + padding + 8, yPos + lineHeight)
        love.graphics.print("I - Toggle Inventory", panelX + padding + 8, yPos + lineHeight * 2)
        love.graphics.print("H - Toggle Help", panelX + padding + 8, yPos + lineHeight * 3)
        love.graphics.print("F3 - Debug Mode", panelX + padding + 8, yPos + lineHeight * 4)
        love.graphics.print("ESC - Quit", panelX + padding + 8, yPos + lineHeight * 5)
        
        -- Item count
        love.graphics.setColor(0.9, 0.85, 0.6)
        love.graphics.print(string.format("Items Collected: %d", #gameState.inventory), panelX + padding + 8, yPos + lineHeight * 6.5)
    end
    
    -- Draw debug panel
    if showDebugPanel then
        local screenWidth = love.graphics.getWidth()
        local panelWidth = 320
        local panelHeight = 240
        local panelX = screenWidth - panelWidth - 115  -- Moved further left to avoid inventory
        local panelY = 15
        local headerHeight = 28
        local padding = 12
        
        -- Main background panel
        love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
        love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
        
        -- Outer border (gold)
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Header background
        love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
        love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth - 4, headerHeight - 2, 3, 3)
        
        -- Header text (centered)
        love.graphics.setColor(1, 0.95, 0.7)
        local headerText = "Debug Info"
        local textWidth = love.graphics.getFont():getWidth(headerText)
        love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, panelY + 7)
        
        -- Divider line below header
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(
            panelX + 8, panelY + headerHeight,
            panelX + panelWidth - 8, panelY + headerHeight
        )
        love.graphics.setLineWidth(1)
        
        -- Debug info
        love.graphics.setColor(1, 1, 1)
        local yPos = panelY + headerHeight + padding + 8
        local lineHeight = 18
        
        -- Player position
        love.graphics.print(string.format("Position: (%.0f, %.0f)", player.x, player.y), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Tile position
        local tileX = math.floor(player.x / 32)
        local tileY = math.floor(player.y / 32)
        love.graphics.print(string.format("Tile: (%d, %d)", tileX, tileY), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Current map
        love.graphics.print(string.format("Map: %s", gameState.currentMap), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Quest state
        love.graphics.print(string.format("Quest: %s", gameState.questState), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Direction & movement
        love.graphics.print(string.format("Direction: %s", player.direction), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        love.graphics.print(string.format("Moving: %s", tostring(player.isMoving)), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Cutscene state
        love.graphics.print(string.format("In Cutscene: %s", tostring(inCutscene)), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- NPC count
        local npcs = world:getCurrentNPCs()
        love.graphics.print(string.format("NPCs: %d", #npcs), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- FPS
        love.graphics.setColor(0.9, 0.85, 0.6)
        love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), panelX + padding + 8, yPos)
        
        -- Note about hitboxes
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("(Collision boxes visible)", panelX + padding + 8, panelY + panelHeight - padding - 12)
    end
    
    -- Draw inventory panel (vertical layout)
    if showInventory then
        local screenWidth = love.graphics.getWidth()
        local itemCount = #gameState.inventory
        local iconSize = 40
        local padding = 12
        local headerHeight = 28
        local minHeight = 100 -- Minimum height for empty inventory
        
        local inventoryWidth = iconSize + padding * 2 + 8
        local inventoryHeight = headerHeight + math.max(itemCount * iconSize, minHeight - headerHeight) + padding * 2
        local inventoryX = screenWidth - inventoryWidth - 15
        local inventoryY = 15
        
        -- Main background panel
        love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
        love.graphics.rectangle("fill", inventoryX, inventoryY, inventoryWidth, inventoryHeight, 4, 4)
        
        -- Outer border (gold)
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", inventoryX, inventoryY, inventoryWidth, inventoryHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Header background
        love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
        love.graphics.rectangle("fill", inventoryX + 2, inventoryY + 2, inventoryWidth - 4, headerHeight - 2, 3, 3)
        
        -- Header text (centered)
        love.graphics.setColor(1, 0.95, 0.7)
        local headerText = "Inventory"
        local textWidth = love.graphics.getFont():getWidth(headerText)
        love.graphics.print(headerText, inventoryX + (inventoryWidth - textWidth) / 2, inventoryY + 7)
        
        -- Divider line below header
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(
            inventoryX + 8, inventoryY + headerHeight,
            inventoryX + inventoryWidth - 8, inventoryY + headerHeight
        )
        love.graphics.setLineWidth(1)
        
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        local hoveredItem = nil
        
        -- If inventory is empty, show a message
        if itemCount == 0 then
            love.graphics.setColor(0.6, 0.55, 0.45)
            local emptyText = "Empty"
            local textWidth = love.graphics.getFont():getWidth(emptyText)
            love.graphics.print(emptyText, inventoryX + (inventoryWidth - textWidth) / 2, inventoryY + headerHeight + 30)
        end
        
        -- Draw each item icon vertically
        for i, item in ipairs(gameState.inventory) do
            local iconX = inventoryX + padding + 4
            local iconY = inventoryY + headerHeight + padding + (i - 1) * iconSize + 4
            
            -- Check if mouse is hovering over this icon
            local isHovered = mouseX >= iconX - 2 and mouseX <= iconX + 34 and
                             mouseY >= iconY - 2 and mouseY <= iconY + 34
            
            if isHovered then
                hoveredItem = item
            end
            
            -- Draw icon slot background
            if isHovered then
                love.graphics.setColor(0.25, 0.22, 0.18, 0.95)
            else
                love.graphics.setColor(0.15, 0.13, 0.11, 0.8)
            end
            love.graphics.rectangle("fill", iconX - 2, iconY - 2, 36, 36, 3, 3)
            
            -- Icon slot border
            if isHovered then
                love.graphics.setColor(0.9, 0.8, 0.4)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.35, 0.30, 0.20)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", iconX - 2, iconY - 2, 36, 36, 3, 3)
            love.graphics.setLineWidth(1)
            
            -- Draw the item icon
            drawItemIcon(item, iconX, iconY, 32, isHovered)
        end
        
        -- Draw tooltip for hovered item
        if hoveredItem then
            local tooltipX = mouseX + 15
            local tooltipY = mouseY
            local tooltipText = hoveredItem
            local tooltipWidth = love.graphics.getFont():getWidth(tooltipText) + 20
            local tooltipHeight = 26
            
            -- Keep tooltip on screen
            if tooltipX + tooltipWidth > screenWidth then
                tooltipX = mouseX - tooltipWidth - 5
            end
            if tooltipY + tooltipHeight > love.graphics.getHeight() then
                tooltipY = love.graphics.getHeight() - tooltipHeight
            end
            
            -- Tooltip background
            love.graphics.setColor(0.12, 0.10, 0.08, 0.95)
            love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
            
            -- Tooltip border (bright gold)
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
            love.graphics.setLineWidth(1)
            
            -- Tooltip text
            love.graphics.setColor(1, 0.95, 0.7)
            love.graphics.print(tooltipText, tooltipX + 10, tooltipY + 6)
        end
    end
end

function drawMessage()
    if currentMessage then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        local padding = 12
        local iconSize = 40
        local panelHeight = 80
        local panelY = screenHeight - panelHeight - 20
        
        -- Calculate panel width based on content
        local textWidth = love.graphics.getFont():getWidth(currentMessage) + padding * 2
        local panelWidth = textWidth + (currentMessageItem and (iconSize + padding * 2) or 0) + padding * 2
        panelWidth = math.max(panelWidth, 300) -- Minimum width
        panelWidth = math.min(panelWidth, screenWidth - 100) -- Maximum width
        local panelX = (screenWidth - panelWidth) / 2
        
        -- Main background panel
        love.graphics.setColor(0.08, 0.08, 0.10, 0.90)
        love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
        
        -- Outer border (gold)
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Inner decorative border
        love.graphics.setColor(0.65, 0.55, 0.20, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", panelX + 4, panelY + 4, panelWidth - 8, panelHeight - 8, 3, 3)
        love.graphics.setLineWidth(1)
        
        -- Message text (centered vertically and accounting for line wrapping)
        love.graphics.setColor(1, 0.95, 0.8)
        local textX = panelX + padding + 8
        local maxTextWidth = panelWidth - padding * 3 - (currentMessageItem and (iconSize + padding) or 0) - 16
        
        -- Calculate actual text height with wrapping
        local _, wrappedText = love.graphics.getFont():getWrap(currentMessage, maxTextWidth)
        local textHeight = #wrappedText * love.graphics.getFont():getHeight()
        local textY = panelY + (panelHeight - textHeight) / 2
        
        love.graphics.printf(currentMessage, textX, textY, maxTextWidth, "left")
        
        -- If there's an item, draw its icon on the right
        if currentMessageItem then
            local iconX = panelX + panelWidth - iconSize - padding - 8
            local iconY = panelY + (panelHeight - iconSize) / 2
            
            -- Draw white background for icon
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 3, 3)
            
            -- Draw item icon
            drawItemIcon(currentMessageItem, iconX + 4, iconY + 4, 32, false)
            
            -- Add border around icon
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize, 3, 3)
            love.graphics.setLineWidth(1)
        end
    end
end

getNearestInteractable = function()
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        if obj:isPlayerNear(player.x, player.y) then
            return obj
        end
    end
    return nil
end

getNearestNPC = function()
    local npcs = world:getCurrentNPCs()
    for _, npc in ipairs(npcs) do
        if npc:isPlayerNear(player.x, player.y) then
            return npc
        end
    end
    return nil
end

checkInteraction = function()
    -- Check NPC interaction first
    local npc = getNearestNPC()
    if npc then
        local result = npc:interact(gameState)
        if result then
            currentMessage = result
            messageTimer = messageDuration
            currentMessageItem = nil
        end
        return
    end
    
    -- Then check interactable objects
    local obj = getNearestInteractable()
    if obj then
        local result = obj:interact(gameState)
        
        -- Door transitions are now handled in update loop after animation
        if result then
            currentMessage = result
            messageTimer = messageDuration
            
            -- If it's a chest with an item being collected, store the item for icon display
            -- Only show icon if the message says "Found:" (i.e., actually collecting the item)
            if obj.type == "chest" and obj.data and obj.data.item and result:find("Found:") then
                currentMessageItem = obj.data.item
            else
                currentMessageItem = nil
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "e" and not inCutscene then
        checkInteraction()
    elseif key == "f3" then
        showDebugPanel = not showDebugPanel
        DEBUG_MODE = showDebugPanel -- Also toggle hitboxes when debug panel is shown
    elseif key == "i" and not inCutscene then
        showInventory = not showInventory
    elseif key == "h" and not inCutscene then
        showHelp = not showHelp
    end
end

