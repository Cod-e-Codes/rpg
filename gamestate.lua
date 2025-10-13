-- Game State Management
local GameState = {}

function GameState:new()
    local state = {
        openedChests = {},
        inventory = {},
        currentMap = "overworld",
        playerSpawn = {x = 400, y = 300},
        questState = "initial", -- Quest progression tracking
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

function GameState:addItem(item)
    table.insert(self.inventory, item)
    
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

function GameState:hasItem(item)
    for _, invItem in ipairs(self.inventory) do
        if invItem == item then
            return true
        end
    end
    return false
end

function GameState:removeItem(item)
    for i, invItem in ipairs(self.inventory) do
        if invItem == item then
            table.remove(self.inventory, i)
            return true
        end
    end
    return false
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

