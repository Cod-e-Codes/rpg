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

function SaveManager:getSaveFilePath(slotNumber)
    slotNumber = slotNumber or 1
    return "save_slot_" .. slotNumber .. ".sav"
end

function SaveManager:save(gameState, slotNumber)
    slotNumber = slotNumber or 1
    
    -- Build save data
    local saveData = {
        version = "1.0",
        timestamp = os.time(),
        
        -- Player position
        playerX = gameState.playerSpawn.x,
        playerY = gameState.playerSpawn.y,
        
        -- Game state
        currentMap = gameState.currentMap,
        questState = gameState.questState,
        playTime = gameState.playTime,
        
        -- Inventory
        inventory = gameState.inventory,
        quickSlots = gameState.quickSlots,
        openedChests = {}, -- Will populate below
        
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
    
    -- Encode to string
    local encoded = SaveManager.simpleEncode(saveData)
    
    -- Write to file
    local filepath = self:getSaveFilePath(slotNumber)
    local success = love.filesystem.write(filepath, encoded)
    
    if success then
        print("Game saved to slot " .. slotNumber)
        return true, "Game saved successfully"
    else
        print("Failed to save game")
        return false, "Failed to save game"
    end
end

function SaveManager:load(slotNumber)
    slotNumber = slotNumber or 1
    local filepath = self:getSaveFilePath(slotNumber)
    
    -- Check if file exists
    local info = love.filesystem.getInfo(filepath)
    if not info then
        return nil, "No save file found in slot " .. slotNumber
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
    
    print("Game loaded from slot " .. slotNumber)
    return saveData, "Game loaded successfully"
end

function SaveManager:listSaves()
    local saves = {}
    
    for slot = 1, 5 do
        local filepath = self:getSaveFilePath(slot)
        local info = love.filesystem.getInfo(filepath)
        
        if info then
            local contents = love.filesystem.read(filepath)
            if contents then
                local saveData = SaveManager.simpleDecode(contents)
                if saveData then
                    table.insert(saves, {
                        slot = slot,
                        timestamp = saveData.timestamp,
                        currentMap = saveData.currentMap,
                        playTime = saveData.playTime,
                        questState = saveData.questState
                    })
                end
            end
        end
    end
    
    return saves
end

function SaveManager:deleteSave(slotNumber)
    local filepath = self:getSaveFilePath(slotNumber)
    local success = love.filesystem.remove(filepath)
    
    if success then
        print("Save slot " .. slotNumber .. " deleted")
        return true, "Save deleted"
    else
        return false, "Failed to delete save"
    end
end

function SaveManager:applySaveData(gameState, saveData)
    -- Apply loaded save data to game state
    if not saveData then return false end
    
    gameState.playerSpawn = {x = saveData.playerX or 400, y = saveData.playerY or 300}
    gameState.currentMap = saveData.currentMap or "overworld"
    gameState.questState = saveData.questState or "initial"
    gameState.playTime = saveData.playTime or 0
    
    gameState.inventory = saveData.inventory or {}
    gameState.quickSlots = saveData.quickSlots or {nil, nil, nil, nil, nil}
    gameState.openedChests = saveData.openedChests or {}
    
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

