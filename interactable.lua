-- Interactable Objects System
local Interactable = {}

function Interactable:new(x, y, width, height, type, data)
    local obj = {
        x = x,
        y = y,
        width = width,
        height = height,
        type = type, -- "chest", "door", "npc", "scroll", "cave_exit", "portal", etc.
        data = data or {},
        isOpen = false,
        -- Animation properties
        openProgress = 0, -- 0 = closed, 1 = open
        targetProgress = 0,
        animationSpeed = 6, -- How fast to animate (increased for snappier feel)
        -- Particle emitter (for glowing objects like scrolls and portals)
        particleEmitter = nil,
        -- Light source reference (for glowing objects)
        lightSource = nil,
        -- Portal animation
        swirlTime = 0
    }
    setmetatable(obj, {__index = self})
    return obj
end

function Interactable:isPlayerNear(playerX, playerY, distance)
    -- Ancient path needs extra large radius due to vertical positioning
    if self.type == "ancient_path" then
        distance = distance or 128
    -- Doors, caves, portals, scrolls, class icons have larger interaction radius
    elseif self.type == "door" or self.type == "cave" or self.type == "cave_exit" or self.type == "portal" or self.type == "scroll" or self.type == "class_icon" then
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
    
    -- Update portal swirl animation
    if self.type == "portal" then
        self.swirlTime = self.swirlTime + dt
    end
    
    -- Update class icon animation
    if self.type == "class_icon" then
        self.swirlTime = self.swirlTime + dt
    end
    
    -- Update strategy icon animation
    if self.type == "strategy_icon" then
        self.swirlTime = self.swirlTime + dt
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
    if self.type == "scroll" then
        -- Learn spell from scroll
        if self.data.spell and not gameState:hasSpell(self.data.spell) then
            gameState:learnSpell(self.data.spell)
            self.isOpen = true -- Mark as used
            
            -- Disable particle emitter
            if self.particleEmitter then
                self.particleEmitter:setActive(false)
            end
            
            -- Return spell learned message with tutorial
            return {
                type = "spell_learned",
                spell = self.data.spell,
                message = string.format("You learned %s!\n\nPress B to open spell menu, then equip it to a slot.\nPress 1-5 to cast equipped spells.", self.data.spell)
            }
        else
            return "The scroll's magic has faded..."
        end
    elseif self.type == "chest" then
        if not gameState:isChestOpened(self.data.id) then
            gameState:openChest(self.data.id)
            self.isOpen = true
            self.targetProgress = 1 -- Animate to open
            
            -- Check if this chest triggers skeleton spawn
            if self.data.triggersSkeletons then
                return {
                    type = "trigger_skeletons",
                    message = self.data.item and string.format("Found: %s!", self.data.item) or "The chest opens..."
                }
            end
            
            if self.data.item then
                gameState:addItem(self.data.item)
                return string.format("Found: %s!", self.data.item)
            end
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
    elseif self.type == "class_icon" then
        -- Class selection
        if gameState.playerClass then
            return "You are already a " .. gameState.playerClass
        else
            -- Return class icon info to trigger UI
            return {
                type = "class_icon_interact",
                className = self.data.className,
                element = self.data.element,
                description = self.data.description
            }
        end
    elseif self.type == "strategy_icon" then
        -- Healing strategy selection
        if gameState.healingStrategy then
            return "You have already chosen your path: " .. gameState.healingStrategy
        else
            -- Return strategy icon info to trigger UI
            return {
                type = "strategy_icon_interact",
                strategyName = self.data.strategyName,
                strategy = self.data.strategy,
                description = self.data.description
            }
        end
    elseif self.type == "portal" then
        -- Portal transition (with fade like caves for magical effect)
        if self.data.destination then
            return {
                type = "fade_transition",
                targetMap = self.data.destination,
                spawnX = self.data.spawnX,
                spawnY = self.data.spawnY
            }
        end
    elseif self.type == "ancient_path" then
        -- Ancient path entrance with fade transition
        if self.data.targetMap then
            return {
                type = "fade_transition",
                targetMap = self.data.targetMap,
                spawnX = self.data.spawnX,
                spawnY = self.data.spawnY
            }
        end
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

function Interactable:draw(layer)
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
        
        -- Draw directional arrow if specified
        if self.data.arrow then
            love.graphics.setColor(0.2, 0.15, 0.1)
            if self.data.arrow == "left" then
                -- Left arrow
                love.graphics.polygon("fill", 
                    self.x + 6, self.y + 8,
                    self.x + 12, self.y + 4,
                    self.x + 12, self.y + 12
                )
            elseif self.data.arrow == "right" then
                -- Right arrow
                love.graphics.polygon("fill", 
                    self.x + 26, self.y + 8,
                    self.x + 20, self.y + 4,
                    self.x + 20, self.y + 12
                )
            end
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
        -- Large cave entrance/exit with two staggered boulders
        -- Player walks behind front boulder to access partially hidden entrance
        
        -- Use position to create unique noise seed for each entrance
        local noiseSeed = self.x * 0.1 + self.y * 0.1
        
        local function drawBoulder(centerX, centerY, radius, seed)
            -- Create irregular boulder shape with noise
            local rockPoints = {}
            local segments = 14
            for i = 0, segments do
                local angle = (i / segments) * math.pi * 2
                -- Add noise to radius for irregular shape (unique per boulder)
                local noiseOffset = math.sin(angle * 3 + seed) * 8 + math.cos(angle * 5 + seed * 1.3) * 6
                local r = radius + noiseOffset
                local px = centerX + math.cos(angle) * r
                local py = centerY + math.sin(angle) * r * 0.85 -- Slightly oval
                table.insert(rockPoints, px)
                table.insert(rockPoints, py)
            end
            
            -- Main rock body (earth tone brown) - toon base
            love.graphics.setColor(0.42, 0.32, 0.22)
            love.graphics.polygon("fill", rockPoints)
            
            -- Rock texture patches (darker brown) - unique placement
            love.graphics.setColor(0.32, 0.24, 0.16)
            for i = 0, 6 do
                local angle = (i / 7) * math.pi * 2 + 0.3 + seed * 0.5
                local r = radius * 0.55
                local px = centerX + math.cos(angle) * r
                local py = centerY + math.sin(angle) * r * 0.85
                love.graphics.circle("fill", px, py, radius * 0.22)
            end
            
            -- Toon highlights (lighter brown) - unique placement
            love.graphics.setColor(0.52, 0.42, 0.32)
            for i = 0, 4 do
                local angle = (i / 5) * math.pi * 2 + 1.2 + seed * 0.7
                local r = radius * 0.65
                local px = centerX + math.cos(angle) * r
                local py = centerY + math.sin(angle) * r * 0.85
                love.graphics.circle("fill", px, py, radius * 0.14)
            end
            
            -- Toon outline (dark brown, follows irregular shape)
            love.graphics.setColor(0.18, 0.12, 0.08)
            love.graphics.setLineWidth(4)
            love.graphics.polygon("line", rockPoints)
            love.graphics.setLineWidth(1)
        end
        
        -- Draw based on layer (for proper Y-sorting with player)
        if not layer or layer == "back_boulder" then
            -- Back boulder (upper left, furthest back) - player walks IN FRONT of this
            local backBoulderX = self.x + 45
            local backBoulderY = self.y + 50
            local backBoulderRadius = 55
            drawBoulder(backBoulderX, backBoulderY, backBoulderRadius, noiseSeed)
        end
            
        if not layer or layer == "opening" then
            -- Cave opening (middle layer) - player walks IN FRONT of this
            local openingX = self.x + 60
            local openingY = self.y + 90
            local openingRadiusX = 38
            local openingRadiusY = 48
            
            local openingPoints = {}
            local openingSegments = 12
            for i = 0, openingSegments do
                local angle = (i / openingSegments) * math.pi * 2
                -- Add noise to opening edge
                local noise = math.sin(angle * 4) * 3 + math.cos(angle * 6) * 2
                local rx = (openingRadiusX + noise)
                local ry = (openingRadiusY + noise)
                local px = openingX + math.cos(angle) * rx
                local py = openingY + math.sin(angle) * ry
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
                local noise = math.sin(angle * 4) * 2
                local rx = (openingRadiusX * 0.7 + noise)
                local ry = (openingRadiusY * 0.7 + noise)
                local px = openingX + math.cos(angle) * rx
                local py = openingY + 3 + math.sin(angle) * ry
                table.insert(innerPoints, px)
                table.insert(innerPoints, py)
            end
            love.graphics.polygon("fill", innerPoints)
            
            -- Opening outline (darker)
            love.graphics.setColor(0.08, 0.05, 0.03)
            love.graphics.setLineWidth(3)
            love.graphics.polygon("line", openingPoints)
            love.graphics.setLineWidth(1)
        end
        
        if not layer or layer == "front_boulder" then
            -- Front boulder (lower right, closest to camera) - player walks BEHIND this
            local frontBoulderX = self.x + 85
            local frontBoulderY = self.y + 135
            local frontBoulderRadius = 60
            drawBoulder(frontBoulderX, frontBoulderY, frontBoulderRadius, noiseSeed + 1.7) -- Different seed for variation
        end
        
    elseif self.type == "scroll" then
        -- Magical glowing scroll
        local centerX = self.x + self.width/2
        local centerY = self.y + self.height/2
        
        -- Don't draw if already collected
        if self.isOpen then
            return
        end
        
        -- Floating animation
        local floatOffset = math.sin(love.timer.getTime() * 2) * 4
        local scrollY = centerY + floatOffset
        
        -- Glow effect (pulsing)
        local glowPulse = 0.7 + math.sin(love.timer.getTime() * 3) * 0.3
        for i = 3, 1, -1 do
            local alpha = 0.2 * i * glowPulse
            love.graphics.setColor(0.95, 0.85, 0.4, alpha)
            love.graphics.circle("fill", centerX, scrollY, 20 + i * 4)
        end
        
        -- Scroll parchment (rolled up)
        love.graphics.setColor(0.95, 0.90, 0.75)
        love.graphics.rectangle("fill", centerX - 12, scrollY - 16, 24, 32, 2, 2)
        
        -- Parchment texture (horizontal lines)
        love.graphics.setColor(0.85, 0.80, 0.65, 0.3)
        for i = 0, 3 do
            love.graphics.rectangle("fill", centerX - 10, scrollY - 12 + i * 8, 20, 2)
        end
        
        -- Scroll ends (darker rolls)
        love.graphics.setColor(0.75, 0.70, 0.55)
        love.graphics.rectangle("fill", centerX - 14, scrollY - 18, 4, 36, 1, 1)
        love.graphics.rectangle("fill", centerX + 10, scrollY - 18, 4, 36, 1, 1)
        
        -- Magical runes (glowing symbols)
        love.graphics.setColor(0.9, 0.75, 0.3, 0.8 + math.sin(love.timer.getTime() * 4) * 0.2)
        -- Draw simple rune symbols
        love.graphics.circle("fill", centerX - 4, scrollY - 6, 2)
        love.graphics.circle("fill", centerX + 4, scrollY - 6, 2)
        love.graphics.circle("fill", centerX, scrollY + 2, 2)
        love.graphics.rectangle("fill", centerX - 1, scrollY - 2, 2, 8)
        
        -- Outline
        love.graphics.setColor(0.3, 0.25, 0.15)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", centerX - 12, scrollY - 16, 24, 32, 2, 2)
        love.graphics.setLineWidth(1)
        
        -- Light rays (toon style)
        love.graphics.setColor(0.95, 0.85, 0.4, 0.4 * glowPulse)
        love.graphics.setLineWidth(2)
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2 + love.timer.getTime()
            local x1 = centerX + math.cos(angle) * 15
            local y1 = scrollY + math.sin(angle) * 15
            local x2 = centerX + math.cos(angle) * 25
            local y2 = scrollY + math.sin(angle) * 25
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(1)
        
    elseif self.type == "portal" then
        -- Swirling magical portal with toon shading and noise distortion
        local centerX = self.x + self.width/2
        local centerY = self.y + self.height/2
        local baseRadius = math.min(self.width, self.height) * 0.45
        
        -- Portal frame - stone ring with noise distortion
        local framePoints = {}
        local frameSegments = 16
        for i = 0, frameSegments do
            local angle = (i / frameSegments) * math.pi * 2
            -- Add noise using self position as seed for uniqueness
            local noiseSeed = self.x * 0.1 + self.y * 0.1
            local noiseOffset = math.sin(angle * 4 + noiseSeed) * 4 + math.cos(angle * 6 + noiseSeed) * 3
            local r = (baseRadius + 12) + noiseOffset
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r
            table.insert(framePoints, px)
            table.insert(framePoints, py)
        end
        
        -- Draw stone frame (earth-tone like cave boulders)
        love.graphics.setColor(0.35, 0.28, 0.20)
        love.graphics.polygon("fill", framePoints)
        
        -- Frame highlights (lighter patches)
        love.graphics.setColor(0.45, 0.38, 0.30)
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2 + self.swirlTime * 0.1
            local r = baseRadius + 12
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r
            love.graphics.circle("fill", px, py, 6)
        end
        
        -- Frame outline (thick toon outline)
        love.graphics.setColor(0.15, 0.10, 0.08)
        love.graphics.setLineWidth(4)
        love.graphics.polygon("line", framePoints)
        love.graphics.setLineWidth(1)
        
        -- Portal inner energy - multiple swirling layers
        -- Layer 1: Outer swirl (purple/blue)
        for layer = 3, 1, -1 do
            local layerRadius = baseRadius * (0.3 + layer * 0.23)
            local layerSegments = 12
            local spiralPoints = {}
            
            for i = 0, layerSegments do
                local t = i / layerSegments
                local angle = t * math.pi * 2 + self.swirlTime * (1 + layer * 0.3)
                
                -- Create spiral with noise distortion
                local spiralOffset = math.sin(angle * 3 + self.swirlTime * 2) * (layerRadius * 0.15)
                local noiseOffset = math.sin(t * 8 + self.swirlTime * 1.5) * 5
                local r = layerRadius + spiralOffset + noiseOffset
                
                local px = centerX + math.cos(angle) * r
                local py = centerY + math.sin(angle) * r
                table.insert(spiralPoints, px)
                table.insert(spiralPoints, py)
            end
            
            -- Color gradient based on layer (purple to blue to cyan)
            if layer == 3 then
                love.graphics.setColor(0.3, 0.15, 0.5, 0.7) -- Deep purple
            elseif layer == 2 then
                love.graphics.setColor(0.4, 0.25, 0.7, 0.8) -- Purple-blue
            else
                love.graphics.setColor(0.5, 0.4, 0.9, 0.9) -- Bright blue
            end
            love.graphics.polygon("fill", spiralPoints)
        end
        
        -- Center vortex with bright glow
        local vortexSegments = 10
        local vortexRadius = baseRadius * 0.25
        local vortexPoints = {}
        
        for i = 0, vortexSegments do
            local angle = (i / vortexSegments) * math.pi * 2 + self.swirlTime * 3
            -- Pulsing noise
            local pulse = 1 + math.sin(self.swirlTime * 4) * 0.2
            local noiseOffset = math.sin(angle * 5 + self.swirlTime * 3) * 3
            local r = (vortexRadius * pulse) + noiseOffset
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r
            table.insert(vortexPoints, px)
            table.insert(vortexPoints, py)
        end
        
        -- Bright cyan-white center
        love.graphics.setColor(0.7, 0.85, 1.0, 0.95)
        love.graphics.polygon("fill", vortexPoints)
        
        -- Inner glow ring
        love.graphics.setColor(0.9, 0.95, 1.0, 0.8)
        love.graphics.circle("fill", centerX, centerY, vortexRadius * 0.5)
        
        -- Swirling energy tendrils
        love.graphics.setLineWidth(2)
        for i = 0, 4 do
            local angle = (i / 5) * math.pi * 2 + self.swirlTime * 2
            local tendrilPoints = {}
            
            for j = 0, 8 do
                local t = j / 8
                local r = baseRadius * (0.2 + t * 0.6)
                local spiralAngle = angle + t * math.pi * 1.5 + self.swirlTime
                local wobble = math.sin(t * 6 + self.swirlTime * 3) * (baseRadius * 0.1)
                
                local px = centerX + math.cos(spiralAngle) * (r + wobble)
                local py = centerY + math.sin(spiralAngle) * (r + wobble)
                table.insert(tendrilPoints, px)
                table.insert(tendrilPoints, py)
            end
            
            -- Draw tendril with color fade
            local alpha = 0.6 + math.sin(self.swirlTime * 2 + i) * 0.2
            love.graphics.setColor(0.6, 0.5, 0.9, alpha)
            
            for j = 1, #tendrilPoints - 2, 2 do
                love.graphics.line(tendrilPoints[j], tendrilPoints[j+1], tendrilPoints[j+2], tendrilPoints[j+3])
            end
        end
        love.graphics.setLineWidth(1)
        
        -- Outer portal edge glow
        love.graphics.setColor(0.5, 0.4, 0.8, 0.4)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", centerX, centerY, baseRadius)
        love.graphics.setLineWidth(1)
        
    elseif self.type == "class_icon" then
        -- Animated glowing elemental class icon
        local centerX = self.x + self.width/2
        local centerY = self.y + self.height/2
        local baseRadius = math.min(self.width, self.height) * 0.4
        
        -- Element-specific colors
        local color1, color2, color3
        if self.data.element == "fire" then
            color1 = {1.0, 0.3, 0.0}
            color2 = {1.0, 0.6, 0.1}
            color3 = {1.0, 0.9, 0.3}
        elseif self.data.element == "ice" then
            color1 = {0.2, 0.6, 1.0}
            color2 = {0.5, 0.8, 1.0}
            color3 = {0.8, 0.95, 1.0}
        elseif self.data.element == "lightning" then
            color1 = {0.5, 0.3, 1.0}
            color2 = {0.7, 0.6, 1.0}
            color3 = {0.9, 0.9, 1.0}
        elseif self.data.element == "earth" then
            color1 = {0.5, 0.35, 0.2}
            color2 = {0.7, 0.55, 0.35}
            color3 = {0.9, 0.75, 0.5}
        end
        
        -- Pulsing glow effect
        local pulse = 0.8 + math.sin(self.swirlTime * 3) * 0.2
        
        -- Outer glow (largest)
        love.graphics.setColor(color1[1], color1[2], color1[3], 0.3 * pulse)
        love.graphics.circle("fill", centerX, centerY, baseRadius * 1.3)
        
        -- Middle glow
        love.graphics.setColor(color2[1], color2[2], color2[3], 0.6 * pulse)
        love.graphics.circle("fill", centerX, centerY, baseRadius)
        
        -- Inner core (brightest)
        love.graphics.setColor(color3[1], color3[2], color3[3], 0.9 * pulse)
        love.graphics.circle("fill", centerX, centerY, baseRadius * 0.6)
        
        -- Rotating particles around the icon
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2 + self.swirlTime * 2
            local r = baseRadius * 1.5
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r
            local particleSize = 3 + math.sin(self.swirlTime * 4 + i) * 2
            
            love.graphics.setColor(color3[1], color3[2], color3[3], 0.8)
            love.graphics.circle("fill", px, py, particleSize)
        end
        
        -- Element symbol in center (simple shape)
        love.graphics.setColor(1, 1, 1, 0.9)
        if self.data.element == "fire" then
            -- Flame shape (more realistic)
            love.graphics.setLineWidth(1)
            -- Main flame body
            love.graphics.polygon("fill",
                centerX, centerY - 18,
                centerX - 8, centerY - 5,
                centerX - 6, centerY + 8,
                centerX, centerY + 12,
                centerX + 6, centerY + 8,
                centerX + 8, centerY - 5
            )
            -- Inner flame highlight
            love.graphics.setColor(1, 1, 0.8, 0.8)
            love.graphics.polygon("fill",
                centerX, centerY - 12,
                centerX - 4, centerY,
                centerX, centerY + 6,
                centerX + 4, centerY
            )
        elseif self.data.element == "ice" then
            -- Snowflake/crystal
            love.graphics.setLineWidth(3)
            love.graphics.line(centerX, centerY - 12, centerX, centerY + 12)
            love.graphics.line(centerX - 12, centerY, centerX + 12, centerY)
            love.graphics.line(centerX - 8, centerY - 8, centerX + 8, centerY + 8)
            love.graphics.line(centerX - 8, centerY + 8, centerX + 8, centerY - 8)
            love.graphics.setLineWidth(1)
        elseif self.data.element == "lightning" then
            -- Lightning bolt
            love.graphics.polygon("fill",
                centerX + 2, centerY - 15,
                centerX - 8, centerY,
                centerX + 2, centerY,
                centerX - 2, centerY + 15,
                centerX + 8, centerY - 2,
                centerX - 2, centerY - 2
            )
        elseif self.data.element == "earth" then
            -- Rock/crystal formation
            love.graphics.polygon("fill",
                centerX, centerY - 12,
                centerX + 10, centerY - 4,
                centerX + 8, centerY + 10,
                centerX - 8, centerY + 10,
                centerX - 10, centerY - 4
            )
            -- Inner facet
            love.graphics.setColor(0.7, 0.6, 0.4, 0.6)
            love.graphics.polygon("fill",
                centerX, centerY - 8,
                centerX + 6, centerY,
                centerX, centerY + 6,
                centerX - 6, centerY
            )
        end
        
        -- Class name label below icon
        love.graphics.setColor(1, 1, 1, 0.9)
        local font = love.graphics.getFont()
        local labelText = self.data.className
        local textWidth = font:getWidth(labelText)
        
        -- Semi-transparent background for label
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", centerX - textWidth/2 - 4, centerY + baseRadius * 1.6 - 2, textWidth + 8, font:getHeight() + 4, 3, 3)
        
        -- Label text
        love.graphics.setColor(color3[1], color3[2], color3[3], 1)
        love.graphics.print(labelText, centerX - textWidth/2, centerY + baseRadius * 1.6)
        
    elseif self.type == "strategy_icon" then
        -- Animated glowing strategy icon (similar to class icons but different symbols)
        local centerX = self.x + self.width/2
        local centerY = self.y + self.height/2
        local baseRadius = math.min(self.width, self.height) * 0.4
        
        -- Strategy-specific colors
        local color1, color2, color3
        if self.data.strategy == "armor" then
            color1 = {0.5, 0.5, 0.55}
            color2 = {0.7, 0.7, 0.75}
            color3 = {0.9, 0.9, 0.95}
        elseif self.data.strategy == "drain" then
            color1 = {0.6, 0.2, 0.8}
            color2 = {0.7, 0.4, 0.9}
            color3 = {0.85, 0.6, 1.0}
        elseif self.data.strategy == "necromancer" then
            color1 = {0.2, 0.8, 0.3}
            color2 = {0.4, 0.9, 0.5}
            color3 = {0.6, 1.0, 0.7}
        end
        
        -- Pulsing glow effect
        local pulse = 0.8 + math.sin(self.swirlTime * 3) * 0.2
        
        -- Outer glow (largest)
        love.graphics.setColor(color1[1], color1[2], color1[3], 0.3 * pulse)
        love.graphics.circle("fill", centerX, centerY, baseRadius * 1.3)
        
        -- Middle glow
        love.graphics.setColor(color2[1], color2[2], color2[3], 0.6 * pulse)
        love.graphics.circle("fill", centerX, centerY, baseRadius)
        
        -- Inner core (brightest)
        love.graphics.setColor(color3[1], color3[2], color3[3], 0.9 * pulse)
        love.graphics.circle("fill", centerX, centerY, baseRadius * 0.6)
        
        -- Rotating particles around the icon
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2 + self.swirlTime * 2
            local r = baseRadius * 1.5
            local px = centerX + math.cos(angle) * r
            local py = centerY + math.sin(angle) * r
            local particleSize = 3 + math.sin(self.swirlTime * 4 + i) * 2
            
            love.graphics.setColor(color3[1], color3[2], color3[3], 0.8)
            love.graphics.circle("fill", px, py, particleSize)
        end
        
        -- Strategy symbol in center
        love.graphics.setColor(1, 1, 1, 0.9)
        if self.data.strategy == "armor" then
            -- Shield symbol
            local points = {
                centerX, centerY - baseRadius*0.35,
                centerX + baseRadius*0.3, centerY - baseRadius*0.1,
                centerX + baseRadius*0.3, centerY + baseRadius*0.2,
                centerX, centerY + baseRadius*0.4,
                centerX - baseRadius*0.3, centerY + baseRadius*0.2,
                centerX - baseRadius*0.3, centerY - baseRadius*0.1
            }
            love.graphics.polygon("fill", points)
        elseif self.data.strategy == "drain" then
            -- Spiral/vortex symbol
            love.graphics.setLineWidth(3)
            local lastX, lastY
            for i = 0, 15 do
                local t = i / 15
                local angle = t * math.pi * 3
                local r = t * baseRadius * 0.4
                local x1 = centerX + math.cos(angle) * r
                local y1 = centerY + math.sin(angle) * r
                if i > 0 then
                    love.graphics.line(lastX, lastY, x1, y1)
                end
                lastX, lastY = x1, y1
            end
            love.graphics.setLineWidth(1)
        elseif self.data.strategy == "necromancer" then
            -- Skull symbol
            love.graphics.circle("fill", centerX, centerY - baseRadius*0.1, baseRadius * 0.25)
            love.graphics.rectangle("fill", centerX - baseRadius*0.15, centerY + baseRadius*0.05, baseRadius*0.3, baseRadius*0.15)
            -- Eyes
            love.graphics.setColor(0.1, 0.3, 0.15)
            love.graphics.circle("fill", centerX - baseRadius*0.08, centerY - baseRadius*0.12, baseRadius * 0.05)
            love.graphics.circle("fill", centerX + baseRadius*0.08, centerY - baseRadius*0.12, baseRadius * 0.05)
        end
        
        -- Strategy name label below icon
        love.graphics.setColor(1, 1, 1, 0.9)
        local font = love.graphics.getFont()
        local labelText = self.data.strategyName
        local textWidth = font:getWidth(labelText)
        
        -- Semi-transparent background for label
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", centerX - textWidth/2 - 4, centerY + baseRadius * 1.6 - 2, textWidth + 8, font:getHeight() + 4, 3, 3)
        
        -- Label text
        love.graphics.setColor(color3[1], color3[2], color3[3], 1)
        love.graphics.print(labelText, centerX - textWidth/2, centerY + baseRadius * 1.6)
        
    elseif self.type == "ancient_path" then
        -- Ancient stone archway breaking through northern wall
        -- Creates a magical gateway with stone pillars and glowing runes
        
        local centerX = self.x + self.width/2
        local archWidth = self.width * 0.8
        local archHeight = self.height * 0.9
        local archX = centerX - archWidth/2
        local archY = self.y + self.height - archHeight
        
        -- Stone pillars (left and right)
        local pillarWidth = archWidth * 0.2
        local pillarHeight = archHeight * 0.8
        
        for side = 0, 1 do
            local pillarX = side == 0 and archX or (archX + archWidth - pillarWidth)
            
            -- Pillar body (earth tones)
            love.graphics.setColor(0.4, 0.35, 0.25)
            love.graphics.rectangle("fill", pillarX, archY + archHeight - pillarHeight, pillarWidth, pillarHeight)
            
            -- Stone blocks/segments
            love.graphics.setColor(0.3, 0.25, 0.18)
            for i = 0, 4 do
                love.graphics.rectangle("fill", pillarX, archY + archHeight - pillarHeight + i * (pillarHeight/5), pillarWidth, 3)
            end
            
            -- Highlights
            love.graphics.setColor(0.5, 0.45, 0.35)
            love.graphics.rectangle("fill", pillarX + 2, archY + archHeight - pillarHeight + 4, pillarWidth * 0.3, pillarHeight - 8)
            
            -- Outline
            love.graphics.setColor(0.15, 0.12, 0.08)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", pillarX, archY + archHeight - pillarHeight, pillarWidth, pillarHeight)
            love.graphics.setLineWidth(1)
        end
        
        -- Arch top (curved stone)
        local archTopHeight = archHeight * 0.3
        local archTopY = archY + archHeight - pillarHeight - archTopHeight
        
        -- Create arch curve with stone blocks
        love.graphics.setColor(0.4, 0.35, 0.25)
        love.graphics.arc("fill", centerX, archY + archHeight - pillarHeight, archWidth/2, math.pi, 0)
        
        -- Arch inner shadow
        love.graphics.setColor(0.2, 0.18, 0.12)
        love.graphics.arc("fill", centerX, archY + archHeight - pillarHeight, archWidth/2 - pillarWidth, math.pi, 0)
        
        -- Arch outline
        love.graphics.setColor(0.15, 0.12, 0.08)
        love.graphics.setLineWidth(3)
        love.graphics.arc("line", centerX, archY + archHeight - pillarHeight, archWidth/2, math.pi, 0)
        love.graphics.setLineWidth(1)
        
        -- Glowing magical runes on pillars
        local time = love.timer.getTime()
        local glowPulse = 0.6 + math.sin(time * 2) * 0.4
        
        love.graphics.setColor(0.5, 0.7, 0.9, glowPulse)
        for side = 0, 1 do
            local pillarX = side == 0 and archX or (archX + archWidth - pillarWidth)
            local centerPillarX = pillarX + pillarWidth/2
            
            -- Simple rune symbols (vertical lines with crosses)
            for i = 0, 2 do
                local runeY = archY + archHeight - pillarHeight + 10 + i * (pillarHeight/4)
                love.graphics.rectangle("fill", centerPillarX - 1, runeY, 2, 12)
                love.graphics.rectangle("fill", centerPillarX - 4, runeY + 6, 8, 2)
            end
        end
        
        -- Magical energy veil in archway (shimmering barrier)
        love.graphics.setColor(0.4, 0.6, 0.8, 0.3 * glowPulse)
        local veilX = archX + pillarWidth
        local veilWidth = archWidth - pillarWidth * 2
        local veilHeight = pillarHeight
        
        -- Draw wavy magical barrier
        for i = 0, 8 do
            local t = i / 8
            local waveOffset = math.sin(time * 3 + t * math.pi * 2) * 3
            local x1 = veilX + waveOffset
            local y1 = archY + archHeight - veilHeight + t * veilHeight
            local x2 = veilX + veilWidth - waveOffset
            local y2 = y1
            
        love.graphics.setLineWidth(2)
            love.graphics.line(x1, y1, x2, y2)
        love.graphics.setLineWidth(1)
        end
        
        -- Glowing particles floating around archway
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2 + time
            local r = archWidth * 0.6
            local px = centerX + math.cos(angle) * r
            local py = archY + archHeight - pillarHeight/2 + math.sin(angle * 1.3) * (pillarHeight * 0.3)
            local particleSize = 2 + math.sin(time * 3 + i) * 1
            
            love.graphics.setColor(0.6, 0.8, 1.0, 0.8 * glowPulse)
            love.graphics.circle("fill", px, py, particleSize)
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

return Interactable

