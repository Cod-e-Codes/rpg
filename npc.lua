-- NPC System with rotation, collision, and dialogue
local NPC = {}

function NPC:new(x, y, npcType, data)
    local npc = {
        x = x,
        y = y,
        width = 32,
        height = 32,
        npcType = npcType, -- "merchant", "villager", etc.
        data = data or {},
        direction = "south", -- Current facing direction (north, south, east, west)
        rotations = {}, -- Loaded rotation images
        animations = {walk = {}, idle = {}}, -- Loaded walk/idle animations
        scale = 2,
        -- Collision (same as player for consistency)
        isSolid = true,
        -- Quest/state tracking
        questState = data.questState or "initial",
        isMoving = false,
        moveTarget = nil,
        moveSpeed = 80,
        -- Animation frames
        currentFrame = 1,
        frameTimer = 0,
        walkFrameDelay = 0.1,
        idleFrameDelay = 0.15,
        rotationUpdateTimer = 0,
        rotationUpdateDelay = 0.1,
        -- Patrol system
        patrolRoute = data.patrolRoute or {}, -- Array of {x, y} waypoints
        currentWaypoint = 1,
        patrolPauseTimer = 0,
        patrolPauseTime = 2, -- Seconds to pause at each waypoint
        useAnimations = data.useAnimations or false, -- Use full animations vs static rotations
        -- Obstacle avoidance
        stuckTimer = 0,
        stuckThreshold = 2.0, -- Seconds before considering NPC stuck
        lastPosition = {x = x, y = y}
    }
    setmetatable(npc, {__index = self})
    
    -- Load sprites (rotations or animations)
    npc:loadSprites()
    
    return npc
end

function NPC:loadSprites()
    local directions = {"north", "south", "east", "west"}
    
    if self.useAnimations then
        -- Load walk animations (6 frames per direction)
        for _, direction in ipairs(directions) do
            self.animations.walk[direction] = {}
            for i = 0, 5 do
                local path = string.format("assets/npcs/%s/animations/walk/%s/frame_%03d.png", 
                    self.npcType, direction, i)
                local success, image = pcall(love.graphics.newImage, path)
                if success then
                    table.insert(self.animations.walk[direction], image)
                end
            end
        end
        
        -- Load idle/breathing animations (4 frames per direction)
        for _, direction in ipairs(directions) do
            self.animations.idle[direction] = {}
            local foundIdleAnimation = false
            
            for i = 0, 3 do
                local path = string.format("assets/npcs/%s/animations/breathing-idle/%s/frame_%03d.png", 
                    self.npcType, direction, i)
                local success, image = pcall(love.graphics.newImage, path)
                if success then
                    table.insert(self.animations.idle[direction], image)
                    foundIdleAnimation = true
                end
            end
            
            -- Fallback to first walk frame if no idle animation
            if not foundIdleAnimation and #self.animations.walk[direction] > 0 then
                table.insert(self.animations.idle[direction], self.animations.walk[direction][1])
            end
        end
    else
        -- Load simple 4 directional rotation sprites (for merchant)
        local basePath = string.format("assets/npcs/%s/rotations/", self.npcType)
        
        for _, dir in ipairs(directions) do
            local path = basePath .. dir .. ".png"
            local success, image = pcall(love.graphics.newImage, path)
            if success then
                self.rotations[dir] = image
            else
                print("Failed to load NPC rotation: " .. path)
            end
        end
    end
end

function NPC:update(dt, playerX, playerY)
    -- Handle patrol route
    if #self.patrolRoute > 0 then
        self:updatePatrol(dt, playerX, playerY)
    else
        -- Update facing direction to look at player (only if not patrolling)
        self.rotationUpdateTimer = self.rotationUpdateTimer + dt
        if self.rotationUpdateTimer >= self.rotationUpdateDelay then
            self.rotationUpdateTimer = 0
            self:facePlayer(playerX, playerY)
        end
    end
    
    -- Update animation frames
    if self.useAnimations then
        self.frameTimer = self.frameTimer + dt
        local animType = self.isMoving and "walk" or "idle"
        local frameDelay = self.isMoving and self.walkFrameDelay or self.idleFrameDelay
        
        -- Ensure current frame is valid for the current animation type
        local maxFrames = #self.animations[animType][self.direction]
        if maxFrames > 0 and self.currentFrame > maxFrames then
            self.currentFrame = 1 -- Reset to first frame if out of range
        end
        
        if self.frameTimer >= frameDelay then
            self.frameTimer = self.frameTimer - frameDelay
            if maxFrames > 0 then
                self.currentFrame = self.currentFrame + 1
                if self.currentFrame > maxFrames then
                    self.currentFrame = 1
                end
            end
        end
    end
    
    -- Handle auto-enter timer (for quest sequences)
    if self.data.autoEnterTimer and self.data.autoEnterTimer > 0 then
        self.data.autoEnterTimer = self.data.autoEnterTimer - dt
        if self.data.autoEnterTimer <= 0 then
            -- Trigger house entry
            if self.data.gameState then
                return "enter_house" -- Signal to main.lua to transition
            end
            self.data.autoEnterTimer = nil
        end
    end
    
    -- Handle movement (for quest sequences)
    if self.moveTarget then
        local dx = self.moveTarget.x - self.x
        local dy = self.moveTarget.y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 5 then
            -- Reached target
            self.x = self.moveTarget.x
            self.y = self.moveTarget.y
            self.isMoving = false
            self.moveTarget = nil
            
            -- Trigger callback if exists
            if self.data.onReachTarget then
                self.data.onReachTarget()
            end
        else
            -- Move towards target
            self.isMoving = true
            local moveX = (dx / distance) * self.moveSpeed * dt
            local moveY = (dy / distance) * self.moveSpeed * dt
            self.x = self.x + moveX
            self.y = self.y + moveY
            
            -- Update facing direction based on movement
            if math.abs(dx) > math.abs(dy) then
                self.direction = dx > 0 and "east" or "west"
            else
                self.direction = dy > 0 and "south" or "north"
            end
        end
    end
    
    return nil
end

function NPC:updatePatrol(dt, playerX, playerY)
    if #self.patrolRoute == 0 then return end
    
    -- Check if player is very close - pause and face them
    local playerDx = playerX - self.x
    local playerDy = playerY - self.y
    local playerDistance = math.sqrt(playerDx * playerDx + playerDy * playerDy)
    
    if playerDistance < 60 then
        -- Player is close, stop and face them
        self.isMoving = false
        self:facePlayer(playerX, playerY)
        return
    end
    
    -- Handle pause at waypoint
    if self.patrolPauseTimer > 0 then
        self.patrolPauseTimer = self.patrolPauseTimer - dt
        self.isMoving = false
        return
    end
    
    -- Get current waypoint
    local waypoint = self.patrolRoute[self.currentWaypoint]
    local dx = waypoint.x - self.x
    local dy = waypoint.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 5 then
        -- Reached waypoint
        self.x = waypoint.x
        self.y = waypoint.y
        self.isMoving = false
        
        -- Pause at waypoint
        self.patrolPauseTimer = self.patrolPauseTime
        
        -- Move to next waypoint
        self.currentWaypoint = self.currentWaypoint + 1
        if self.currentWaypoint > #self.patrolRoute then
            self.currentWaypoint = 1
        end
    else
        -- Move towards waypoint
        self.isMoving = true
        local moveX = (dx / distance) * self.moveSpeed * dt
        local moveY = (dy / distance) * self.moveSpeed * dt
        
        local newX = self.x + moveX
        local newY = self.y + moveY
        local didMove = false
        
        -- Check collision with interactables (if callback is set)
        if self.checkInteractableCollision then
            if not self.checkInteractableCollision(newX, newY) then
                self.x = newX
                self.y = newY
                didMove = true
            elseif not self.checkInteractableCollision(newX, self.y) then
                -- Try X only
                self.x = newX
                didMove = true
            elseif not self.checkInteractableCollision(self.x, newY) then
                -- Try Y only
                self.y = newY
                didMove = true
            end
        else
            -- No collision checking available, just move
            self.x = newX
            self.y = newY
            didMove = true
        end
        
        -- Smart obstacle avoidance - detect if stuck
        if didMove then
            -- Check if actually moved significantly
            local moveDist = math.sqrt((self.x - self.lastPosition.x)^2 + (self.y - self.lastPosition.y)^2)
            if moveDist > 0.5 then
                -- Made progress, reset stuck timer
                self.stuckTimer = 0
                self.lastPosition.x = self.x
                self.lastPosition.y = self.y
            else
                -- Not making progress, increment stuck timer
                self.stuckTimer = self.stuckTimer + dt
            end
        else
            -- Completely blocked, increment stuck timer faster
            self.stuckTimer = self.stuckTimer + dt * 2
        end
        
        -- If stuck for too long, skip to next waypoint
        if self.stuckTimer > self.stuckThreshold then
            self.stuckTimer = 0
            self.currentWaypoint = self.currentWaypoint + 1
            if self.currentWaypoint > #self.patrolRoute then
                self.currentWaypoint = 1
            end
            self.patrolPauseTimer = 0.5 -- Brief pause before continuing
        end
        
        -- Update facing direction based on movement
        if math.abs(dx) > math.abs(dy) then
            self.direction = dx > 0 and "east" or "west"
        else
            self.direction = dy > 0 and "south" or "north"
        end
    end
end

function NPC:facePlayer(playerX, playerY)
    if self.isMoving then return end -- Don't change direction while moving
    
    local dx = playerX - self.x
    local dy = playerY - self.y
    
    -- Only update if player is reasonably close (within interaction range)
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > 200 then return end
    
    -- Determine which axis has larger difference
    if math.abs(dx) > math.abs(dy) then
        -- Horizontal direction dominates
        if dx > 0 then
            self.direction = "east"
        else
            self.direction = "west"
        end
    else
        -- Vertical direction dominates
        if dy > 0 then
            self.direction = "south"
        else
            self.direction = "north"
        end
    end
end

function NPC:isPlayerNear(playerX, playerY, distance)
    distance = distance or 48
    local dx = self.x - playerX
    local dy = self.y - playerY
    return math.sqrt(dx * dx + dy * dy) < distance
end

function NPC:interact(gameState)
    -- Return dialogue based on NPC type
    if self.npcType == "merchant" then
        return self:merchantDialogue(gameState)
    elseif self.npcType == "villager" then
        return self:villagerDialogue(gameState)
    end
    
    return "..."
end

function NPC:villagerDialogue(gameState)
    -- Villager gives hints and comments on the quest
    if gameState.questState == "initial" or gameState.questState == "looking_for_key" then
        -- Before key is found - give hint
        return "I saw something shiny near the trees to the west... Maybe that's what the merchant is looking for?"
    elseif gameState.questState == "has_key" or 
           gameState.questState == "merchant_unlocking" or
           gameState.questState == "merchant_at_door" then
        -- After finding key but before entering house
        return "Oh, you found something! The merchant will be so happy!"
    else
        -- After quest is complete
        return "It's nice to see neighbors helping each other. Thank you for being so kind!"
    end
end

function NPC:merchantDialogue(gameState)
    if gameState.questState == "initial" then
        -- First interaction - check if player already has the key
        if gameState:hasItem("Gold Key") then
            -- Player found key before talking to merchant
            gameState:removeItem("Gold Key") -- Take the key
            gameState.questState = "has_key"
            self:moveToHouse(gameState)
            return "Oh! You found my key! I didn't even realize you were helping me. Thank you so much! Let me unlock the door..."
        else
            -- Normal first interaction - merchant is locked out
            gameState.questState = "looking_for_key"
            return "Oh, hello traveler! I'm locked out of my house and can't find my key. I think I dropped it somewhere around here..."
        end
    elseif gameState.questState == "looking_for_key" then
        -- Check if player found the key but hasn't come back yet
        if gameState:hasItem("Gold Key") then
            gameState:removeItem("Gold Key") -- Take the key
            gameState.questState = "has_key"
            self:moveToHouse(gameState)
            return "Oh! You found my key! Thank you so much! Let me unlock the door..."
        else
            -- Player hasn't found key yet
            return "Have you seen my key? I really need to get back inside..."
        end
    elseif gameState.questState == "has_key" then
        -- Player found the key! Start walking to house
        gameState:removeItem("Gold Key") -- Take the key
        gameState.questState = "merchant_unlocking"
        self:moveToHouse(gameState)
        return "You found my key! Thank you so much! Let me unlock the door..."
    elseif gameState.questState == "merchant_unlocking" or gameState.questState == "merchant_at_door" then
        return "Just a moment, let me unlock this door..."
    elseif gameState.questState == "house_unlocked" then
        return "The door is open now. Please, come inside!"
    elseif gameState.questState == "inside_house" then
        return "Please, take that sword as a reward for helping me. You've been so kind!"
    elseif gameState.questState == "sword_collected" then
        return "That sword has been in my family for generations. Use it well, brave traveler!"
    end
    
    return "Thank you again for your help!"
end

function NPC:moveToHouse(gameState)
    -- Set target to house door position
    self.moveTarget = {x = 55 * 32, y = 19 * 32}
    self.isMoving = true
    
    -- Store gameState for the callback
    self.data.gameState = gameState
    
    -- Set callback for when merchant reaches door
    self.data.onReachTarget = function()
        gameState.questState = "merchant_at_door"
        gameState:unlockHouseDoor()
        
        -- Trigger automatic entry after a short delay
        self.data.autoEnterTimer = 1.5 -- Wait 1.5 seconds then auto-enter
    end
end

function NPC:draw()
    local image = nil
    
    if self.useAnimations then
        -- Use full animations
        local animType = self.isMoving and "walk" or "idle"
        if self.animations[animType][self.direction] and 
           #self.animations[animType][self.direction] > 0 then
            image = self.animations[animType][self.direction][self.currentFrame]
        end
    else
        -- Use static rotations
        image = self.rotations[self.direction]
    end
    
    if image then
        local imageWidth = image:getWidth()
        local imageHeight = image:getHeight()
        
        love.graphics.draw(
            image,
            self.x,
            self.y,
            0,
            self.scale,
            self.scale,
            imageWidth / 2,
            imageHeight / 2
        )
    else
        -- Fallback: draw a simple colored rectangle
        love.graphics.setColor(0.8, 0.6, 0.2)
        love.graphics.rectangle("fill", self.x - 16, self.y - 16, 32, 32)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Debug: draw collision box
    if DEBUG_MODE then
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle("line", self.x - 16, self.y - 16, 32, 32)
        love.graphics.setColor(1, 1, 1)
    end
end

function NPC:checkCollision(x, y, width, height)
    -- AABB collision check
    local npcLeft = self.x - 16
    local npcRight = self.x + 16
    local npcTop = self.y - 16
    local npcBottom = self.y + 16
    
    return x < npcRight and
           x + width > npcLeft and
           y < npcBottom and
           y + height > npcTop
end

return NPC

