-- Enemy System with patrol and chase AI
local Enemy = {}

function Enemy:new(x, y, enemyType, data)
    local enemy = {
        x = x,
        y = y,
        width = 32,
        height = 32,
        enemyType = enemyType, -- "skeleton", etc.
        data = data or {},
        direction = "south", -- Current facing direction (north, south, east, west)
        animations = {walk = {}}, -- Loaded walk animations
        scale = 2,
        -- Collision
        isSolid = true,
        isMoving = false,
        moveSpeed = 60, -- Slower than player
        -- Animation frames
        currentFrame = 1,
        frameTimer = 0,
        walkFrameDelay = 0.12,
        -- Patrol system
        patrolRoute = data.patrolRoute or {},
        currentWaypoint = 1,
        patrolPauseTimer = 0,
        patrolPauseTime = 1.5,
        -- Chase AI
        aggroRange = data.aggroRange or 150, -- Distance to start chasing
        deaggroRange = data.deaggroRange or 250, -- Distance to give up chase
        isChasing = false,
        chaseTarget = nil,
        -- Terrain collision callback
        checkTerrainCollision = nil,
        -- Knockback
        knockbackDistance = 80
    }
    setmetatable(enemy, {__index = self})
    
    -- Load animations
    enemy:loadAnimations()
    
    return enemy
end

function Enemy:loadAnimations()
    local basePath = string.format("assets/enemies/%s/animations/scary-walk/", self.enemyType)
    local directions = {"north", "south", "east", "west"}
    
    -- Load walk animations (6 frames per direction for skeleton)
    for _, direction in ipairs(directions) do
        self.animations.walk[direction] = {}
        for i = 0, 5 do
            local path = string.format("%s%s/frame_%03d.png", basePath, direction, i)
            local success, image = pcall(love.graphics.newImage, path)
            if success then
                table.insert(self.animations.walk[direction], image)
            end
        end
    end
end

function Enemy:update(dt, playerX, playerY, gameTime, canHitPlayer)
    -- Check distance to player
    local dx = playerX - self.x
    local dy = playerY - self.y
    local distanceToPlayer = math.sqrt(dx * dx + dy * dy)
    
    -- Check for knockback collision (when enemy touches player and they can be hit)
    if distanceToPlayer < 28 and canHitPlayer then
        -- Return knockback event
        return {
            type = "knockback",
            direction = {x = dx, y = dy},
            distance = self.knockbackDistance
        }
    end
    
    -- Chase AI
    if not self.isChasing and distanceToPlayer < self.aggroRange then
        -- Start chasing
        self.isChasing = true
        self.chaseTarget = {x = playerX, y = playerY}
    elseif self.isChasing and distanceToPlayer > self.deaggroRange then
        -- Give up chase, return to patrol
        self.isChasing = false
        self.chaseTarget = nil
    end
    
    -- Update behavior based on state
    if self.isChasing then
        self:updateChase(dt, playerX, playerY)
    elseif #self.patrolRoute > 0 then
        self:updatePatrol(dt)
    else
        -- Idle
        self.isMoving = false
    end
    
    -- Update animation frames
    self.frameTimer = self.frameTimer + dt
    if self.frameTimer >= self.walkFrameDelay then
        self.frameTimer = self.frameTimer - self.walkFrameDelay
        if self.isMoving and #self.animations.walk[self.direction] > 0 then
            self.currentFrame = self.currentFrame + 1
            if self.currentFrame > #self.animations.walk[self.direction] then
                self.currentFrame = 1
            end
        end
    end
    
    return nil
end

function Enemy:updateChase(dt, playerX, playerY)
    -- Chase player
    local dx = playerX - self.x
    local dy = playerY - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 10 then
        -- Move towards player
        self.isMoving = true
        local moveX = (dx / distance) * self.moveSpeed * dt
        local moveY = (dy / distance) * self.moveSpeed * dt
        
        local newX = self.x + moveX
        local newY = self.y + moveY
        
        -- Check terrain collision (callback set from main.lua)
        if self.checkTerrainCollision then
            if not self.checkTerrainCollision(newX, newY) then
                self.x = newX
                self.y = newY
            elseif not self.checkTerrainCollision(newX, self.y) then
                -- Try X only
                self.x = newX
            elseif not self.checkTerrainCollision(self.x, newY) then
                -- Try Y only
                self.y = newY
            end
        else
            -- No collision check available, just move
            self.x = newX
            self.y = newY
        end
        
        -- Update facing direction based on movement
        if math.abs(dx) > math.abs(dy) then
            self.direction = dx > 0 and "east" or "west"
        else
            self.direction = dy > 0 and "south" or "north"
        end
    else
        self.isMoving = false
    end
end

function Enemy:updatePatrol(dt)
    if #self.patrolRoute == 0 then return end
    
    -- Handle pause at waypoint
    if self.patrolPauseTimer > 0 then
        self.patrolPauseTimer = self.patrolPauseTimer - dt
        self.isMoving = false
        return
    end
    
    -- Get current waypoint
    local waypoint = self.patrolRoute[self.currentWaypoint]
    local dx = waypoint.x - self.x
    local dy = waypoint.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 5 then
        -- Reached waypoint
        self.x = waypoint.x
        self.y = waypoint.y
        self.isMoving = false
        
        -- Pause at waypoint
        self.patrolPauseTimer = self.patrolPauseTime
        
        -- Move to next waypoint
        self.currentWaypoint = self.currentWaypoint + 1
        if self.currentWaypoint > #self.patrolRoute then
            self.currentWaypoint = 1
        end
    else
        -- Move towards waypoint
        self.isMoving = true
        local moveX = (dx / distance) * self.moveSpeed * dt
        local moveY = (dy / distance) * self.moveSpeed * dt
        
        local newX = self.x + moveX
        local newY = self.y + moveY
        
        -- Check terrain collision
        if self.checkTerrainCollision then
            if not self.checkTerrainCollision(newX, newY) then
                self.x = newX
                self.y = newY
            elseif not self.checkTerrainCollision(newX, self.y) then
                -- Try X only
                self.x = newX
            elseif not self.checkTerrainCollision(self.x, newY) then
                -- Try Y only
                self.y = newY
            end
        else
            -- No collision check available, just move
            self.x = newX
            self.y = newY
        end
        
        -- Update facing direction based on movement
        if math.abs(dx) > math.abs(dy) then
            self.direction = dx > 0 and "east" or "west"
        else
            self.direction = dy > 0 and "south" or "north"
        end
    end
end

function Enemy:draw()
    local image = nil
    
    -- Always use walk animation (even when idle for spooky effect)
    if self.animations.walk[self.direction] and 
       #self.animations.walk[self.direction] > 0 then
        image = self.animations.walk[self.direction][self.currentFrame]
    end
    
    if image then
        local imageWidth = image:getWidth()
        local imageHeight = image:getHeight()
        
        -- Tint red when chasing
        if self.isChasing then
            love.graphics.setColor(1, 0.7, 0.7)
        end
        
        love.graphics.draw(
            image,
            self.x,
            self.y,
            0,
            self.scale,
            self.scale,
            imageWidth / 2,
            imageHeight / 2
        )
        
        love.graphics.setColor(1, 1, 1)
    else
        -- Fallback: draw a simple colored rectangle
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", self.x - 16, self.y - 16, 32, 32)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Debug: draw aggro range and chase state
    if DEBUG_MODE then
        -- Aggro range circle (yellow when idle, red when chasing)
        love.graphics.setLineWidth(2)
        if self.isChasing then
            love.graphics.setColor(1, 0, 0, 0.4)
            love.graphics.circle("line", self.x, self.y, self.aggroRange)
            
            -- Draw line to player when chasing
            love.graphics.setColor(1, 0, 0, 0.6)
            love.graphics.setLineWidth(3)
            -- Note: playerX, playerY not available here, would need to pass them
        else
            love.graphics.setColor(1, 1, 0, 0.3)
            love.graphics.circle("line", self.x, self.y, self.aggroRange)
        end
        
        -- De-aggro range (outer circle, cyan)
        love.graphics.setColor(0, 1, 1, 0.2)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", self.x, self.y, self.deaggroRange)
        
        -- State text above enemy
        love.graphics.setColor(1, 1, 1)
        local stateText = self.isChasing and "CHASING" or (self.isMoving and "PATROL" or "IDLE")
        local textWidth = love.graphics.getFont():getWidth(stateText)
        
        -- Dark background for text
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", self.x - textWidth/2 - 4, self.y - 50 - 4, textWidth + 8, 20)
        
        -- State text
        if self.isChasing then
            love.graphics.setColor(1, 0.3, 0.3)
        elseif self.isMoving then
            love.graphics.setColor(1, 1, 0.5)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
        end
        love.graphics.print(stateText, self.x - textWidth/2, self.y - 50)
        
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1)
    end
end

function Enemy:checkCollision(x, y, width, height)
    -- AABB collision check
    local enemyLeft = self.x - 16
    local enemyRight = self.x + 16
    local enemyTop = self.y - 16
    local enemyBottom = self.y + 16
    
    return x < enemyRight and
           x + width > enemyLeft and
           y < enemyBottom and
           y + height > enemyTop
end

function Enemy:isPlayerNear(playerX, playerY, distance)
    distance = distance or 48
    local dx = self.x - playerX
    local dy = self.y - playerY
    return math.sqrt(dx * dx + dy * dy) < distance
end

return Enemy

