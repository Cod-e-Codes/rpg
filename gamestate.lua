-- Game State Management
local GameState = {}

function GameState:new()
    local state = {
        openedChests = {},
        inventory = {},
        currentMap = "overworld",
        playerSpawn = {x = 400, y = 300},
        questState = "initial", -- Quest progression tracking
        houseDoorLocked = true -- House starts locked
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

return GameState

