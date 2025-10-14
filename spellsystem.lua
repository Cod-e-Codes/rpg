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
        spellMenuWidth = 0, -- Current animated width
        spellMenuTargetWidth = 0, -- Target width for lerping
        spellMenuScrollOffset = 0, -- Scroll offset for spell list
        selectedSpellForEquip = nil, -- Currently selected spell to equip
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
    -- Lerp spell menu width
    local lerpSpeed = 12
    self.spellMenuWidth = self.spellMenuWidth + (self.spellMenuTargetWidth - self.spellMenuWidth) * lerpSpeed * dt
    
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
    
    -- Draw spell menu if it has any width (for lerp animation)
    if self.spellMenuWidth > 5 then
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
    if self.spellMenuWidth < 5 then return end -- Don't draw if not visible
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local panelWidth = self.spellMenuWidth
    local panelHeight = screenHeight
    local panelX = 0
    local panelY = 0
    
    -- Semi-transparent background overlay (only if fully open)
    if self.spellMenuWidth > 400 then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end
    
    -- Main panel background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    
    -- Border on right edge
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.line(panelWidth, 0, panelWidth, screenHeight)
    love.graphics.setLineWidth(1)
    
    -- Header
    local headerHeight = 40
    love.graphics.setColor(1, 0.95, 0.7)
    local font = love.graphics.getFont()
    local headerText = "Spell Book"
    love.graphics.print(headerText, panelX + 10, panelY + 12)
    
    -- Divider
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 5, panelY + headerHeight, panelX + panelWidth - 5, panelY + headerHeight)
    love.graphics.setLineWidth(1)
    
    -- Spell list
    local listWidth = panelWidth - 30
    local contentY = panelY + headerHeight + 15
    -- Reserve more space at bottom for equipped slots section (170px total)
    local contentHeight = panelHeight - headerHeight - 170
    
    local listX = panelX + 15
    love.graphics.setColor(1, 0.95, 0.7)
    love.graphics.print("Click spell, then click slot:", listX, contentY)
    
    local spellListY = contentY + 25
    local mouseX, mouseY = love.mouse.getPosition()
    self.hoveredMenuSpell = nil
    
    -- Calculate max scroll based on total spell list height
    local totalSpellListHeight = #self.learnedSpells * 55
    local maxScroll = math.max(0, totalSpellListHeight - contentHeight)
    self.spellMenuScrollOffset = math.max(0, math.min(self.spellMenuScrollOffset, maxScroll))
    
    -- Set up scissor testing to clip spell list to content area (only if dimensions are valid)
    if listWidth > 0 and contentHeight > 0 then
        love.graphics.setScissor(listX, spellListY, listWidth, contentHeight)
    end
    
    for i, spell in ipairs(self.learnedSpells) do
        local itemY = spellListY + (i - 1) * 55 - self.spellMenuScrollOffset
        local itemHeight = 50
        
        -- Skip if item is outside visible area (optimization)
        if itemY + itemHeight < spellListY or itemY > spellListY + contentHeight then
            goto continue
        end
        
        -- Check if selected
        local isSelected = (self.selectedSpellForEquip == spell)
        
        -- Check hover (only within scrollable area)
        local isHovered = mouseX >= listX and mouseX <= listX + listWidth and
                         mouseY >= itemY and mouseY <= itemY + itemHeight and
                         mouseY >= spellListY and mouseY <= spellListY + contentHeight
        
        if isHovered then
            self.hoveredMenuSpell = spell
        end
        
        -- Background
        if isSelected then
            love.graphics.setColor(0.35, 0.30, 0.22, 0.9)
        elseif isHovered then
            love.graphics.setColor(0.25, 0.22, 0.18, 0.9)
        else
            love.graphics.setColor(0.15, 0.13, 0.11, 0.6)
        end
        
        love.graphics.rectangle("fill", listX, itemY, listWidth, itemHeight, 3, 3)
        
        -- Border
        if isSelected then
            love.graphics.setColor(1, 0.9, 0.4)
            love.graphics.setLineWidth(3)
        elseif isHovered then
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.35, 0.30, 0.20)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", listX, itemY, listWidth, itemHeight, 3, 3)
        love.graphics.setLineWidth(1)
        
        -- Draw spell icon
        spell:draw(listX + 5, itemY + 5, 40, false, false)
        
        -- Draw spell name
        love.graphics.setColor(1, 0.95, 0.7)
        love.graphics.print(spell.name, listX + 52, itemY + 10)
        
        -- Draw level
        love.graphics.setColor(0.9, 0.85, 0.6)
        love.graphics.print(string.format("Lv.%d", spell.level), listX + 52, itemY + 28)
        
        ::continue::
    end
    
    -- Disable scissor testing
    love.graphics.setScissor()
    
    -- Draw hover tooltip for spell details
    if self.hoveredMenuSpell then
        local spell = self.hoveredMenuSpell
        self:drawSpellTooltip(spell, mouseX, mouseY)
    end
    
    -- Spell slots at bottom (click to equip selected spell)
    local slotSize = 48
    local slotSpacing = 8
    local slotsStartY = screenHeight - 80
    local slotsStartX = panelX + (panelWidth - (5 * (slotSize + slotSpacing))) / 2
    
    love.graphics.setColor(1, 0.95, 0.7)
    love.graphics.print("Equipped Spells (click to equip/unequip):", panelX + 10, slotsStartY - 25)
    
    for i = 1, 5 do
        local slotX = slotsStartX + (i - 1) * (slotSize + slotSpacing)
        local slotY = slotsStartY
        
        -- Background
        love.graphics.setColor(0.18, 0.16, 0.12, 0.9)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 3, 3)
        
        -- Draw equipped spell icon if any
        local equippedSpell = self.equippedSpells[i]
        if equippedSpell then
            equippedSpell:draw(slotX + 4, slotY + 4, slotSize - 8, false, false)
        end
        
        -- Border
        love.graphics.setColor(0.35, 0.30, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 3, 3)
        love.graphics.setLineWidth(1)
        
        -- Slot number
        love.graphics.setColor(0.8, 0.75, 0.6)
        love.graphics.print(tostring(i), slotX + slotSize - 12, slotY + slotSize - 16)
    end
    
    -- Close hint
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("[B] or [ESC] to close", panelX + 10, screenHeight - 25)
    
    love.graphics.setColor(1, 1, 1)
end

function SpellSystem:drawSpellTooltip(spell, mouseX, mouseY)
    local padding = 10
    local lineHeight = 18
    local font = love.graphics.getFont()
    local maxTooltipWidth = 250
    local wrapWidth = maxTooltipWidth - padding * 2
    
    -- Wrap description text
    local wrappedDescription, wrappedLines = font:getWrap(spell.description, wrapWidth)
    
    -- Build tooltip lines
    local lines = {spell.name, ""}
    for _, line in ipairs(wrappedLines) do
        table.insert(lines, line)
    end
    table.insert(lines, "")
    table.insert(lines, string.format("Mana: %d", spell.manaCost))
    table.insert(lines, string.format("Cooldown: %.1fs", spell.cooldown))
    
    -- Add spell-specific stats
    if spell.damage then
        local totalDamage = spell.damage + (spell.level - 1) * (spell.damagePerLevel or 0)
        table.insert(lines, string.format("Damage: %d", totalDamage))
    end
    if spell.duration and not spell.damage then
        table.insert(lines, string.format("Duration: %.0fs", spell:getCurrentDuration()))
    end
    if spell.radius and not spell.damage then
        table.insert(lines, string.format("Radius: %.0fpx", spell:getCurrentRadius()))
    end
    
    table.insert(lines, string.format("Level %d/%d", spell.level, spell.maxLevel))
    
    -- Calculate size
    local tooltipWidth = maxTooltipWidth
    local tooltipHeight = (#lines * lineHeight) + padding * 2
    
    -- Position (right side of spell menu)
    local tooltipX = self.spellMenuWidth + 10
    local tooltipY = mouseY - tooltipHeight / 2
    
    -- Keep on screen
    if tooltipY < 0 then tooltipY = 0 end
    if tooltipY + tooltipHeight > love.graphics.getHeight() then
        tooltipY = love.graphics.getHeight() - tooltipHeight
    end
    
    -- Background
    love.graphics.setColor(0.12, 0.10, 0.08, 0.95)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
    
    -- Border
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Text
    love.graphics.setColor(1, 0.95, 0.7)
    local yPos = tooltipY + padding
    for _, line in ipairs(lines) do
        love.graphics.print(line, tooltipX + padding, yPos)
        yPos = yPos + lineHeight
    end
end


function SpellSystem:drawSpellMessage()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local padding = 15
    local panelHeight = 60
    local panelWidth = 200  -- Narrower message panel
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = screenHeight / 2 + 100  -- Moved down 200 pixels from center
    
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
        
        -- Basic elemental spells
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
        
        -- Defense trial strategy spells
        elseif spellName == "Iron Fortitude" then
            spell = Spell.createArmorBuff()
        elseif spellName == "Soul Siphon" then
            spell = Spell.createDrainBuff()
        elseif spellName == "Death Harvest" then
            spell = Spell.createNecromancerBuff()
        
        -- Elemental resistance spells
        elseif spellName == "Fire Resistance" then
            spell = Spell.createFireResistance()
        elseif spellName == "Ice Resistance" then
            spell = Spell.createIceResistance()
        elseif spellName == "Lightning Resistance" then
            spell = Spell.createLightningResistance()
        elseif spellName == "Earth Resistance" then
            spell = Spell.createEarthResistance()
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
    if self.showSpellMenu then
        self.spellMenuTargetWidth = 450
    else
        self.spellMenuTargetWidth = 0
        self.selectedSpell = nil -- Clear selection when closing
    end
end

function SpellSystem:handleClick(mouseX, mouseY)
    if not self.showSpellMenu or self.spellMenuWidth < 400 then return end
    
    local screenHeight = love.graphics.getHeight()
    local panelX = 0
    local panelY = 0
    local panelHeight = screenHeight
    local headerHeight = 40
    local contentY = panelY + headerHeight + 15
    local contentHeight = panelHeight - headerHeight - 170
    local spellListY = contentY + 25
    local listX = panelX + 15
    local listWidth = self.spellMenuWidth - 30
    
    -- Check if clicking on spell list (only within scrollable area)
    if mouseX >= listX and mouseX <= listX + listWidth and
       mouseY >= spellListY and mouseY <= spellListY + contentHeight then
        for i, spell in ipairs(self.learnedSpells) do
            local itemY = spellListY + (i - 1) * 55 - self.spellMenuScrollOffset
            local itemHeight = 50
            
            if mouseY >= itemY and mouseY <= itemY + itemHeight then
                -- Toggle selection
                if self.selectedSpellForEquip == spell then
                    self.selectedSpellForEquip = nil
                else
                    self.selectedSpellForEquip = spell
                end
                return
            end
        end
    end
    
    -- Check if clicking on spell slots
    local slotSize = 48
    local slotSpacing = 8
    local slotsStartY = screenHeight - 80
    local slotsStartX = panelX + (self.spellMenuWidth - (5 * (slotSize + slotSpacing))) / 2
    
    for i = 1, 5 do
        local slotX = slotsStartX + (i - 1) * (slotSize + slotSpacing)
        local slotY = slotsStartY
        
        if mouseX >= slotX and mouseX <= slotX + slotSize and
           mouseY >= slotY and mouseY <= slotY + slotSize then
            -- Clicked on slot
            if self.selectedSpellForEquip then
                -- Equip selected spell to this slot
                self:equipSpell(self.selectedSpellForEquip, i)
                self.selectedSpellForEquip = nil
            elseif self.equippedSpells[i] then
                -- Unequip spell from this slot
                self:unequipSpell(i)
            end
            return
        end
    end
end

return SpellSystem

