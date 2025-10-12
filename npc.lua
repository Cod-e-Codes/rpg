-- NPC System with rotation, collision, and dialogue
local NPC = {}

function NPC:new(x, y, npcType, data)
    local npc = {
        x = x,
        y = y,
        width = 32,
        height = 32,
        npcType = npcType, -- "merchant", etc.
        data = data or {},
        direction = "south", -- Current facing direction (north, south, east, west)
        rotations = {}, -- Loaded rotation images
        scale = 2,
        -- Collision (same as player for consistency)
        isSolid = true,
        -- Quest/state tracking
        questState = data.questState or "initial",
        isMoving = false,
        moveTarget = nil,
        moveSpeed = 80,
        -- Animation
        rotationUpdateTimer = 0,
        rotationUpdateDelay = 0.1 -- Update facing direction periodically
    }
    setmetatable(npc, {__index = self})
    
    -- Load rotation sprites
    npc:loadSprites()
    
    return npc
end

function NPC:loadSprites()
    -- Load 4 directional rotation sprites
    local basePath = string.format("assets/npcs/%s/rotations/", self.npcType)
    local directions = {"north", "south", "east", "west"}
    
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

function NPC:update(dt, playerX, playerY)
    -- Update facing direction to look at player
    self.rotationUpdateTimer = self.rotationUpdateTimer + dt
    if self.rotationUpdateTimer >= self.rotationUpdateDelay then
        self.rotationUpdateTimer = 0
        self:facePlayer(playerX, playerY)
    end
    
    -- Handle auto-enter timer (for quest sequence)
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
    if self.isMoving and self.moveTarget then
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
    -- Return dialogue based on quest state
    if self.npcType == "merchant" then
        return self:merchantDialogue(gameState)
    end
    
    return "..."
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
    if self.rotations[self.direction] then
        local image = self.rotations[self.direction]
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

