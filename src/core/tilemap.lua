-- Simple Tilemap System (without external dependencies)
-- For a real game, consider using STI (Simple Tiled Implementation) library
local TileMap = {}

function TileMap:new(width, height, tileSize)
    local map = {
        width = width,
        height = height,
        tileSize = tileSize,
    layers = {
        ground = {},
        collision = {},
        objects = {},
        roofs = {},  -- Layer for building roofs
        water = {},  -- Layer for water/rivers
        decorations = {}  -- Layer for trees, bushes, etc.
    },
        tilesets = {}
    }
    setmetatable(map, {__index = self})
    return map
end

-- Load a simple map from data
function TileMap:loadFromData(data)
    self.layers.ground = data.ground or {}
    self.layers.collision = data.collision or {}
    self.layers.roofs = data.roofs or {}
    self.layers.water = data.water or {}
    self.layers.decorations = data.decorations or {}
    self.layers.hazards = data.hazards or {}
end

-- Check if a position collides with terrain
function TileMap:isColliding(x, y, width, height)
    width = width or self.tileSize
    height = height or self.tileSize
    
    -- Get tile coordinates for all corners of the bounding box
    local left = math.floor(x / self.tileSize)
    local right = math.floor((x + width - 1) / self.tileSize)
    local top = math.floor(y / self.tileSize)
    local bottom = math.floor((y + height - 1) / self.tileSize)
    
    -- First pass: check if player's feet (bottom) are on a bridge
    local onBridge = false
    for col = left, right do
        local waterTile = self:getTile(col, bottom, "water")
        if waterTile == 2 then
            onBridge = true
            break
        end
    end
    
    -- Check collision layer (both 1 and 2 are solid)
    for row = top, bottom do
        for col = left, right do
            local tile = self:getTile(col, row, "collision")
            if tile == 1 or tile == 2 then
                local waterTile = self:getTile(col, row, "water")
                -- If feet are on bridge, allow passage over water collision
                if waterTile == 1 and onBridge then
                    -- Standing on bridge, water collision doesn't count
                elseif waterTile == 2 then
                    -- It's a bridge tile, no collision
                else
                    return true
                end
            end
        end
    end
    
    return false
end

function TileMap:getTile(x, y, layer)
    layer = layer or "ground"
    if not self.layers[layer][y] then
        return 0
    end
    return self.layers[layer][y][x] or 0
end

function TileMap:hasVisibleWater(camera)
    -- Check if there are any water tiles visible in the current camera view
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local startX = math.max(0, math.floor(camera.x / self.tileSize) - 1)
    local endX = math.min(self.width - 1, math.ceil((camera.x + screenWidth) / self.tileSize) + 1)
    local startY = math.max(0, math.floor(camera.y / self.tileSize) - 1)
    local endY = math.min(self.height - 1, math.ceil((camera.y + screenHeight) / self.tileSize) + 1)
    
    -- Check for water tiles (type 1) in the visible range
    for y = startY, endY do
        for x = startX, endX do
            local waterType = self:getTile(x, y, "water")
            if waterType == 1 then
                return true
            end
        end
    end
    
    return false
end

function TileMap:hasVisibleFountain(camera)
    -- Check if there are any fountain water tiles visible in the current camera view
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local startX = math.max(0, math.floor(camera.x / self.tileSize) - 1)
    local endX = math.min(self.width - 1, math.ceil((camera.x + screenWidth) / self.tileSize) + 1)
    local startY = math.max(0, math.floor(camera.y / self.tileSize) - 1)
    local endY = math.min(self.height - 1, math.ceil((camera.y + screenHeight) / self.tileSize) + 1)
    
    -- Check for fountain water tiles (type 5) in the visible range
    for y = startY, endY do
        for x = startX, endX do
            local waterType = self:getTile(x, y, "water")
            if waterType == 5 then
                return true
            end
        end
    end
    
    return false
end

function TileMap:draw(camera, gameTime)
    gameTime = gameTime or 0
    
    -- Calculate visible tile range (viewport culling)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local startX = math.max(0, math.floor(camera.x / self.tileSize) - 1)
    local endX = math.min(self.width - 1, math.ceil((camera.x + screenWidth) / self.tileSize) + 1)
    local startY = math.max(0, math.floor(camera.y / self.tileSize) - 1)
    local endY = math.min(self.height - 1, math.ceil((camera.y + screenHeight) / self.tileSize) + 1)
    
    -- Draw ground layer (only visible tiles)
    for y = startY, endY do
        for x = startX, endX do
            local tile = self:getTile(x, y, "ground")
            if tile > 0 then
                local px = x * self.tileSize
                local py = y * self.tileSize
                
                -- Pixel art style with toon shading
                if tile == 1 or tile == 4 then
                    -- Grass with toon shader and organic noise variation
                    local seed = x * 7 + y * 13
                    -- More complex noise for breaking up patterns
                    local noise1 = ((seed * 17) % 100) / 100
                    local noise2 = ((seed * 23) % 100) / 100
                    local noise3 = ((x * 11 + y * 19) % 100) / 100
                    local noise4 = ((x * 2 + y * 3) % 100) / 100
                    local combinedNoise = (noise1 + noise2 + noise3 + noise4) / 4
                    
                    -- Toon shading levels with more variation
                    local toonLevel
                    -- Use multiple noise sources to break up patterns
                    local toonNoise = ((seed * 31 + x * 3 + y * 5) % 100) / 100
                    if toonNoise < 0.30 then
                        toonLevel = 0 -- Dark
                    elseif toonNoise < 0.65 then
                        toonLevel = 1 -- Medium
                    else
                        toonLevel = 2 -- Light
                    end
                    
                    -- Apply toon color bands with subtle variation
                    local colorVar = (combinedNoise - 0.5) * 0.08
                    if toonLevel == 0 then
                        love.graphics.setColor(0.18 + colorVar, 0.42 + colorVar, 0.18 + colorVar)
                    elseif toonLevel == 1 then
                        love.graphics.setColor(0.22 + colorVar, 0.50 + colorVar, 0.22 + colorVar)
                    else
                        love.graphics.setColor(0.28 + colorVar, 0.58 + colorVar, 0.28 + colorVar)
                    end
                    
                    love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                    
                    -- Optimized: fewer, simpler grass details
                    -- Add organic grass tufts (circles with outlines - much faster)
                    local tuftCount = ((seed % 3) + 2)  -- 2-4 tufts per tile (reduced)
                    for i = 0, tuftCount do
                        local tuftSeed = seed * 11 + i * 17
                        local tuftX = px + ((tuftSeed * 7) % 26) + 3
                        local tuftY = py + ((tuftSeed * 13) % 26) + 3
                        local tuftSize = ((tuftSeed % 3) + 2)
                        
                        -- Darker grass tuft
                        local tuftDark = 0.14 + ((tuftSeed % 10) / 100)
                        love.graphics.setColor(tuftDark, tuftDark + 0.20, tuftDark, 0.4)
                        love.graphics.circle("fill", tuftX, tuftY, tuftSize)
                        
                        -- Subtle outline on some tufts
                        if (tuftSeed % 3) == 0 then
                            love.graphics.setColor(tuftDark - 0.05, tuftDark + 0.15, tuftDark - 0.05, 0.6)
                            love.graphics.setLineWidth(1)
                            love.graphics.circle("line", tuftX, tuftY, tuftSize)
                        end
                    end
                    
                    -- Individual grass blades (simple rectangles)
                    local bladeCount = ((seed % 2) + 1)  -- 1-2 blades per tile
                    for i = 0, bladeCount do
                        local bladeSeed = seed * 13 + i * 19
                        local bladeX = ((bladeSeed * 11 + x * 7) % 24) + 4
                        local bladeY = ((bladeSeed * 19 + y * 11) % 24) + 4
                        local bladeH = ((bladeSeed * 7) % 5) + 3
                        
                        local bladeDark = 0.13 + ((bladeSeed % 10) / 100)
                        love.graphics.setColor(bladeDark, 0.30 + ((bladeSeed % 10) / 100), bladeDark, 0.4)
                        love.graphics.rectangle("fill", px + bladeX, py + bladeY, 1, bladeH)
                    end
                    
                    -- Darker patches (circles - faster than polygons)
                    if ((seed * 13 + x * 2) % 5) == 0 then
                        local patchX = px + ((seed * 17) % 18) + 7
                        local patchY = py + ((seed * 19) % 18) + 7
                        local patchSize = ((seed * 3) % 4) + 4
                        
                        love.graphics.setColor(0.12, 0.30, 0.12, 0.25)
                        love.graphics.circle("fill", patchX, patchY, patchSize)
                    end
                    
                    -- Bright highlights (circles instead of polygons)
                    if toonLevel == 2 and ((seed % 6) < 2) then
                        love.graphics.setColor(0.35, 0.65, 0.35, 0.3)
                        local highlightX = px + ((seed * 7) % 14) + 9
                        local highlightY = py + ((seed * 11) % 14) + 9
                        local highlightSize = ((seed % 3) + 3)
                        love.graphics.circle("fill", highlightX, highlightY, highlightSize)
                    end
                    
                elseif tile == 2 then
                    -- Dirt path with organic, interlocking edges and toon shading
                    local seed = x * 7 + y * 13
                    
                    -- First fill the entire tile with average brown (to prevent gaps)
                    love.graphics.setColor(0.42, 0.32, 0.22)  -- Average brown
                    love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                    
                    -- Toon shading (3 levels for dirt)
                    local toonLevel = (seed % 3)
                    if toonLevel == 0 then
                        love.graphics.setColor(0.35, 0.25, 0.18)  -- Dark
                    elseif toonLevel == 1 then
                        love.graphics.setColor(0.42, 0.32, 0.22)  -- Medium
                    else
                        love.graphics.setColor(0.50, 0.38, 0.26)  -- Light
                    end
                    
                    -- Draw irregular path shape with noise distortion
                    local pathPoints = {}
                    for i = 0, 15 do
                        local angle = (i / 16) * math.pi * 2
                        -- Add noise to create irregular edges
                        local edgeNoise = ((seed * 11 + i * 13) % 10) / 15 + 0.85
                        local radius = (self.tileSize / 2) * edgeNoise
                        local cx = px + self.tileSize / 2
                        local cy = py + self.tileSize / 2
                        table.insert(pathPoints, cx + math.cos(angle) * radius)
                        table.insert(pathPoints, cy + math.sin(angle) * radius)
                    end
                    
                    love.graphics.polygon("fill", pathPoints)
                    
                elseif tile == 3 then
                    -- Stone floor with toon shading
                    local seed = x * 5 + y * 11
                    local toonLevel = (seed % 3)
                    
                    if toonLevel == 0 then
                        love.graphics.setColor(0.38, 0.38, 0.38)  -- Dark
                    elseif toonLevel == 1 then
                        love.graphics.setColor(0.45, 0.45, 0.45)  -- Medium
                    else
                        love.graphics.setColor(0.52, 0.52, 0.52)  -- Light
                    end
                    
                    love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                    
                    -- Toon highlight
                    if toonLevel == 2 then
                        love.graphics.setColor(0.60, 0.60, 0.60, 0.4)
                        love.graphics.rectangle("fill", px + 2, py + 2, 10, 10)
                    end
                    
                elseif tile == 5 then
                    -- Dark cave stone with toon shading (darker than regular stone)
                    local seed = x * 5 + y * 11
                    local toonLevel = (seed % 3)
                    
                    -- Earth tone color palette for caves (browns like the entrance boulders)
                    if toonLevel == 0 then
                        love.graphics.setColor(0.28, 0.21, 0.15)  -- Dark earthy brown
                    elseif toonLevel == 1 then
                        love.graphics.setColor(0.32, 0.24, 0.17)  -- Medium brown
                    else
                        love.graphics.setColor(0.38, 0.28, 0.20)  -- Lighter brown
                    end
                    
                    love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                    
                    -- Add some texture (cracks/roughness) - darker brown
                    love.graphics.setColor(0.18, 0.13, 0.09, 0.5)
                    local crackCount = (seed % 3) + 1
                    for i = 0, crackCount do
                        local crackSeed = seed * 7 + i * 13
                        local cx1 = px + ((crackSeed * 3) % 28) + 2
                        local cy1 = py + ((crackSeed * 5) % 28) + 2
                        local cx2 = cx1 + ((crackSeed * 7) % 8) - 4
                        local cy2 = cy1 + ((crackSeed * 11) % 8) - 4
                        love.graphics.setLineWidth(1)
                        love.graphics.line(cx1, cy1, cx2, cy2)
                    end
                    
                    -- Subtle highlight on lighter tiles - warm brown
                    if toonLevel == 2 then
                        love.graphics.setColor(0.44, 0.34, 0.24, 0.3)
                        love.graphics.rectangle("fill", px + 2, py + 2, 8, 8)
                    end
                    
                elseif tile == 6 then
                    -- Wooden floor with toon shading
                    local seed = x * 11 + y * 7
                    local toonLevel = (seed % 3)
                    if toonLevel == 0 then
                        love.graphics.setColor(0.42, 0.30, 0.18)  -- Dark wood
                    elseif toonLevel == 1 then
                        love.graphics.setColor(0.50, 0.35, 0.22)  -- Medium wood
                    else
                        love.graphics.setColor(0.58, 0.42, 0.26)  -- Light wood
                    end
                    
                    love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                    
                    -- Plank separations (dark lines)
                    love.graphics.setColor(0.28, 0.18, 0.10)
                    love.graphics.setLineWidth(2)
                    for i = 0, 3 do
                        love.graphics.line(px, py + i * 8, px + self.tileSize, py + i * 8)
                    end
                    love.graphics.setLineWidth(1)
                    
                    -- Wood grain lines (horizontal)
                    love.graphics.setColor(0.35, 0.24, 0.16)
                    for i = 1, 2 do
                        local grainY = py + i * 10 + ((seed + i * 3) % 4) - 2
                        love.graphics.line(px + 2, grainY, px + self.tileSize - 2, grainY)
                    end
                    
                    -- Toon highlight (if light)
                    if toonLevel == 2 then
                        love.graphics.setColor(0.68, 0.52, 0.36, 0.5)
                        love.graphics.rectangle("fill", px + 4, py + 4, self.tileSize - 8, 6)
                    end
                end
                
                -- Dirt path texture (only if it's a path tile)
                if tile == 2 then
                    local seed = (x + y * 100)
                    
                    -- Dirt path texture with lines and variation
                    love.graphics.setColor(0.3, 0.2, 0.15, 0.3)
                    
                    -- Random dirt lines
                    for i = 0, 3 do
                        local lineY = ((seed * 7 + i * 13) % 24) + 4
                        local lineLen = ((seed * 11 + i * 17) % 16) + 10
                        local lineX = ((seed * 3 + i * 7) % 10) + 4
                        love.graphics.rectangle("fill", px + lineX, py + lineY, lineLen, 1)
                    end
                    
                    -- Random dirt specks for texture
                    for i = 0, 6 do
                        local speckX = ((seed * 19 + i * 23) % 24) + 4
                        local speckY = ((seed * 29 + i * 31) % 24) + 4
                        love.graphics.rectangle("fill", px + speckX, py + speckY, 2, 2)
                    end
                    
                    -- Add some pebbles
                    love.graphics.setColor(0.35, 0.25, 0.18, 0.4)
                    for i = 0, 2 do
                        local pebbleX = ((seed * 37 + i * 41) % 20) + 6
                        local pebbleY = ((seed * 43 + i * 47) % 20) + 6
                        local pebbleSize = ((seed * 3 + i * 5) % 3) + 2
                        love.graphics.circle("fill", px + pebbleX, py + pebbleY, pebbleSize)
                    end
                end
            end
        end
    end
    
    -- Draw organic edges for grass and dirt paths (only visible tiles)
    for y = startY, endY do
        for x = startX, endX do
            local tile = self:getTile(x, y, "ground")
            local px = x * self.tileSize
            local py = y * self.tileSize
            local seed = x * 7 + y * 13
            
            -- Grass edges (next to dirt, water, or empty)
            if tile == 1 or tile == 4 then
                -- Check each direction for edge
                local neighbors = {
                    {dx = 0, dy = -1}, -- North
                    {dx = 1, dy = 0},  -- East
                    {dx = 0, dy = 1},  -- South
                    {dx = -1, dy = 0}  -- West
                }
                
                for i, dir in ipairs(neighbors) do
                    local nx, ny = x + dir.dx, y + dir.dy
                    local neighborTile = self:getTile(nx, ny, "ground")
                    local neighborWater = self:getTile(nx, ny, "water")
                    
                    -- Draw edge if neighbor is different (dirt, water, or out of bounds)
                    if neighborTile ~= 1 and neighborTile ~= 4 or neighborWater > 0 then
                        -- Darker green outline
                        love.graphics.setColor(0.10 + ((seed + i * 7) % 10) / 200, 
                                               0.25 + ((seed + i * 11) % 10) / 200, 
                                               0.10 + ((seed + i * 13) % 10) / 200,
                                               0.6)
                        
                        -- Draw organic edge line with noise (optimized)
                        local pointCount = 4  -- Reduced from 8 for performance
                        for p = 0, pointCount - 1 do
                            local progress = p / pointCount
                            local x1, y1, x2, y2
                            
                            -- Base thickness with noise
                            local thickness = 2 + ((seed * 17 + p * 19) % 3)
                            
                            if dir.dy == -1 then -- North edge
                                x1 = px + progress * self.tileSize
                                y1 = py + ((seed * 11 + p * 7) % 3) - 1
                                x2 = px + (progress + 1/pointCount) * self.tileSize
                                y2 = py + ((seed * 13 + p * 11) % 3) - 1
                            elseif dir.dx == 1 then -- East edge
                                x1 = px + self.tileSize - 1 - ((seed * 11 + p * 7) % 3)
                                y1 = py + progress * self.tileSize
                                x2 = px + self.tileSize - 1 - ((seed * 13 + p * 11) % 3)
                                y2 = py + (progress + 1/pointCount) * self.tileSize
                            elseif dir.dy == 1 then -- South edge
                                x1 = px + progress * self.tileSize
                                y1 = py + self.tileSize - 1 - ((seed * 11 + p * 7) % 3)
                                x2 = px + (progress + 1/pointCount) * self.tileSize
                                y2 = py + self.tileSize - 1 - ((seed * 13 + p * 11) % 3)
                            else -- West edge
                                x1 = px + ((seed * 11 + p * 7) % 3) - 1
                                y1 = py + progress * self.tileSize
                                x2 = px + ((seed * 13 + p * 11) % 3) - 1
                                y2 = py + (progress + 1/pointCount) * self.tileSize
                            end
                            
                            love.graphics.setLineWidth(thickness)
                            love.graphics.line(x1, y1, x2, y2)
                        end
                        love.graphics.setLineWidth(1)
                    end
                end
            end
            
            -- Dirt path edges (only at borders with grass)
            if tile == 2 then
                local neighbors = {
                    {dx = 0, dy = -1}, -- North
                    {dx = 1, dy = 0},  -- East
                    {dx = 0, dy = 1},  -- South
                    {dx = -1, dy = 0}  -- West
                }
                
                for i, dir in ipairs(neighbors) do
                    local nx, ny = x + dir.dx, y + dir.dy
                    local neighborTile = self:getTile(nx, ny, "ground")
                    
                    -- Draw edge if neighbor is grass
                    if neighborTile == 1 or neighborTile == 4 then
                        -- Darker brown outline
                        love.graphics.setColor(0.20 + ((seed + i * 7) % 10) / 200, 
                                               0.15 + ((seed + i * 11) % 10) / 200, 
                                               0.10 + ((seed + i * 13) % 10) / 200,
                                               0.5)
                        
                        -- Draw organic edge line with noise (optimized)
                        local pointCount = 4  -- Reduced from 8 for performance
                        for p = 0, pointCount - 1 do
                            local progress = p / pointCount
                            local x1, y1, x2, y2
                            
                            -- Variable thickness with noise
                            local thickness = 1 + ((seed * 17 + p * 19) % 2)
                            
                            if dir.dy == -1 then -- North edge
                                x1 = px + progress * self.tileSize
                                y1 = py + ((seed * 11 + p * 7) % 4)
                                x2 = px + (progress + 1/pointCount) * self.tileSize
                                y2 = py + ((seed * 13 + p * 11) % 4)
                            elseif dir.dx == 1 then -- East edge
                                x1 = px + self.tileSize - 1 - ((seed * 11 + p * 7) % 4)
                                y1 = py + progress * self.tileSize
                                x2 = px + self.tileSize - 1 - ((seed * 13 + p * 11) % 4)
                                y2 = py + (progress + 1/pointCount) * self.tileSize
                            elseif dir.dy == 1 then -- South edge
                                x1 = px + progress * self.tileSize
                                y1 = py + self.tileSize - 1 - ((seed * 11 + p * 7) % 4)
                                x2 = px + (progress + 1/pointCount) * self.tileSize
                                y2 = py + self.tileSize - 1 - ((seed * 13 + p * 11) % 4)
                            else -- West edge
                                x1 = px + ((seed * 11 + p * 7) % 4)
                                y1 = py + progress * self.tileSize
                                x2 = px + ((seed * 13 + p * 11) % 4)
                                y2 = py + (progress + 1/pointCount) * self.tileSize
                            end
                            
                            love.graphics.setLineWidth(thickness)
                            love.graphics.line(x1, y1, x2, y2)
                        end
                        love.graphics.setLineWidth(1)
                    end
                end
            end
        end
    end
    
    -- Draw water layer (animated, only visible tiles)
    for y = startY, endY do
        for x = startX, endX do
            local waterType = self:getTile(x, y, "water")
            if waterType == 1 then
                local px = x * self.tileSize
                local py = y * self.tileSize
                
                -- Animated water with toon shader (3 levels)
                local wavePhase = (gameTime * 1.5 + x * 0.5 + y * 0.5) % (math.pi * 2)
                local waveValue = (math.sin(wavePhase) + 1) / 2  -- 0 to 1
                
                -- Toon shading levels for water
                local toonLevel
                if waveValue < 0.33 then
                    toonLevel = 0  -- Dark
                elseif waveValue < 0.66 then
                    toonLevel = 1  -- Medium
                else
                    toonLevel = 2  -- Light (wave peaks)
                end
                
                -- Apply toon colors
                if toonLevel == 0 then
                    love.graphics.setColor(0.15, 0.35, 0.55)
                elseif toonLevel == 1 then
                    love.graphics.setColor(0.22, 0.45, 0.65)
                else
                    love.graphics.setColor(0.30, 0.55, 0.75)
                end
                
                love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                
                -- Sharp highlight (toon style)
                if toonLevel == 2 then
                    love.graphics.setColor(0.45, 0.70, 0.85, 0.6)
                    love.graphics.rectangle("fill", px + 4, py + 4, self.tileSize - 8, 6)
                end
                
                -- Sharp shadow (toon style)
                if toonLevel == 0 then
                    love.graphics.setColor(0.08, 0.18, 0.35, 0.5)
                    love.graphics.rectangle("fill", px + 8, py + 20, 16, 8)
                end
                
            elseif waterType == 2 then
                -- Bridge tile with toon shading
                local px = x * self.tileSize
                local py = y * self.tileSize
                local seed = x * 11 + y * 7
                
                -- Toon shading for wood
                local toonLevel = (seed % 3)
                if toonLevel == 0 then
                    love.graphics.setColor(0.42, 0.30, 0.18)  -- Dark wood
                elseif toonLevel == 1 then
                    love.graphics.setColor(0.50, 0.35, 0.22)  -- Medium wood
                else
                    love.graphics.setColor(0.58, 0.42, 0.26)  -- Light wood
                end
                
                love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                
                -- Plank separations (dark)
                love.graphics.setColor(0.28, 0.18, 0.10)
                love.graphics.setLineWidth(2)
                for i = 0, 3 do
                    love.graphics.line(px, py + i * 8, px + self.tileSize, py + i * 8)
                end
                love.graphics.setLineWidth(1)
                
                -- Toon highlight (if light)
                if toonLevel == 2 then
                    love.graphics.setColor(0.68, 0.52, 0.36, 0.5)
                    love.graphics.rectangle("fill", px + 4, py + 4, self.tileSize - 8, 6)
                end
                
                -- Side rails (sharp shadow)
                love.graphics.setColor(0.30, 0.20, 0.12)
                love.graphics.rectangle("fill", px, py, self.tileSize, 4)
                love.graphics.rectangle("fill", px, py + self.tileSize - 4, self.tileSize, 4)
                
                -- Nails/bolts (toon style - simple circles)
                love.graphics.setColor(0.25, 0.25, 0.28)
                for i = 0, 2 do
                    love.graphics.circle("fill", px + 8 + i * 8, py + 6, 2)
                    love.graphics.circle("fill", px + 8 + i * 8, py + self.tileSize - 6, 2)
                end
            
            elseif waterType == 5 then
                -- Fountain water (special animated water for fountains)
                local px = x * self.tileSize
                local py = y * self.tileSize
                
                -- Animated water with toon shader (same as river but brighter)
                local wavePhase = (gameTime * 2 + x * 0.7 + y * 0.7) % (math.pi * 2)
                local waveValue = (math.sin(wavePhase) + 1) / 2  -- 0 to 1
                
                -- Toon shading levels for fountain water (brighter than river)
                local toonLevel
                if waveValue < 0.33 then
                    toonLevel = 0  -- Dark
                elseif waveValue < 0.66 then
                    toonLevel = 1  -- Medium
                else
                    toonLevel = 2  -- Light (wave peaks)
                end
                
                -- Apply brighter toon colors for fountain
                if toonLevel == 0 then
                    love.graphics.setColor(0.25, 0.45, 0.65)
                elseif toonLevel == 1 then
                    love.graphics.setColor(0.35, 0.55, 0.75)
                else
                    love.graphics.setColor(0.45, 0.65, 0.85)
                end
                
                love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                
                -- Sharp highlight (toon style, more prominent)
                if toonLevel == 2 then
                    love.graphics.setColor(0.60, 0.80, 0.95, 0.7)
                    love.graphics.rectangle("fill", px + 4, py + 4, self.tileSize - 8, 8)
                end
                
                -- Sparkle effect (occasional bright spots)
                if (x + y + math.floor(gameTime * 3)) % 7 == 0 then
                    love.graphics.setColor(0.85, 0.95, 1.0, 0.8)
                    love.graphics.circle("fill", px + 12, py + 12, 3)
                end
            end
        end
    end
    
    -- Draw walls/rocks (collision type 2) with noise distortion and toon shader (only visible)
    for y = startY, endY do
        for x = startX, endX do
            local deco = self:getTile(x, y, "decorations")
            -- Only draw rocks if collision is 2 AND there's no decoration (bush/tree) here
            if self:getTile(x, y, "collision") == 2 and deco == 0 then
                local px = x * self.tileSize
                local py = y * self.tileSize
                local seed = x * 7 + y * 13
                
                -- Check if we're in a cave (dark ground tile)
                local groundTile = self:getTile(x, y, "ground")
                local isInCave = (groundTile == 5)
                
                -- Check if this is a fountain border stone (more rectangular)
                local isFountainStone = (x >= 22 and x <= 27 and y >= 19 and y <= 24 and 
                    (x == 22 or x == 27 or y == 19 or y == 24))
                
                -- Fountain stones are more rectangular and blocky
                local segments
                local sizeVar
                local rotationOffset = 0
                if isFountainStone then
                    segments = 6  -- More corners for irregular blocky shape
                    sizeVar = 0.90  -- Slightly smaller for gap between blocks
                    -- Add slight rotation offset (each stone rotates slightly differently)
                    rotationOffset = ((seed % 20) - 10) * 0.05  -- -0.5 to +0.5 radians (~-30 to +30 degrees)
                elseif isInCave then
                    segments = 10
                    sizeVar = ((seed % 8) / 10) + 1.0  -- 1.0 to 1.8 (bigger)
                else
                    segments = 7
                    sizeVar = ((seed % 7) / 10) + 0.7  -- 0.7 to 1.4 (normal)
                end
                
                local rockSize = self.tileSize * sizeVar
                local offsetX = (self.tileSize - rockSize) / 2
                local offsetY = (self.tileSize - rockSize) / 2
                
                -- Create shape points with appropriate distortion
                local noisePoints = {}
                for i = 0, segments do
                    local angle = (i / segments) * math.pi * 2 + rotationOffset
                    local distortion
                    if isFountainStone then
                        -- More noise distortion for irregular outline (but still blocky)
                        distortion = ((seed * 11 + i * 17) % 15) / 50 + 0.85  -- 0.85 to 1.15
                    elseif isInCave then
                        distortion = ((seed * 11 + i * 17) % 10) / 30 + 0.85
                        distortion = distortion * 0.9  -- More irregular in caves
                    else
                        distortion = ((seed * 11 + i * 17) % 10) / 30 + 0.85
                    end
                    local radius = (rockSize / 2) * distortion
                    local cx = px + self.tileSize / 2
                    local cy = py + self.tileSize / 2
                    table.insert(noisePoints, cx + math.cos(angle) * radius)
                    table.insert(noisePoints, cy + math.sin(angle) * radius)
                end
                
                -- Color palette
                local lightLevel = ((seed % 5) / 5)
                local baseColor
                if isFountainStone then
                    -- Lighter, cut stone blocks for fountain
                    if lightLevel < 0.33 then
                        baseColor = {0.55, 0.52, 0.48}  -- Light gray stone
                    elseif lightLevel < 0.66 then
                        baseColor = {0.62, 0.58, 0.54}  -- Medium gray stone
                    else
                        baseColor = {0.68, 0.64, 0.60}  -- Lighter gray stone
                    end
                elseif isInCave then
                    -- Earth tone cave boulders (like entrance boulders)
                    if lightLevel < 0.33 then
                        baseColor = {0.32, 0.24, 0.16}  -- Dark earthy brown
                    elseif lightLevel < 0.66 then
                        baseColor = {0.38, 0.28, 0.20}  -- Medium brown
                    else
                        baseColor = {0.42, 0.32, 0.22}  -- Lighter brown (matches entrance)
                    end
                else
                    -- Regular overworld rocks
                    if lightLevel < 0.33 then
                        baseColor = {0.35, 0.30, 0.25}  -- Dark
                    elseif lightLevel < 0.66 then
                        baseColor = {0.42, 0.37, 0.32}  -- Medium
                    else
                        baseColor = {0.50, 0.45, 0.40}  -- Light
                    end
                end
                
                -- Draw main rock shape
                love.graphics.setColor(baseColor)
                love.graphics.polygon("fill", noisePoints)
                
                -- Toon highlights
                if lightLevel >= 0.66 then
                    if isFountainStone then
                        -- Brighter highlight for cut stone
                        love.graphics.setColor(0.80, 0.76, 0.72, 0.6)
                    elseif isInCave then
                        love.graphics.setColor(0.52, 0.42, 0.32, 0.5)
                    else
                        love.graphics.setColor(0.60, 0.55, 0.50, 0.7)
                    end
                    local highlightSize = rockSize * 0.3
                    love.graphics.circle("fill", px + offsetX + highlightSize, py + offsetY + highlightSize, highlightSize * 0.5)
                end
                
                -- Toon shadows
                if isFountainStone then
                    love.graphics.setColor(0.35, 0.32, 0.30, 0.5)
                elseif isInCave then
                    love.graphics.setColor(0.14, 0.12, 0.10, 0.8)
                else
                    love.graphics.setColor(0.22, 0.18, 0.15, 0.6)
                end
                local shadowSize = rockSize * 0.25
                love.graphics.circle("fill", 
                    px + self.tileSize / 2 + shadowSize, 
                    py + self.tileSize / 2 + shadowSize, 
                    shadowSize)
                
                -- Cracks (skip for cut fountain stones)
                if not isFountainStone then
                    if isInCave then
                        love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
                    else
                        love.graphics.setColor(0.18, 0.14, 0.10, 0.8)
                    end
                    love.graphics.setLineWidth(isInCave and 3 or 2)
                    
                    local crackPattern = (seed % 4)
                    if crackPattern == 0 then
                        love.graphics.line(
                            px + offsetX + rockSize * 0.2, 
                            py + offsetY + rockSize * 0.3,
                            px + offsetX + rockSize * 0.8, 
                            py + offsetY + rockSize * 0.7)
                    elseif crackPattern == 1 then
                        love.graphics.line(
                            px + offsetX + rockSize * 0.5, 
                            py + offsetY + rockSize * 0.1,
                            px + offsetX + rockSize * 0.5, 
                            py + offsetY + rockSize * 0.9)
                    elseif crackPattern == 2 then
                        love.graphics.circle("line", 
                            px + self.tileSize / 2, 
                            py + self.tileSize / 2, 
                            rockSize * 0.3)
                    end
                end
                
                -- Outline (stronger for fountain stones)
                if isFountainStone then
                    love.graphics.setColor(0.25, 0.22, 0.20)
                    love.graphics.setLineWidth(3)
                else
                    love.graphics.setColor(0.10, 0.08, 0.06)
                    love.graphics.setLineWidth(isInCave and 4 or 3)
                end
                love.graphics.polygon("line", noisePoints)
                love.graphics.setLineWidth(1)
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

function TileMap:drawSingleDecoration(x, y, deco)
    -- Draw a single decoration at the given tile position
    local px = x * self.tileSize
    local py = y * self.tileSize
    
    if deco == 1 then
        -- Tree with toon shading and noise variation
        local seed = x * 7 + y * 13
        
        -- Random size variation (0.8 to 1.2)
        local sizeVar = ((seed % 10) / 25) + 0.8
        
        -- Trunk with noise variation
        local trunkW = 16 * sizeVar
        local trunkH = 48 * sizeVar
        local trunkX = px + 16 - trunkW/2
        
        love.graphics.setColor(0.32, 0.20, 0.12)  -- Dark trunk
        love.graphics.rectangle("fill", trunkX, py + 16, trunkW, trunkH)
        
        -- Trunk highlight (toon style)
        love.graphics.setColor(0.42, 0.28, 0.16)
        love.graphics.rectangle("fill", trunkX, py + 16, trunkW * 0.4, trunkH)
        
        -- Trunk shadow (sharp)
        love.graphics.setColor(0.20, 0.12, 0.07)
        love.graphics.rectangle("fill", trunkX + trunkW * 0.6, py + 16, trunkW * 0.4, trunkH)
        
        -- Trunk outline
        love.graphics.setColor(0.12, 0.08, 0.05)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", trunkX, py + 16, trunkW, trunkH)
        love.graphics.setLineWidth(1)
        
        -- Foliage with noise distortion and size variation
        -- Dark base with noise
        local baseRadius = 24 * sizeVar
        local baseY = py + 20
        love.graphics.setColor(0.12, 0.32, 0.12)
        
        -- Create noisy foliage shape with multiple circles
        for i = 0, 7 do
            local angle = (i / 8) * math.pi * 2
            local noiseOffset = ((seed * 11 + i * 13) % 10) / 10
            local radius = baseRadius * (0.7 + noiseOffset * 0.4)
            local dist = baseRadius * 0.6
            love.graphics.circle("fill", 
                px + 16 + math.cos(angle) * dist, 
                baseY + math.sin(angle) * dist, 
                radius * 0.8)
        end
        
        -- Center cluster
        love.graphics.circle("fill", px + 16, baseY, baseRadius)
        
        -- Medium level with variation
        love.graphics.setColor(0.18, 0.45, 0.18)
        local midRadius = 18 * sizeVar
        local midY = py + 12
        
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2
            local noiseOffset = ((seed * 17 + i * 19) % 10) / 10
            local radius = midRadius * (0.8 + noiseOffset * 0.3)
            local dist = midRadius * 0.8
            love.graphics.circle("fill", 
                px + 16 + math.cos(angle) * dist, 
                midY + math.sin(angle) * dist * 0.7, 
                radius)
        end
        
        -- Light highlights with noise
        love.graphics.setColor(0.25, 0.58, 0.25)
        local topRadius = 14 * sizeVar
        local topY = py + 4
        
        for i = 0, 3 do
            local angle = (i / 4) * math.pi * 2
            local noiseOffset = ((seed * 23 + i * 29) % 10) / 10
            local radius = topRadius * (0.7 + noiseOffset * 0.4)
            local dist = topRadius * 0.5
            love.graphics.circle("fill", 
                px + 16 + math.cos(angle) * dist, 
                topY + math.sin(angle) * dist * 0.5, 
                radius)
        end
        
        -- Sharp toon highlights (brightest)
        love.graphics.setColor(0.35, 0.70, 0.35)
        love.graphics.circle("fill", px + 14, py - 2 * sizeVar, 8 * sizeVar)
        love.graphics.circle("fill", px + 18, py + 2 * sizeVar, 6 * sizeVar)
        
        -- Organic outline following noise pattern
        love.graphics.setColor(0.06, 0.15, 0.06)
        love.graphics.setLineWidth(2)
        
        -- Draw outline with noise distortion
        local outlinePoints = {}
        for i = 0, 15 do
            local angle = (i / 16) * math.pi * 2
            local noiseVal = ((seed * 13 + i * 17) % 10) / 10
            local radius = (26 * sizeVar) * (0.85 + noiseVal * 0.3)
            table.insert(outlinePoints, px + 16 + math.cos(angle) * radius)
            table.insert(outlinePoints, midY + math.sin(angle) * radius * 0.9)
        end
        
        love.graphics.polygon("line", outlinePoints)
        love.graphics.setLineWidth(1)
        
    elseif deco == 2 then
        -- Bush with noise variation and toon shading
        local seed = x * 11 + y * 17
        
        -- Random size variation (0.75 to 1.25)
        local sizeVar = ((seed % 10) / 20) + 0.75
        
        -- Vertical offset variation to break up uniform placement
        local yOffset = ((seed * 7) % 6) - 3  -- -3 to +3 pixel variation
        local centerY = py + 20 + yOffset  -- Moved up from 24 to 20, plus variation
        
        -- Sharp shadow (toon style)
        love.graphics.setColor(0.05, 0.15, 0.05)
        love.graphics.ellipse("fill", px + 16, centerY + 9 * sizeVar, 14 * sizeVar, 4 * sizeVar)
        
        -- Dark level (base) with noise variation
        local baseRadius = 11 * sizeVar
        love.graphics.setColor(0.14, 0.35, 0.14)
        love.graphics.circle("fill", px + 16, centerY + 4, baseRadius)
        
        -- Medium level (multiple clumps with noise positions)
        love.graphics.setColor(0.20, 0.48, 0.20)
        
        -- Randomize number of clumps (4-6)
        local clumpCount = (seed % 3) + 4
        for i = 0, clumpCount - 1 do
            local angle = (i / clumpCount) * math.pi * 2 + ((seed * 13 + i * 7) % 100) / 100
            local dist = (6 + ((seed * 3 + i * 5) % 4)) * sizeVar
            local radius = (7 + ((seed * 5 + i * 11) % 3)) * sizeVar
            local offsetX = math.cos(angle) * dist
            local offsetY = math.sin(angle) * dist * 0.7  -- Squash vertically
            love.graphics.circle("fill", px + 16 + offsetX, centerY + 2 + offsetY, radius)
        end
        
        -- Center clump
        love.graphics.circle("fill", px + 16, centerY, 9 * sizeVar)
        
        -- Light level (top highlights with noise)
        love.graphics.setColor(0.28, 0.60, 0.28)
        local highlightCount = (seed % 2) + 2  -- 2-3 highlights
        for i = 0, highlightCount do
            local angle = (i / (highlightCount + 1)) * math.pi * 2 + ((seed * 17 + i * 13) % 100) / 100
            local dist = (4 + ((seed * 7 + i * 3) % 3)) * sizeVar
            local radius = (5 + ((seed * 11 + i * 7) % 3)) * sizeVar
            local offsetX = math.cos(angle) * dist
            local offsetY = math.sin(angle) * dist * 0.6
            love.graphics.circle("fill", px + 16 + offsetX, centerY - 2 + offsetY, radius)
        end
        
        -- Brightest toon highlights (random positions)
        love.graphics.setColor(0.38, 0.75, 0.38)
        for i = 0, 2 do
            local spotX = px + 16 + ((seed * 19 + i * 23) % 8) - 4
            local spotY = centerY - 3 + ((seed * 23 + i * 19) % 6) - 3
            local spotRadius = (2 + ((seed * 3 + i) % 2)) * sizeVar
            love.graphics.circle("fill", spotX, spotY, spotRadius)
        end
        
        -- Organic outline with noise distortion
        love.graphics.setColor(0.06, 0.15, 0.06)
        love.graphics.setLineWidth(2)
        
        -- Single outline following the bush shape
        local outlinePoints = {}
        for i = 0, 11 do
            local angle = (i / 12) * math.pi * 2
            local noiseVal = ((seed * 13 + i * 17) % 10) / 10
            local radius = (baseRadius + 2) * (0.85 + noiseVal * 0.3)
            table.insert(outlinePoints, px + 16 + math.cos(angle) * radius)
            table.insert(outlinePoints, centerY + 4 + math.sin(angle) * radius * 0.8)
        end
        
        love.graphics.polygon("line", outlinePoints)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.setColor(1, 1, 1)
end

function TileMap:drawDecorations(camera)
    -- Draw decorations layer (trees, bushes, etc.)
    -- Note: This is kept for compatibility but Y-sorting should be done in main.lua
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local deco = self:getTile(x, y, "decorations")
            if deco > 0 then
                self:drawSingleDecoration(x, y, deco)
            end
        end
    end
end

function TileMap:drawRoofs(camera, playerX, playerY)
    -- Draw roofs, but only if player is NOT inside the building
    -- Check if player is within any roofed area
    local playerTileX = math.floor(playerX / self.tileSize)
    local playerTileY = math.floor(playerY / self.tileSize)
    
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            if self:getTile(x, y, "roofs") == 1 then
                -- Only draw roof if player is NOT in this building
                -- Check if player is within this roofed area (with some margin)
                local isPlayerInside = (playerTileX >= x - 1 and playerTileX <= x + 1 and
                                       playerTileY >= y - 1 and playerTileY <= y + 1)
                
                if not isPlayerInside then
                    local px = x * self.tileSize
                    local py = y * self.tileSize
                    
                -- Draw roof with toon shading
                local seed = x * 5 + y * 7
                local toonLevel = (seed % 3)
                
                -- Apply toon colors for roof
                if toonLevel == 0 then
                    love.graphics.setColor(0.35, 0.18, 0.13)  -- Dark
                elseif toonLevel == 1 then
                    love.graphics.setColor(0.42, 0.22, 0.16)  -- Medium
                else
                    love.graphics.setColor(0.50, 0.28, 0.20)  -- Light
                end
                
                love.graphics.rectangle("fill", px, py, self.tileSize, self.tileSize)
                
                -- Roof tile pattern (sharp)
                love.graphics.setColor(0.28, 0.14, 0.10)
                if (x + y) % 2 == 0 then
                    love.graphics.rectangle("fill", px, py, self.tileSize, 3)
                end
                
                -- Sharp highlight (toon style)
                if toonLevel == 2 then
                    love.graphics.setColor(0.60, 0.35, 0.25, 0.5)
                    love.graphics.rectangle("fill", px, py, self.tileSize, 2)
                end
                
                -- Draw outlines only on edges (where there's no roof neighbor)
                local hasNorth = self:getTile(x, y - 1, "roofs") == 1
                local hasSouth = self:getTile(x, y + 1, "roofs") == 1
                local hasEast = self:getTile(x + 1, y, "roofs") == 1
                local hasWest = self:getTile(x - 1, y, "roofs") == 1
                
                -- Outline color with noise variations
                local outlineR = 0.15 + ((seed * 7) % 8) / 100
                local outlineG = 0.08 + ((seed * 11) % 8) / 120
                local outlineB = 0.05 + ((seed * 13) % 8) / 150
                love.graphics.setColor(outlineR, outlineG, outlineB, 0.9)
                
                -- Variable thickness (2-4 pixels)
                local thickness = 2 + ((seed * 17) % 3)
                love.graphics.setLineWidth(thickness)
                
                -- Draw edge lines only where there's no neighbor
                if not hasNorth then
                    love.graphics.line(px, py, px + self.tileSize, py)
                end
                if not hasSouth then
                    love.graphics.line(px, py + self.tileSize, px + self.tileSize, py + self.tileSize)
                end
                if not hasWest then
                    love.graphics.line(px, py, px, py + self.tileSize)
                end
                if not hasEast then
                    love.graphics.line(px + self.tileSize, py, px + self.tileSize, py + self.tileSize)
                end
                
                love.graphics.setLineWidth(1)
                end
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

return TileMap

