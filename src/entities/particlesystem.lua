-- Particle System with camera culling for performance
local ParticleSystem = {}

-- Individual Particle class
local Particle = {}

function Particle:new(x, y, config)
    local particle = {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        lifetime = config.lifetime or 1.0,
        maxLifetime = config.lifetime or 1.0,
        size = config.size or 3,
        color = config.color or {1, 1, 1},
        alpha = 1,
        fadeIn = config.fadeIn or 0.2,
        fadeOut = config.fadeOut or 0.5,
        -- Orbit properties (for particles that orbit a point)
        orbitCenter = config.orbitCenter or nil,
        orbitRadius = config.orbitRadius or 0,
        orbitAngle = config.orbitAngle or 0,
        orbitSpeed = config.orbitSpeed or 0,
        isDead = false
    }
    
    -- Random velocity if speed range provided
    if config.speed then
        local angle = math.random() * math.pi * 2
        local speed = config.speed.min + math.random() * (config.speed.max - config.speed.min)
        particle.vx = math.cos(angle) * speed
        particle.vy = math.sin(angle) * speed
    end
    
    setmetatable(particle, {__index = Particle})
    return particle
end

function Particle:update(dt)
    self.lifetime = self.lifetime - dt
    
    if self.lifetime <= 0 then
        self.isDead = true
        return
    end
    
    -- Update position
    if self.orbitCenter then
        -- Orbit around center point
        self.orbitAngle = self.orbitAngle + self.orbitSpeed * dt
        self.x = self.orbitCenter.x + math.cos(self.orbitAngle) * self.orbitRadius
        self.y = self.orbitCenter.y + math.sin(self.orbitAngle) * self.orbitRadius
    else
        -- Move with velocity
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
    end
    
    -- Update alpha (fade in/out)
    local age = self.maxLifetime - self.lifetime
    if age < self.fadeIn then
        -- Fading in
        self.alpha = age / self.fadeIn
    elseif self.lifetime < self.fadeOut then
        -- Fading out
        self.alpha = self.lifetime / self.fadeOut
    else
        -- Fully visible
        self.alpha = 1
    end
end

function Particle:draw()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
    love.graphics.circle("fill", self.x, self.y, self.size)
end

-- Particle Emitter class
local ParticleEmitter = {}

function ParticleEmitter:new(x, y, config)
    local emitter = {
        x = x,
        y = y,
        config = config or {},
        particles = {},
        spawnTimer = 0,
        spawnRate = config.spawnRate or 10, -- Particles per second
        maxParticles = config.maxParticles or 200,
        isActive = true,
        -- For following objects (like player)
        followTarget = config.followTarget or nil,
        -- Camera culling margin
        cullingMargin = 200
    }
    setmetatable(emitter, {__index = ParticleEmitter})
    return emitter
end

function ParticleEmitter:update(dt, camera)
    -- Update position if following target
    if self.followTarget then
        self.x = self.followTarget.x or self.x
        self.y = self.followTarget.y or self.y
    end
    
    -- Spawn new particles
    if self.isActive and #self.particles < self.maxParticles then
        self.spawnTimer = self.spawnTimer + dt
        local spawnInterval = 1 / self.spawnRate
        
        while self.spawnTimer >= spawnInterval and #self.particles < self.maxParticles do
            self.spawnTimer = self.spawnTimer - spawnInterval
            self:spawnParticle()
        end
    end
    
    -- Update existing particles (with camera culling)
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        
        -- Check if particle is in view (with margin)
        local inView = true
        if camera then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            inView = particle.x > camera.x - self.cullingMargin and
                     particle.x < camera.x + screenWidth + self.cullingMargin and
                     particle.y > camera.y - self.cullingMargin and
                     particle.y < camera.y + screenHeight + self.cullingMargin
        end
        
        if inView then
            particle:update(dt)
        else
            -- Still update lifetime even if off-screen (so particles don't accumulate)
            particle.lifetime = particle.lifetime - dt
            if particle.lifetime <= 0 then
                particle.isDead = true
            end
        end
        
        -- Remove dead particles
        if particle.isDead then
            table.remove(self.particles, i)
        end
    end
end

function ParticleEmitter:spawnParticle()
    local config = self.config
    
    -- Random offset from emitter position
    local offsetX = 0
    local offsetY = 0
    if config.spawnRadius then
        local angle = math.random() * math.pi * 2
        local dist = math.random() * config.spawnRadius
        offsetX = math.cos(angle) * dist
        offsetY = math.sin(angle) * dist
    end
    
    -- Create particle config
    local particleConfig = {
        lifetime = config.lifetime or 1.0,
        size = config.size or 3,
        color = config.color or {1, 1, 1},
        speed = config.speed or nil,
        fadeIn = config.fadeIn or 0.2,
        fadeOut = config.fadeOut or 0.5
    }
    
    -- Random size variation
    if type(config.size) == "table" then
        particleConfig.size = config.size.min + math.random() * (config.size.max - config.size.min)
    end
    
    -- Orbit configuration
    if config.orbitRadius and config.orbitRadius > 0 then
        particleConfig.orbitCenter = {x = self.x, y = self.y}
        particleConfig.orbitRadius = config.orbitRadius
        particleConfig.orbitAngle = math.random() * math.pi * 2
        particleConfig.orbitSpeed = config.orbitSpeed or 2 -- Radians per second
        
        -- Start particle at orbit position
        offsetX = math.cos(particleConfig.orbitAngle) * config.orbitRadius
        offsetY = math.sin(particleConfig.orbitAngle) * config.orbitRadius
    end
    
    local particle = Particle:new(self.x + offsetX, self.y + offsetY, particleConfig)
    table.insert(self.particles, particle)
end

function ParticleEmitter:draw(camera)
    -- Only draw particles in view
    for _, particle in ipairs(self.particles) do
        -- Check if particle is in view
        local inView = true
        if camera then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            inView = particle.x > camera.x - self.cullingMargin and
                     particle.x < camera.x + screenWidth + self.cullingMargin and
                     particle.y > camera.y - self.cullingMargin and
                     particle.y < camera.y + screenHeight + self.cullingMargin
        end
        
        if inView then
            particle:draw()
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

function ParticleEmitter:setPosition(x, y)
    self.x = x
    self.y = y
end

function ParticleEmitter:setActive(active)
    self.isActive = active
end

function ParticleEmitter:clear()
    self.particles = {}
end

function ParticleEmitter:getParticleCount()
    return #self.particles
end

-- Predefined particle configurations
ParticleSystem.configs = {
    illumination = {
        spawnRate = 15,
        lifetime = 1.5,
        speed = {min = 20, max = 40},
        size = {min = 2, max = 4},
        color = {0.9, 0.9, 0.5},
        orbitRadius = 60,
        orbitSpeed = 2,
        fadeIn = 0.2,
        fadeOut = 0.5,
        maxParticles = 100
    },
    
    scroll_glow = {
        spawnRate = 8,
        lifetime = 2.0,
        speed = {min = 5, max = 15},
        size = {min = 2, max = 3},
        color = {0.95, 0.85, 0.4},
        spawnRadius = 20,
        fadeIn = 0.3,
        fadeOut = 0.8,
        maxParticles = 50
    },
    
    magic_sparkle = {
        spawnRate = 20,
        lifetime = 0.8,
        speed = {min = 30, max = 60},
        size = {min = 1, max = 3},
        color = {0.8, 0.5, 0.9},
        fadeIn = 0.1,
        fadeOut = 0.3,
        maxParticles = 80
    },
    
    torch = {
        spawnRate = 12,
        lifetime = 1.2,
        speed = {min = 10, max = 25},
        size = {min = 2, max = 4},
        color = {1, 0.6, 0.2},
        spawnRadius = 8,
        fadeIn = 0.2,
        fadeOut = 0.5,
        maxParticles = 60
    }
}

-- Factory method to create emitter with predefined config
function ParticleSystem.createEmitter(x, y, configName, customConfig)
    local config = ParticleSystem.configs[configName] or {}
    
    -- Merge custom config if provided
    if customConfig then
        for k, v in pairs(customConfig) do
            config[k] = v
        end
    end
    
    return ParticleEmitter:new(x, y, config)
end

-- Export classes
ParticleSystem.Particle = Particle
ParticleSystem.ParticleEmitter = ParticleEmitter

return ParticleSystem

