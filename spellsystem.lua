-- Spell System Manager - Handles learned spells, equipped slots, and UI
local Spell = require("spell")
local ParticleSystem = require("particlesystem")

local SpellSystem = {}

function SpellSystem:new(gameState)
    local system = {
        gameState = gameState,
        learnedSpells = {}, -- Array of Spell objects
        equippedSpells = {nil, nil, nil, nil, nil}, -- 5 slots (1-5 keys)
        particleEmitters = {}, -- Active particle emitters for spells
        
        -- Mana system
        currentMana = 100,
        maxMana = 100,
        manaRegenRate = 5, -- Mana per second
        
        -- UI state
        showSpellMenu = false,
        selectedSpell = nil, -- Currently selected spell in menu
        selectedSlot = 1, -- Currently selected slot (1-5) for equipping
        hoveredSlot = nil, -- Slot being hovered in bottom bar
        hoveredMenuSpell = nil, -- Spell being hovered in menu
        
        -- Slot UI position (calculated in draw)
        slotSize = 48,
        slotSpacing = 8,
        slotYOffset = 10, -- From bottom of screen
        
        -- Messages
        currentSpellMessage = nil,
        spellMessageTimer = 0,
        spellMessageDuration = 3
    }
    setmetatable(system, {__index = self})
    return system
end

function SpellSystem:update(dt, playerX, playerY, camera)
    -- Update mana regeneration
    if self.currentMana < self.maxMana then
        self.currentMana = math.min(self.maxMana, self.currentMana + self.manaRegenRate * dt)
    end
    
    -- Update all learned spells
    for _, spell in ipairs(self.learnedSpells) do
        spell:update(dt)
        
        -- Sync spell progress to game state
        self.gameState:setSpellLevel(spell.name, spell.level)
        self.gameState:setSpellExperience(spell.name, spell.experience)
        
        -- Check for level up messages
        if spell:addExperience(0) then -- Will return true if leveled up this frame
            -- Note: addExperience is called in spell:update, so we just check
        end
    end
    
    -- Update particle emitters
    for slotIndex, emitter in pairs(self.particleEmitters) do
        local spell = self.equippedSpells[slotIndex]
        if spell and spell.isActive then
            -- Update position to follow player
            emitter:setPosition(playerX, playerY)
            emitter:update(dt, camera)
        else
            -- Spell is no longer active, clear particles
            emitter:clear()
        end
    end
    
    -- Update spell message timer
    if self.spellMessageTimer > 0 then
        self.spellMessageTimer = self.spellMessageTimer - dt
        if self.spellMessageTimer <= 0 then
            self.currentSpellMessage = nil
        end
    end
end

function SpellSystem:draw(camera, playerX, playerY)
    -- Draw particle effects (in world space)
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    
    for _, emitter in pairs(self.particleEmitters) do
        emitter:draw(camera)
    end
    
    love.graphics.pop()
    
    -- Only draw UI if player has learned at least one spell
    if #self.learnedSpells > 0 then
        self:drawSlotBar()
    end
    
    if self.showSpellMenu then
        self:drawSpellMenu()
    end
    
    if self.currentSpellMessage then
        self:drawSpellMessage()
    end
end

function SpellSystem:drawSlotBar()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Vertical layout on left side
    local startX = 10
    local startY = 80  -- Below mana bar
    local totalSlots = 5
    
    -- Get mouse position for hover detection
    local mouseX, mouseY = love.mouse.getPosition()
    self.hoveredSlot = nil
    
    -- Draw mana bar (vertical on left, below slots)
    local manaBarWidth = 20
    local manaBarHeight = 100
    local manaBarX = 10
    local manaBarY = startY + (totalSlots * (self.slotSize + self.slotSpacing)) + 20
    
    -- Background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
    love.graphics.rectangle("fill", manaBarX, manaBarY, manaBarWidth, manaBarHeight, 2, 2)
    
    -- Mana fill (bottom to top)
    local manaPercent = self.currentMana / self.maxMana
    local fillHeight = manaBarHeight * manaPercent
    love.graphics.setColor(0.3, 0.5, 0.9)
    love.graphics.rectangle("fill", manaBarX, manaBarY + (manaBarHeight - fillHeight), manaBarWidth, fillHeight, 2, 2)
    
    -- Border
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", manaBarX, manaBarY, manaBarWidth, manaBarHeight, 2, 2)
    love.graphics.setLineWidth(1)
    
    -- Draw each slot (vertical stack)
    for i = 1, totalSlots do
        local slotX = startX
        local slotY = startY + (i - 1) * (self.slotSize + self.slotSpacing)
        
        -- Check hover
        local isHovered = mouseX >= slotX and mouseX <= slotX + self.slotSize and
                         mouseY >= slotY and mouseY <= slotY + self.slotSize
        
        if isHovered then
            self.hoveredSlot = i
        end
        
        -- Draw slot background
        if isHovered then
            love.graphics.setColor(0.25, 0.22, 0.18, 0.95)
        elseif i == self.selectedSlot then
            love.graphics.setColor(0.20, 0.18, 0.14, 0.9)
        else
            love.graphics.setColor(0.15, 0.13, 0.11, 0.8)
        end
        love.graphics.rectangle("fill", slotX, slotY, self.slotSize, self.slotSize, 3, 3)
        
        -- Draw spell if equipped
        local spell = self.equippedSpells[i]
        if spell then
            spell:draw(slotX, slotY, self.slotSize, isHovered, true)
        end
        
        -- Draw slot border
        if isHovered then
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
        elseif i == self.selectedSlot then
            love.graphics.setColor(0.7, 0.6, 0.3)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.35, 0.30, 0.20)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", slotX, slotY, self.slotSize, self.slotSize, 3, 3)
        love.graphics.setLineWidth(1)
    end
    
    -- Draw hover tooltip
    if self.hoveredSlot and self.equippedSpells[self.hoveredSlot] then
        self:drawSlotTooltip(self.equippedSpells[self.hoveredSlot], mouseX, mouseY)
    end
    
    love.graphics.setColor(1, 1, 1)
end

function SpellSystem:drawSlotTooltip(spell, mouseX, mouseY)
    local padding = 10
    local lineHeight = 16
    
    -- Build tooltip text lines
    local lines = {
        spell.name,
        string.format("Mana: %d  Cooldown: %.1fs", spell.manaCost, spell.cooldown),
        string.format("Duration: %.0fs  Radius: %.0f", spell:getCurrentDuration(), spell:getCurrentRadius()),
        string.format("Level %d/%d", spell.level, spell.maxLevel)
    }
    
    -- Calculate tooltip size
    local font = love.graphics.getFont()
    local maxWidth = 0
    for _, line in ipairs(lines) do
        maxWidth = math.max(maxWidth, font:getWidth(line))
    end
    
    local tooltipWidth = maxWidth + padding * 2
    local tooltipHeight = (#lines * lineHeight) + padding * 2
    
    -- Position tooltip (avoid screen edges)
    local tooltipX = mouseX + 15
    local tooltipY = mouseY
    
    if tooltipX + tooltipWidth > love.graphics.getWidth() then
        tooltipX = mouseX - tooltipWidth - 5
    end
    if tooltipY + tooltipHeight > love.graphics.getHeight() then
        tooltipY = love.graphics.getHeight() - tooltipHeight
    end
    
    -- Draw tooltip background
    love.graphics.setColor(0.12, 0.10, 0.08, 0.95)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
    
    -- Border
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Draw text
    love.graphics.setColor(1, 0.95, 0.7)
    for i, line in ipairs(lines) do
        love.graphics.print(line, tooltipX + padding, tooltipY + padding + (i - 1) * lineHeight)
    end
end

function SpellSystem:drawSpellMenu()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local panelWidth = 500
    local panelHeight = 400
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = (screenHeight - panelHeight) / 2
    
    -- Semi-transparent background overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Main panel background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
    
    -- Border
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Header
    local headerHeight = 40
    love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
    love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth - 4, headerHeight - 2, 3, 3)
    
    love.graphics.setColor(1, 0.95, 0.7)
    local font = love.graphics.getFont()
    local headerText = "Spell Book"
    local textWidth = font:getWidth(headerText)
    love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, panelY + 12)
    
    -- Divider
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 8, panelY + headerHeight, panelX + panelWidth - 8, panelY + headerHeight)
    love.graphics.setLineWidth(1)
    
    -- Split into two columns
    local listWidth = 200
    local detailsWidth = panelWidth - listWidth - 30
    local contentY = panelY + headerHeight + 15
    local contentHeight = panelHeight - headerHeight - 80
    
    -- Left column: Spell list
    local listX = panelX + 15
    love.graphics.setColor(1, 0.95, 0.7)
    love.graphics.print("Learned Spells:", listX, contentY)
    
    local spellListY = contentY + 25
    local mouseX, mouseY = love.mouse.getPosition()
    self.hoveredMenuSpell = nil
    
    for i, spell in ipairs(self.learnedSpells) do
        local itemY = spellListY + (i - 1) * 55
        local itemHeight = 50
        
        -- Check hover
        local isHovered = mouseX >= listX and mouseX <= listX + listWidth and
                         mouseY >= itemY and mouseY <= itemY + itemHeight
        
        if isHovered then
            self.hoveredMenuSpell = spell
            love.graphics.setColor(0.25, 0.22, 0.18, 0.9)
        else
            love.graphics.setColor(0.15, 0.13, 0.11, 0.6)
        end
        
        love.graphics.rectangle("fill", listX, itemY, listWidth, itemHeight, 3, 3)
        
        -- Border
        if isHovered then
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.35, 0.30, 0.20)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", listX, itemY, listWidth, itemHeight, 3, 3)
        love.graphics.setLineWidth(1)
        
        -- Draw spell icon
        spell:draw(listX + 5, itemY + 5, 40, isHovered, false)
        
        -- Draw spell name
        love.graphics.setColor(1, 0.95, 0.7)
        love.graphics.print(spell.name, listX + 52, itemY + 10)
        
        -- Draw level
        love.graphics.setColor(0.9, 0.85, 0.6)
        love.graphics.print(string.format("Lv.%d", spell.level), listX + 52, itemY + 28)
    end
    
    -- Right column: Spell details
    local detailsX = panelX + listWidth + 30
    if self.selectedSpell or self.hoveredMenuSpell then
        local spell = self.hoveredMenuSpell or self.selectedSpell
        
        love.graphics.setColor(1, 0.95, 0.7)
        love.graphics.print("Spell Details:", detailsX, contentY)
        
        local detailY = contentY + 30
        
        -- Draw large icon
        spell:draw(detailsX + (detailsWidth - 64) / 2, detailY, 64, false, false)
        detailY = detailY + 74
        
        -- Name
        love.graphics.setColor(1, 0.95, 0.7)
        local nameWidth = font:getWidth(spell.name)
        love.graphics.print(spell.name, detailsX + (detailsWidth - nameWidth) / 2, detailY)
        detailY = detailY + 25
        
        -- Description
        love.graphics.setColor(0.9, 0.85, 0.7)
        love.graphics.printf(spell.description, detailsX, detailY, detailsWidth, "left")
        detailY = detailY + 40
        
        -- Stats
        love.graphics.setColor(0.8, 0.75, 0.6)
        love.graphics.print(string.format("Mana Cost: %d", spell.manaCost), detailsX, detailY)
        detailY = detailY + 18
        love.graphics.print(string.format("Cooldown: %.1fs", spell.cooldown), detailsX, detailY)
        detailY = detailY + 18
        love.graphics.print(string.format("Duration: %.0fs", spell:getCurrentDuration()), detailsX, detailY)
        detailY = detailY + 18
        love.graphics.print(string.format("Radius: %.0fpx", spell:getCurrentRadius()), detailsX, detailY)
        detailY = detailY + 25
        
        -- Level and experience
        love.graphics.setColor(0.9, 0.75, 0.2)
        love.graphics.print(string.format("Level %d / %d", spell.level, spell.maxLevel), detailsX, detailY)
        detailY = detailY + 20
        
        if spell.level < spell.maxLevel then
            -- XP bar
            local xpBarWidth = detailsWidth
            local xpBarHeight = 12
            
            -- Background
            love.graphics.setColor(0.15, 0.13, 0.11, 0.8)
            love.graphics.rectangle("fill", detailsX, detailY, xpBarWidth, xpBarHeight, 2, 2)
            
            -- Fill
            local progress = spell:getExperienceProgress()
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.rectangle("fill", detailsX, detailY, xpBarWidth * progress, xpBarHeight, 2, 2)
            
            -- Border
            love.graphics.setColor(0.65, 0.55, 0.20)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", detailsX, detailY, xpBarWidth, xpBarHeight, 2, 2)
            love.graphics.setLineWidth(1)
            
            -- Text
            love.graphics.setColor(1, 1, 1)
            local xpText = string.format("%d / %d XP", math.floor(spell.experience), spell.experienceThresholds[spell.level])
            local xpTextWidth = font:getWidth(xpText)
            love.graphics.print(xpText, detailsX + (xpBarWidth - xpTextWidth) / 2, detailY + 2)
        else
            love.graphics.setColor(0.9, 0.75, 0.2)
            love.graphics.print("MAX LEVEL", detailsX, detailY)
        end
    elseif #self.learnedSpells == 0 then
        love.graphics.setColor(0.6, 0.55, 0.45)
        love.graphics.printf("No spells learned yet.\nFind magical scrolls to learn spells!", detailsX, contentY + 50, detailsWidth, "center")
    else
        love.graphics.setColor(0.6, 0.55, 0.45)
        love.graphics.printf("Hover over a spell to see details.", detailsX, contentY + 50, detailsWidth, "center")
    end
    
    -- Bottom: Slot selector and equip button
    local bottomY = panelY + panelHeight - 60
    love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
    love.graphics.rectangle("fill", panelX + 10, bottomY, panelWidth - 20, 50, 3, 3)
    
    love.graphics.setColor(1, 0.95, 0.7)
    love.graphics.print("Select Slot:", panelX + 20, bottomY + 10)
    
    -- Slot selector buttons
    local slotButtonSize = 32
    local slotButtonSpacing = 8
    local slotStartX = panelX + 120
    
    for i = 1, 5 do
        local slotBtnX = slotStartX + (i - 1) * (slotButtonSize + slotButtonSpacing)
        local slotBtnY = bottomY + 10
        
        -- Check hover
        local isHovered = mouseX >= slotBtnX and mouseX <= slotBtnX + slotButtonSize and
                         mouseY >= slotBtnY and mouseY <= slotBtnY + slotButtonSize
        
        -- Background
        if i == self.selectedSlot then
            love.graphics.setColor(0.3, 0.25, 0.18)
        elseif isHovered then
            love.graphics.setColor(0.25, 0.22, 0.18)
        else
            love.graphics.setColor(0.18, 0.16, 0.12)
        end
        love.graphics.rectangle("fill", slotBtnX, slotBtnY, slotButtonSize, slotButtonSize, 3, 3)
        
        -- Border
        if i == self.selectedSlot then
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
        elseif isHovered then
            love.graphics.setColor(0.7, 0.6, 0.3)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.35, 0.30, 0.20)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", slotBtnX, slotBtnY, slotButtonSize, slotButtonSize, 3, 3)
        love.graphics.setLineWidth(1)
        
        -- Number
        love.graphics.setColor(1, 0.95, 0.7)
        local numText = tostring(i)
        local numWidth = font:getWidth(numText)
        love.graphics.print(numText, slotBtnX + (slotButtonSize - numWidth) / 2, slotBtnY + 8)
    end
    
    -- Equip button
    local equipBtnWidth = 100
    local equipBtnHeight = 32
    local equipBtnX = panelX + panelWidth - equipBtnWidth - 20
    local equipBtnY = bottomY + 10
    
    local canEquip = (self.hoveredMenuSpell or self.selectedSpell) ~= nil
    local equipHovered = mouseX >= equipBtnX and mouseX <= equipBtnX + equipBtnWidth and
                        mouseY >= equipBtnY and mouseY <= equipBtnY + equipBtnHeight
    
    -- Button background
    if canEquip then
        if equipHovered then
            love.graphics.setColor(0.35, 0.55, 0.35)
        else
            love.graphics.setColor(0.25, 0.45, 0.25)
        end
    else
        love.graphics.setColor(0.2, 0.18, 0.15)
    end
    love.graphics.rectangle("fill", equipBtnX, equipBtnY, equipBtnWidth, equipBtnHeight, 3, 3)
    
    -- Button border
    if canEquip and equipHovered then
        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(0.35, 0.30, 0.20)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", equipBtnX, equipBtnY, equipBtnWidth, equipBtnHeight, 3, 3)
    love.graphics.setLineWidth(1)
    
    -- Button text
    if canEquip then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.5, 0.45, 0.35)
    end
    local equipText = "Equip"
    local equipTextWidth = font:getWidth(equipText)
    love.graphics.print(equipText, equipBtnX + (equipBtnWidth - equipTextWidth) / 2, equipBtnY + 8)
    
    -- Close hint
    love.graphics.setColor(0.6, 0.55, 0.45)
    love.graphics.print("[B] or [ESC] to close", panelX + 20, panelY + panelHeight - 22)
    
    love.graphics.setColor(1, 1, 1)
end

function SpellSystem:drawSpellMessage()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local padding = 15
    local panelHeight = 60
    local panelWidth = 400
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = screenHeight / 2 - 100
    
    -- Background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.90)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
    
    -- Border
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Text
    love.graphics.setColor(1, 0.95, 0.8)
    love.graphics.printf(self.currentSpellMessage, panelX + padding, panelY + panelHeight / 2 - 10, panelWidth - padding * 2, "center")
    
    love.graphics.setColor(1, 1, 1)
end

-- Spell management functions
function SpellSystem:learnSpell(spell)
    -- Check if already learned
    for _, learned in ipairs(self.learnedSpells) do
        if learned.name == spell.name then
            return false, "Already learned this spell"
        end
    end
    
    table.insert(self.learnedSpells, spell)
    
    -- Sync with game state for save/load
    if not self.gameState:hasSpell(spell.name) then
        self.gameState:learnSpell(spell.name)
        self.gameState:setSpellLevel(spell.name, spell.level)
        self.gameState:setSpellExperience(spell.name, spell.experience)
    end
    
    self.currentSpellMessage = string.format("Learned: %s!", spell.name)
    self.spellMessageTimer = self.spellMessageDuration
    return true, "Spell learned"
end

function SpellSystem:rebuildLearnedSpells()
    -- Clear current learned spells
    self.learnedSpells = {}
    
    local Spell = require("spell")
    
    -- Rebuild from game state
    for _, spellName in ipairs(self.gameState.learnedSpells) do
        local spell = nil
        
        if spellName == "Illumination" then
            spell = Spell.createIllumination()
        elseif spellName == "Fireball" then
            spell = Spell.createFireball()
        elseif spellName == "Ice Shard" then
            spell = Spell.createIceShard()
        elseif spellName == "Lightning Bolt" then
            spell = Spell.createLightningBolt()
        elseif spellName == "Stone Spike" then
            spell = Spell.createStoneSpike()
        end
        
        if spell then
            spell.level = self.gameState:getSpellLevel(spellName)
            spell.experience = self.gameState:getSpellExperience(spellName)
            table.insert(self.learnedSpells, spell)
        end
    end
    
    -- Rebuild equipped spells
    for i = 1, 5 do
        local equippedName = self.gameState.equippedSpells[i]
        if equippedName then
            for _, spell in ipairs(self.learnedSpells) do
                if spell.name == equippedName then
                    self.equippedSpells[i] = spell
                    break
                end
            end
        else
            self.equippedSpells[i] = nil
        end
    end
end

function SpellSystem:equipSpell(spell, slotIndex)
    if slotIndex < 1 or slotIndex > 5 then
        return false, "Invalid slot"
    end
    
    -- Check if spell is learned
    local isLearned = false
    for _, learned in ipairs(self.learnedSpells) do
        if learned == spell then
            isLearned = true
            break
        end
    end
    
    if not isLearned then
        return false, "Spell not learned"
    end
    
    self.equippedSpells[slotIndex] = spell
    
    -- Sync with game state for save/load
    self.gameState:equipSpell(spell.name, slotIndex)
    
    self.currentSpellMessage = string.format("%s equipped to slot %d", spell.name, slotIndex)
    self.spellMessageTimer = self.spellMessageDuration
    return true, "Spell equipped"
end

function SpellSystem:unequipSpell(slotIndex)
    if slotIndex < 1 or slotIndex > 5 then
        return false
    end
    
    self.equippedSpells[slotIndex] = nil
    
    -- Sync with game state for save/load
    self.gameState:unequipSpell(slotIndex)
    return true
end

function SpellSystem:activateSlot(slotIndex)
    if slotIndex < 1 or slotIndex > 5 then
        return false, "Invalid slot"
    end
    
    local spell = self.equippedSpells[slotIndex]
    if not spell then
        return false, "No spell equipped in this slot"
    end
    
    local success, message = spell:activate(self.currentMana)
    if success then
        self.currentMana = self.currentMana - spell.manaCost
        
        -- Create particle emitter for this spell (non-attack spells)
        if spell.particleConfig and not spell.damage then
            local emitter = ParticleSystem.createEmitter(0, 0, "illumination", spell.particleConfig)
            self.particleEmitters[slotIndex] = emitter
        end
        
        -- Don't show success message, let animations speak for themselves
    else
        -- Only show error messages (not enough mana, on cooldown, etc)
        self.currentSpellMessage = message
        self.spellMessageTimer = 2
    end
    
    return success, spell  -- Return spell object instead of message
end

function SpellSystem:toggleSpellMenu()
    self.showSpellMenu = not self.showSpellMenu
end

function SpellSystem:handleClick(mouseX, mouseY)
    if not self.showSpellMenu then return end
    
    -- Handle spell list clicks
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local panelWidth = 500
    local panelHeight = 400
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = (screenHeight - panelHeight) / 2
    
    local listX = panelX + 15
    local contentY = panelY + 40 + 15
    local spellListY = contentY + 25
    local listWidth = 200
    
    -- Check spell list clicks
    for i, spell in ipairs(self.learnedSpells) do
        local itemY = spellListY + (i - 1) * 55
        local itemHeight = 50
        
        if mouseX >= listX and mouseX <= listX + listWidth and
           mouseY >= itemY and mouseY <= itemY + itemHeight then
            self.selectedSpell = spell
            return
        end
    end
    
    -- Check slot selector clicks
    local bottomY = panelY + panelHeight - 60
    local slotButtonSize = 32
    local slotButtonSpacing = 8
    local slotStartX = panelX + 120
    
    for i = 1, 5 do
        local slotBtnX = slotStartX + (i - 1) * (slotButtonSize + slotButtonSpacing)
        local slotBtnY = bottomY + 10
        
        if mouseX >= slotBtnX and mouseX <= slotBtnX + slotButtonSize and
           mouseY >= slotBtnY and mouseY <= slotBtnY + slotButtonSize then
            self.selectedSlot = i
            return
        end
    end
    
    -- Check equip button click
    local equipBtnWidth = 100
    local equipBtnHeight = 32
    local equipBtnX = panelX + panelWidth - equipBtnWidth - 20
    local equipBtnY = bottomY + 10
    
    if mouseX >= equipBtnX and mouseX <= equipBtnX + equipBtnWidth and
       mouseY >= equipBtnY and mouseY <= equipBtnY + equipBtnHeight then
        local spell = self.hoveredMenuSpell or self.selectedSpell
        if spell then
            self:equipSpell(spell, self.selectedSlot)
        end
        return
    end
end

return SpellSystem

