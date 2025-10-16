-- World/Map Management
local TileMap = require("src.core.tilemap")
local Interactable = require("src.entities.interactable")
local NPC = require("src.entities.npc")
local Enemy = require("src.entities.enemy")

local World = {}

function World:new()
    local world = {
        maps = {},
        currentMap = nil,
        interactables = {},
        npcs = {}, -- NPCs per map
        enemies = {}, -- Enemies per map
        gameState = nil, -- Reference to game state for quest filtering
        decorations = {} -- Quest-conditional decorations per map
    }
    setmetatable(world, {__index = self})
    return world
end

function World:createExampleOverworld()
    local Overworld = require("src.maps.overworld")
    Overworld.build(self)
end

function World:createHouseInterior()
    local House = require("src.maps.house_interior")
    House.build(self)
end

function World:createCaveLevel1()
    local Cave = require("src.maps.cave_level1")
    Cave.build(self)
end

function World:createClassSelection()
    local ClassSel = require("src.maps.class_selection")
    ClassSel.build(self)
end

function World:createDefenseTrials()
    local Trials = require("src.maps.defense_trials")
    Trials.build(self)
end

function World:createTown()
    local Town = require("src.maps.town")
    Town.build(self)
end

function World:createInnInterior()
    local Inn = require("src.maps.inn_interior")
    Inn.build(self)
end

function World:createPotionShopInterior()
    local PotionShop = require("src.maps.potion_shop_interior")
    PotionShop.build(self)
end

function World:loadMap(mapName)
    self.currentMap = self.maps[mapName]
    
    -- Update northern archway collision based on class selection
    if mapName == "overworld" and self.currentMap and self.gameState then
        local collision = self.currentMap.layers.collision
        collision[-1] = collision[-1] or {} -- Ensure row -1 exists
        if self.gameState.playerClass then
            -- Player has class: invisible barrier at row -1, no rocks anywhere
            for x = 38, 41 do
                collision[-1][x] = 1 -- Invisible barrier
                collision[0][x] = 0 -- No visible rocks
            end
        else
            -- No class yet: visible rocks at both rows to block passage
            for x = 38, 41 do
                collision[-1][x] = 2 -- Visible rocks at barrier
                collision[0][x] = 2 -- Visible rocks at ground level
            end
        end
        
        -- Update eastern path collision based on trials completion
        if self.gameState.eastPathRevealed then
            -- Remove rocks at eastern border to reveal path
            for y = 27, 31 do
                collision[y][79] = 0 -- Remove rocks
                collision[y][78] = 0 -- Ensure path is clear
            end
        else
            -- Keep rocks blocking the path
            for y = 27, 31 do
                collision[y][79] = 2 -- Visible rocks blocking path
            end
        end
    end
    
    return self.currentMap
end

function World:getCurrentInteractables()
    for mapName, interactables in pairs(self.interactables) do
        if self.maps[mapName] == self.currentMap then
            -- Filter interactables based on quest requirements
            local filtered = {}
            for _, obj in ipairs(interactables) do
                local shouldShow = true
                
                -- Check if this interactable requires an exact quest state
                if obj.data.questRequired and self.gameState then
                    -- Special case: east_path_revealed checks if eastern path has been revealed
                    if obj.data.questRequired == "east_path_revealed" then
                        shouldShow = (self.gameState.eastPathRevealed == true)
                    else
                        shouldShow = (self.gameState.questState == obj.data.questRequired)
                    end
                end
                
                -- Check if this interactable requires a minimum quest state (unlocked and stays visible)
                if obj.data.questMinimum and self.gameState then
                    -- Special case: has_class checks if player has chosen a class
                    if obj.data.questMinimum == "has_class" then
                        shouldShow = (self.gameState.playerClass ~= nil)
                    -- Special case: east_path_revealed checks if eastern path has been revealed
                    elseif obj.data.questMinimum == "east_path_revealed" then
                        shouldShow = (self.gameState.eastPathRevealed == true)
                    else
                        -- Define quest progression order
                        local questOrder = {"initial", "sword_collected", "cave_completed", "final"}
                        local currentIndex = 1
                        local minimumIndex = 1
                        
                        for i, q in ipairs(questOrder) do
                            if q == self.gameState.questState then
                                currentIndex = i
                            end
                            if q == obj.data.questMinimum then
                                minimumIndex = i
                            end
                        end
                        
                        shouldShow = (currentIndex >= minimumIndex)
                    end
                end
                
                -- Special case: Hide mysterious cave after class selection
                if obj.data.id == "mysterious_cave" and self.gameState and self.gameState.mysteriousCaveHidden then
                    shouldShow = false
                end
                
                if shouldShow then
                    table.insert(filtered, obj)
                end
            end
            return filtered
        end
    end
    return {}
end

function World:getCurrentHazards()
    -- Get hazards for current map (stored in map data)
    if self.currentMap and self.currentMap.layers.hazards then
        return self.currentMap.layers.hazards
    end
    return {}
end

function World:getCurrentNPCs()
    local npcs = {}
    for mapName, npcList in pairs(self.npcs) do
        if self.maps[mapName] == self.currentMap then
            -- Filter NPCs based on quest state
            for _, npc in ipairs(npcList) do
                local shouldShow = true
                
                if npc.npcType == "merchant" and self.gameState then
                    if mapName == "overworld" then
                        -- Show merchant outside only before entering house
                        shouldShow = (self.gameState.questState ~= "inside_house" and 
                                     self.gameState.questState ~= "sword_collected")
                    elseif mapName == "house_interior" then
                        -- Show merchant inside only after entering house
                        shouldShow = (self.gameState.questState == "inside_house" or 
                                     self.gameState.questState == "sword_collected")
                    end
                end
                
                if shouldShow then
                    table.insert(npcs, npc)
                end
            end
            return npcs
        end
    end
    return {}
end

function World:getCurrentEnemies()
    for mapName, enemies in pairs(self.enemies) do
        if self.maps[mapName] == self.currentMap then
            -- Filter out killed enemies if gameState is available
            if self.gameState then
                local aliveEnemies = {}
                for _, enemy in ipairs(enemies) do
                    if not self.gameState:isEnemyKilled(enemy.id) then
                        table.insert(aliveEnemies, enemy)
                    end
                end
                return aliveEnemies
            end
            return enemies
        end
    end
    return {}
end

function World:setGameState(gs)
    self.gameState = gs
end

function World:draw(camera, gameTime)
    if self.currentMap then
        self.currentMap:draw(camera, gameTime)
        
        -- Draw interactables
        local interactables = self:getCurrentInteractables()
        for _, obj in ipairs(interactables) do
            obj:draw()
        end
    end
end

function World:drawDecorations(camera)
    if self.currentMap then
        self.currentMap:drawDecorations(camera)
    end
end

function World:drawRoofs(camera, playerX, playerY)
    if self.currentMap then
        self.currentMap:drawRoofs(camera, playerX, playerY)
    end
end

return World

