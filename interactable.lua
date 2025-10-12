-- Interactable Objects System
local Interactable = {}

function Interactable:new(x, y, width, height, type, data)
    local obj = {
        x = x,
        y = y,
        width = width,
        height = height,
        type = type, -- "chest", "door", "npc", etc.
        data = data or {},
        isOpen = false,
        -- Animation properties
        openProgress = 0, -- 0 = closed, 1 = open
        targetProgress = 0,
        animationSpeed = 6 -- How fast to animate (increased for snappier feel)
    }
    setmetatable(obj, {__index = self})
    return obj
end

function Interactable:isPlayerNear(playerX, playerY, distance)
    -- Doors and caves have larger interaction radius
    if self.type == "door" or self.type == "cave" or self.type == "cave_exit" then
        distance = distance or 64
    else
        distance = distance or 48
    end
    local dx = (self.x + self.width/2) - playerX
    local dy = (self.y + self.height/2) - playerY
    return math.sqrt(dx*dx + dy*dy) < distance
end

function Interactable:update(dt, gameState)
    -- Smooth animation towards target
    if self.openProgress < self.targetProgress then
        self.openProgress = math.min(self.openProgress + self.animationSpeed * dt, self.targetProgress)
    elseif self.openProgress > self.targetProgress then
        self.openProgress = math.max(self.openProgress - self.animationSpeed * dt, self.targetProgress)
    end
    
    -- Handle door transition timer
    if self.doorTransition then
        self.doorTransition.timer = self.doorTransition.timer - dt
        if self.doorTransition.timer <= 0 and gameState then
            gameState:changeMap(self.doorTransition.destination, self.doorTransition.spawnX, self.doorTransition.spawnY)
            local result = "door_transition"
            self.doorTransition = nil
            return result
        end
    end
    
    return nil
end

function Interactable:syncWithGameState(gameState)
    -- Sync chest state on load
    if self.type == "chest" and self.data.id then
        if gameState:isChestOpened(self.data.id) then
            self.isOpen = true
            self.openProgress = 1
            self.targetProgress = 1
        end
    end
end

function Interactable:interact(gameState)
    if self.type == "chest" then
        if not gameState:isChestOpened(self.data.id) then
            gameState:openChest(self.data.id)
            if self.data.item then
                gameState:addItem(self.data.item)
                self.isOpen = true
                self.targetProgress = 1 -- Animate to open
                return string.format("Found: %s!", self.data.item)
            end
            self.isOpen = true
            self.targetProgress = 1 -- Animate to open
            return "Nothing inside..."
        else
            return "Already looted this one."
        end
    elseif self.type == "door" then
        if self.data.destination then
            -- Check if this is the locked house door
            if self.data.isHouseDoor and gameState:isHouseDoorLocked() then
                return "The door is locked. You need a key..."
            end
            
            -- Don't transition immediately - let door animate first
            self.targetProgress = 1
            self.doorTransition = {
                destination = self.data.destination,
                spawnX = self.data.spawnX,
                spawnY = self.data.spawnY,
                timer = 0.1 -- Quick animation
            }
            return nil -- No message yet
        end
    elseif self.type == "sign" then
        return self.data.message or "..."
    elseif self.type == "cave" or self.type == "cave_exit" then
        -- Cave entrance with fade transition
        if self.data.targetMap then
            -- Mark for fade transition (handled by main.lua)
            return {
                type = "fade_transition",
                targetMap = self.data.targetMap,
                spawnX = self.data.spawnX,
                spawnY = self.data.spawnY
            }
        elseif self.data.destination then
            -- Alternative format (same as door)
            return {
                type = "fade_transition",
                targetMap = self.data.destination,
                spawnX = self.data.spawnX,
                spawnY = self.data.spawnY
            }
        end
    end
end

function Interactable:checkTransition(gameState)
    -- Check if door is ready to transition
    if self.doorTransition then
        self.doorTransition.timer = self.doorTransition.timer - (1/60) -- Approximate dt
        if self.doorTransition.timer <= 0 then
            gameState:changeMap(self.doorTransition.destination, self.doorTransition.spawnX, self.doorTransition.spawnY)
            self.doorTransition = nil
            return "door_transition"
        end
    end
    return nil
end

function Interactable:draw()
    -- Draw based on type with toon shading and animations
    if self.type == "chest" then
        -- Chest with smooth open animation
        -- Base (bottom part) - dark
        love.graphics.setColor(0.42, 0.30, 0.18)
        love.graphics.rectangle("fill", self.x, self.y + 8, self.width, self.height - 8)
        
        -- Body shadow (sharp toon shadow)
        love.graphics.setColor(0.32, 0.22, 0.13)
        love.graphics.rectangle("fill", self.x + self.width - 6, self.y + 8, 6, self.height - 8)
        
        -- Base outline (doesn't move)
        love.graphics.setColor(0.18, 0.12, 0.07)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x, self.y + 8, self.width, self.height - 8)
        love.graphics.setLineWidth(1)
        
        -- Inside (visible when opening)
        if self.openProgress > 0 then
            love.graphics.setColor(0.15, 0.10, 0.06)
            local insideHeight = 12 * self.openProgress
            love.graphics.rectangle("fill", self.x + 3, self.y + 12, self.width - 6, insideHeight)
        end
        
        -- Animated lid (rotates based on openProgress)
        love.graphics.push()
        -- Pivot point at back of lid
        love.graphics.translate(self.x + self.width/2, self.y + 10)
        love.graphics.rotate(-self.openProgress * math.pi * 0.4) -- Rotate up to ~72 degrees
        love.graphics.translate(-(self.x + self.width/2), -(self.y + 10))
        
        -- Lid (rounded top) - medium
        love.graphics.setColor(0.52, 0.38, 0.24)
        love.graphics.rectangle("fill", self.x, self.y, self.width, 12)
        love.graphics.rectangle("fill", self.x + 2, self.y - 2, self.width - 4, 8)
        
        -- Toon highlight on lid
        love.graphics.setColor(0.62, 0.48, 0.32)
        love.graphics.rectangle("fill", self.x + 2, self.y + 2, 10, 6)
        
        -- Gold bands (bright toon gold)
        love.graphics.setColor(0.95, 0.85, 0.35)
        love.graphics.rectangle("fill", self.x, self.y + 10, self.width, 3)
        love.graphics.rectangle("fill", self.x + 2, self.y + 4, self.width - 4, 2)
        
        -- Lid outline (follows the rotation)
        love.graphics.setColor(0.18, 0.12, 0.07)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x, self.y, self.width, 12)
        love.graphics.setLineWidth(1)
        
        love.graphics.pop()
        
        -- Lock (only visible when closed)
        if self.openProgress < 0.5 then
            local lockAlpha = 1 - (self.openProgress * 2)
            -- Lock plate (toon metal)
            love.graphics.setColor(0.75, 0.70, 0.45, lockAlpha)
            love.graphics.rectangle("fill", self.x + self.width/2 - 4, self.y + 12, 8, 10)
            
            -- Lock highlight
            love.graphics.setColor(0.85, 0.80, 0.55, lockAlpha)
            love.graphics.rectangle("fill", self.x + self.width/2 - 3, self.y + 13, 3, 3)
            
            -- Keyhole (dark)
            love.graphics.setColor(0.15, 0.10, 0.06, lockAlpha)
            love.graphics.rectangle("fill", self.x + self.width/2 - 2, self.y + 15, 4, 4)
            love.graphics.rectangle("fill", self.x + self.width/2 - 1, self.y + 19, 2, 3)
        end
        
    elseif self.type == "door" then
        -- Wooden door with perspective swing animation
        local doorAlpha = 1 - (self.openProgress * 0.5) -- Fade slightly when opening
        local perspectiveScale = 1 - self.openProgress * 0.9 -- Narrow in perspective
        
        -- Door frame (always visible, doesn't move)
        love.graphics.setColor(0.55, 0.48, 0.35)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
        love.graphics.setLineWidth(1)
        
        if perspectiveScale > 0.05 then -- Only draw if visible
            love.graphics.push()
            -- Pivot at left edge, create perspective
            love.graphics.translate(self.x, self.y + self.height/2)
            love.graphics.scale(perspectiveScale, 1) -- Horizontal squash for perspective
            love.graphics.translate(-self.x, -(self.y + self.height/2))
            
            -- Main door body - dark wood
            love.graphics.setColor(0.38, 0.26, 0.16, doorAlpha)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
            
            -- Wood planks (vertical) - medium
            love.graphics.setColor(0.46, 0.32, 0.20, doorAlpha)
            for i = 0, 2 do
                love.graphics.rectangle("fill", self.x + 2 + i * 10, self.y, 8, self.height)
            end
            
            -- Toon highlights on planks
            love.graphics.setColor(0.56, 0.40, 0.26, doorAlpha)
            for i = 0, 2 do
                love.graphics.rectangle("fill", self.x + 3 + i * 10, self.y + 4, 3, self.height - 8)
            end
            
            -- Cross beams (dark)
            love.graphics.setColor(0.28, 0.18, 0.10, doorAlpha)
            love.graphics.rectangle("fill", self.x, self.y + self.height * 0.3, self.width, 5)
            love.graphics.rectangle("fill", self.x, self.y + self.height * 0.7, self.width, 5)
            
            -- Door handle/ring (iron with toon shading)
            love.graphics.setColor(0.35, 0.35, 0.40, doorAlpha)
            love.graphics.circle("fill", self.x + self.width - 8, self.y + self.height/2, 5)
            love.graphics.setColor(0.20, 0.20, 0.25, doorAlpha)
            love.graphics.circle("fill", self.x + self.width - 8, self.y + self.height/2, 3)
            
            -- Highlight on handle
            love.graphics.setColor(0.50, 0.50, 0.55, doorAlpha)
            love.graphics.circle("fill", self.x + self.width - 9, self.y + self.height/2 - 1, 2)
            
            -- Metal studs (toon style)
            love.graphics.setColor(0.40, 0.40, 0.45, doorAlpha)
            for i = 0, 1 do
                for j = 0, 3 do
                    love.graphics.circle("fill", self.x + 6 + i * 20, self.y + 10 + j * 12, 2)
                end
            end
            
            -- Toon outline (follows the door)
            love.graphics.setColor(0.15, 0.10, 0.06, doorAlpha)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
            love.graphics.setLineWidth(1)
            
            love.graphics.pop()
        end
        
    elseif self.type == "sign" then
        -- Wooden sign post with toon shading
        -- Sign board (horizontal) - medium tone (draw first)
        love.graphics.setColor(0.52, 0.38, 0.24)
        love.graphics.rectangle("fill", self.x, self.y, 32, 16)
        
        -- Sign highlight (toon style)
        love.graphics.setColor(0.62, 0.48, 0.32)
        love.graphics.rectangle("fill", self.x + 2, self.y + 2, 12, 6)
        
        -- Wood grain lines (darker)
        love.graphics.setColor(0.38, 0.26, 0.16)
        for i = 0, 2 do
            love.graphics.rectangle("fill", self.x + 2, self.y + 4 + i * 4, 28, 2)
        end
        
        -- Nails (toon metal)
        love.graphics.setColor(0.35, 0.35, 0.40)
        love.graphics.circle("fill", self.x + 4, self.y + 4, 2)
        love.graphics.circle("fill", self.x + 28, self.y + 4, 2)
        love.graphics.circle("fill", self.x + 4, self.y + 12, 2)
        love.graphics.circle("fill", self.x + 28, self.y + 12, 2)
        
        -- Nail highlights
        love.graphics.setColor(0.50, 0.50, 0.55)
        love.graphics.circle("fill", self.x + 3, self.y + 3, 1)
        love.graphics.circle("fill", self.x + 27, self.y + 3, 1)
        
        -- Sign board outline
        love.graphics.setColor(0.20, 0.14, 0.08)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x, self.y, 32, 16)
        love.graphics.setLineWidth(1)
        
        -- Post (vertical) with toon shading (draw after board)
        love.graphics.setColor(0.42, 0.30, 0.18)
        love.graphics.rectangle("fill", self.x + 12, self.y + 8, 8, 24)
        
        -- Post highlight
        love.graphics.setColor(0.52, 0.38, 0.24)
        love.graphics.rectangle("fill", self.x + 12, self.y + 8, 3, 24)
        
        -- Post outline (separate from board)
        love.graphics.setColor(0.20, 0.14, 0.08)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x + 12, self.y + 16, 8, 16)  -- Only bottom part of post
        love.graphics.setLineWidth(1)
        
    elseif self.type == "cave" or self.type == "cave_exit" then
        -- Cave entrance - toon-shaded with irregular rocky shape
        local centerX = self.x + self.width/2
        local centerY = self.y + self.height/2
        local baseRadius = self.width * 0.45
        
        -- Create irregular rock shape with noise
        local rockPoints = {}
        local segments = 12
        for i = 0, segments do
            local angle = (i / segments) * math.pi * 2
            -- Add noise to radius for irregular shape
            local noiseOffset = math.sin(angle * 3) * 6 + math.cos(angle * 5) * 4
            local r = baseRadius + noiseOffset
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r * 0.9 -- Slightly oval
            table.insert(rockPoints, px)
            table.insert(rockPoints, py)
        end
        
        -- Main rock body (medium brown) - toon base
        love.graphics.setColor(0.42, 0.32, 0.22)
        love.graphics.polygon("fill", rockPoints)
        
        -- Rock texture patches (darker brown)
        love.graphics.setColor(0.32, 0.24, 0.16)
        for i = 0, 4 do
            local angle = (i / 5) * math.pi * 2 + 0.3
            local r = baseRadius * 0.6
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r * 0.9
            love.graphics.circle("fill", px, py, baseRadius * 0.25)
        end
        
        -- Toon highlights (lighter brown)
        love.graphics.setColor(0.52, 0.42, 0.32)
        for i = 0, 3 do
            local angle = (i / 4) * math.pi * 2 + 1.2
            local r = baseRadius * 0.7
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r * 0.9
            love.graphics.circle("fill", px, py, baseRadius * 0.15)
        end
        
        -- Cave opening (irregular oval with noise)
        local openingPoints = {}
        local openingSegments = 10
        local openingRadiusX = baseRadius * 0.4
        local openingRadiusY = baseRadius * 0.5
        for i = 0, openingSegments do
            local angle = (i / openingSegments) * math.pi * 2
            -- Add noise to opening edge
            local noise = math.sin(angle * 4) * 2 + math.cos(angle * 6) * 1.5
            local rx = (openingRadiusX + noise)
            local ry = (openingRadiusY + noise)
            local px = centerX + math.cos(angle) * rx
            local py = centerY + math.sin(angle) * ry
            table.insert(openingPoints, px)
            table.insert(openingPoints, py)
        end
        
        -- Black opening
        love.graphics.setColor(0.02, 0.02, 0.02)
        love.graphics.polygon("fill", openingPoints)
        
        -- Inner shadow (even darker)
        love.graphics.setColor(0, 0, 0)
        local innerPoints = {}
        for i = 0, openingSegments do
            local angle = (i / openingSegments) * math.pi * 2
            local noise = math.sin(angle * 4) * 1.5
            local rx = (openingRadiusX * 0.7 + noise)
            local ry = (openingRadiusY * 0.7 + noise)
            local px = centerX + math.cos(angle) * rx
            local py = centerY + 2 + math.sin(angle) * ry
            table.insert(innerPoints, px)
            table.insert(innerPoints, py)
        end
        love.graphics.polygon("fill", innerPoints)
        
        -- Toon outline (dark brown, follows irregular shape)
        love.graphics.setColor(0.18, 0.12, 0.08)
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", rockPoints)
        
        -- Opening outline (darker)
        love.graphics.setColor(0.08, 0.05, 0.03)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", openingPoints)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.setColor(1, 1, 1)
end

return Interactable

