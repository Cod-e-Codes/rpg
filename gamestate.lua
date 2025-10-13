-- Game State Management
local GameState = {}

function GameState:new()
    local state = {
        openedChests = {},
        killedEnemies = {}, -- Table: {enemyID = true} for tracking defeated enemies
        inventory = {}, -- Table: {["item_name"] = count}
        quickSlots = {nil, nil, nil, nil, nil}, -- Quick slots for keys 6,7,8,9,0
        currentMap = "overworld",
        playerSpawn = {x = 400, y = 300},
        questState = "initial", -- Quest progression tracking
        playerClass = nil, -- Chosen wizard class (Fire Mage, Ice Mage, etc.)
        playerElement = nil, -- Element type (fire, ice, lightning, earth)
        playerName = "Hero", -- Player's name (set at start screen)
        playerHealth = 100, -- Current health
        playerX = 400, -- Saved X position
        playerY = 300, -- Saved Y position
        houseDoorLocked = true, -- House starts locked
        
        -- Spell system
        learnedSpells = {}, -- Array of spell names (string identifiers)
        equippedSpells = {nil, nil, nil, nil, nil}, -- 5 slots (spell names)
        spellLevels = {}, -- {spellName = level}
        spellExperience = {}, -- {spellName = experience}
        
        -- Player stats
        currentMana = 100,
        maxMana = 100,
        
        -- Level progression
        levelHistory = {}, -- Array of completed level names
        playTime = 0 -- Total play time in seconds
    }
    setmetatable(state, {__index = self})
    return state
end

function GameState:openChest(chestId)
    self.openedChests[chestId] = true
end

function GameState:isChestOpened(chestId)
    return self.openedChests[chestId] or false
end

function GameState:killEnemy(enemyId)
    self.killedEnemies[enemyId] = true
end

function GameState:isEnemyKilled(enemyId)
    return self.killedEnemies[enemyId] or false
end

function GameState:addItem(item)
    -- Stack items - increment count if already exists
    if self.inventory[item] then
        self.inventory[item] = self.inventory[item] + 1
    else
        self.inventory[item] = 1
    end
    
    -- Check if item affects quest
    if item == "Gold Key" then
        -- If player hasn't talked to merchant yet, advance to looking_for_key first
        if self.questState == "initial" then
            self.questState = "looking_for_key"
        end
        -- Then advance to has_key if they were looking
        if self.questState == "looking_for_key" then
            self.questState = "has_key"
        end
    elseif item == "Magic Sword" and self.questState == "inside_house" then
        self.questState = "sword_collected"
    end
end

function GameState:removeItem(item, count)
    count = count or 1
    if self.inventory[item] then
        self.inventory[item] = self.inventory[item] - count
        if self.inventory[item] <= 0 then
            self.inventory[item] = nil
            
            -- Also unequip from quick slots if equipped
            for i = 1, 5 do
                if self.quickSlots[i] == item then
                    self.quickSlots[i] = nil
                end
            end
        end
        return true
    end
    return false
end

function GameState:hasItem(item)
    return self.inventory[item] and self.inventory[item] > 0
end

function GameState:getItemCount(item)
    return self.inventory[item] or 0
end


function GameState:changeMap(mapName, spawnX, spawnY)
    self.currentMap = mapName
    self.playerSpawn = {x = spawnX, y = spawnY}
    
    -- Check if entering house with merchant
    if mapName == "house_interior" and self.questState == "house_unlocked" then
        self.questState = "inside_house"
    end
end

function GameState:unlockHouseDoor()
    self.houseDoorLocked = false
    self.questState = "house_unlocked"
end

function GameState:isHouseDoorLocked()
    return self.houseDoorLocked
end

-- Spell management
function GameState:learnSpell(spellName)
    -- Check if already learned
    for _, learned in ipairs(self.learnedSpells) do
        if learned == spellName then
            return false
        end
    end
    
    table.insert(self.learnedSpells, spellName)
    self.spellLevels[spellName] = 1
    self.spellExperience[spellName] = 0
    return true
end

function GameState:hasSpell(spellName)
    for _, learned in ipairs(self.learnedSpells) do
        if learned == spellName then
            return true
        end
    end
    return false
end

function GameState:equipSpell(spellName, slotIndex)
    if slotIndex < 1 or slotIndex > 5 then
        return false
    end
    
    if not self:hasSpell(spellName) then
        return false
    end
    
    self.equippedSpells[slotIndex] = spellName
    return true
end

function GameState:unequipSpell(slotIndex)
    if slotIndex < 1 or slotIndex > 5 then
        return false
    end
    
    self.equippedSpells[slotIndex] = nil
    return true
end

function GameState:setSpellLevel(spellName, level)
    self.spellLevels[spellName] = level
end

function GameState:getSpellLevel(spellName)
    return self.spellLevels[spellName] or 1
end

function GameState:setSpellExperience(spellName, experience)
    self.spellExperience[spellName] = experience
end

function GameState:getSpellExperience(spellName)
    return self.spellExperience[spellName] or 0
end

-- Level progression
function GameState:completeLevel(levelName)
    -- Check if already completed
    for _, completed in ipairs(self.levelHistory) do
        if completed == levelName then
            return false
        end
    end
    
    table.insert(self.levelHistory, levelName)
    return true
end

function GameState:hasCompletedLevel(levelName)
    for _, completed in ipairs(self.levelHistory) do
        if completed == levelName then
            return true
        end
    end
    return false
end

return GameState

