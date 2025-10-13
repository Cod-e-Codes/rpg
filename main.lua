-- Enhanced RPG with Tilemap, Collision, and Interactions
-- Controls: WASD/Arrows to move, E to interact, F3 for debug

-- Require modules
local GameState = require("gamestate")
local World = require("world")
local Spell = require("spell")
local SpellSystem = require("spellsystem")
local Lighting = require("lighting")
local SaveManager = require("savemanager")
local DevMode = require("devmode")
local Projectile = require("projectile")

-- Debug mode
DEBUG_MODE = false

-- Game state
local player = {
    x = 400,
    y = 300,
    speed = 150,
    direction = "south",
    isMoving = false,
    -- Combat stats
    health = 100,
    maxHealth = 100,
    isDead = false,
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
local spellSystem
local projectiles = {} -- Active projectiles
local lighting
local saveManager
local devMode
local currentMessage = nil
local currentMessageItem = nil  -- Store item for message icon
local messageTimer = 0
local messageDuration = 5  -- Increased from 3 to give more time to read

-- UI state
local showInventory = false
local showFullInventory = false
local inventoryWidth = 0 -- Current animated width
local inventoryTargetWidth = 0 -- Target width to lerp to
local inventoryScrollOffset = 0
local lastInventoryPress = 0
local inventoryDoublePressWindow = 0.3
local selectedInventoryItem = nil -- Currently selected item for equipping
local showHelp = false
local showDebugPanel = false
local isPaused = false
local pauseMenuState = "main" -- "main", "controls", or "save_confirm"
local pauseMenuHeight = 250 -- Current animated height
local pauseMenuTargetHeight = 250 -- Target height to lerp to

-- Cutscene state
local inCutscene = false
local cutsceneWalkTarget = nil
local cutsceneOnComplete = nil

-- Start screen state
local gameStarted = false
local playerNameInput = ""
local showProfileMenu = false
local startScreenState = "menu" -- "menu", "new_game", "loading"
local startMenuSelection = 1 -- 1 = New Game, 2 = Load Game, 3 = Quit

-- Fade transition state
local fadeState = "none" -- "none", "fade_out", "fade_in"
local fadeAlpha = 0
local fadeSpeed = 2 -- How fast to fade (alpha per second)
local fadeTargetMap = nil
local fadeSpawnX = nil
local fadeSpawnY = nil

-- Camera pan cutscene state
local cameraPanState = "none" -- "none", "pan_to_target", "pause", "pan_back"
local cameraPanTarget = {x = 0, y = 0}
local cameraPanSpeed = 300 -- Pixels per second
local cameraPanPauseTimer = 0
local cameraPanPauseDuration = 2 -- Seconds to pause at target
local cameraPanOriginal = {x = 0, y = 0}
local cameraPanCutsceneShown = false -- Track if we've shown the cave cutscene

-- Direction mappings
local directions = {
    "north", "north-east", "east", "south-east",
    "south", "south-west", "west", "north-west"
}

-- Forward declarations
local loadAnimations, getDirection, drawPlayer, drawUI, drawMessage, drawPauseMenu
local checkInteraction, getNearestInteractable, getNearestNPC

function love.load()
    -- Set up window
    love.window.setTitle("RPG Adventure")
    love.window.setMode(800, 600, {resizable=false})
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Enable text input for name entry
    love.keyboard.setTextInput(true)
    
    -- Initialize game systems
    gameState = GameState:new()
    world = World:new()
    world:setGameState(gameState)
    
    -- Initialize spell system
    spellSystem = SpellSystem:new(gameState)
    
    -- Initialize lighting system
    lighting = Lighting:new()
    
    -- Initialize save manager
    saveManager = SaveManager
    
    -- Initialize dev mode
    devMode = DevMode:new()
    
    -- Create example maps
    world:createExampleOverworld()
    world:createHouseInterior()
    world:createCaveLevel1()
    world:createClassSelection()
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
    -- Don't update game if not started
    if not gameStarted then
        return
    end
    
    -- Always update UI animations even when paused
    if isPaused then
        -- Lerp pause menu height
        local lerpSpeed = 12
        pauseMenuHeight = pauseMenuHeight + (pauseMenuTargetHeight - pauseMenuHeight) * lerpSpeed * dt
        return
    end
    
    -- Lerp inventory width animation
    local lerpSpeed = 12
    inventoryWidth = inventoryWidth + (inventoryTargetWidth - inventoryWidth) * lerpSpeed * dt
    
    -- Apply dev mode speed multiplier
    if devMode and devMode.enabled and devMode.speedMultiplier > 1 then
        dt = dt * devMode.speedMultiplier
    end
    
    gameTime = gameTime + dt
    
    -- Update play time
    gameState.playTime = gameState.playTime + dt
    
    -- Update dev mode
    if devMode then
        devMode:update(dt)
    end
    
    -- Update lighting system
    if lighting then
        lighting:update(dt)
        
        -- Update ambient darkness based on current map
        if gameState.currentMap == "cave_level1" then
            lighting:setAmbientDarkness(0.88) -- Very dark - need illumination spell
        else
            lighting:setAmbientDarkness(0) -- No darkness in overworld/house
        end
        
        -- Clear and recreate lights each frame
        lighting:clearLights()
        
        -- Add cave entrance light (if in cave)
        if gameState.currentMap == "cave_level1" then
            -- Light from entrance (modest glow)
            lighting:addLight(2*32, 9*32, 120, 1.2, {0.7, 0.7, 0.6}, 0.1)
            
            -- Light from scroll (if not collected) - bright beacon that reveals cave
            local interactables = world:getCurrentInteractables()
            for _, obj in ipairs(interactables) do
                if obj.type == "scroll" and not obj.isOpen then
                    lighting:addLight(obj.x + obj.width/2, obj.y + obj.height/2, 180, 2.0, {0.95, 0.85, 0.4}, 0.2)
                end
            end
        end
        
        -- Add portal lights (glowing magical energy)
        local interactables = world:getCurrentInteractables()
        for _, obj in ipairs(interactables) do
            if obj.type == "portal" then
                -- Pulsing purple/blue magical light
                local pulse = 1 + math.sin(love.timer.getTime() * 3) * 0.2
                lighting:addLight(obj.x + obj.width/2, obj.y + obj.height/2, 120 * pulse, 1.5, {0.6, 0.5, 0.9}, 0.15)
            end
        end
        
        -- Add active spell lights (illumination spell)
        if spellSystem then
            for slotIndex, spell in pairs(spellSystem.equippedSpells) do
                if spell and spell.isActive and spell.name == "Illumination" then
                    -- Large bright light that fully reveals the cave floor
                    lighting:addLight(player.x, player.y, spell:getCurrentRadius() * 2.5, 2.5, spell.lightColor, 0.05)
                end
            end
        end
    end
    
    -- Update spell system
    if spellSystem then
        spellSystem:update(dt, player.x, player.y, camera)
        
        -- Sync mana with game state
        gameState.currentMana = spellSystem.currentMana
        gameState.maxMana = spellSystem.maxMana
        
        -- Rebuild learned spells from game state (after loading)
        if #spellSystem.learnedSpells == 0 and #gameState.learnedSpells > 0 then
            for _, spellName in ipairs(gameState.learnedSpells) do
                if spellName == "Illumination" then
                    local spell = Spell.createIllumination()
                    spell.level = gameState:getSpellLevel(spellName)
                    spell.experience = gameState:getSpellExperience(spellName)
                    spellSystem:learnSpell(spell)
                end
            end
        end
    end
    
    -- Update fade transitions
    if fadeState == "fade_out" then
        fadeAlpha = fadeAlpha + fadeSpeed * dt
        if fadeAlpha >= 1 then
            fadeAlpha = 1
            -- Transition to new map
            if fadeTargetMap then
                gameState:changeMap(fadeTargetMap, fadeSpawnX, fadeSpawnY)
                world:loadMap(gameState.currentMap)
                player.x = gameState.playerSpawn.x
                player.y = gameState.playerSpawn.y
            end
            fadeState = "fade_in"
        end
    elseif fadeState == "fade_in" then
        fadeAlpha = fadeAlpha - fadeSpeed * dt
        if fadeAlpha <= 0 then
            fadeAlpha = 0
            fadeState = "none"
            fadeTargetMap = nil
        end
    end
    
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
        
        -- Handle knockback and damage
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
                
                -- Take damage from enemy
                player.health = player.health - enemy.damage
                if player.health <= 0 then
                    player.health = 0
                    player.isDead = true
                end
            end
        end
    end
    
    -- Update projectiles and check collisions
    for i = #projectiles, 1, -1 do
        local proj = projectiles[i]
        proj:update(dt)
        
        -- Check collision with enemies
        local hitEnemy = proj:checkCollision(enemies)
        if hitEnemy then
            local died = hitEnemy:takeDamage(proj.damage)
            if died then
                -- Remove dead enemy from world
                for j, enemy in ipairs(enemies) do
                    if enemy == hitEnemy then
                        table.remove(enemies, j)
                        break
                    end
                end
            end
        end
        
        -- Remove inactive projectiles
        if not proj.active then
            table.remove(projectiles, i)
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
            
            -- Trigger cave reveal cutscene when exiting house with sword
            local triggerCaveCutscene = false
            if gameState.currentMap == "overworld" and 
               gameState.questState == "sword_collected" and 
               not cameraPanCutsceneShown then
                cameraPanCutsceneShown = true
                triggerCaveCutscene = true
                
                -- Start a walking cutscene first (player walks out)
                inCutscene = true
                player.isMoving = false -- Stop any current movement
                cutsceneWalkTarget = {x = player.x, y = player.y + 64} -- Walk south a bit
                cutsceneOnComplete = function()
                    -- After walking out, clear cutscene walk state
                    cutsceneWalkTarget = nil
                    cutsceneOnComplete = nil
                    
                    -- Start camera pan
                    local screenWidth = love.graphics.getWidth()
                    local screenHeight = love.graphics.getHeight()
                    local caveX = 80  -- Cave center (new large entrance at x=0, width=160)
                    local caveY = 26*32 + 96  -- Cave center (y=26*32, height=192)
                    
                    cameraPanOriginal.x = player.x - screenWidth / 2
                    cameraPanOriginal.y = player.y - screenHeight / 2
                    cameraPanTarget.x = caveX - screenWidth / 2
                    cameraPanTarget.y = caveY - screenHeight / 2
                    cameraPanState = "pan_to_target"
                    
                    currentMessage = "A mysterious cave has appeared to the west!"
                    currentMessageItem = nil -- Clear any item icon
                    messageTimer = 999 -- Keep message until cutscene ends
                end
            end
            
            -- Better dialogue based on where we're going (skip if cave cutscene)
            if not triggerCaveCutscene then
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
            player.isMoving = false
            if cutsceneOnComplete then
                cutsceneOnComplete()
            else
                -- No follow-up action, end cutscene
                inCutscene = false
                cutsceneWalkTarget = nil
            end
        else
            -- Move towards target
            dx = targetDx / distance
            dy = targetDy / distance
            player.isMoving = true
        end
    else
        -- Normal player input (only when not in cutscene and alive)
        if not inCutscene and not player.isDead then
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
    
    -- Update camera pan cutscene
    if cameraPanState == "pan_to_target" then
        local dx = cameraPanTarget.x - camera.x
        local dy = cameraPanTarget.y - camera.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 10 then
            -- Reached target
            camera.x = cameraPanTarget.x
            camera.y = cameraPanTarget.y
            cameraPanState = "pause"
            cameraPanPauseTimer = cameraPanPauseDuration
            
            if DEBUG_MODE then
                print("Camera reached cave, pausing...")
            end
        else
            -- Move towards target
            local moveX = (dx / distance) * cameraPanSpeed * dt
            local moveY = (dy / distance) * cameraPanSpeed * dt
            camera.x = camera.x + moveX
            camera.y = camera.y + moveY
        end
    elseif cameraPanState == "pause" then
        cameraPanPauseTimer = cameraPanPauseTimer - dt
        if cameraPanPauseTimer <= 0 then
            cameraPanState = "pan_back"
            
            if DEBUG_MODE then
                print("Panning back to player...")
            end
        end
    elseif cameraPanState == "pan_back" then
        local dx = cameraPanOriginal.x - camera.x
        local dy = cameraPanOriginal.y - camera.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 10 then
            -- Back to player
            camera.x = cameraPanOriginal.x
            camera.y = cameraPanOriginal.y
            cameraPanState = "none"
            inCutscene = false
            player.isMoving = false -- Ensure player stops
            currentMessage = nil
            messageTimer = 0
            
            if DEBUG_MODE then
                print("Cave cutscene completed")
            end
        else
            -- Move back to player
            local moveX = (dx / distance) * cameraPanSpeed * dt
            local moveY = (dy / distance) * cameraPanSpeed * dt
            camera.x = camera.x + moveX
            camera.y = camera.y + moveY
        end
    end
    
    -- Update camera to follow player (only when not in camera pan cutscene)
    if cameraPanState == "none" then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        camera.x = player.x - screenWidth / 2
        camera.y = player.y - screenHeight / 2
    end
    
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
    -- Draw start screen if game hasn't started
    if not gameStarted then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local font = love.graphics.getFont()
        
        -- Background
        love.graphics.setColor(0.05, 0.05, 0.1)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        
        -- Title
        love.graphics.setColor(1, 0.9, 0.6)
        local titleText = "RPG ADVENTURE"
        local titleWidth = font:getWidth(titleText)
        love.graphics.print(titleText, screenWidth/2 - titleWidth/2, 80)
        
        if startScreenState == "menu" then
            -- Main menu
            local menuY = screenHeight/2 - 60
            local lineHeight = 40
            local hasSaveFile = saveManager:saveExists()
            
            -- New Game option
            if startMenuSelection == 1 then
                love.graphics.setColor(1, 0.9, 0.6)
                love.graphics.print("> New Game <", screenWidth/2 - font:getWidth("> New Game <")/2, menuY)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.print("New Game", screenWidth/2 - font:getWidth("New Game")/2, menuY)
            end
            
            -- Load Game option (only if save exists)
            menuY = menuY + lineHeight
            if hasSaveFile then
                if startMenuSelection == 2 then
                    love.graphics.setColor(1, 0.9, 0.6)
                    love.graphics.print("> Load Game <", screenWidth/2 - font:getWidth("> Load Game <")/2, menuY)
                else
                    love.graphics.setColor(0.8, 0.8, 0.8)
                    love.graphics.print("Load Game", screenWidth/2 - font:getWidth("Load Game")/2, menuY)
                end
                menuY = menuY + lineHeight
            end
            
            -- Quit option
            local quitSelection = hasSaveFile and 3 or 2
            if startMenuSelection == quitSelection then
                love.graphics.setColor(1, 0.9, 0.6)
                love.graphics.print("> Quit <", screenWidth/2 - font:getWidth("> Quit <")/2, menuY)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.print("Quit", screenWidth/2 - font:getWidth("Quit")/2, menuY)
            end
            
            -- Controls hint
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print("W/S or Up/Down - Navigate", screenWidth/2 - font:getWidth("W/S or Up/Down - Navigate")/2, screenHeight - 80)
            love.graphics.print("ENTER - Select  |  ESC - Quit", screenWidth/2 - font:getWidth("ENTER - Select  |  ESC - Quit")/2, screenHeight - 50)
            
        elseif startScreenState == "new_game" then
            -- Name entry screen
            love.graphics.setColor(1, 1, 1)
            local promptText = "Enter your name:"
            local promptWidth = font:getWidth(promptText)
            love.graphics.print(promptText, screenWidth/2 - promptWidth/2, screenHeight/2 - 40)
            
            -- Input box
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", screenWidth/2 - 100, screenHeight/2, 200, 30, 3, 3)
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", screenWidth/2 - 100, screenHeight/2, 200, 30, 3, 3)
            
            -- Player name input
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(playerNameInput, screenWidth/2 - 95, screenHeight/2 + 7)
            
            -- Instructions
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Press ENTER to start", screenWidth/2 - font:getWidth("Press ENTER to start")/2, screenHeight/2 + 50)
            love.graphics.print("ESC - Back to menu", screenWidth/2 - font:getWidth("ESC - Back to menu")/2, screenHeight - 50)
        end
        
        love.graphics.setColor(1, 1, 1)
        return
    end
    
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
        if obj.type == "cave" then
            -- Cave has layered drawing: back boulder + opening (behind player), front boulder (in front of player)
            -- Back layer: back boulder and cave opening (drawn earlier, player walks in front)
            table.insert(entities, {
                y = obj.y + 100,  -- Upper part of cave
                draw = function() obj:draw("back_layer") end
            })
            -- Front layer: front boulder (drawn later, player walks behind)
            table.insert(entities, {
                y = obj.y + obj.height - 40,  -- Lower part of cave (front boulder position)
                draw = function() obj:draw("front_layer") end
            })
        else
            -- Use bottom of object for sorting
            local sortY = obj.y + obj.height
            table.insert(entities, {
                y = sortY,
                draw = function() obj:draw() end
            })
        end
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
    
    -- Draw projectiles
    for _, proj in ipairs(projectiles) do
        proj:draw()
    end
    
    love.graphics.pop()
    
    -- Draw lighting overlay in screen space (after pop) so it covers the world but not UI
    if lighting then
        lighting:draw(camera)
    end
    
    -- Draw UI (screen space)
    drawUI()
    drawMessage()
    
    -- Draw spell system UI (includes particles and spell bar)
    if spellSystem then
        spellSystem:draw(camera, player.x, player.y)
    end
    
    -- Draw dev mode panel
    if devMode and devMode.enabled then
        devMode:draw()
    end
    
    -- Draw pause menu
    if isPaused then
        drawPauseMenu()
    end
    
    -- Draw profile menu
    if showProfileMenu and gameState.playerClass then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local panelWidth = 400
        local panelHeight = 350
        local panelX = (screenWidth - panelWidth) / 2
        local panelY = (screenHeight - panelHeight) / 2
        
        -- Semi-transparent background overlay
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        
        -- Main panel background
        love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
        love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)
        
        -- Border
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 6, 6)
        love.graphics.setLineWidth(1)
        
        -- Title
        love.graphics.setColor(1, 0.9, 0.6)
        local title = "PLAYER PROFILE"
        local font = love.graphics.getFont()
        local titleWidth = font:getWidth(title)
        love.graphics.print(title, panelX + (panelWidth - titleWidth) / 2, panelY + 15)
        
        -- Divider line
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(panelX + 20, panelY + 45, panelX + panelWidth - 20, panelY + 45)
        love.graphics.setLineWidth(1)
        
        -- Player info
        love.graphics.setColor(1, 1, 1)
        local yPos = panelY + 60
        local lineHeight = 25
        
        -- Name
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Name:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(gameState.playerName, panelX + 150, yPos)
        
        -- Class
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Class:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(gameState.playerClass, panelX + 150, yPos)
        
        -- Element
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Element:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.upper(string.sub(gameState.playerElement, 1, 1)) .. string.sub(gameState.playerElement, 2), panelX + 150, yPos)
        
        -- Health
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Health:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%d / %d", player.health, player.maxHealth), panelX + 150, yPos)
        
        -- Mana
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Mana:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%d / %d", spellSystem.currentMana, spellSystem.maxMana), panelX + 150, yPos)
        
        -- Play time
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Play Time:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        local hours = math.floor(gameState.playTime / 3600)
        local minutes = math.floor((gameState.playTime % 3600) / 60)
        local seconds = math.floor(gameState.playTime % 60)
        love.graphics.print(string.format("%02d:%02d:%02d", hours, minutes, seconds), panelX + 150, yPos)
        
        -- Spells learned
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Spells Learned:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(#gameState.learnedSpells, panelX + 150, yPos)
        
        -- Location
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Location:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        local locationName = gameState.currentMap == "class_selection" and "Class Selection" or string.upper(string.sub(gameState.currentMap, 1, 1)) .. string.sub(gameState.currentMap, 2):gsub("_", " ")
        love.graphics.print(locationName, panelX + 150, yPos)
        
        -- Close hint
        love.graphics.setColor(0.7, 0.7, 0.7)
        local closeText = "[P] or [ESC] to close"
        local closeWidth = font:getWidth(closeText)
        love.graphics.print(closeText, panelX + (panelWidth - closeWidth) / 2, panelY + panelHeight - 30)
        
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw fade overlay (for cave transitions)
    if fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function drawPauseMenu()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Pause menu panel (animated height)
    local panelWidth = 300
    local panelHeight = math.floor(pauseMenuHeight) -- Use animated height
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = (screenHeight - panelHeight) / 2
    
    -- Background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
    
    -- Border
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Header
    love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
    love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth - 4, 36, 3, 3)
    
    love.graphics.setColor(1, 0.95, 0.7)
    local font = love.graphics.getFont()
    local titleText = "PAUSED"
    if pauseMenuState == "controls" then
        titleText = "CONTROLS"
    elseif pauseMenuState == "save_confirm" then
        titleText = "CONFIRM OVERWRITE"
    end
    local titleWidth = font:getWidth(titleText)
    love.graphics.print(titleText, panelX + (panelWidth - titleWidth) / 2, panelY + 12)
    
    -- Divider
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 8, panelY + 42, panelX + panelWidth - 8, panelY + 42)
    love.graphics.setLineWidth(1)
    
    -- Menu options
    local yPos = panelY + 60
    local padding = 12
    local options = {}
    
    if pauseMenuState == "main" then
        options = {
            "Resume (ESC)",
            "Save Game (S)",
            "Load Game (L)",
            "Controls (C)",
            "Quit Game (Q)"
        }
        pauseMenuTargetHeight = 250
    elseif pauseMenuState == "save_confirm" then
        -- Save confirmation - will be drawn differently below
        options = {}
        pauseMenuTargetHeight = 200
    elseif pauseMenuState == "controls" then
        -- Controls screen - will be drawn differently below
        options = {"Back (ESC)"}
        pauseMenuTargetHeight = 380 -- Taller for controls list
    end
    
    love.graphics.setColor(1, 0.95, 0.8)
    
    if pauseMenuState == "main" then
        -- Main pause menu
        for i, option in ipairs(options) do
            local optionWidth = font:getWidth(option)
            love.graphics.print(option, panelX + (panelWidth - optionWidth) / 2, yPos)
            yPos = yPos + 30
        end
    elseif pauseMenuState == "save_confirm" then
        -- Save confirmation dialog
        love.graphics.setColor(0.9, 0.85, 0.7)
        local msg1 = "A save file already exists."
        local msg2 = "Overwrite it?"
        local msg1Width = font:getWidth(msg1)
        local msg2Width = font:getWidth(msg2)
        love.graphics.print(msg1, panelX + (panelWidth - msg1Width) / 2, yPos)
        love.graphics.print(msg2, panelX + (panelWidth - msg2Width) / 2, yPos + 25)
        
        yPos = yPos + 65
        local confirmOptions = {"Yes (Y)", "No (N)"}
        for _, option in ipairs(confirmOptions) do
            local optionWidth = font:getWidth(option)
            love.graphics.print(option, panelX + (panelWidth - optionWidth) / 2, yPos)
            yPos = yPos + 30
        end
    elseif pauseMenuState == "controls" then
        -- Controls screen
        local controlsList = {
            {"WASD / Arrow Keys", "Move"},
            {"E", "Interact"},
            {"1-5", "Cast Spell (Slot)"},
            {"B", "Open Spellbook"},
            {"I", "Quick Slots"},
            {"I+I", "Full Inventory"},
            {"6-0", "Use Quick Slot"},
            {"ESC / P", "Pause"},
            {"F3", "Debug Info"},
            {"F12", "Dev Mode"}
        }
        
        yPos = yPos + 10
        for _, control in ipairs(controlsList) do
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.print(control[1], panelX + padding + 10, yPos)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(control[2], panelX + 200, yPos)
            yPos = yPos + 25
        end
        
        yPos = yPos + 20
        love.graphics.setColor(0.6, 0.6, 0.6)
        local backText = "Press ESC to return"
        local backWidth = font:getWidth(backText)
        love.graphics.print(backText, panelX + (panelWidth - backWidth) / 2, yPos)
    end
    
    -- Footer hint (only in main menu, controls has its own "return" hint)
    if pauseMenuState == "main" then
        love.graphics.setColor(0.6, 0.55, 0.45)
        local hintText = "Press ESC to resume"
        local hintWidth = font:getWidth(hintText)
        love.graphics.print(hintText, panelX + (panelWidth - hintWidth) / 2, panelY + panelHeight - 25)
    end
    
    love.graphics.setColor(1, 1, 1)
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
    -- Draw player health bar (only if class selected and not dead)
    if gameState.playerClass then
        local barWidth = 200
        local barHeight = 20
        local barX = (love.graphics.getWidth() - barWidth) / 2
        local barY = 20
        
        -- Background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 3, 3)
        
        -- Health (red to green gradient based on health)
        local healthPercent = player.health / player.maxHealth
        local r = 1 - (healthPercent * 0.5) -- Red 100% at 0 health, 50% at full
        local g = healthPercent -- Green 0% at 0 health, 100% at full
        love.graphics.setColor(r, g, 0.2)
        love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight, 3, 3)
        
        -- Border
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 3, 3)
        
        -- Health text
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%d / %d", player.health, player.maxHealth), barX + barWidth/2 - 25, barY + 3)
        
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw death screen
    if player.isDead then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        -- Dark overlay
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        
        -- Death message
        love.graphics.setColor(0.8, 0.1, 0.1)
        local deathText = "YOU DIED"
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(deathText)
        love.graphics.print(deathText, screenWidth/2 - textWidth/2, screenHeight/2 - 40)
        
        -- Respawn instruction
        love.graphics.setColor(1, 1, 1)
        local respawnText = "Press R to Respawn"
        local respawnWidth = font:getWidth(respawnText)
        love.graphics.print(respawnText, screenWidth/2 - respawnWidth/2, screenHeight/2 + 20)
        
        love.graphics.setColor(1, 1, 1)
        return -- Don't draw other UI when dead
    end
    
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
        yPos = yPos + lineHeight
        
        -- Mana (if spells learned)
        if spellSystem and #spellSystem.learnedSpells > 0 then
            love.graphics.setColor(0.3, 0.5, 0.9)
            love.graphics.print(string.format("Mana: %d/%d", 
                math.floor(spellSystem.currentMana), spellSystem.maxMana), panelX + padding + 8, yPos)
        end
        
        -- Note about hitboxes
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("(Collision boxes visible)", panelX + padding + 8, panelY + panelHeight - padding - 12)
    end
    
    -- Draw inventory quick slots (visible when inventory is open)
    if showInventory then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local slotSize = 48
        local slotSpacing = 8
        local totalSlots = 5
        
        -- Position on right side of screen
        local startX = screenWidth - slotSize - 15
        local startY = screenHeight / 2 - ((totalSlots * slotSize + (totalSlots - 1) * slotSpacing) / 2)
        
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Draw each quick slot
        for i = 1, totalSlots do
            local slotX = startX
            local slotY = startY + (i - 1) * (slotSize + slotSpacing)
            local item = gameState.quickSlots[i]
            local key = tostring(i + 5) -- Keys 6-0
            if i == 5 then key = "0" end
            
            -- Check hover
            local isHovered = mouseX >= slotX and mouseX <= slotX + slotSize and
                             mouseY >= slotY and mouseY <= slotY + slotSize
            
            -- Background
            if item then
                love.graphics.setColor(0.15, 0.13, 0.11, 0.9)
            else
                love.graphics.setColor(0.08, 0.08, 0.10, 0.7)
            end
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            
            -- Border
            if isHovered then
                love.graphics.setColor(0.9, 0.8, 0.4)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.35, 0.30, 0.20)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)
            love.graphics.setLineWidth(1)
            
            -- Draw item if equipped
            if item then
                drawItemIcon(item, slotX + 8, slotY + 8, 32, isHovered)
            end
        end
        
        -- Draw full inventory panel (slides from right)
        if inventoryWidth > 5 then
            local panelWidth = math.floor(inventoryWidth)
            local panelHeight = slotSize * 5 + slotSpacing * 4 + 40 -- 5 rows + header
            local panelX = startX - panelWidth - 10
            local panelY = startY - 20
            
            -- Background
            love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
            love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
            
            -- Border
            love.graphics.setColor(0.75, 0.65, 0.25)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
            love.graphics.setLineWidth(1)
            
            -- Header
            love.graphics.setColor(1, 0.95, 0.7)
            local headerText = "Inventory"
            local textWidth = love.graphics.getFont():getWidth(headerText)
            love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, panelY + 8)
            
            -- Divider
            love.graphics.setColor(0.65, 0.55, 0.20)
            love.graphics.setLineWidth(2)
            love.graphics.line(panelX + 8, panelY + 32, panelX + panelWidth - 8, panelY + 32)
            love.graphics.setLineWidth(1)
            
            -- Scrollable inventory grid
            local contentY = panelY + 40
            local contentHeight = panelHeight - 48
            local columns = math.max(1, math.floor((panelWidth - 16) / (slotSize + 4)))
            
            -- Only set scissor if dimensions are valid
            if panelWidth > 8 and contentHeight > 0 then
                love.graphics.setScissor(panelX + 4, contentY, panelWidth - 8, contentHeight)
            end
            
            local hoveredItem = nil
            local hoveredItemName = nil
            local i = 0
            
            for itemName, count in pairs(gameState.inventory) do
                local col = i % columns
                local row = math.floor(i / columns)
                local itemX = panelX + 8 + col * (slotSize + 4)
                local itemY = contentY + row * (slotSize + 4) - inventoryScrollOffset
                
                -- Only draw if visible
                if itemY + slotSize >= contentY and itemY <= contentY + contentHeight then
                    local isHovered = mouseX >= itemX and mouseX <= itemX + slotSize and
                                     mouseY >= itemY and mouseY <= itemY + slotSize and
                                     mouseY >= contentY and mouseY <= contentY + contentHeight
                    
                    if isHovered then
                        hoveredItem = itemName
                        hoveredItemName = itemName
                    end
                    
                    local isSelected = (selectedInventoryItem == itemName)
                    
                    -- Background
                    if isSelected then
                        love.graphics.setColor(0.35, 0.28, 0.18, 0.95) -- Selected color
                    elseif isHovered then
                        love.graphics.setColor(0.25, 0.22, 0.18, 0.95)
                    else
                        love.graphics.setColor(0.15, 0.13, 0.11, 0.8)
                    end
                    love.graphics.rectangle("fill", itemX, itemY, slotSize, slotSize, 3, 3)
                    
                    -- Border
                    if isSelected then
                        love.graphics.setColor(1, 0.9, 0.5) -- Bright selected border
                        love.graphics.setLineWidth(3)
                    elseif isHovered then
                        love.graphics.setColor(0.9, 0.8, 0.4)
                        love.graphics.setLineWidth(2)
                    else
                        love.graphics.setColor(0.35, 0.30, 0.20)
                        love.graphics.setLineWidth(1)
                    end
                    love.graphics.rectangle("line", itemX, itemY, slotSize, slotSize, 3, 3)
                    love.graphics.setLineWidth(1)
                    
                    -- Draw item
                    drawItemIcon(itemName, itemX + 8, itemY + 8, 32, isHovered)
                    
                    -- Draw count if > 1
                    if count > 1 then
                        local countText = "x" .. count
                        local textWidth = love.graphics.getFont():getWidth(countText)
                        local textHeight = love.graphics.getFont():getHeight()
                        local textX = itemX + slotSize - textWidth - 4
                        local textY = itemY + slotSize - 16
                        
                        -- Background for better visibility
                        love.graphics.setColor(0, 0, 0, 0.7)
                        love.graphics.rectangle("fill", textX - 2, textY - 1, textWidth + 4, textHeight + 2, 2, 2)
                        
                        -- Text
                        love.graphics.setColor(1, 1, 1)
                        love.graphics.print(countText, textX, textY)
                    end
                end
                
                i = i + 1
            end
            
            love.graphics.setScissor()
            
            -- Tooltip
            if hoveredItem then
                local tooltipX = mouseX + 15
                local tooltipY = mouseY
                local tooltipText = hoveredItem
                local tooltipWidth = love.graphics.getFont():getWidth(tooltipText) + 20
                local tooltipHeight = 26
                
                if tooltipX + tooltipWidth > screenWidth then
                    tooltipX = mouseX - tooltipWidth - 5
                end
                
                love.graphics.setColor(0.12, 0.10, 0.08, 0.95)
                love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
                love.graphics.setColor(0.75, 0.65, 0.25)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 0.95, 0.7)
                love.graphics.print(hoveredItem, tooltipX + 10, tooltipY + 5)
            end
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
        
        -- Handle class selection
        if type(result) == "table" and result.type == "class_selected" then
            -- Give the player their starter attack spell based on element
            if spellSystem and result.element then
                local spell = nil
                if result.element == "fire" then
                    spell = Spell.createFireball()
                elseif result.element == "ice" then
                    spell = Spell.createIceShard()
                elseif result.element == "lightning" then
                    spell = Spell.createLightningBolt()
                elseif result.element == "earth" then
                    spell = Spell.createStoneSpike()
                end
                
                if spell then
                    spellSystem:learnSpell(spell)
                end
            end
            
            currentMessage = result.message
            messageTimer = 5 -- Longer duration for class selection message
            currentMessageItem = nil
            return
        end
        
        -- Handle spell learned (special result type)
        if type(result) == "table" and result.type == "spell_learned" then
            -- Create and learn the spell
            if result.spell == "Illumination" and spellSystem then
                local spell = Spell.createIllumination()
                spellSystem:learnSpell(spell)
            end
            
            currentMessage = result.message
            messageTimer = 5 -- Longer duration for tutorial message
            currentMessageItem = nil
            return
        end
        
        -- Handle fade transitions (caves)
        if type(result) == "table" and result.type == "fade_transition" then
            fadeState = "fade_out"
            fadeTargetMap = result.targetMap
            fadeSpawnX = result.spawnX
            fadeSpawnY = result.spawnY
            return
        end
        
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
    -- Start screen handling
    if not gameStarted then
        if startScreenState == "menu" then
            local hasSaveFile = saveManager:saveExists()
            local maxSelection = hasSaveFile and 3 or 2
            
            if key == "w" or key == "up" then
                startMenuSelection = startMenuSelection - 1
                if startMenuSelection < 1 then startMenuSelection = maxSelection end
            elseif key == "s" or key == "down" then
                startMenuSelection = startMenuSelection + 1
                if startMenuSelection > maxSelection then startMenuSelection = 1 end
            elseif key == "return" or key == "kpenter" then
                if startMenuSelection == 1 then
                    -- New Game
                    startScreenState = "new_game"
                    playerNameInput = ""
                elseif startMenuSelection == 2 and hasSaveFile then
                    -- Load Game
                    local success, loadedState = saveManager:load()
                    if success and loadedState then
                        -- Apply loaded state (use applySaveData which properly merges)
                        saveManager:applySaveData(gameState, loadedState)
                        
                        -- After applySaveData, read from gameState (which now has the merged data)
                        player.x = gameState.playerX or gameState.playerSpawn.x
                        player.y = gameState.playerY or gameState.playerSpawn.y
                        player.health = gameState.playerHealth or player.maxHealth
                        
                        -- Rebuild spell system with loaded data
                        spellSystem = SpellSystem:new(gameState)
                        spellSystem:rebuildLearnedSpells()
                        
                        -- Load the saved map
                        world:loadMap(gameState.currentMap)
                        
                        -- Sync interactables
                        local interactables = world:getCurrentInteractables()
                        for _, obj in ipairs(interactables) do
                            obj:syncWithGameState(gameState)
                        end
                        
                        gameStarted = true
                    end
                elseif (startMenuSelection == 2 and not hasSaveFile) or (startMenuSelection == 3 and hasSaveFile) then
                    -- Quit
                    love.event.quit()
                end
            elseif key == "escape" then
                love.event.quit()
            end
        elseif startScreenState == "new_game" then
            if key == "return" or key == "kpenter" then
                if #playerNameInput > 0 then
                    gameState.playerName = playerNameInput
                else
                    gameState.playerName = "Hero"
                end
                gameStarted = true
            elseif key == "backspace" then
                playerNameInput = string.sub(playerNameInput, 1, -2)
            elseif key == "escape" then
                startScreenState = "menu"
                playerNameInput = ""
            end
        end
        return
    end
    
    -- Handle death respawn
    if player.isDead and key == "r" then
        player.health = player.maxHealth
        player.isDead = false
        player.x = gameState.playerSpawn.x
        player.y = gameState.playerSpawn.y
        return
    end
    
    -- Dev mode toggle (works always) - F12 toggles both dev mode and panel
    if key == "f12" then
        if devMode then
            devMode:toggle()
        end
        return
    end
    
    -- Pause handling
    if key == "escape" then
        -- Close profile menu if open
        if showProfileMenu then
            showProfileMenu = false
            return
        end
        
        -- Close spell menu if open
        if spellSystem and spellSystem.showSpellMenu then
            spellSystem:toggleSpellMenu()
            return
        end
        
        -- Close dev panel if open
        if devMode and devMode.enabled and devMode.showPanel then
            devMode:togglePanel()
            return
        end
        
        -- Close full inventory if open (don't close quick slots)
        if showFullInventory then
            showFullInventory = false
            inventoryTargetWidth = 0
            inventoryScrollOffset = 0
            selectedInventoryItem = nil -- Clear selection
            return
        end
        
        -- Handle pause menu navigation
        if isPaused and pauseMenuState == "controls" then
            -- Return to main pause menu
            pauseMenuState = "main"
            pauseMenuTargetHeight = 250
            return
        elseif isPaused and pauseMenuState == "save_confirm" then
            -- Cancel save confirmation
            pauseMenuState = "main"
            pauseMenuTargetHeight = 250
            return
        end
        
        -- Toggle pause
        isPaused = not isPaused
        if isPaused then
            pauseMenuState = "main" -- Reset to main menu when pausing
            pauseMenuTargetHeight = 250
            pauseMenuHeight = 250 -- Reset animation
        end
        return
    end
    
    -- Pause menu shortcuts
    if isPaused then
        if key == "s" then
            -- Quick save - check if save exists first
            local saveExists = saveManager:saveExists()
            if saveExists then
                -- Show confirmation dialog
                pauseMenuState = "save_confirm"
                pauseMenuTargetHeight = 200
            else
                -- No existing save, just save
                local success, msg = saveManager:save(gameState, player.x, player.y, player.health)
                currentMessage = msg or "Game saved"
                messageTimer = 3
            end
        elseif key == "l" then
            -- Quick load
            local saveData, err = saveManager:load()
            if saveData then
                saveManager:applySaveData(gameState, saveData)
                world:loadMap(gameState.currentMap)
                player.x = gameState.playerSpawn.x
                player.y = gameState.playerSpawn.y
                
                -- Rebuild spell system from loaded data
                spellSystem.gameState = gameState
                spellSystem:rebuildLearnedSpells()
                
                isPaused = false
                currentMessage = "Game loaded"
                messageTimer = 3
            else
                currentMessage = err or "Failed to load game"
                messageTimer = 3
                print("Load error: " .. tostring(err))
            end
        elseif key == "c" then
            -- Show controls submenu
            pauseMenuState = "controls"
            pauseMenuTargetHeight = 380
        elseif key == "y" and pauseMenuState == "save_confirm" then
            -- Confirm overwrite
            local success, msg = saveManager:save(gameState, player.x, player.y, player.health)
            currentMessage = msg or "Game saved"
            messageTimer = 3
            pauseMenuState = "main"
            pauseMenuTargetHeight = 250
        elseif key == "n" and pauseMenuState == "save_confirm" then
            -- Cancel save
            pauseMenuState = "main"
            pauseMenuTargetHeight = 250
        elseif key == "q" then
            love.event.quit()
        end
        return
    end
    
    -- Normal game controls (not paused)
    if key == "e" and not inCutscene then
        checkInteraction()
    elseif key == "f3" then
        showDebugPanel = not showDebugPanel
        DEBUG_MODE = showDebugPanel -- Also toggle hitboxes when debug panel is shown
    elseif key == "i" and not inCutscene then
        local currentTime = love.timer.getTime()
        
        -- If full inventory is open, close it first
        if showFullInventory then
            showFullInventory = false
            inventoryTargetWidth = 0
            inventoryScrollOffset = 0
            selectedInventoryItem = nil -- Clear selection
            lastInventoryPress = 0 -- Reset double-press timer
        -- Check for double-press to open full inventory
        elseif currentTime - lastInventoryPress < inventoryDoublePressWindow and showInventory then
            -- Double press - open full inventory
            showFullInventory = true
            inventoryTargetWidth = 300
            lastInventoryPress = currentTime
        else
            -- Single press - toggle quick slots
            showInventory = not showInventory
            lastInventoryPress = currentTime
        end
    elseif key == "h" and not inCutscene then
        showHelp = not showHelp
    elseif key == "b" and not inCutscene then
        -- Toggle spell menu (only if spells learned)
        if spellSystem then
            if #gameState.learnedSpells > 0 then
                spellSystem:toggleSpellMenu()
            else
                currentMessage = "You haven't learned any spells yet..."
                messageTimer = 2
            end
        end
    elseif key == "1" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(1)
        if success and spell and spell.damage then
            -- Create projectile for attack spell
            table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
        end
    elseif key == "2" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(2)
        if success and spell and spell.damage then
            table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
        end
    elseif key == "3" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(3)
        if success and spell and spell.damage then
            table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
        end
    elseif key == "4" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(4)
        if success and spell and spell.damage then
            table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
        end
    elseif key == "5" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(5)
        if success and spell and spell.damage then
            table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
        end
    elseif key == "6" and not inCutscene then
        -- Use quick slot 1
        if gameState.quickSlots[1] then
            currentMessage = string.format("Used %s", gameState.quickSlots[1])
            messageTimer = 2
        end
    elseif key == "7" and not inCutscene then
        -- Use quick slot 2
        if gameState.quickSlots[2] then
            currentMessage = string.format("Used %s", gameState.quickSlots[2])
            messageTimer = 2
        end
    elseif key == "8" and not inCutscene then
        -- Use quick slot 3
        if gameState.quickSlots[3] then
            currentMessage = string.format("Used %s", gameState.quickSlots[3])
            messageTimer = 2
        end
    elseif key == "9" and not inCutscene then
        -- Use quick slot 4
        if gameState.quickSlots[4] then
            currentMessage = string.format("Used %s", gameState.quickSlots[4])
            messageTimer = 2
        end
    elseif key == "0" and not inCutscene then
        -- Use quick slot 5
        if gameState.quickSlots[5] then
            currentMessage = string.format("Used %s", gameState.quickSlots[5])
            messageTimer = 2
        end
    elseif key == "p" and not inCutscene then
        -- Profile menu (only available after selecting class)
        if gameState.playerClass then
            showProfileMenu = not showProfileMenu
        else
            currentMessage = "Complete class selection first..."
            messageTimer = 2
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Left click
        -- Dev mode clicks
        if devMode and devMode.enabled and devMode.showPanel then
            devMode:handleClick(x, y, gameState, world, player, spellSystem, Spell)
        end
        
        -- Handle spell menu clicks
        if spellSystem and spellSystem.showSpellMenu then
            spellSystem:handleClick(x, y)
        end
        
        -- Handle inventory clicks (equipping to quick slots)
        if showFullInventory and inventoryWidth > 5 then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local slotSize = 48
            local slotSpacing = 8
            local startX = screenWidth - slotSize - 15
            local startY = screenHeight / 2 - ((5 * slotSize + 4 * slotSpacing) / 2)
            local panelWidth = math.floor(inventoryWidth)
            local panelHeight = slotSize * 5 + slotSpacing * 4 + 40
            local panelX = startX - panelWidth - 10
            local panelY = startY - 20
            local contentY = panelY + 40
            local contentHeight = panelHeight - 48
            local columns = math.floor((panelWidth - 16) / (slotSize + 4))
            
            -- Check if clicking on a quick slot
            for s = 1, 5 do
                local slotX = startX
                local slotY = startY + (s - 1) * (slotSize + slotSpacing)
                if x >= slotX and x <= slotX + slotSize and
                   y >= slotY and y <= slotY + slotSize then
                    if selectedInventoryItem then
                        -- Equip selected item to this slot
                        gameState.quickSlots[s] = selectedInventoryItem
                        currentMessage = string.format("Equipped %s to slot %d", selectedInventoryItem, s + 5)
                        messageTimer = 2
                        selectedInventoryItem = nil -- Deselect after equipping
                    elseif gameState.quickSlots[s] then
                        -- Unequip item from this slot
                        local unequippedItem = gameState.quickSlots[s]
                        gameState.quickSlots[s] = nil
                        currentMessage = string.format("Unequipped %s from slot %d", unequippedItem, s + 5)
                        messageTimer = 2
                    end
                    return
                end
            end
            
            -- Check if clicking on an inventory item (to select it)
            local i = 0
            for itemName, count in pairs(gameState.inventory) do
                local col = i % columns
                local row = math.floor(i / columns)
                local itemX = panelX + 8 + col * (slotSize + 4)
                local itemY = contentY + row * (slotSize + 4) - inventoryScrollOffset
                
                if itemY + slotSize >= contentY and itemY <= contentY + contentHeight then
                    if x >= itemX and x <= itemX + slotSize and
                       y >= itemY and y <= itemY + slotSize and
                       y >= contentY and y <= contentY + contentHeight then
                        -- Toggle selection
                        if selectedInventoryItem == itemName then
                            selectedInventoryItem = nil -- Deselect
                            currentMessage = "Deselected"
                            messageTimer = 1
                        else
                            selectedInventoryItem = itemName -- Select
                            currentMessage = string.format("Selected %s - Click a slot to equip", itemName)
                            messageTimer = 2
                        end
                        return
                    end
                end
                i = i + 1
            end
        end
    end
end

function love.wheelmoved(x, y)
    if showFullInventory and inventoryWidth > 5 then
        -- Scroll inventory
        local slotSize = 48
        local itemCount = 0
        for _ in pairs(gameState.inventory) do itemCount = itemCount + 1 end
        local inventoryRows = math.ceil(itemCount / math.floor((inventoryWidth - 16) / (slotSize + 4)))
        local maxScroll = math.max(0, inventoryRows * (slotSize + 4) - (slotSize * 5 + 32))
        
        inventoryScrollOffset = inventoryScrollOffset - y * 20
        inventoryScrollOffset = math.max(0, math.min(inventoryScrollOffset, maxScroll))
    end
end

function love.textinput(text)
    if not gameStarted and startScreenState == "new_game" and #playerNameInput < 15 then
        playerNameInput = playerNameInput .. text
    end
end

