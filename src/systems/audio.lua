-- Centralized Audio subsystem
local AudioSystem = {}

function AudioSystem.new()
    local self = {
        -- Sources (populated in loadAll)
        footstepSound = nil,
        riverSound = nil,
        fountainSound = nil,
        caveSound = nil,
        overworldSound = nil,
        villageSound = nil,
        magicalVoyageMusic = nil,
        fightSongMusic = nil,
        npcTalkingSound = nil,

        -- Volume state/lerp
        footstepTargetVolume = 0, footstepCurrentVolume = 0, footstepFadeSpeed = 2,
        riverTargetVolume = 0, riverCurrentVolume = 0, riverFadeSpeed = 1.5, riverPreviousTargetVolume = 0,
        fountainTargetVolume = 0, fountainCurrentVolume = 0, fountainFadeSpeed = 1.5, fountainPreviousTargetVolume = 0,
        caveTargetVolume = 0, caveCurrentVolume = 0, caveFadeSpeed = 1,
        overworldTargetVolume = 0, overworldCurrentVolume = 0, overworldFadeSpeed = 0.8,
        villageTargetVolume = 0, villageCurrentVolume = 0, villageFadeSpeed = 0.5,
        magicalVoyageTargetVolume = 0, magicalVoyageCurrentVolume = 0, magicalVoyageFadeSpeed = 0.6,
        fightSongTargetVolume = 0, fightSongCurrentVolume = 0, fightSongFadeSpeed = 0.8,
        npcTalkingTargetVolume = 0, npcTalkingCurrentVolume = 0, npcTalkingFadeSpeed = 2
    }

    function self:loadAll(gameState)
        local ok, err
        -- Footsteps
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/footsteps.mp3", "stream")
            self.footstepSound = s; s:setLooping(true); s:setVolume(0); s:setPitch(2.0); s:play()
        end)
        if not ok then print("Warning: Could not load footsteps.mp3: " .. tostring(err)) end

        -- River
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/river.mp3", "stream")
            self.riverSound = s; s:setLooping(true); s:setVolume(0); s:play()
        end)
        if not ok then print("Warning: Could not load river.mp3: " .. tostring(err)) end

        -- Fountain
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/fountain.mp3", "stream")
            self.fountainSound = s; s:setLooping(true); s:setVolume(0); s:play()
        end)
        if not ok then print("Warning: Could not load fountain.mp3: " .. tostring(err)) end

        -- Cave ambient
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/cave-sounds.mp3", "stream")
            self.caveSound = s; s:setLooping(true); s:setVolume(0); s:play()
        end)
        if not ok then print("Warning: Could not load cave-sounds.mp3: " .. tostring(err)) end

        -- Overworld ambient
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/overworld-sounds.mp3", "stream")
            self.overworldSound = s; s:setLooping(true); s:setVolume(0); s:play()
        end)
        if not ok then print("Warning: Could not load overworld-sounds.mp3: " .. tostring(err)) end

        -- Village ambient
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/village-sounds.mp3", "stream")
            self.villageSound = s; s:setLooping(true); s:setVolume(0); s:play()
        end)
        if not ok then print("Warning: Could not load village-sounds.mp3: " .. tostring(err)) end

        -- Music: Magical Voyage
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/magical-voyage.mp3", "stream")
            self.magicalVoyageMusic = s; s:setLooping(true); s:setVolume(0)
        end)
        if not ok then print("Warning: Could not load magical-voyage.mp3: " .. tostring(err)) end

        -- Music: Fight song
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/fight-song.mp3", "stream")
            self.fightSongMusic = s; s:setLooping(true); s:setVolume(0)
        end)
        if not ok then print("Warning: Could not load fight-song.mp3: " .. tostring(err)) end

        -- NPC talking sound (looped, starts at 0)
        ok, err = pcall(function()
            local s = love.audio.newSource("assets/sounds/npc-talking.mp3", "static")
            self.npcTalkingSound = s; if s.setLooping then s:setLooping(true) end; if s.setVolume then s:setVolume(0) end
        end)
        if not ok then print("Warning: Could not load npc-talking.mp3: " .. tostring(err)) end
    end

    function self:update(dt, gameState, startScreen, uiState, world, player, skeletonSpawn, camera)
        if uiState.isPaused then return end

        -- Magical voyage background music
        if self.magicalVoyageMusic then
            local onStart = not startScreen.gameStarted
            local inMusicMap = startScreen.gameStarted and gameState and (gameState.currentMap == "class_selection" or gameState.currentMap == "defense_trials")
            local inCombat = (skeletonSpawn.state == "spawning" or skeletonSpawn.state == "combat")
            self.magicalVoyageTargetVolume = (not player.isDead and (onStart or (inMusicMap and not inCombat))) and 0.4 or 0
            if self.magicalVoyageCurrentVolume < self.magicalVoyageTargetVolume then
                self.magicalVoyageCurrentVolume = math.min(self.magicalVoyageTargetVolume, self.magicalVoyageCurrentVolume + self.magicalVoyageFadeSpeed * dt)
            elseif self.magicalVoyageCurrentVolume > self.magicalVoyageTargetVolume then
                self.magicalVoyageCurrentVolume = math.max(self.magicalVoyageTargetVolume, self.magicalVoyageCurrentVolume - self.magicalVoyageFadeSpeed * dt)
            end
            ---@type any
            local s = self.magicalVoyageMusic
            if s then
                if s.setVolume then s:setVolume(self.magicalVoyageCurrentVolume * gameState.musicVolume) end
                if self.magicalVoyageCurrentVolume > 0 and s.isPlaying and s.play and not s:isPlaying() then s:play() end
                if self.magicalVoyageCurrentVolume <= 0 and s.isPlaying and s.stop and s:isPlaying() then s:stop() end
            end
        end

        -- Fight song
        if self.fightSongMusic then
            if player.isDead or (startScreen.gameStarted and (skeletonSpawn.state == "spawning" or skeletonSpawn.state == "combat")) then
                self.fightSongTargetVolume = 0.4
            else
                self.fightSongTargetVolume = 0
            end
            if self.fightSongCurrentVolume < self.fightSongTargetVolume then
                self.fightSongCurrentVolume = math.min(self.fightSongTargetVolume, self.fightSongCurrentVolume + self.fightSongFadeSpeed * dt)
            elseif self.fightSongCurrentVolume > self.fightSongTargetVolume then
                self.fightSongCurrentVolume = math.max(self.fightSongTargetVolume, self.fightSongCurrentVolume - self.fightSongFadeSpeed * dt)
            end
            ---@type any
            local s = self.fightSongMusic
            if s then
                if s.setVolume then s:setVolume(self.fightSongCurrentVolume * gameState.musicVolume) end
                if self.fightSongCurrentVolume > 0 and s.isPlaying and s.play and not s:isPlaying() then s:play() end
                if self.fightSongCurrentVolume <= 0 and s.isPlaying and s.stop and s:isPlaying() then s:stop() end
            end
        end

        -- Footsteps
        if self.footstepSound then
            if self.footstepCurrentVolume < self.footstepTargetVolume then
                self.footstepCurrentVolume = math.min(self.footstepTargetVolume, self.footstepCurrentVolume + self.footstepFadeSpeed * dt)
            elseif self.footstepCurrentVolume > self.footstepTargetVolume then
                self.footstepCurrentVolume = math.max(self.footstepTargetVolume, self.footstepCurrentVolume - self.footstepFadeSpeed * dt)
            end
            ---@type any
            local s = self.footstepSound
            if s and s.setVolume then s:setVolume(self.footstepCurrentVolume * gameState.sfxVolume) end
        end

        -- River volume (based on visibility)
        if self.riverSound and startScreen.gameStarted and world.currentMap then
            local hasWater = false
            if camera and world.currentMap.hasVisibleWater then
                hasWater = world.currentMap:hasVisibleWater(camera)
            end
            self.riverTargetVolume = hasWater and 0.85 or 0
            if self.riverCurrentVolume < self.riverTargetVolume then
                self.riverCurrentVolume = math.min(self.riverTargetVolume, self.riverCurrentVolume + self.riverFadeSpeed * dt)
            elseif self.riverCurrentVolume > self.riverTargetVolume then
                self.riverCurrentVolume = math.max(self.riverTargetVolume, self.riverCurrentVolume - self.riverFadeSpeed * dt)
            end
            ---@type any
            local s = self.riverSound
            if s and s.setVolume then s:setVolume(self.riverCurrentVolume * gameState.sfxVolume) end
        end

        -- Fountain volume (based on visibility)
        if self.fountainSound and startScreen.gameStarted and world.currentMap then
            local hasFountain = false
            if camera and world.currentMap.hasVisibleFountain then
                hasFountain = world.currentMap:hasVisibleFountain(camera)
            end
            self.fountainTargetVolume = hasFountain and 0.7 or 0
            if self.fountainCurrentVolume < self.fountainTargetVolume then
                self.fountainCurrentVolume = math.min(self.fountainTargetVolume, self.fountainCurrentVolume + self.fountainFadeSpeed * dt)
            elseif self.fountainCurrentVolume > self.fountainTargetVolume then
                self.fountainCurrentVolume = math.max(self.fountainTargetVolume, self.fountainCurrentVolume - self.fountainFadeSpeed * dt)
            end
            ---@type any
            local s = self.fountainSound
            if s and s.setVolume then s:setVolume(self.fountainCurrentVolume * gameState.sfxVolume) end
        end

        -- Cave ambient
        if self.caveSound and startScreen.gameStarted then
            local inCave = gameState.currentMap == "cave_level1"
            self.caveTargetVolume = inCave and 0.6 or 0
            if self.caveCurrentVolume < self.caveTargetVolume then
                self.caveCurrentVolume = math.min(self.caveTargetVolume, self.caveCurrentVolume + self.caveFadeSpeed * dt)
            elseif self.caveCurrentVolume > self.caveTargetVolume then
                self.caveCurrentVolume = math.max(self.caveTargetVolume, self.caveCurrentVolume - self.caveFadeSpeed * dt)
            end
            ---@type any
            local s = self.caveSound
            if s and s.setVolume then s:setVolume(self.caveCurrentVolume * gameState.sfxVolume) end
        end

        -- Overworld ambient
        if self.overworldSound and startScreen.gameStarted then
            local inOverworld = gameState.currentMap == "overworld"
            self.overworldTargetVolume = inOverworld and 0.5 or 0
            if self.overworldCurrentVolume < self.overworldTargetVolume then
                self.overworldCurrentVolume = math.min(self.overworldTargetVolume, self.overworldCurrentVolume + self.overworldFadeSpeed * dt)
            elseif self.overworldCurrentVolume > self.overworldTargetVolume then
                self.overworldCurrentVolume = math.max(self.overworldTargetVolume, self.overworldCurrentVolume - self.overworldFadeSpeed * dt)
            end
            ---@type any
            local s = self.overworldSound
            if s and s.setVolume then s:setVolume(self.overworldCurrentVolume * gameState.musicVolume) end
        end

        -- Village ambient
        if self.villageSound and startScreen.gameStarted then
            local inTown = gameState.currentMap == "town"
            self.villageTargetVolume = inTown and 0.3 or 0
            if self.villageCurrentVolume < self.villageTargetVolume then
                self.villageCurrentVolume = math.min(self.villageTargetVolume, self.villageCurrentVolume + self.villageFadeSpeed * dt)
            elseif self.villageCurrentVolume > self.villageTargetVolume then
                self.villageCurrentVolume = math.max(self.villageTargetVolume, self.villageCurrentVolume - self.villageFadeSpeed * dt)
            end
            ---@type any
            local s = self.villageSound
            if s and s.setVolume then s:setVolume(self.villageCurrentVolume * gameState.musicVolume) end
        end
    end

    return self
end

return AudioSystem


