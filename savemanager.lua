-- Save/Load System for game state persistence
local SaveManager = {}

-- JSON encoding/decoding (using simple implementation since LÖVE doesn't have built-in JSON)
local function encodeJSON(data)
    return SaveManager.simpleEncode(data)
end

local function decodeJSON(str)
    return SaveManager.simpleDecode(str)
end

-- Simple JSON-like encoder (fallback)
function SaveManager.simpleEncode(data, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    
    if type(data) == "table" then
        local result = "{\n"
        local first = true
        for k, v in pairs(data) do
            if not first then
                result = result .. ",\n"
            end
            first = false
            -- Use Lua table syntax instead of JSON
            if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
                result = result .. spacing .. "  " .. k .. " = " .. SaveManager.simpleEncode(v, indent + 1)
            else
                result = result .. spacing .. "  [" .. SaveManager.simpleEncode(k, 0) .. "] = " .. SaveManager.simpleEncode(v, indent + 1)
            end
        end
        result = result .. "\n" .. spacing .. "}"
        return result
    elseif type(data) == "string" then
        return "\"" .. data:gsub("\"", "\\\""):gsub("\n", "\\n") .. "\""
    elseif type(data) == "number" or type(data) == "boolean" then
        return tostring(data)
    elseif type(data) == "nil" then
        return "nil"
    else
        return "\"" .. tostring(data) .. "\""
    end
end

-- Simple JSON-like decoder (fallback - basic implementation)
function SaveManager.simpleDecode(str)
    -- Decode Lua table format (safe evaluation)
    local func, err = load("return " .. str)
    if func then
        local success, result = pcall(func)
        if success then
            return result
        else
            print("Error decoding save data: " .. tostring(result))
            return nil
        end
    else
        print("Error parsing save data: " .. tostring(err))
        return nil
    end
end

function SaveManager:getSaveFilePath()
    return "savegame.sav"
end

function SaveManager:saveExists()
    local filepath = self:getSaveFilePath()
    local info = love.filesystem.getInfo(filepath)
    return info ~= nil
end

function SaveManager:save(gameState, playerX, playerY, playerHealth)
    
    -- Build save data
    local saveData = {
        version = "1.0",
        timestamp = os.time(),
        
        -- Player info
        playerName = gameState.playerName,
        playerClass = gameState.playerClass,
        playerElement = gameState.playerElement,
        playerHealth = playerHealth or 100,
        
        -- Player position (use actual position if provided, otherwise use spawn point)
        playerX = playerX or gameState.playerSpawn.x,
        playerY = playerY or gameState.playerSpawn.y,
        
        -- Game state
        currentMap = gameState.currentMap,
        questState = gameState.questState,
        playTime = gameState.playTime,
        
        -- Inventory
        inventory = gameState.inventory,
        quickSlots = gameState.quickSlots,
        openedChests = {}, -- Will populate below
        killedEnemies = {}, -- Will populate below
        
        -- Spell system
        learnedSpells = gameState.learnedSpells,
        equippedSpells = gameState.equippedSpells,
        spellLevels = gameState.spellLevels,
        spellExperience = gameState.spellExperience,
        currentMana = gameState.currentMana,
        maxMana = gameState.maxMana,
        
        -- Level progression
        levelHistory = gameState.levelHistory,
        houseDoorLocked = gameState.houseDoorLocked
    }
    
    -- Convert openedChests table to array for saving
    saveData.openedChests = {}
    for chestId, opened in pairs(gameState.openedChests) do
        if opened then
            table.insert(saveData.openedChests, chestId)
        end
    end
    
    -- Convert killedEnemies table to array for saving
    saveData.killedEnemies = {}
    for enemyId, killed in pairs(gameState.killedEnemies) do
        if killed then
            table.insert(saveData.killedEnemies, enemyId)
        end
    end
    
    -- Encode to string
    local encoded = SaveManager.simpleEncode(saveData)
    
    -- Write to file
    local filepath = self:getSaveFilePath()
    local success = love.filesystem.write(filepath, encoded)
    
    if success then
        print("Game saved successfully")
        return true, "Game saved successfully"
    else
        print("Failed to save game")
        return false, "Failed to save game"
    end
end

function SaveManager:load()
    local filepath = self:getSaveFilePath()
    
    -- Check if file exists
    local info = love.filesystem.getInfo(filepath)
    if not info then
        return nil, "No save file found"
    end
    
    -- Read file
    local contents, err = love.filesystem.read(filepath)
    if not contents then
        return nil, "Failed to read save file: " .. (err or "unknown error")
    end
    
    -- Decode
    local saveData = SaveManager.simpleDecode(contents)
    if not saveData then
        return nil, "Failed to decode save file"
    end
    
    -- Convert openedChests array back to table
    local openedChests = {}
    if saveData.openedChests then
        for _, chestId in ipairs(saveData.openedChests) do
            openedChests[chestId] = true
        end
    end
    saveData.openedChests = openedChests
    
    -- Convert killedEnemies array back to table
    local killedEnemies = {}
    if saveData.killedEnemies then
        for _, enemyId in ipairs(saveData.killedEnemies) do
            killedEnemies[enemyId] = true
        end
    end
    saveData.killedEnemies = killedEnemies
    
    print("Game loaded successfully")
    return saveData, "Game loaded successfully"
end

function SaveManager:deleteSave()
    local filepath = self:getSaveFilePath()
    local success = love.filesystem.remove(filepath)
    
    if success then
        print("Save deleted")
        return true, "Save deleted"
    else
        return false, "Failed to delete save"
    end
end

function SaveManager:applySaveData(gameState, saveData)
    -- Apply loaded save data to game state
    if not saveData then return false end
    
    -- Player info
    gameState.playerName = saveData.playerName or "Hero"
    gameState.playerClass = saveData.playerClass
    gameState.playerElement = saveData.playerElement
    gameState.playerHealth = saveData.playerHealth or 100
    gameState.playerX = saveData.playerX or 400
    gameState.playerY = saveData.playerY or 300
    
    gameState.playerSpawn = {x = saveData.playerX or 400, y = saveData.playerY or 300}
    gameState.currentMap = saveData.currentMap or "overworld"
    gameState.questState = saveData.questState or "initial"
    gameState.playTime = saveData.playTime or 0
    
    gameState.inventory = saveData.inventory or {}
    gameState.quickSlots = saveData.quickSlots or {nil, nil, nil, nil, nil}
    gameState.openedChests = saveData.openedChests or {}
    gameState.killedEnemies = saveData.killedEnemies or {}
    
    gameState.learnedSpells = saveData.learnedSpells or {}
    gameState.equippedSpells = saveData.equippedSpells or {nil, nil, nil, nil, nil}
    gameState.spellLevels = saveData.spellLevels or {}
    gameState.spellExperience = saveData.spellExperience or {}
    gameState.currentMana = saveData.currentMana or 100
    gameState.maxMana = saveData.maxMana or 100
    
    gameState.levelHistory = saveData.levelHistory or {}
    gameState.houseDoorLocked = saveData.houseDoorLocked ~= false -- Default true
    
    return true
end

return SaveManager

