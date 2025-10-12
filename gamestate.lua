-- Game State Management
local GameState = {}

function GameState:new()
    local state = {
        openedChests = {},
        inventory = {},
        currentMap = "overworld",
        playerSpawn = {x = 400, y = 300}
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
end

function GameState:changeMap(mapName, spawnX, spawnY)
    self.currentMap = mapName
    self.playerSpawn = {x = spawnX, y = spawnY}
end

return GameState

