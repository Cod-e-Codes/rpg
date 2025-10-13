-- Lighting System - Darkness overlay with multiple light sources
local Lighting = {}

function Lighting:new()
    local lighting = {
        -- Canvas for rendering darkness overlay
        darknessCanvas = nil,
        lightCanvas = nil,
        
        -- Light sources
        lights = {}, -- Array of {x, y, radius, intensity, color, flicker}
        
        -- Ambient darkness (0 = no darkness, 1 = pitch black)
        ambientDarkness = 0,
        
        -- Rendering settings
        darknessColor = {0, 0, 0},
        useStencil = true
    }
    setmetatable(lighting, {__index = self})
    
    -- Initialize canvases
    lighting:createCanvases()
    
    return lighting
end

function Lighting:createCanvases()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Create canvases if they don't exist or are the wrong size
    if not self.darknessCanvas or 
       self.darknessCanvas:getWidth() ~= width or 
       self.darknessCanvas:getHeight() ~= height then
        self.darknessCanvas = love.graphics.newCanvas(width, height)
        self.lightCanvas = love.graphics.newCanvas(width, height)
    end
end

function Lighting:setAmbientDarkness(level)
    self.ambientDarkness = math.max(0, math.min(1, level))
end

function Lighting:addLight(x, y, radius, intensity, color, flicker)
    local light = {
        x = x or 0,
        y = y or 0,
        radius = radius or 100,
        intensity = intensity or 1.0,
        color = color or {1, 1, 1},
        flicker = flicker or 0, -- Amount of flicker (0 = none, 1 = max)
        flickerTimer = 0,
        flickerAmount = 0
    }
    table.insert(self.lights, light)
    return light
end

function Lighting:removeLight(light)
    for i, l in ipairs(self.lights) do
        if l == light then
            table.remove(self.lights, i)
            return true
        end
    end
    return false
end

function Lighting:clearLights()
    self.lights = {}
end

function Lighting:updateLight(light, x, y)
    if light then
        light.x = x
        light.y = y
    end
end

function Lighting:update(dt)
    -- Update flicker for all lights
    for _, light in ipairs(self.lights) do
        if light.flicker > 0 then
            light.flickerTimer = light.flickerTimer + dt * 5 -- Flicker speed
            light.flickerAmount = math.sin(light.flickerTimer) * light.flicker * 0.2
        end
    end
end

function Lighting:draw(camera)
    if self.ambientDarkness <= 0 then
        return -- No darkness, skip rendering
    end
    
    -- Recreate canvases if needed (window resize)
    self:createCanvases()
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- STEP 1: Create a light mask (white where lit, dark gray where not)
    love.graphics.setCanvas(self.lightCanvas)
    -- Start with dark gray (will become fully dark)
    local baseBrightness = 1 - self.ambientDarkness
    love.graphics.clear(baseBrightness, baseBrightness, baseBrightness, 1)
    
    -- Draw lights with additive blending (brightens the mask)
    love.graphics.setBlendMode("add", "premultiplied")
    
    for _, light in ipairs(self.lights) do
        -- Calculate screen position
        local screenX = light.x - camera.x
        local screenY = light.y - camera.y
        
        -- Only draw if light is potentially visible
        local margin = light.radius
        if screenX + margin >= 0 and screenX - margin <= screenWidth and
           screenY + margin >= 0 and screenY - margin <= screenHeight then
            
            -- Apply flicker
            local currentRadius = light.radius + (light.radius * light.flickerAmount)
            local currentIntensity = math.min(light.intensity + light.flickerAmount, 1.0)
            
            -- Draw light that brightens the mask
            self:drawLightBrightness(screenX, screenY, currentRadius, currentIntensity)
        end
    end
    
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()
    
    -- STEP 2: Multiply the light mask over the scene (darkens everything proportionally)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.lightCanvas, 0, 0)
    
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function Lighting:drawRadialGradient(x, y, radius, color, intensity)
    -- Draw a radial gradient using multiple circles with smooth falloff
    local steps = 30 -- More steps for smoother gradient
    
    for i = steps, 1, -1 do
        local ratio = i / steps
        local currentRadius = radius * ratio
        -- Smooth falloff curve - quadratic easing
        local falloff = 1 - (ratio * ratio)
        local alpha = intensity * falloff * falloff -- Double curve for very smooth falloff
        
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.circle("fill", x, y, currentRadius)
    end
end

function Lighting:drawLightBrightness(x, y, radius, intensity)
    -- Draw light that brightens the mask (additive - adds white)
    local steps = 25
    
    for i = steps, 1, -1 do
        local ratio = i / steps
        local currentRadius = radius * ratio
        
        -- Smooth falloff
        local falloff = 1 - (ratio * ratio)
        
        -- Add subtle noise for organic feel
        local noiseSeed = (x * 0.05 + y * 0.05 + i * 2.1)
        local noise = math.sin(noiseSeed) * math.cos(noiseSeed * 1.7) * 0.08 + 1.0
        
        -- Alpha determines brightness added to mask
        -- High intensity = more brightness = less darkening when multiplied
        local brightness = intensity * falloff * falloff * noise * self.ambientDarkness
        brightness = math.max(0, math.min(1, brightness))
        
        -- White color brightens the mask (resists multiplication darkening)
        love.graphics.setColor(brightness, brightness, brightness, brightness)
        love.graphics.circle("fill", x, y, currentRadius)
    end
end

-- Alternative implementation using custom shader (more performant but requires shader support)
function Lighting:createLightShader()
    local pixelcode = [[
        extern vec2 lightPosition;
        extern float lightRadius;
        extern vec3 lightColor;
        extern float lightIntensity;
        
        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            float dist = distance(screen_coords, lightPosition);
            float attenuation = 1.0 - smoothstep(0.0, lightRadius, dist);
            attenuation = attenuation * attenuation; // Quadratic falloff
            
            vec4 result = vec4(lightColor * lightIntensity * attenuation, attenuation);
            return result * color;
        }
    ]]
    
    local success, shader = pcall(love.graphics.newShader, pixelcode)
    if success then
        self.lightShader = shader
        return true
    else
        print("Warning: Could not create light shader, using fallback rendering")
        return false
    end
end

-- Draw using shader if available (much faster for many lights)
function Lighting:drawWithShader(camera)
    if not self.lightShader then
        return self:draw(camera) -- Fallback
    end
    
    -- Similar implementation but using shader for each light
    -- This would be significantly faster but requires more setup
    -- For now, the basic version is sufficient given current performance
end

-- Helper: Create a light that follows an object
function Lighting:createFollowLight(object, radius, intensity, color, flicker)
    local light = self:addLight(object.x, object.y, radius, intensity, color, flicker)
    light.followObject = object
    return light
end

-- Update follow lights
function Lighting:updateFollowLights()
    for _, light in ipairs(self.lights) do
        if light.followObject then
            light.x = light.followObject.x
            light.y = light.followObject.y
        end
    end
end

-- Debug visualization
function Lighting:drawDebug(camera)
    if not DEBUG_MODE then return end
    
    for _, light in ipairs(self.lights) do
        local screenX = light.x - camera.x
        local screenY = light.y - camera.y
        
        -- Draw light radius
        love.graphics.setColor(light.color[1], light.color[2], light.color[3], 0.3)
        love.graphics.circle("line", screenX, screenY, light.radius)
        
        -- Draw center point
        love.graphics.setColor(light.color[1], light.color[2], light.color[3], 0.8)
        love.graphics.circle("fill", screenX, screenY, 5)
        
        -- Draw info
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("R:%.0f I:%.1f", light.radius, light.intensity), screenX + 10, screenY)
    end
    
    -- Draw ambient darkness level
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Ambient Darkness: %.1f%%", self.ambientDarkness * 100), 10, 100)
end

return Lighting

