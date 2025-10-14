-- Spell Projectile System
local Projectile = {}

function Projectile:new(x, y, playerDirection, spell, playerElement)
    -- Calculate direction based on player facing
    local velocityX, velocityY = 0, 0
    local speed = 300
    
    if playerDirection == "north" then
        velocityY = -speed
    elseif playerDirection == "south" then
        velocityY = speed
    elseif playerDirection == "east" then
        velocityX = speed
    elseif playerDirection == "west" then
        velocityX = -speed
    elseif playerDirection == "north-east" then
        velocityX = speed * 0.707
        velocityY = -speed * 0.707
    elseif playerDirection == "north-west" then
        velocityX = -speed * 0.707
        velocityY = -speed * 0.707
    elseif playerDirection == "south-east" then
        velocityX = speed * 0.707
        velocityY = speed * 0.707
    elseif playerDirection == "south-west" then
        velocityX = -speed * 0.707
        velocityY = speed * 0.707
    end
    
    local proj = {
        x = x,
        y = y,
        velocityX = velocityX,
        velocityY = velocityY,
        radius = 12, -- Bigger for visibility
        lifetime = 2.5, -- Seconds before despawn
        age = 0,
        damage = spell.damage or 20,
        spellName = spell.name,
        element = playerElement or "fire",
        active = true,
        hitEnemies = {} -- Track which enemies have been hit
    }
    setmetatable(proj, {__index = self})
    return proj
end

function Projectile:update(dt)
    if not self.active then return end
    
    self.x = self.x + self.velocityX * dt
    self.y = self.y + self.velocityY * dt
    self.age = self.age + dt
    
    -- Despawn after lifetime
    if self.age >= self.lifetime then
        self.active = false
    end
end

function Projectile:checkCollision(enemies)
    if not self.active then return nil end
    
    for i, enemy in ipairs(enemies) do
        if not enemy.isDead and not self.hitEnemies[i] then
            local dx = self.x - enemy.x
            local dy = self.y - enemy.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance < self.radius + 16 then -- Enemy collision radius
                self.hitEnemies[i] = true
                self.active = false -- Projectile disappears on hit
                return enemy
            end
        end
    end
    
    return nil
end

function Projectile:draw()
    if not self.active then return end
    
    -- Element-specific colors
    local color1, color2
    if self.element == "fire" then
        color1 = {1.0, 0.4, 0.1}
        color2 = {1.0, 0.8, 0.3}
    elseif self.element == "ice" then
        color1 = {0.4, 0.7, 1.0}
        color2 = {0.8, 0.95, 1.0}
    elseif self.element == "lightning" then
        color1 = {0.6, 0.4, 1.0}
        color2 = {0.9, 0.9, 1.0}
    elseif self.element == "earth" then
        color1 = {0.6, 0.4, 0.3}
        color2 = {0.9, 0.75, 0.5}
    elseif self.element == "light" then
        color1 = {1.0, 1.0, 0.8}
        color2 = {1.0, 1.0, 0.95}
    end
    
    -- Draw projectile with glow effect (make it bigger and more visible)
    love.graphics.setColor(color1[1], color1[2], color1[3], 0.4)
    love.graphics.circle("fill", self.x, self.y, self.radius * 3)
    
    love.graphics.setColor(color1[1], color1[2], color1[3], 0.8)
    love.graphics.circle("fill", self.x, self.y, self.radius * 2)
    
    love.graphics.setColor(color2[1], color2[2], color2[3], 1)
    love.graphics.circle("fill", self.x, self.y, self.radius * 1.2)
    
    -- Bright core
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", self.x, self.y, self.radius * 0.5)
    
    love.graphics.setColor(1, 1, 1)
end

return Projectile

