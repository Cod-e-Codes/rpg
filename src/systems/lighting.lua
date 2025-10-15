-- Lighting System - Darkness overlay with multiple light sources
local Lighting = {}

function Lighting.new()
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
    setmetatable(lighting, {__index = Lighting})
    lighting:createCanvases()
    return lighting
end

function Lighting:createCanvases()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
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
        flicker = flicker or 0,
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
    for _, light in ipairs(self.lights) do
        if light.flicker > 0 then
            light.flickerTimer = light.flickerTimer + dt * 5
            light.flickerAmount = math.sin(light.flickerTimer) * light.flicker * 0.2
        end
    end
end

function Lighting:draw(camera)
    if self.ambientDarkness <= 0 then return end
    self:createCanvases()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    love.graphics.setCanvas(self.lightCanvas)
    local baseBrightness = 1 - self.ambientDarkness
    love.graphics.clear(baseBrightness, baseBrightness, baseBrightness, 1)
    love.graphics.setBlendMode("add", "premultiplied")
    for _, light in ipairs(self.lights) do
        local screenX = light.x - camera.x
        local screenY = light.y - camera.y
        local margin = light.radius
        if screenX + margin >= 0 and screenX - margin <= screenWidth and
           screenY + margin >= 0 and screenY - margin <= screenHeight then
            local currentRadius = light.radius + (light.radius * light.flickerAmount)
            local currentIntensity = math.min(light.intensity + light.flickerAmount, 1.0)
            self:drawLightBrightness(screenX, screenY, currentRadius, currentIntensity)
        end
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.lightCanvas, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function Lighting:drawRadialGradient(x, y, radius, color, intensity)
    local steps = 30
    for i = steps, 1, -1 do
        local ratio = i / steps
        local currentRadius = radius * ratio
        local falloff = 1 - (ratio * ratio)
        local alpha = intensity * falloff * falloff
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.circle("fill", x, y, currentRadius)
    end
end

function Lighting:drawLightBrightness(x, y, radius, intensity)
    local steps = 25
    for i = steps, 1, -1 do
        local ratio = i / steps
        local currentRadius = radius * ratio
        local falloff = 1 - (ratio * ratio)
        local noiseSeed = (x * 0.05 + y * 0.05 + i * 2.1)
        local noise = math.sin(noiseSeed) * math.cos(noiseSeed * 1.7) * 0.08 + 1.0
        local brightness = intensity * falloff * falloff * noise * self.ambientDarkness
        brightness = math.max(0, math.min(1, brightness))
        love.graphics.setColor(brightness, brightness, brightness, brightness)
        love.graphics.circle("fill", x, y, currentRadius)
    end
end

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

function Lighting:drawWithShader(camera)
    if not self.lightShader then
        return self:draw(camera)
    end
end

function Lighting:createFollowLight(object, radius, intensity, color, flicker)
    local light = self:addLight(object.x, object.y, radius, intensity, color, flicker)
    light.followObject = object
    return light
end

function Lighting:updateFollowLights()
    for _, light in ipairs(self.lights) do
        if light.followObject then
            light.x = light.followObject.x
            light.y = light.followObject.y
        end
    end
end

function Lighting:drawDebug(camera)
    if not DEBUG_MODE then return end
    for _, light in ipairs(self.lights) do
        local screenX = light.x - camera.x
        local screenY = light.y - camera.y
        love.graphics.setColor(light.color[1], light.color[2], light.color[3], 0.3)
        love.graphics.circle("line", screenX, screenY, light.radius)
        love.graphics.setColor(light.color[1], light.color[2], light.color[3], 0.8)
        love.graphics.circle("fill", screenX, screenY, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("R:%.0f I:%.1f", light.radius, light.intensity), screenX + 10, screenY)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Ambient Darkness: %.1f%%", self.ambientDarkness * 100), 10, 100)
end

return Lighting


