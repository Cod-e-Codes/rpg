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
    -- Ancient path and eastern path need extra large radius
    if self.type == "ancient_path" or self.type == "eastern_path" then
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
    
    -- Door transitions now use fade system instead of timer
    
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
                    message = "The chest opens... Something stirs in the shadows!"
                }
            end
            
            if self.data.item then
                -- Check if it's a gold chest
                if self.data.item == "Gold" and self.data.goldAmount then
                    gameState:addGold(self.data.goldAmount)
                    return {
                        type = "gold_found",
                        amount = self.data.goldAmount,
                        message = string.format("Found: %d Gold!", self.data.goldAmount)
                    }
                else
                    gameState:addItem(self.data.item)
                    return string.format("Found: %s!", self.data.item)
                end
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
            
            -- Use fade transition instead of direct door transition
            return {
                type = "fade_transition",
                targetMap = self.data.destination,
                spawnX = self.data.spawnX,
                spawnY = self.data.spawnY
            }
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
    elseif self.type == "eastern_path" then
        -- Eastern path entrance with fade transition
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
    -- Door transitions now use fade system
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
        -- Check if this is a side-of-building door (isometric style) or interior door (vertical style)
        local isSideDoor = self.data.isSideDoor or false
        
        if isSideDoor then
            -- Use custom side-door image if available
            if SideDoorImage then
                local doorAlpha = 1 - (self.openProgress * 0.3)
                
                -- Scale to fit the height (48px) while maintaining aspect ratio, then make it 2x bigger
                local maxHeight = self.height -- 48
                local imageSize = 150
                
                -- Scale to fit height, then double it
                local scale = (maxHeight / imageSize) * 2
                
                -- Calculate centered position with upward offset
                local scaledWidth = imageSize * scale
                local scaledHeight = imageSize * scale
                local offsetX = (self.width - scaledWidth) / 2
                local offsetY = (self.height - scaledHeight) / 2 - 8  -- Move up by 8 pixels
                
                love.graphics.setColor(1, 1, 1, doorAlpha)
                love.graphics.draw(SideDoorImage, self.x + offsetX, self.y + offsetY, 0, scale, scale)
                love.graphics.setColor(1, 1, 1)
            else
                -- Fallback to procedural side-of-building isometric door with artistic detail
            local doorAlpha = 1 - (self.openProgress * 0.3)
            local time = love.timer.getTime()
            local seed = self.x * 7 + self.y * 11
            
            -- Door dimensions
            local doorWidth = self.width
            local doorHeight = self.height
            
            -- Create proper parallelogram with vertical left/right sides and 45-degree top/bottom
            local leftX = self.x
            local rightX = self.x + doorWidth
            local topY = self.y
            local bottomY = self.y + doorHeight
            
            -- Parallelogram points: vertical sides, 45-degree top/bottom
            local offset = doorHeight * 0.3 -- 45-degree angle offset
            local doorPoints = {
                leftX, topY,                    -- Top-left
                rightX, topY,                   -- Top-right  
                rightX + offset, bottomY,       -- Bottom-right (45-degree angle)
                leftX + offset, bottomY         -- Bottom-left (45-degree angle)
            }
            
            -- Wood grain base with noise distortion
            love.graphics.setColor(0.35, 0.24, 0.14, doorAlpha)
            love.graphics.polygon("fill", doorPoints)
            
            -- Wood planks (horizontal) with individual character
            love.graphics.setColor(0.42, 0.29, 0.18, doorAlpha)
            for i = 1, 4 do
                local plankProgress = (i - 1) / 3
                local plankTopY = topY + plankProgress * doorHeight
                local plankBottomY = topY + (plankProgress + 0.25) * doorHeight
                
                -- Add slight variation to each plank
                local plankNoise = math.sin(seed + i * 5) * 1.5
                local leftOffset = leftX + offset * plankProgress + plankNoise
                local rightOffset = rightX + offset * plankProgress + plankNoise
                
                local plankPoints = {
                    leftOffset, plankTopY,
                    rightOffset, plankTopY,
                    rightOffset + offset * 0.25, plankBottomY,
                    leftOffset + offset * 0.25, plankBottomY
                }
                love.graphics.polygon("fill", plankPoints)
                
                -- Individual plank highlights (toon style)
                love.graphics.setColor(0.52, 0.37, 0.24, doorAlpha)
                local highlightPoints = {
                    leftOffset + 2, plankTopY + 2,
                    rightOffset - 2, plankTopY + 2,
                    rightOffset + offset * 0.25 - 2, plankBottomY - 2,
                    leftOffset + offset * 0.25 + 2, plankBottomY - 2
                }
                love.graphics.polygon("fill", highlightPoints)
                love.graphics.setColor(0.42, 0.29, 0.18, doorAlpha)
            end
            
            -- Wood grain lines with noise distortion
            love.graphics.setColor(0.28, 0.18, 0.10, doorAlpha)
            for i = 1, 6 do
                local grainProgress = (i - 1) / 5
                local grainY = topY + grainProgress * doorHeight
                local grainNoise = math.sin(seed + i * 3 + time * 0.1) * 2
                
                local grainPoints = {
                    leftX + offset * grainProgress + grainNoise, grainY,
                    rightX + offset * grainProgress + grainNoise, grainY
                }
                love.graphics.line(grainPoints)
            end
            
            -- Metal reinforcement strips (horizontal)
            love.graphics.setColor(0.45, 0.45, 0.50, doorAlpha)
            for i = 1, 3 do
                local stripProgress = (i - 1) / 2
                local stripY = topY + stripProgress * doorHeight
                local stripHeight = 4
                
                local stripPoints = {
                    leftX + offset * stripProgress, stripY,
                    rightX + offset * stripProgress, stripY,
                    rightX + offset * stripProgress + offset * 0.15, stripY + stripHeight,
                    leftX + offset * stripProgress + offset * 0.15, stripY + stripHeight
                }
                love.graphics.polygon("fill", stripPoints)
                
                -- Metal strip highlights
                love.graphics.setColor(0.60, 0.60, 0.65, doorAlpha)
                local highlightStripPoints = {
                    leftX + offset * stripProgress + 1, stripY + 1,
                    rightX + offset * stripProgress - 1, stripY + 1,
                    rightX + offset * stripProgress + offset * 0.15 - 1, stripY + stripHeight - 1,
                    leftX + offset * stripProgress + offset * 0.15 + 1, stripY + stripHeight - 1
                }
                love.graphics.polygon("fill", highlightStripPoints)
                love.graphics.setColor(0.45, 0.45, 0.50, doorAlpha)
            end
            
            -- Decorative metal studs/rivets
            love.graphics.setColor(0.35, 0.35, 0.40, doorAlpha)
            for i = 1, 3 do
                for j = 1, 4 do
                    local studX = leftX + offset * ((j - 1) / 3) + (i - 1) * 12
                    local studY = topY + ((j - 1) / 3) * doorHeight + 8
                    local studNoise = math.sin(seed + i * j) * 0.5
                    
                    love.graphics.circle("fill", studX + studNoise, studY, 3)
                    -- Stud highlight
                    love.graphics.setColor(0.50, 0.50, 0.55, doorAlpha)
                    love.graphics.circle("fill", studX + studNoise - 1, studY - 1, 1.5)
                    love.graphics.setColor(0.35, 0.35, 0.40, doorAlpha)
                end
            end
            
            -- Door handle/ring (iron)
            local handleX = rightX + offset * 0.7 - 12
            local handleY = topY + doorHeight * 0.6
            love.graphics.setColor(0.30, 0.30, 0.35, doorAlpha)
            love.graphics.circle("fill", handleX, handleY, 6)
            love.graphics.setColor(0.20, 0.20, 0.25, doorAlpha)
            love.graphics.circle("fill", handleX, handleY, 4)
            -- Handle highlight
            love.graphics.setColor(0.45, 0.45, 0.50, doorAlpha)
            love.graphics.circle("fill", handleX - 2, handleY - 2, 2)
            
            -- Decorative corner brackets
            love.graphics.setColor(0.40, 0.40, 0.45, doorAlpha)
            -- Top-left bracket
            love.graphics.rectangle("fill", leftX, topY, 8, 8)
            -- Top-right bracket  
            love.graphics.rectangle("fill", rightX - 8, topY, 8, 8)
            -- Bottom-left bracket
            love.graphics.rectangle("fill", leftX + offset - 8, bottomY - 8, 8, 8)
            -- Bottom-right bracket
            love.graphics.rectangle("fill", rightX + offset - 8, bottomY - 8, 8, 8)
            
            -- Bracket highlights
            love.graphics.setColor(0.55, 0.55, 0.60, doorAlpha)
            love.graphics.rectangle("fill", leftX + 1, topY + 1, 4, 4)
            love.graphics.rectangle("fill", rightX - 7, topY + 1, 4, 4)
            love.graphics.rectangle("fill", leftX + offset - 7, bottomY - 7, 4, 4)
            love.graphics.rectangle("fill", rightX + offset - 7, bottomY - 7, 4, 4)
            
            -- Weathered wood texture (subtle)
            love.graphics.setColor(0.25, 0.16, 0.08, doorAlpha * 0.3)
            for i = 1, 8 do
                local weatherX = leftX + (i - 1) * 8 + math.sin(seed + i * 7) * 3
                local weatherY = topY + math.sin(seed + i * 11) * 4
                local weatherLength = doorHeight + math.sin(seed + i * 13) * 6
                love.graphics.line(weatherX, weatherY, weatherX, weatherY + weatherLength)
            end
            
            -- Door outline with proper parallelogram shape
            love.graphics.setColor(0.15, 0.10, 0.06, doorAlpha)
            love.graphics.setLineWidth(4)
            love.graphics.polygon("line", doorPoints)
            love.graphics.setLineWidth(1)
            
            -- Subtle shadow effect
            love.graphics.setColor(0.10, 0.06, 0.03, doorAlpha * 0.4)
            local shadowPoints = {
                leftX + 2, topY + 2,
                rightX + 2, topY + 2,
                rightX + offset + 2, bottomY + 2,
                leftX + offset + 2, bottomY + 2
            }
            love.graphics.polygon("fill", shadowPoints)
            end -- End of procedural door fallback
            
        else
            -- Vertical door (interior style) - standing upright with perspective
            local doorAlpha = 1 - (self.openProgress * 0.3)
            local perspectiveOffset = self.openProgress * 16
            
            -- Door frame (always visible, doesn't move)
            love.graphics.setColor(0.55, 0.48, 0.35)
            love.graphics.setLineWidth(6)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
            love.graphics.setLineWidth(1)
            
            -- Draw isometric door (standing upright with perspective)
            -- Door face (front) - dark wood
            love.graphics.setColor(0.38, 0.26, 0.16, doorAlpha)
            love.graphics.rectangle("fill", self.x + perspectiveOffset, self.y, self.width - perspectiveOffset, self.height)
        
        -- Door side (visible when opening) - darker
        if perspectiveOffset > 0 then
            love.graphics.setColor(0.28, 0.18, 0.10, doorAlpha)
            -- Draw the side face as a parallelogram
            local sidePoints = {
                self.x, self.y,
                self.x + perspectiveOffset, self.y,
                self.x + perspectiveOffset + 8, self.y + self.height,
                self.x + 8, self.y + self.height
            }
            love.graphics.polygon("fill", sidePoints)
        end
        
        -- Wood planks (vertical) on door face - medium
        love.graphics.setColor(0.46, 0.32, 0.20, doorAlpha)
        for i = 0, 2 do
            local plankX = self.x + perspectiveOffset + 2 + i * 10
            if plankX < self.x + self.width then -- Only draw visible parts
                local plankWidth = math.min(8, self.x + self.width - plankX)
                love.graphics.rectangle("fill", plankX, self.y, plankWidth, self.height)
            end
        end
        
        -- Toon highlights on planks
        love.graphics.setColor(0.56, 0.40, 0.26, doorAlpha)
        for i = 0, 2 do
            local plankX = self.x + perspectiveOffset + 3 + i * 10
            if plankX < self.x + self.width - 3 then
                local highlightWidth = math.min(3, self.x + self.width - plankX - 3)
                love.graphics.rectangle("fill", plankX, self.y + 4, highlightWidth, self.height - 8)
            end
        end
        
        -- Cross beams (dark) on door face
        love.graphics.setColor(0.28, 0.18, 0.10, doorAlpha)
        local beamWidth = self.width - perspectiveOffset
        if beamWidth > 0 then
            love.graphics.rectangle("fill", self.x + perspectiveOffset, self.y + self.height * 0.3, beamWidth, 5)
            love.graphics.rectangle("fill", self.x + perspectiveOffset, self.y + self.height * 0.7, beamWidth, 5)
        end
        
        -- Door handle/ring (iron with toon shading) - only if visible
        if self.x + self.width - 8 > self.x + perspectiveOffset then
            local handleX = math.max(self.x + perspectiveOffset + 4, self.x + self.width - 8)
            love.graphics.setColor(0.35, 0.35, 0.40, doorAlpha)
            love.graphics.circle("fill", handleX, self.y + self.height/2, 5)
            love.graphics.setColor(0.20, 0.20, 0.25, doorAlpha)
            love.graphics.circle("fill", handleX, self.y + self.height/2, 3)
            
            -- Highlight on handle
            love.graphics.setColor(0.50, 0.50, 0.55, doorAlpha)
            love.graphics.circle("fill", handleX - 1, self.y + self.height/2 - 1, 2)
        end
        
        -- Metal studs (toon style) - only visible ones
        love.graphics.setColor(0.40, 0.40, 0.45, doorAlpha)
        for i = 0, 1 do
            for j = 0, 3 do
                local studX = self.x + perspectiveOffset + 6 + i * 20
                if studX < self.x + self.width then
                    love.graphics.circle("fill", studX, self.y + 10 + j * 12, 2)
                end
            end
        end
        
        -- Toon outline (follows the door face)
        love.graphics.setColor(0.15, 0.10, 0.06, doorAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x + perspectiveOffset, self.y, self.width - perspectiveOffset, self.height)
        
        -- Draw outline for door side if visible
        if perspectiveOffset > 0 then
            local sidePoints = {
                self.x, self.y,
                self.x + perspectiveOffset, self.y,
                self.x + perspectiveOffset + 8, self.y + self.height,
                self.x + 8, self.y + self.height
            }
            love.graphics.polygon("line", sidePoints)
        end
        love.graphics.setLineWidth(1)
        
        end -- End of vertical door (else block)
        
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
        
    elseif self.type == "inn_table" then
        -- Inn table with toon shading and noise distortion for hand-drawn look
        local time = love.timer.getTime()
        local seed = self.x * 7 + self.y * 11
        
        -- Table dimensions
        local tableWidth = 64
        local tableHeight = 64
        local tableTop = 48
        
        -- Draw table legs (4 corners) with noise distortion
        local legWidth = 6
        local legHeight = 16
        for i = 1, 4 do
            local legX, legY
            if i == 1 then legX, legY = self.x + 8, self.y + tableTop - legHeight
            elseif i == 2 then legX, legY = self.x + tableWidth - 8 - legWidth, self.y + tableTop - legHeight
            elseif i == 3 then legX, legY = self.x + 8, self.y + tableHeight - 8
            else legX, legY = self.x + tableWidth - 8 - legWidth, self.y + tableHeight - 8
            end
            
            -- Leg with slight noise distortion
            local noiseX = math.sin(seed + i * 3) * 0.5
            local noiseY = math.cos(seed + i * 5) * 0.5
            
            -- Dark leg
            love.graphics.setColor(0.35, 0.25, 0.15)
            love.graphics.rectangle("fill", legX + noiseX, legY + noiseY, legWidth, legHeight)
            
            -- Leg highlight
            love.graphics.setColor(0.45, 0.32, 0.20)
            love.graphics.rectangle("fill", legX + noiseX + 1, legY + noiseY, 2, legHeight)
            
            -- Leg outline with noise
            love.graphics.setColor(0.18, 0.12, 0.07)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", legX + noiseX, legY + noiseY, legWidth, legHeight)
        end
        
        -- Draw table top (round-ish with noise)
        local centerX = self.x + tableWidth / 2
        local centerY = self.y + tableTop / 2
        local radiusX = 28
        local radiusY = 24
        
        -- Create irregular table top shape with noise
        local tablePoints = {}
        local segments = 16
        for i = 0, segments do
            local angle = (i / segments) * math.pi * 2
            local noiseOffset = math.sin(angle * 4 + seed) * 1.5 + math.cos(angle * 6 + seed * 1.7) * 1.2
            local rx = radiusX + noiseOffset
            local ry = radiusY + noiseOffset * 0.8
            local px = centerX + math.cos(angle) * rx
            local py = centerY + math.sin(angle) * ry
            table.insert(tablePoints, px)
            table.insert(tablePoints, py)
        end
        
        -- Table top base color
        love.graphics.setColor(0.52, 0.38, 0.24)
        love.graphics.polygon("fill", tablePoints)
        
        -- Table top highlight (toon style)
        love.graphics.setColor(0.62, 0.48, 0.32)
        local highlightPoints = {}
        for i = 0, segments do
            local angle = (i / segments) * math.pi * 2
            local noiseOffset = math.sin(angle * 4 + seed) * 1.5 + math.cos(angle * 6 + seed * 1.7) * 1.2
            local rx = (radiusX + noiseOffset) * 0.6
            local ry = (radiusY + noiseOffset * 0.8) * 0.6
            local px = centerX - 4 + math.cos(angle) * rx
            local py = centerY - 4 + math.sin(angle) * ry
            table.insert(highlightPoints, px)
            table.insert(highlightPoints, py)
        end
        love.graphics.polygon("fill", highlightPoints)
        
        -- Wood grain lines
        love.graphics.setColor(0.38, 0.26, 0.16)
        for i = 1, 3 do
            local grainY = centerY - 8 + i * 6
            local grainNoise = math.sin(seed + i * 2) * 2
            love.graphics.line(centerX - 20 + grainNoise, grainY, centerX + 20 + grainNoise, grainY)
        end
        
        -- Table top outline with noise distortion
        love.graphics.setColor(0.20, 0.14, 0.08)
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", tablePoints)
        love.graphics.setLineWidth(1)
        
        -- Draw mug if specified
        if self.data.hasMug then
            local mugX = centerX - 10
            local mugY = centerY + 4
            local mugNoise = math.sin(time * 0.5 + seed) * 0.3
            
            -- Mug body
            love.graphics.setColor(0.6, 0.5, 0.4)
            love.graphics.rectangle("fill", mugX + mugNoise, mugY, 12, 10, 2, 2)
            
            -- Mug highlight
            love.graphics.setColor(0.75, 0.65, 0.55)
            love.graphics.rectangle("fill", mugX + mugNoise + 1, mugY + 1, 4, 8)
            
            -- Mug handle
            love.graphics.setColor(0.6, 0.5, 0.4)
            love.graphics.arc("line", "open", mugX + 12 + mugNoise, mugY + 5, 4, -math.pi/2, math.pi/2)
            
            -- Mug outline
            love.graphics.setColor(0.2, 0.15, 0.1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", mugX + mugNoise, mugY, 12, 10, 2, 2)
            love.graphics.setLineWidth(1)
        end
        
        -- Draw candle if specified
        if self.data.hasCandle then
            local candleX = centerX + 8
            local candleY = centerY - 6
            local flicker = math.sin(time * 8 + seed) * 0.5 + math.cos(time * 12 + seed * 1.3) * 0.3
            
            -- Candle body
            love.graphics.setColor(0.9, 0.85, 0.7)
            love.graphics.rectangle("fill", candleX, candleY + 4, 6, 10, 1, 1)
            
            -- Candle highlight
            love.graphics.setColor(0.95, 0.92, 0.85)
            love.graphics.rectangle("fill", candleX + 1, candleY + 5, 2, 8)
            
            -- Candle outline
            love.graphics.setColor(0.3, 0.25, 0.2)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", candleX, candleY + 4, 6, 10, 1, 1)
            love.graphics.setLineWidth(1)
            
            -- Flame (animated)
            local flameHeight = 6 + flicker
            local flameWidth = 4 + flicker * 0.5
            
            -- Flame glow (outer)
            love.graphics.setColor(1, 0.6, 0.1, 0.4)
            love.graphics.ellipse("fill", candleX + 3, candleY + flicker, flameWidth + 2, flameHeight + 2)
            
            -- Flame core
            love.graphics.setColor(1, 0.8, 0.2)
            love.graphics.ellipse("fill", candleX + 3, candleY + flicker, flameWidth, flameHeight)
            
            -- Flame highlight (brightest part)
            love.graphics.setColor(1, 0.95, 0.7)
            love.graphics.ellipse("fill", candleX + 3, candleY + flicker, flameWidth * 0.5, flameHeight * 0.6)
            
            -- Tiny flame particles (sparkles)
            for i = 1, 3 do
                local particleSeed = seed + i * 13 + time * 2
                local px = candleX + 3 + math.sin(particleSeed) * 4
                local py = candleY - 4 + (particleSeed % 8) - flicker
                local pSize = 1 + math.sin(particleSeed * 3) * 0.5
                love.graphics.setColor(1, 0.9, 0.5, 0.6)
                love.graphics.circle("fill", px, py, pSize)
            end
        end
        
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
    
    elseif self.type == "eastern_path" then
        -- Eastern path - Invisible transition point (no visual bridge)
        -- Just a cleared path with no rocks, no visual elements needed
        
    elseif self.type == "potion_shelf" then
        -- Detailed potion shelf with magical bottles and toon shading
        local time = love.timer.getTime()
        local seed = self.x * 7 + self.y * 11
        
        -- Shelf base (dark wood)
        love.graphics.setColor(0.28, 0.18, 0.10)
        love.graphics.rectangle("fill", self.x, self.y + self.height - 8, self.width, 8)
        
        -- Shelf back (medium wood)
        love.graphics.setColor(0.42, 0.30, 0.18)
        love.graphics.rectangle("fill", self.x, self.y, 8, self.height)
        
        -- Draw potion bottles with magical glow effects
        local bottleCount = 6
        for i = 1, bottleCount do
            local bottleX = self.x + 12 + (i - 1) * 12
            local bottleY = self.y + 8 + ((i - 1) % 3) * 24
            
            -- Bottle type based on position
            local bottleType = self.data.potionTypes[((i - 1) % #self.data.potionTypes) + 1]
            local bottleColor = {1, 0.2, 0.2} -- Default red
            
            if bottleType == "health" then
                bottleColor = {1, 0.2, 0.2} -- Red
            elseif bottleType == "mana" then
                bottleColor = {0.2, 0.2, 1} -- Blue
            elseif bottleType == "magic" then
                bottleColor = {0.8, 0.2, 1} -- Purple
            elseif bottleType == "rare" then
                bottleColor = {1, 1, 0.2} -- Gold
            elseif bottleType == "mystic" then
                bottleColor = {0.2, 1, 0.8} -- Cyan
            elseif bottleType == "elixir" then
                bottleColor = {1, 0.6, 0.2} -- Orange
            end
            
            -- Magical glow effect
            if self.data.hasGlow then
                local glowPulse = 0.7 + math.sin(time * 2 + i) * 0.3
                love.graphics.setColor(bottleColor[1], bottleColor[2], bottleColor[3], 0.3 * glowPulse)
                love.graphics.circle("fill", bottleX + 4, bottleY + 8, 8)
            end
            
            -- Bottle body
            love.graphics.setColor(bottleColor[1], bottleColor[2], bottleColor[3])
            love.graphics.rectangle("fill", bottleX, bottleY, 8, 12, 1, 1)
            
            -- Bottle neck
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.rectangle("fill", bottleX + 2, bottleY - 2, 4, 4)
            
            -- Bottle cork
            love.graphics.setColor(0.6, 0.4, 0.2)
            love.graphics.rectangle("fill", bottleX + 2.5, bottleY - 3, 3, 2)
            
            -- Bottle outline with noise
            local outlineNoise = math.sin(seed + i * 3) * 0.5
            love.graphics.setColor(0.1, 0.1, 0.1)
            love.graphics.setLineWidth(1 + outlineNoise)
            love.graphics.rectangle("line", bottleX + outlineNoise, bottleY, 8, 12, 1, 1)
            love.graphics.setLineWidth(1)
        end
        
        -- Shelf outline with hand-drawn noise
        love.graphics.setColor(0.15, 0.10, 0.06)
        love.graphics.setLineWidth(2)
        for i = 0, 3 do
            local noise = math.sin(seed + i * 2) * 1
            love.graphics.rectangle("line", self.x + noise, self.y + i * 2, self.width + noise * 2, 2)
        end
        love.graphics.setLineWidth(1)
        
    elseif self.type == "alchemy_table" then
        -- Magical alchemy table with equipment and toon shading
        local time = love.timer.getTime()
        local seed = self.x * 7 + self.y * 11
        
        -- Table base (dark wood)
        love.graphics.setColor(0.28, 0.18, 0.10)
        love.graphics.rectangle("fill", self.x, self.y + self.height - 8, self.width, 8)
        
        -- Table top (medium wood)
        love.graphics.setColor(0.42, 0.30, 0.18)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height - 8)
        
        -- Wood grain lines with noise
        love.graphics.setColor(0.35, 0.24, 0.16)
        for i = 1, 3 do
            local grainY = self.y + i * 8 + math.sin(seed + i * 3) * 1
            love.graphics.line(self.x + 2, grainY, self.x + self.width - 2, grainY)
        end
        
        -- Mortar and pestle
        if self.data.hasMortar then
            local mortarX = self.x + 16
            local mortarY = self.y + 16
            
            -- Mortar bowl
            love.graphics.setColor(0.6, 0.6, 0.65)
            love.graphics.rectangle("fill", mortarX, mortarY, 12, 8, 2, 2)
            
            -- Mortar contents (magical powder)
            love.graphics.setColor(0.8, 0.7, 1.0)
            love.graphics.rectangle("fill", mortarX + 2, mortarY + 2, 8, 4, 1, 1)
            
            -- Pestle
            love.graphics.setColor(0.4, 0.3, 0.2)
            love.graphics.rectangle("fill", mortarX + 20, mortarY - 4, 4, 16)
            
            -- Magical sparkles
            for i = 1, 3 do
                local sparkleX = mortarX + 8 + math.sin(time * 3 + i) * 4
                local sparkleY = mortarY + 4 + math.cos(time * 2 + i) * 2
                love.graphics.setColor(1, 1, 0.8, 0.8)
                love.graphics.circle("fill", sparkleX, sparkleY, 1)
            end
        end
        
        -- Alchemy bottles
        if self.data.hasBottles then
            for i = 1, 4 do
                local bottleX = self.x + 8 + (i - 1) * 16
                local bottleY = self.y + 32
                
                -- Bottle with different colors
                local colors = {{0.2, 1, 0.2}, {0.2, 0.2, 1}, {1, 0.2, 1}, {1, 1, 0.2}}
                local color = colors[i]
                
                love.graphics.setColor(color[1], color[2], color[3])
                love.graphics.rectangle("fill", bottleX, bottleY, 6, 10, 1, 1)
                
                -- Bottle outline with noise
                local noise = math.sin(seed + i * 5) * 0.3
                love.graphics.setColor(0.1, 0.1, 0.1)
                love.graphics.setLineWidth(1 + noise)
                love.graphics.rectangle("line", bottleX + noise, bottleY, 6, 10, 1, 1)
                love.graphics.setLineWidth(1)
            end
        end
        
        -- Magical herbs
        if self.data.hasHerbs then
            local herbX = self.x + self.width - 20
            local herbY = self.y + 16
            
            -- Herb bundles
            for i = 1, 3 do
                local bundleX = herbX + (i - 1) * 6
                local bundleY = herbY + math.sin(time * 2 + i) * 2
                
                -- Herb colors
                local herbColors = {{0.2, 0.8, 0.2}, {0.8, 0.6, 0.2}, {0.6, 0.4, 0.8}}
                local herbColor = herbColors[i]
                
                love.graphics.setColor(herbColor[1], herbColor[2], herbColor[3])
                love.graphics.rectangle("fill", bundleX, bundleY, 4, 12)
                
                -- Herb outline with noise
                local noise = math.sin(seed + i * 7) * 0.5
                love.graphics.setColor(0.1, 0.3, 0.1)
                love.graphics.setLineWidth(1 + noise)
                love.graphics.rectangle("line", bundleX + noise, bundleY, 4, 12)
                love.graphics.setLineWidth(1)
            end
        end
        
        -- Table outline with hand-drawn noise
        love.graphics.setColor(0.15, 0.10, 0.06)
        love.graphics.setLineWidth(2)
        for i = 0, 3 do
            local noise = math.sin(seed + i * 2) * 1
            love.graphics.rectangle("line", self.x + noise, self.y + i * 2, self.width + noise * 2, 2)
        end
        love.graphics.setLineWidth(1)
        
    elseif self.type == "ingredient_cabinet" then
        -- Magical ingredient storage cabinet
        local time = love.timer.getTime()
        local seed = self.x * 7 + self.y * 11
        
        -- Cabinet frame (dark wood)
        love.graphics.setColor(0.28, 0.18, 0.10)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        
        -- Cabinet doors
        love.graphics.setColor(0.42, 0.30, 0.18)
        love.graphics.rectangle("fill", self.x + 4, self.y + 4, (self.width - 8) / 2, self.height - 8)
        love.graphics.rectangle("fill", self.x + self.width / 2, self.y + 4, (self.width - 8) / 2, self.height - 8)
        
        -- Wood grain
        love.graphics.setColor(0.35, 0.24, 0.16)
        for i = 1, 3 do
            local grainY = self.y + 8 + i * 8 + math.sin(seed + i * 3) * 0.5
            love.graphics.line(self.x + 8, grainY, self.x + self.width - 8, grainY)
        end
        
        -- Draw ingredient jars
        if self.data.hasJars then
            for i = 1, 6 do
                local jarX = self.x + 8 + ((i - 1) % 3) * 16
                local jarY = self.y + 12 + math.floor((i - 1) / 3) * 16
                
                -- Jar body
                love.graphics.setColor(0.9, 0.9, 0.95)
                love.graphics.rectangle("fill", jarX, jarY, 8, 10, 1, 1)
                
                -- Jar contents (different colors)
                local contentsColors = {{1, 0.5, 0.5}, {0.5, 1, 0.5}, {0.5, 0.5, 1}, {1, 1, 0.5}, {1, 0.5, 1}, {0.5, 1, 1}}
                local contentsColor = contentsColors[i]
                
                love.graphics.setColor(contentsColor[1], contentsColor[2], contentsColor[3], 0.8)
                love.graphics.rectangle("fill", jarX + 1, jarY + 2, 6, 6, 1, 1)
                
                -- Jar lid
                love.graphics.setColor(0.6, 0.4, 0.2)
                love.graphics.rectangle("fill", jarX + 1, jarY - 2, 6, 3)
                
                -- Jar outline with noise
                local noise = math.sin(seed + i * 4) * 0.3
                love.graphics.setColor(0.1, 0.1, 0.1)
                love.graphics.setLineWidth(1 + noise)
                love.graphics.rectangle("line", jarX + noise, jarY, 8, 10, 1, 1)
                love.graphics.setLineWidth(1)
            end
        end
        
        -- Magical crystals
        if self.data.hasCrystals then
            for i = 1, 4 do
                local crystalX = self.x + self.width - 12
                local crystalY = self.y + 8 + (i - 1) * 8
                
                -- Crystal body
                local crystalColors = {{1, 0.2, 0.2}, {0.2, 1, 0.2}, {0.2, 0.2, 1}, {1, 1, 0.2}}
                local crystalColor = crystalColors[i]
                
                love.graphics.setColor(crystalColor[1], crystalColor[2], crystalColor[3])
                love.graphics.polygon("fill", 
                    crystalX, crystalY,
                    crystalX + 6, crystalY + 3,
                    crystalX + 4, crystalY + 8,
                    crystalX - 2, crystalY + 5
                )
                
                -- Crystal glow
                love.graphics.setColor(crystalColor[1], crystalColor[2], crystalColor[3], 0.5)
                love.graphics.polygon("fill", 
                    crystalX + 1, crystalY + 1,
                    crystalX + 4, crystalY + 3,
                    crystalX + 3, crystalY + 6,
                    crystalX - 1, crystalY + 4
                )
            end
        end
        
        -- Cabinet handles
        love.graphics.setColor(0.7, 0.5, 0.3)
        love.graphics.circle("fill", self.x + 12, self.y + self.height / 2, 2)
        love.graphics.circle("fill", self.x + self.width - 12, self.y + self.height / 2, 2)
        
        -- Cabinet outline with hand-drawn noise
        love.graphics.setColor(0.15, 0.10, 0.06)
        love.graphics.setLineWidth(2)
        for i = 0, 3 do
            local noise = math.sin(seed + i * 2) * 1
            love.graphics.rectangle("line", self.x + noise, self.y + i * 2, self.width + noise * 2, 2)
        end
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.setColor(1, 1, 1)
end

return Interactable

