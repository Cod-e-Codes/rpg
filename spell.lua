-- Spell System - Individual spell class
local Spell = {}

function Spell:new(data)
    local spell = {
        -- Base properties
        name = data.name or "Unknown Spell",
        type = data.type or "active", -- "active" or "passive"
        description = data.description or "",
        
        -- Active spell properties
        duration = data.duration or 0, -- Seconds (0 = instant/permanent)
        radius = data.radius or 0, -- Effect radius in pixels
        manaCost = data.manaCost or 10,
        cooldown = data.cooldown or 3, -- Seconds between casts
        
        -- Current state
        isActive = false,
        activeTimer = 0, -- Time remaining if active
        cooldownTimer = 0, -- Time remaining before can cast again
        
        -- Progression
        level = 1,
        maxLevel = data.maxLevel or 5,
        experience = 0,
        experiencePerSecond = data.experiencePerSecond or 5, -- XP gained per second while active
        
        -- Level thresholds for experience
        experienceThresholds = data.experienceThresholds or {100, 250, 500, 1000, 2000},
        
        -- Stat scaling per level
        radiusPerLevel = data.radiusPerLevel or 30,
        durationPerLevel = data.durationPerLevel or 10,
        
        -- Visual properties
        particleConfig = data.particleConfig or nil,
        lightColor = data.lightColor or {1, 1, 0.7},
        
        -- Icon drawing function (drawn procedurally)
        drawIcon = data.drawIcon or nil
    }
    setmetatable(spell, {__index = self})
    return spell
end

function Spell:update(dt)
    -- Update cooldown
    if self.cooldownTimer > 0 then
        self.cooldownTimer = self.cooldownTimer - dt
        if self.cooldownTimer < 0 then
            self.cooldownTimer = 0
        end
    end
    
    -- Update active duration
    if self.isActive and self.duration > 0 then
        self.activeTimer = self.activeTimer - dt
        
        -- Gain experience while active
        if self.level < self.maxLevel then
            self:addExperience(self.experiencePerSecond * dt)
        end
        
        if self.activeTimer <= 0 then
            self:deactivate()
        end
    end
end

function Spell:canActivate(playerMana)
    -- Check if spell can be activated
    if self.cooldownTimer > 0 then
        return false, "Spell is on cooldown"
    end
    
    if playerMana < self.manaCost then
        return false, "Not enough mana"
    end
    
    if self.isActive then
        return false, "Spell is already active"
    end
    
    return true, "OK"
end

function Spell:activate(playerMana)
    local canCast, reason = self:canActivate(playerMana)
    if not canCast then
        return false, reason
    end
    
    -- Attack spells (with damage) are instant cast, don't stay active
    if not self.damage then
        self.isActive = true
        self.activeTimer = self:getCurrentDuration()
    end
    
    self.cooldownTimer = self.cooldown
    
    return true, "Spell activated"
end

function Spell:deactivate()
    self.isActive = false
    self.activeTimer = 0
end

function Spell:addExperience(amount)
    if self.level >= self.maxLevel then
        return false -- Already max level
    end
    
    self.experience = self.experience + amount
    
    -- Check for level up
    local threshold = self.experienceThresholds[self.level]
    if threshold and self.experience >= threshold then
        self:levelUp()
        return true -- Leveled up
    end
    
    return false -- No level up
end

function Spell:levelUp()
    if self.level >= self.maxLevel then
        return false
    end
    
    self.level = self.level + 1
    self.experience = 0 -- Reset experience for next level
    
    return true
end

function Spell:getCurrentRadius()
    return self.radius + (self.level - 1) * self.radiusPerLevel
end

function Spell:getCurrentDuration()
    return self.duration + (self.level - 1) * self.durationPerLevel
end

function Spell:getExperienceProgress()
    if self.level >= self.maxLevel then
        return 1.0 -- 100% at max level
    end
    
    local threshold = self.experienceThresholds[self.level]
    if not threshold then
        return 1.0
    end
    
    return self.experience / threshold
end

function Spell:getCooldownProgress()
    if self.cooldownTimer <= 0 then
        return 1.0 -- Ready
    end
    
    return 1.0 - (self.cooldownTimer / self.cooldown)
end

function Spell:draw(x, y, size, isHovered, showCooldown)
    size = size or 32
    
    -- Draw background
    if isHovered then
        love.graphics.setColor(0.25, 0.22, 0.18, 0.95)
    else
        love.graphics.setColor(0.15, 0.13, 0.11, 0.8)
    end
    love.graphics.rectangle("fill", x, y, size, size, 3, 3)
    
    -- Draw icon (use custom draw function if provided)
    if self.drawIcon then
        self.drawIcon(x, y, size)
    else
        -- Default icon (simple colored square)
        love.graphics.setColor(self.lightColor)
        love.graphics.rectangle("fill", x + 4, y + 4, size - 8, size - 8, 2, 2)
    end
    
    -- Draw cooldown overlay
    if showCooldown and self.cooldownTimer > 0 then
        local progress = self:getCooldownProgress()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x, y, size, size * (1 - progress), 3, 3)
        
        -- Cooldown timer text
        love.graphics.setColor(1, 1, 1)
        local timeText = string.format("%.1f", self.cooldownTimer)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(timeText)
        love.graphics.print(timeText, x + (size - textWidth) / 2, y + size / 2 - font:getHeight() / 2)
    end
    
    -- Draw active indicator (glow)
    if self.isActive then
        love.graphics.setColor(self.lightColor[1], self.lightColor[2], self.lightColor[3], 0.3 + math.sin(love.timer.getTime() * 5) * 0.2)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 3, 3)
        love.graphics.setLineWidth(1)
    end
    
    -- Draw level badge
    if self.level > 1 then
        local badgeSize = 16
        local badgeX = x + size - badgeSize - 2
        local badgeY = y + 2
        
        -- Badge background
        love.graphics.setColor(0.9, 0.75, 0.2)
        love.graphics.circle("fill", badgeX + badgeSize / 2, badgeY + badgeSize / 2, badgeSize / 2)
        
        -- Badge outline
        love.graphics.setColor(0.2, 0.15, 0.05)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", badgeX + badgeSize / 2, badgeY + badgeSize / 2, badgeSize / 2)
        love.graphics.setLineWidth(1)
        
        -- Level number
        love.graphics.setColor(0.1, 0.08, 0.03)
        local levelText = tostring(self.level)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(levelText)
        love.graphics.print(levelText, badgeX + (badgeSize - textWidth) / 2, badgeY + 2)
    end
    
    -- Border
    if isHovered then
        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(0.35, 0.30, 0.20)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", x, y, size, size, 3, 3)
    love.graphics.setLineWidth(1)
    
    love.graphics.setColor(1, 1, 1)
end

-- Predefined spell: Illumination
function Spell.createIllumination()
    return Spell:new({
        name = "Illumination",
        type = "active",
        description = "Creates a magical light that reveals the darkness around you.",
        duration = 20,
        radius = 120,
        manaCost = 15,
        cooldown = 3,
        maxLevel = 5,
        experiencePerSecond = 5,
        experienceThresholds = {100, 250, 500, 1000, 2000},
        radiusPerLevel = 30,
        durationPerLevel = 10,
        lightColor = {0.9, 0.9, 0.5},
        particleConfig = {
            spawnRate = 15,
            lifetime = 1.5,
            speed = {min = 20, max = 40},
            size = {min = 2, max = 4},
            color = {0.9, 0.9, 0.5},
            orbitRadius = 60
        },
        drawIcon = function(x, y, size)
            -- Draw illumination spell icon
            local centerX = x + size / 2
            local centerY = y + size / 2
            local radius = size * 0.3
            
            -- Glow effect (multiple circles)
            for i = 3, 1, -1 do
                local alpha = 0.15 * i
                love.graphics.setColor(0.95, 0.95, 0.6, alpha)
                love.graphics.circle("fill", centerX, centerY, radius + i * 3)
            end
            
            -- Main orb (gradient effect with multiple circles)
            love.graphics.setColor(0.95, 0.95, 0.55)
            love.graphics.circle("fill", centerX, centerY, radius)
            
            love.graphics.setColor(0.98, 0.98, 0.7)
            love.graphics.circle("fill", centerX, centerY, radius * 0.7)
            
            love.graphics.setColor(1, 1, 0.9)
            love.graphics.circle("fill", centerX - radius * 0.2, centerY - radius * 0.2, radius * 0.3)
            
            -- Radiating lines (toon style)
            love.graphics.setColor(0.95, 0.95, 0.6, 0.6)
            love.graphics.setLineWidth(2)
            for i = 0, 7 do
                local angle = (i / 8) * math.pi * 2
                local x1 = centerX + math.cos(angle) * (radius + 2)
                local y1 = centerY + math.sin(angle) * (radius + 2)
                local x2 = centerX + math.cos(angle) * (radius + 8)
                local y2 = centerY + math.sin(angle) * (radius + 8)
                love.graphics.line(x1, y1, x2, y2)
            end
            love.graphics.setLineWidth(1)
            
            -- Outline
            love.graphics.setColor(0.3, 0.25, 0.1)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", centerX, centerY, radius)
            love.graphics.setLineWidth(1)
        end
    })
end

-- Attack Spells for each class

-- Fire Mage: Fireball
function Spell.createFireball()
    return Spell:new({
        name = "Fireball",
        type = "active",
        description = "Launch a blazing projectile",
        duration = 0,
        radius = 80,
        manaCost = 20,
        cooldown = 1.5,
        radiusPerLevel = 10,
        damage = 25,
        damagePerLevel = 5,
        lightColor = {1.0, 0.4, 0.1},
        experiencePerSecond = 10,
        
        drawIcon = function(x, y, size)
            love.graphics.setColor(1, 0.3, 0)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.4)
            love.graphics.setColor(1, 0.6, 0.1)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.25)
            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.12)
        end
    })
end

-- Ice Mage: Ice Shard
function Spell.createIceShard()
    return Spell:new({
        name = "Ice Shard",
        type = "active",
        description = "Fire a freezing projectile",
        duration = 0,
        radius = 70,
        manaCost = 18,
        cooldown = 1.3,
        radiusPerLevel = 8,
        damage = 20,
        damagePerLevel = 4,
        lightColor = {0.4, 0.7, 1.0},
        experiencePerSecond = 10,
        
        drawIcon = function(x, y, size)
            love.graphics.setColor(0.3, 0.6, 1)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.4)
            love.graphics.setColor(0.6, 0.8, 1)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.25)
            love.graphics.setColor(0.9, 0.95, 1)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.12)
        end
    })
end

-- Lightning Mage: Lightning Bolt
function Spell.createLightningBolt()
    return Spell:new({
        name = "Lightning Bolt",
        type = "active",
        description = "Strike with electric fury",
        duration = 0,
        radius = 90,
        manaCost = 22,
        cooldown = 1.8,
        radiusPerLevel = 12,
        damage = 30,
        damagePerLevel = 6,
        lightColor = {0.7, 0.6, 1.0},
        experiencePerSecond = 10,
        
        drawIcon = function(x, y, size)
            love.graphics.setColor(0.5, 0.3, 1)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.4)
            love.graphics.setColor(0.7, 0.6, 1)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.25)
            love.graphics.setColor(0.9, 0.9, 1)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.12)
        end
    })
end

-- Earth Mage: Stone Spike
function Spell.createStoneSpike()
    return Spell:new({
        name = "Stone Spike",
        type = "active",
        description = "Summon earth from below",
        duration = 0,
        radius = 75,
        manaCost = 19,
        cooldown = 1.6,
        radiusPerLevel = 9,
        damage = 22,
        damagePerLevel = 5,
        lightColor = {0.7, 0.5, 0.3},
        experiencePerSecond = 10,
        
        drawIcon = function(x, y, size)
            love.graphics.setColor(0.5, 0.35, 0.2)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.4)
            love.graphics.setColor(0.7, 0.55, 0.35)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.25)
            love.graphics.setColor(0.9, 0.75, 0.5)
            love.graphics.circle("fill", x + size/2, y + size/2, size * 0.12)
        end
    })
end

return Spell

