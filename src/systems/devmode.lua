-- Developer Mode - Testing and debugging tools
local DevMode = {}

function DevMode:new()
    local devMode = {
        enabled = false,
        showPanel = false,
        
        -- Level list
        availableLevels = {
            {name = "overworld", display = "Overworld", spawnX = 40*32, spawnY = 30*32},
            {name = "house_interior", display = "House Interior", spawnX = 7*32, spawnY = 9*32},
            {name = "cave_level1", display = "Cave Level 1", spawnX = 3*32, spawnY = 12*32},
            {name = "class_selection", display = "Class Selection", spawnX = 3*32, spawnY = 15*32},
            {name = "defense_trials", display = "Defense Trials", spawnX = 14*32, spawnY = 35*32},
            {name = "town", display = "Sanctuary Village", spawnX = 24*32, spawnY = 37*32},
            {name = "inn_interior", display = "The Restful Inn", spawnX = 10*32, spawnY = 12*32},
            {name = "potion_shop_interior", display = "Potion Shop", spawnX = 10*32, spawnY = 12*32}
        },
        
        selectedLevelIndex = 1,
        
        -- Speed modifier
        speedMultiplier = 1,
        
        -- UI state
        hoveredButton = nil
    }
    setmetatable(devMode, {__index = self})
    return devMode
end

function DevMode:toggle()
    self.enabled = not self.enabled
    self.showPanel = self.enabled
    
    if self.enabled then
        print("Developer Mode: ENABLED")
    else
        print("Developer Mode: DISABLED")
    end
end

function DevMode:togglePanel()
    if self.enabled then
        self.showPanel = not self.showPanel
    end
end

function DevMode:jumpToLevel(gameState, world, player, levelName, spawnX, spawnY)
    if not self.enabled then
        return false, "Dev mode not enabled"
    end
    
    -- Change map
    gameState:changeMap(levelName, spawnX, spawnY)
    world:loadMap(levelName)
    player.x = spawnX
    player.y = spawnY
    
    -- Sync interactables with game state (important for chest states, etc.)
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        obj:syncWithGameState(gameState)
    end
    
    print("Jumped to level: " .. levelName)
    return true, "Jumped to " .. levelName
end

function DevMode:giveAllSpells(gameState, spellSystem, Spell)
    if not self.enabled then
        return false, "Dev mode not enabled"
    end
    
    -- Enable player class and combat if not already set
    if not gameState.playerClass then
        gameState.playerClass = "Storm Mage" -- Default class for dev mode
        gameState.playerElement = "lightning"
        print("Enabled combat system (Storm Mage)")
    end
    
    -- Give Illumination spell if not already learned
    if not gameState:hasSpell("Illumination") then
        local spell = Spell.createIllumination()
        spellSystem:learnSpell(spell)
        print("Gave spell: Illumination")
    end
    
    -- Give all attack spells
    local spellCreators = {
        {name = "Fireball", create = Spell.createFireball},
        {name = "Ice Shard", create = Spell.createIceShard},
        {name = "Lightning Bolt", create = Spell.createLightningBolt},
        {name = "Stone Spike", create = Spell.createStoneSpike},
        {name = "Fire Ward", create = Spell.createFireResistance},
        {name = "Frost Barrier", create = Spell.createIceResistance},
        {name = "Storm Shield", create = Spell.createLightningResistance},
        {name = "Stone Skin", create = Spell.createEarthResistance},
        {name = "Iron Fortitude", create = Spell.createArmorBuff},
        {name = "Soul Siphon", create = Spell.createDrainBuff},
        {name = "Death Harvest", create = Spell.createNecromancerBuff}
    }
    
    for _, spellInfo in ipairs(spellCreators) do
        if not gameState:hasSpell(spellInfo.name) then
            local spell = spellInfo.create()
            spellSystem:learnSpell(spell)
            print("Gave spell: " .. spellInfo.name)
        end
    end
    
    -- Set default healing strategy if not already set
    if not gameState.healingStrategy then
        gameState.healingStrategy = "armor" -- Default to tank for dev mode
        print("Set healing strategy: armor")
    end
    
    return true, "All spells granted"
end

function DevMode:setQuestState(gameState, stateName)
    if not self.enabled then
        return false, "Dev mode not enabled"
    end
    
    gameState.questState = stateName
    print("Quest state set to: " .. stateName)
    return true, "Quest state changed"
end

function DevMode:giveAllItems(gameState)
    if not self.enabled then
        return false, "Dev mode not enabled"
    end
    
    local items = {"Gold Key", "Health Potion", "Magic Sword"}
    for _, item in ipairs(items) do
        if not gameState:hasItem(item) then
            gameState:addItem(item)
        end
    end
    
    print("Gave all items")
    return true, "All items granted"
end

function DevMode:resetProgress(gameState, world)
    if not self.enabled then
        return false, "Dev mode not enabled"
    end
    
    -- Clear chest states
    gameState.openedChests = {}
    
    -- Clear killed enemies
    gameState.killedEnemies = {}
    
    -- Sync current interactables to reflect reset
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        if obj.type == "chest" then
            obj.isOpen = false
            obj.openProgress = 0
            obj.targetProgress = 0
        end
    end
    
    print("Reset chests and enemy states")
    return true, "Progress reset"
end

function DevMode:toggleSpeed()
    if not self.enabled then return end
    
    if self.speedMultiplier == 1 then
        self.speedMultiplier = 2
    elseif self.speedMultiplier == 2 then
        self.speedMultiplier = 4
    else
        self.speedMultiplier = 1
    end
    
    print("Speed multiplier: x" .. self.speedMultiplier)
end

function DevMode:update(dt)
    -- Could add time-based dev features here
end

function DevMode:draw()
    if not self.enabled or not self.showPanel then return end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local font = love.graphics.getFont()
    
    local panelWidth = 300
    local panelX = screenWidth - panelWidth - 15
    local panelY = 15
    local padding = 12
    local buttonHeight = 30
    local buttonSpacing = 8
    
    -- Calculate dynamic panel height based on content
    -- Header (32) + Level selector (20 + 25 + 30) + Prev/Next buttons (25 + 35)
    -- + Action buttons (6 * (30 + 8)) + Bottom padding (15) + Shortcuts text (20)
    local numButtons = 6 -- jump, spells, items, reset, speed, unlock
    local panelHeight = 42 + -- Header and initial spacing
                        20 + 25 + 30 + -- Level selector
                        25 + 35 + -- Prev/Next buttons
                        (buttonHeight + buttonSpacing) * numButtons + -- Action buttons
                        15 + 20 -- Bottom padding and shortcuts
    
    -- Panel background (yellow tint to indicate dev mode)
    love.graphics.setColor(0.15, 0.13, 0.05, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
    
    -- Border (bright yellow for dev mode)
    love.graphics.setColor(0.9, 0.9, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Header
    love.graphics.setColor(0.12, 0.10, 0.02, 0.9)
    love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth - 4, 26, 3, 3)
    
    love.graphics.setColor(0.9, 0.9, 0.3)
    local headerText = "DEV MODE"
    local textWidth = font:getWidth(headerText)
    love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, panelY + 8)
    
    -- Divider
    love.graphics.setColor(0.7, 0.7, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 8, panelY + 32, panelX + panelWidth - 8, panelY + 32)
    love.graphics.setLineWidth(1)
    
    local yPos = panelY + 42
    
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    self.hoveredButton = nil
    
    -- Level selector
    love.graphics.setColor(1, 1, 0.8)
    love.graphics.print("Jump to Level:", panelX + padding, yPos)
    yPos = yPos + 20
    
    -- Level dropdown (simplified - show current and buttons)
    local currentLevel = self.availableLevels[self.selectedLevelIndex]
    love.graphics.setColor(0.2, 0.18, 0.08)
    love.graphics.rectangle("fill", panelX + padding, yPos, panelWidth - padding * 2, 25, 3, 3)
    
    love.graphics.setColor(0.7, 0.7, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX + padding, yPos, panelWidth - padding * 2, 25, 3, 3)
    love.graphics.setLineWidth(1)
    
    love.graphics.setColor(1, 1, 0.9)
    love.graphics.print(currentLevel.display, panelX + padding + 8, yPos + 6)
    
    yPos = yPos + 30
    
    -- Previous/Next buttons
    local btnWidth = (panelWidth - padding * 2 - 8) / 2
    
    -- Previous button
    local prevBtnX = panelX + padding
    local prevBtnY = yPos
    local prevHovered = mouseX >= prevBtnX and mouseX <= prevBtnX + btnWidth and
                       mouseY >= prevBtnY and mouseY <= prevBtnY + 25
    
    if prevHovered then
        self.hoveredButton = "prev_level"
        love.graphics.setColor(0.3, 0.25, 0.1)
    else
        love.graphics.setColor(0.2, 0.18, 0.08)
    end
    love.graphics.rectangle("fill", prevBtnX, prevBtnY, btnWidth, 25, 3, 3)
    
    love.graphics.setColor(0.7, 0.7, 0.2)
    love.graphics.setLineWidth(prevHovered and 2 or 1)
    love.graphics.rectangle("line", prevBtnX, prevBtnY, btnWidth, 25, 3, 3)
    love.graphics.setLineWidth(1)
    
    love.graphics.setColor(1, 1, 0.9)
    local prevText = "< Prev"
    love.graphics.print(prevText, prevBtnX + (btnWidth - font:getWidth(prevText)) / 2, prevBtnY + 6)
    
    -- Next button
    local nextBtnX = panelX + padding + btnWidth + 8
    local nextBtnY = yPos
    local nextHovered = mouseX >= nextBtnX and mouseX <= nextBtnX + btnWidth and
                       mouseY >= nextBtnY and mouseY <= nextBtnY + 25
    
    if nextHovered then
        self.hoveredButton = "next_level"
        love.graphics.setColor(0.3, 0.25, 0.1)
    else
        love.graphics.setColor(0.2, 0.18, 0.08)
    end
    love.graphics.rectangle("fill", nextBtnX, nextBtnY, btnWidth, 25, 3, 3)
    
    love.graphics.setColor(0.7, 0.7, 0.2)
    love.graphics.setLineWidth(nextHovered and 2 or 1)
    love.graphics.rectangle("line", nextBtnX, nextBtnY, btnWidth, 25, 3, 3)
    love.graphics.setLineWidth(1)
    
    love.graphics.setColor(1, 1, 0.9)
    local nextText = "Next >"
    love.graphics.print(nextText, nextBtnX + (btnWidth - font:getWidth(nextText)) / 2, nextBtnY + 6)
    
    yPos = yPos + 35
    
    -- Action buttons
    local buttons = {
        {id = "jump", text = "Jump to Level", yOffset = 0},
        {id = "spells", text = "Give All Spells", yOffset = buttonHeight + buttonSpacing},
        {id = "items", text = "Give All Items", yOffset = (buttonHeight + buttonSpacing) * 2},
        {id = "reset", text = "Reset Progress", yOffset = (buttonHeight + buttonSpacing) * 3},
        {id = "speed", text = "Speed x" .. self.speedMultiplier, yOffset = (buttonHeight + buttonSpacing) * 4},
        {id = "unlock", text = "Unlock All", yOffset = (buttonHeight + buttonSpacing) * 5}
    }
    
    for _, btn in ipairs(buttons) do
        local btnX = panelX + padding
        local btnY = yPos + btn.yOffset
        local btnW = panelWidth - padding * 2
        
        local isHovered = mouseX >= btnX and mouseX <= btnX + btnW and
                         mouseY >= btnY and mouseY <= btnY + buttonHeight
        
        if isHovered then
            self.hoveredButton = btn.id
            love.graphics.setColor(0.3, 0.28, 0.12)
        else
            love.graphics.setColor(0.22, 0.20, 0.10)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, buttonHeight, 3, 3)
        
        love.graphics.setColor(0.8, 0.8, 0.3)
        love.graphics.setLineWidth(isHovered and 2 or 1)
        love.graphics.rectangle("line", btnX, btnY, btnW, buttonHeight, 3, 3)
        love.graphics.setLineWidth(1)
        
        love.graphics.setColor(1, 1, 0.9)
        local textW = font:getWidth(btn.text)
        love.graphics.print(btn.text, btnX + (btnW - textW) / 2, btnY + 8)
    end
    
    yPos = yPos + (buttonHeight + buttonSpacing) * #buttons + 15
    
    -- Keyboard shortcuts
    love.graphics.setColor(0.7, 0.7, 0.5)
    love.graphics.print("F12: Toggle Dev Mode", panelX + padding, yPos)
    
    love.graphics.setColor(1, 1, 1)
end

function DevMode:handleClick(mouseX, mouseY, gameState, world, player, spellSystem, Spell)
    if not self.enabled or not self.showPanel then return end
    
    if self.hoveredButton == "prev_level" then
        self.selectedLevelIndex = self.selectedLevelIndex - 1
        if self.selectedLevelIndex < 1 then
            self.selectedLevelIndex = #self.availableLevels
        end
    elseif self.hoveredButton == "next_level" then
        self.selectedLevelIndex = self.selectedLevelIndex + 1
        if self.selectedLevelIndex > #self.availableLevels then
            self.selectedLevelIndex = 1
        end
    elseif self.hoveredButton == "jump" then
        local level = self.availableLevels[self.selectedLevelIndex]
        self:jumpToLevel(gameState, world, player, level.name, level.spawnX, level.spawnY)
    elseif self.hoveredButton == "spells" then
        self:giveAllSpells(gameState, spellSystem, Spell)
    elseif self.hoveredButton == "items" then
        self:giveAllItems(gameState)
    elseif self.hoveredButton == "reset" then
        self:resetProgress(gameState, world)
    elseif self.hoveredButton == "speed" then
        self:toggleSpeed()
    elseif self.hoveredButton == "unlock" then
        gameState.houseDoorLocked = false
        gameState.questState = "sword_collected"
        gameState.mysteriousCaveHidden = true
        gameState.eastPathRevealed = true
        -- Don't set townGreetingShown = true, let player experience the cutscene
        gameState.defenseTrialsCompleted = true
        gameState.resistanceSpellLearned = true
        gameState.gold = 200
        print("Unlocked all progression gates (including town access and 200 gold)")
    end
end

return DevMode


