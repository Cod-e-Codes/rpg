-- Enhanced RPG with Tilemap, Collision, and Interactions
-- Controls: WASD/Arrows to move, E to interact, F3 for debug

-- Require modules
local GameState = require("gamestate")
local World = require("world")

-- Debug mode
DEBUG_MODE = false

-- Game state
local player = {
    x = 400,
    y = 300,
    speed = 150,
    direction = "south",
    isMoving = false,
    wasMoving = false,
    scale = 2,
    -- Collision box offsets (relative to player center)
    collisionLeft = -13,    -- Left edge of hitbox (negative = left of center)
    collisionRight = 13,    -- Right edge of hitbox (positive = right of center)
    collisionTop = -4,      -- Top edge of hitbox (negative = above center, small value = near feet)
    collisionBottom = 28    -- Bottom edge of hitbox (positive = below center, at feet)
}

local animations = {
    walk = {},
    idle = {}
}
local currentFrame = 1
local frameTimer = 0
local walkFrameDelay = 0.1
local idleFrameDelay = 0.15
local gameTime = 0  -- For water animation

local camera = {
    x = 0,
    y = 0
}

-- Game systems
local gameState
local world
local currentMessage = nil
local currentMessageItem = nil  -- Store item for message icon
local messageTimer = 0
local messageDuration = 3

-- UI state
local showInventory = false
local showHelp = false

-- Direction mappings
local directions = {
    "north", "north-east", "east", "south-east",
    "south", "south-west", "west", "north-west"
}

-- Forward declarations
local loadAnimations
local getDirection
local drawPlayer
local drawUI
local drawMessage
local checkInteraction
local getNearestInteractable

function love.load()
    -- Set up window
    love.window.setTitle("RPG Adventure")
    love.window.setMode(800, 600, {resizable=false})
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Initialize game systems
    gameState = GameState:new()
    world = World:new()
    
    -- Create example maps
    world:createExampleOverworld()
    world:createHouseInterior()
    world:loadMap("overworld")
    
    -- Sync all interactables with game state
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        obj:syncWithGameState(gameState)
    end
    
    -- Load animations
    loadAnimations()
    
    -- Set initial position (center of map)
    player.x = 40 * 32  -- Center of 80-tile wide map
    player.y = 30 * 32  -- Center of 60-tile tall map
    currentFrame = 1
end

function loadAnimations()
    -- Load walking animations (6 frames per direction)
    for _, direction in ipairs(directions) do
        animations.walk[direction] = {}
        for i = 0, 5 do
            local path = string.format("assets/animations/walk/%s/frame_%03d.png", direction, i)
            local success, image = pcall(love.graphics.newImage, path)
            if success then
                table.insert(animations.walk[direction], image)
            else
                print("Failed to load walk animation: " .. path)
            end
        end
    end
    
    -- Try to load breathing idle animations (4 frames per direction)
    for _, direction in ipairs(directions) do
        animations.idle[direction] = {}
        local foundIdleAnimation = false
        
        for i = 0, 3 do
            local path = string.format("assets/animations/breathing-idle/%s/frame_%03d.png", direction, i)
            local success, image = pcall(love.graphics.newImage, path)
            if success then
                table.insert(animations.idle[direction], image)
                foundIdleAnimation = true
            end
        end
        
        -- If no idle animation found, use first frame of walk animation
        if not foundIdleAnimation and #animations.walk[direction] > 0 then
            print("No idle animation found for " .. direction .. ", using walk frame 0")
            table.insert(animations.idle[direction], animations.walk[direction][1])
        end
    end
end

function love.update(dt)
    gameTime = gameTime + dt
    
    -- Update all interactables (for animations)
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        local transitionResult = obj:update(dt, gameState)
        
        -- Handle delayed door transitions
        if transitionResult == "door_transition" then
            world:loadMap(gameState.currentMap)
            player.x = gameState.playerSpawn.x
            player.y = gameState.playerSpawn.y
            
            -- Reset all door animations in new map
            local newInteractables = world:getCurrentInteractables()
            for _, interactable in ipairs(newInteractables) do
                if interactable.type == "door" then
                    interactable.openProgress = 0
                    interactable.targetProgress = 0
                end
                -- Sync chest states
                interactable:syncWithGameState(gameState)
            end
            
            -- Better dialogue based on where we're going
            if gameState.currentMap == "overworld" then
                currentMessage = "Back outside..."
            elseif gameState.currentMap == "house_interior" then
                currentMessage = "Inside the house"
            else
                currentMessage = gameState.currentMap
            end
            currentMessageItem = nil  -- Clear item icon for door transitions
            messageTimer = 2
        end
    end
    
    local dx = 0
    local dy = 0
    
    -- Check input
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        dy = dy - 1
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        dy = dy + 1
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        dx = dx - 1
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        dx = dx + 1
    end
    
    -- Determine if player is moving
    player.isMoving = (dx ~= 0 or dy ~= 0)
    
    -- Reset animation frame when transitioning between states
    if player.isMoving ~= player.wasMoving then
        currentFrame = 1
        frameTimer = 0
    end
    player.wasMoving = player.isMoving
    
    if player.isMoving then
        -- Normalize diagonal movement
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0 then
            dx = dx / length
            dy = dy / length
        end
        
        -- Store old position for collision rollback
        local oldX = player.x
        local oldY = player.y
        
        -- Helper function to check if position has collision
        local function checkCollision(testX, testY)
            -- Calculate collision box edges
            local boxLeft = testX + player.collisionLeft
            local boxRight = testX + player.collisionRight
            local boxTop = testY + player.collisionTop
            local boxBottom = testY + player.collisionBottom
            local boxWidth = boxRight - boxLeft
            local boxHeight = boxBottom - boxTop
            
            -- Check tilemap collision
            if world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight) then
                return true
            end
            
            -- Check collision with solid interactables
            local interactables = world:getCurrentInteractables()
            for _, obj in ipairs(interactables) do
                -- Chests and signs always have collision
                -- Doors only have collision when closed (openProgress == 0)
                local hasCollision = false
                if obj.type == "chest" or obj.type == "sign" then
                    hasCollision = true
                elseif obj.type == "door" then
                    -- Only collide with closed doors
                    hasCollision = (obj.openProgress == 0)
                end
                
                if hasCollision then
                    -- AABB collision check
                    if boxLeft < obj.x + obj.width and
                       boxRight > obj.x and
                       boxTop < obj.y + obj.height and
                       boxBottom > obj.y then
                        return true
                    end
                end
            end
            
            return false
        end
        
        -- Try to move both X and Y
        local newX = player.x + dx * player.speed * dt
        local newY = player.y + dy * player.speed * dt
        
        if not checkCollision(newX, newY) then
            -- Full movement is clear
            player.x = newX
            player.y = newY
        else
            -- Try sliding along X axis only
            if not checkCollision(newX, oldY) then
                player.x = newX
            -- Try sliding along Y axis only
            elseif not checkCollision(oldX, newY) then
                player.y = newY
            end
            -- If both fail, player stays in place (fully blocked)
        end
        
        -- Determine direction
        player.direction = getDirection(dx, dy)
        
        -- Update walk animation frame
        frameTimer = frameTimer + dt
        if frameTimer >= walkFrameDelay then
            frameTimer = frameTimer - walkFrameDelay
            currentFrame = currentFrame + 1
            if currentFrame > #animations.walk[player.direction] then
                currentFrame = 1
            end
        end
    else
        -- Update breathing idle animation
        frameTimer = frameTimer + dt
        if frameTimer >= idleFrameDelay then
            frameTimer = frameTimer - idleFrameDelay
            currentFrame = currentFrame + 1
            if currentFrame > #animations.idle[player.direction] then
                currentFrame = 1
            end
        end
    end
    
    -- Update camera to follow player
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    camera.x = player.x - screenWidth / 2
    camera.y = player.y - screenHeight / 2
    
    -- Update message timer
    if currentMessage and messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then
            currentMessage = nil
            currentMessageItem = nil
        end
    end
end

function getDirection(dx, dy)
    local angle = math.atan2(dy, dx)
    local degrees = angle * (180 / math.pi)
    
    -- Normalize to 0-360
    if degrees < 0 then
        degrees = degrees + 360
    end
    
    -- Map angle to 8 directions
    if degrees >= 337.5 or degrees < 22.5 then
        return "east"
    elseif degrees >= 22.5 and degrees < 67.5 then
        return "south-east"
    elseif degrees >= 67.5 and degrees < 112.5 then
        return "south"
    elseif degrees >= 112.5 and degrees < 157.5 then
        return "south-west"
    elseif degrees >= 157.5 and degrees < 202.5 then
        return "west"
    elseif degrees >= 202.5 and degrees < 247.5 then
        return "north-west"
    elseif degrees >= 247.5 and degrees < 292.5 then
        return "north"
    else
        return "north-east"
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    
    -- Draw world (ground, water, walls)
    world:draw(camera, gameTime)
    
    -- Y-sort all entities (player, decorations, interactables)
    local entities = {}
    
    -- Add player (sort by feet position for proper depth)
    -- Player sprite is centered, so feet are at y + half the sprite height
    local playerSortY = player.y + 16 -- Approximate feet position
    table.insert(entities, {
        y = playerSortY,
        draw = drawPlayer
    })
    
    -- Add decorations (trees, bushes)
    if world.currentMap then
        for y = 0, world.currentMap.height - 1 do
            for x = 0, world.currentMap.width - 1 do
                local deco = world.currentMap:getTile(x, y, "decorations")
                if deco > 0 then
                    local px = x * world.currentMap.tileSize
                    local py = y * world.currentMap.tileSize
                    -- Use bottom of decoration for sorting
                    local sortY = py + world.currentMap.tileSize
                    
                    table.insert(entities, {
                        y = sortY,
                        draw = function()
                            world.currentMap:drawSingleDecoration(x, y, deco)
                        end
                    })
                end
            end
        end
    end
    
    -- Add interactables
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        -- Use bottom of object for sorting
        local sortY = obj.y + obj.height
        table.insert(entities, {
            y = sortY,
            draw = function() obj:draw() end
        })
    end
    
    -- Sort by Y position
    table.sort(entities, function(a, b) return a.y < b.y end)
    
    -- Draw in sorted order
    for _, entity in ipairs(entities) do
        entity.draw()
    end
    
    -- Draw roofs AFTER entities (but they won't draw if player is near)
    world:drawRoofs(camera, player.x, player.y)
    
    -- Draw interaction indicator (on top of everything)
    local nearObj = getNearestInteractable()
    if nearObj then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("E", nearObj.x + nearObj.width/2 - 4, nearObj.y - 20)
        love.graphics.setColor(1, 1, 1)
    end
    
    love.graphics.pop()
    
    -- Draw UI (screen space)
    drawUI()
    drawMessage()
end

function drawPlayer()
    local animationType = player.isMoving and "walk" or "idle"
    if animations[animationType][player.direction] and #animations[animationType][player.direction] > 0 then
        local image = animations[animationType][player.direction][currentFrame]
        local imageWidth = image:getWidth()
        local imageHeight = image:getHeight()
        
        love.graphics.draw(
            image,
            player.x,
            player.y,
            0,
            player.scale,
            player.scale,
            imageWidth / 2,
            imageHeight / 2
        )
    end
    
    -- Debug: draw collision box
    if DEBUG_MODE then
        love.graphics.setColor(0, 1, 0, 0.5)
        local boxLeft = player.x + player.collisionLeft
        local boxTop = player.y + player.collisionTop
        local boxWidth = player.collisionRight - player.collisionLeft
        local boxHeight = player.collisionBottom - player.collisionTop
        love.graphics.rectangle("line", boxLeft, boxTop, boxWidth, boxHeight)
        
        -- Draw center point
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("fill", player.x, player.y, 2)
        
        love.graphics.setColor(1, 1, 1)
    end
end

local function drawItemIcon(itemName, x, y, size, isHovered)
    -- Draw item icons with toon shading and outlines
    size = size or 32
    
    -- Simple white background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", x, y, 32, 32, 2, 2)
    
    if itemName == "Gold Key" then
        -- Redesigned smaller key
        -- Key head (ornate circle)
        love.graphics.setColor(0.90, 0.75, 0.20)
        love.graphics.circle("fill", x + 16, y + 10, 5)
        
        -- Inner circle (decorative)
        love.graphics.setColor(0.75, 0.60, 0.15)
        love.graphics.circle("fill", x + 16, y + 10, 2)
        
        -- Key shaft
        love.graphics.setColor(0.90, 0.75, 0.20)
        love.graphics.rectangle("fill", x + 14, y + 15, 4, 10)
        
        -- Key teeth (smaller, more detailed)
        love.graphics.rectangle("fill", x + 18, y + 22, 3, 3)
        love.graphics.rectangle("fill", x + 18, y + 19, 2, 2)
        
        -- Highlight (toon style)
        love.graphics.setColor(0.98, 0.92, 0.50)
        love.graphics.circle("fill", x + 14, y + 8, 2)
        
        -- Shadow side
        love.graphics.setColor(0.65, 0.52, 0.12)
        love.graphics.arc("fill", x + 16, y + 10, 5, math.pi * 0.3, math.pi * 1.3)
        
        -- Outline
        love.graphics.setColor(0.20, 0.15, 0.05)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x + 16, y + 10, 5)
        love.graphics.rectangle("line", x + 14, y + 15, 4, 10)
        love.graphics.setLineWidth(1)
        
    elseif itemName == "Health Potion" then
        -- Bottle (glass)
        love.graphics.setColor(0.7, 0.85, 0.9)
        love.graphics.rectangle("fill", x + 8, y + 10, 16, 18, 2, 2)
        
        -- Red liquid (toon shaded)
        love.graphics.setColor(0.85, 0.15, 0.15)
        love.graphics.rectangle("fill", x + 10, y + 14, 12, 12, 2, 2)
        
        -- Liquid highlight
        love.graphics.setColor(0.95, 0.35, 0.35)
        love.graphics.rectangle("fill", x + 11, y + 15, 4, 4)
        
        -- Cork
        love.graphics.setColor(0.55, 0.35, 0.25)
        love.graphics.rectangle("fill", x + 12, y + 6, 8, 6)
        
        -- Outline
        love.graphics.setColor(0.15, 0.10, 0.10)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 8, y + 10, 16, 18, 2, 2)
        love.graphics.rectangle("line", x + 12, y + 6, 8, 6)
        love.graphics.setLineWidth(1)
        
    elseif itemName == "Magic Sword" then
        -- Blade (silver with purple glow)
        love.graphics.setColor(0.75, 0.75, 0.85)
        love.graphics.polygon("fill", 
            x + 16, y + 4,   -- tip
            x + 14, y + 22,  -- left
            x + 18, y + 22)  -- right
        
        -- Blade highlight
        love.graphics.setColor(0.90, 0.90, 0.95)
        love.graphics.line(x + 15, y + 6, x + 15, y + 20)
        
        -- Magic glow (purple)
        love.graphics.setColor(0.6, 0.3, 0.9, 0.5)
        love.graphics.polygon("fill",
            x + 16, y + 2,
            x + 12, y + 20,
            x + 20, y + 20)
        
        -- Guard
        love.graphics.setColor(0.60, 0.55, 0.30)
        love.graphics.rectangle("fill", x + 10, y + 22, 12, 3)
        
        -- Handle
        love.graphics.setColor(0.45, 0.30, 0.20)
        love.graphics.rectangle("fill", x + 14, y + 25, 4, 6)
        
        -- Pommel
        love.graphics.setColor(0.60, 0.55, 0.30)
        love.graphics.circle("fill", x + 16, y + 31, 3)
        
        -- Outline
        love.graphics.setColor(0.10, 0.08, 0.08)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line",
            x + 16, y + 4,
            x + 14, y + 22,
            x + 18, y + 22)
        love.graphics.rectangle("line", x + 10, y + 22, 12, 3)
        love.graphics.rectangle("line", x + 14, y + 25, 4, 6)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.setColor(1, 1, 1)
end

function drawUI()
    -- Draw toggle hints at bottom
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("[I] Inventory  [H] Help", 10, love.graphics.getHeight() - 20)
    
    -- Draw help panel
    if showHelp then
        local screenWidth = love.graphics.getWidth()
        local panelWidth = 320
        local panelHeight = 210
        local panelX = 15
        local panelY = 15
        local headerHeight = 28
        local padding = 12
        
        -- Main background panel
        love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
        love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
        
        -- Outer border (gold)
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Header background
        love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
        love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth - 4, headerHeight - 2, 3, 3)
        
        -- Header text (centered)
        love.graphics.setColor(1, 0.95, 0.7)
        local headerText = "Controls"
        local textWidth = love.graphics.getFont():getWidth(headerText)
        love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, panelY + 7)
        
        -- Divider line below header
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(
            panelX + 8, panelY + headerHeight,
            panelX + panelWidth - 8, panelY + headerHeight
        )
        love.graphics.setLineWidth(1)
        
        -- Controls list
        love.graphics.setColor(1, 1, 1)
        local yPos = panelY + headerHeight + padding + 8
        local lineHeight = 20
        love.graphics.print("WASD/Arrows - Move", panelX + padding + 8, yPos)
        love.graphics.print("E - Interact", panelX + padding + 8, yPos + lineHeight)
        love.graphics.print("I - Toggle Inventory", panelX + padding + 8, yPos + lineHeight * 2)
        love.graphics.print("H - Toggle Help", panelX + padding + 8, yPos + lineHeight * 3)
        love.graphics.print("F3 - Debug Mode", panelX + padding + 8, yPos + lineHeight * 4)
        love.graphics.print("ESC - Quit", panelX + padding + 8, yPos + lineHeight * 5)
        
        -- Item count
        love.graphics.setColor(0.9, 0.85, 0.6)
        love.graphics.print(string.format("Items Collected: %d", #gameState.inventory), panelX + padding + 8, yPos + lineHeight * 6.5)
    end
    
    -- Draw inventory panel (vertical layout)
    if showInventory then
        local screenWidth = love.graphics.getWidth()
        local itemCount = #gameState.inventory
        local iconSize = 40
        local padding = 12
        local headerHeight = 28
        local minHeight = 100 -- Minimum height for empty inventory
        
        local inventoryWidth = iconSize + padding * 2 + 8
        local inventoryHeight = headerHeight + math.max(itemCount * iconSize, minHeight - headerHeight) + padding * 2
        local inventoryX = screenWidth - inventoryWidth - 15
        local inventoryY = 15
        
        -- Main background panel
        love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
        love.graphics.rectangle("fill", inventoryX, inventoryY, inventoryWidth, inventoryHeight, 4, 4)
        
        -- Outer border (gold)
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", inventoryX, inventoryY, inventoryWidth, inventoryHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Header background
        love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
        love.graphics.rectangle("fill", inventoryX + 2, inventoryY + 2, inventoryWidth - 4, headerHeight - 2, 3, 3)
        
        -- Header text (centered)
        love.graphics.setColor(1, 0.95, 0.7)
        local headerText = "Inventory"
        local textWidth = love.graphics.getFont():getWidth(headerText)
        love.graphics.print(headerText, inventoryX + (inventoryWidth - textWidth) / 2, inventoryY + 7)
        
        -- Divider line below header
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(
            inventoryX + 8, inventoryY + headerHeight,
            inventoryX + inventoryWidth - 8, inventoryY + headerHeight
        )
        love.graphics.setLineWidth(1)
        
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        local hoveredItem = nil
        
        -- If inventory is empty, show a message
        if itemCount == 0 then
            love.graphics.setColor(0.6, 0.55, 0.45)
            local emptyText = "Empty"
            local textWidth = love.graphics.getFont():getWidth(emptyText)
            love.graphics.print(emptyText, inventoryX + (inventoryWidth - textWidth) / 2, inventoryY + headerHeight + 30)
        end
        
        -- Draw each item icon vertically
        for i, item in ipairs(gameState.inventory) do
            local iconX = inventoryX + padding + 4
            local iconY = inventoryY + headerHeight + padding + (i - 1) * iconSize + 4
            
            -- Check if mouse is hovering over this icon
            local isHovered = mouseX >= iconX - 2 and mouseX <= iconX + 34 and
                             mouseY >= iconY - 2 and mouseY <= iconY + 34
            
            if isHovered then
                hoveredItem = item
            end
            
            -- Draw icon slot background
            if isHovered then
                love.graphics.setColor(0.25, 0.22, 0.18, 0.95)
            else
                love.graphics.setColor(0.15, 0.13, 0.11, 0.8)
            end
            love.graphics.rectangle("fill", iconX - 2, iconY - 2, 36, 36, 3, 3)
            
            -- Icon slot border
            if isHovered then
                love.graphics.setColor(0.9, 0.8, 0.4)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.35, 0.30, 0.20)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", iconX - 2, iconY - 2, 36, 36, 3, 3)
            love.graphics.setLineWidth(1)
            
            -- Draw the item icon
            drawItemIcon(item, iconX, iconY, 32, isHovered)
        end
        
        -- Draw tooltip for hovered item
        if hoveredItem then
            local tooltipX = mouseX + 15
            local tooltipY = mouseY
            local tooltipText = hoveredItem
            local tooltipWidth = love.graphics.getFont():getWidth(tooltipText) + 20
            local tooltipHeight = 26
            
            -- Keep tooltip on screen
            if tooltipX + tooltipWidth > screenWidth then
                tooltipX = mouseX - tooltipWidth - 5
            end
            if tooltipY + tooltipHeight > love.graphics.getHeight() then
                tooltipY = love.graphics.getHeight() - tooltipHeight
            end
            
            -- Tooltip background
            love.graphics.setColor(0.12, 0.10, 0.08, 0.95)
            love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
            
            -- Tooltip border (bright gold)
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
            love.graphics.setLineWidth(1)
            
            -- Tooltip text
            love.graphics.setColor(1, 0.95, 0.7)
            love.graphics.print(tooltipText, tooltipX + 10, tooltipY + 6)
        end
    end
end

function drawMessage()
    if currentMessage then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        local padding = 12
        local iconSize = 40
        local panelHeight = 80
        local panelY = screenHeight - panelHeight - 20
        
        -- Calculate panel width based on content
        local textWidth = love.graphics.getFont():getWidth(currentMessage) + padding * 2
        local panelWidth = textWidth + (currentMessageItem and (iconSize + padding * 2) or 0) + padding * 2
        panelWidth = math.max(panelWidth, 300) -- Minimum width
        panelWidth = math.min(panelWidth, screenWidth - 100) -- Maximum width
        local panelX = (screenWidth - panelWidth) / 2
        
        -- Main background panel
        love.graphics.setColor(0.08, 0.08, 0.10, 0.90)
        love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
        
        -- Outer border (gold)
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Inner decorative border
        love.graphics.setColor(0.65, 0.55, 0.20, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", panelX + 4, panelY + 4, panelWidth - 8, panelHeight - 8, 3, 3)
        love.graphics.setLineWidth(1)
        
        -- Message text (centered vertically and accounting for line wrapping)
        love.graphics.setColor(1, 0.95, 0.8)
        local textX = panelX + padding + 8
        local maxTextWidth = panelWidth - padding * 3 - (currentMessageItem and (iconSize + padding) or 0) - 16
        
        -- Calculate actual text height with wrapping
        local _, wrappedText = love.graphics.getFont():getWrap(currentMessage, maxTextWidth)
        local textHeight = #wrappedText * love.graphics.getFont():getHeight()
        local textY = panelY + (panelHeight - textHeight) / 2
        
        love.graphics.printf(currentMessage, textX, textY, maxTextWidth, "left")
        
        -- If there's an item, draw its icon on the right
        if currentMessageItem then
            local iconX = panelX + panelWidth - iconSize - padding - 8
            local iconY = panelY + (panelHeight - iconSize) / 2
            
            -- Draw white background for icon
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 3, 3)
            
            -- Draw item icon
            drawItemIcon(currentMessageItem, iconX + 4, iconY + 4, 32, false)
            
            -- Add border around icon
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize, 3, 3)
            love.graphics.setLineWidth(1)
        end
    end
end

function getNearestInteractable()
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        if obj:isPlayerNear(player.x, player.y) then
            return obj
        end
    end
    return nil
end

function checkInteraction()
    local obj = getNearestInteractable()
    if obj then
        local result = obj:interact(gameState)
        
        -- Door transitions are now handled in update loop after animation
        if result then
            currentMessage = result
            messageTimer = messageDuration
            
            -- If it's a chest with an item being collected, store the item for icon display
            -- Only show icon if the message says "Found:" (i.e., actually collecting the item)
            if obj.type == "chest" and obj.data and obj.data.item and result:find("Found:") then
                currentMessageItem = obj.data.item
            else
                currentMessageItem = nil
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "e" then
        checkInteraction()
    elseif key == "f3" then
        DEBUG_MODE = not DEBUG_MODE
    elseif key == "i" then
        showInventory = not showInventory
    elseif key == "h" then
        showHelp = not showHelp
    end
end

