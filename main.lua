-- Enhanced RPG with Tilemap, Collision, and Interactions
-- Controls: WASD/Arrows to move, E to interact, F3 for debug

-- Require modules
local GameState = require("gamestate")
local World = require("world")
local Spell = require("spell")
local SpellSystem = require("spellsystem")
local Lighting = require("lighting")
local SaveManager = require("savemanager")
local DevMode = require("devmode")
local Projectile = require("projectile")

-- Debug mode
DEBUG_MODE = false

-- UI Images
local deathScreenImage = nil
local titleScreenImage = nil
local classImages = {}

-- Class Information Database
local classInfo = {
    ["Fire Mage"] = {
        element = "fire",
        description = "Masters of flame and destruction, Fire Mages wield the raw power of fire to incinerate their enemies.",
        strengths = {
            "High burst damage",
            "Area damage potential",
            "Fast spell casting",
            "Excellent against groups"
        },
        weaknesses = {
            "Lower sustained damage",
            "High mana consumption",
            "Vulnerable in melee",
            "Fire-resistant enemies"
        },
        abilities = {
            "Fireball - Launches a burning projectile",
            "Flame Ward - Protective fire shield (future)",
            "Meteor Storm - Devastating area attack (future)"
        },
        lore = "Born from the eternal flames of the Crimson Peaks, Fire Mages channel the destructive force of fire itself. Their magic is chaotic and powerful, consuming everything in its path. They are feared across the realm for their ability to reduce entire armies to ash."
    },
    ["Ice Mage"] = {
        element = "ice",
        description = "Ice mages who freeze their foes and control the battlefield with chilling precision.",
        strengths = {
            "Crowd control effects",
            "Defensive capabilities",
            "Slowing enemies",
            "Consistent damage"
        },
        weaknesses = {
            "Lower single-target damage",
            "Slower cast times",
            "Ice-immune enemies",
            "Requires positioning"
        },
        abilities = {
            "Ice Shard - Piercing frozen projectile",
            "Frost Armor - Protective ice barrier (future)",
            "Blizzard - Freezing area storm (future)"
        },
        lore = "From the frozen wastes of the Glacial Expanse come the Ice Mages, wielders of eternal winter. Their magic flows like glacial rivers, methodical and unstoppable. They are patient strategists who can freeze time itself."
    },
    ["Storm Mage"] = {
        element = "lightning",
        description = "Wielders of lightning and thunder, Storm Mages strike with the fury of the tempest.",
        strengths = {
            "Fastest spells",
            "Chain lightning effects",
            "High mobility",
            "Ignores armor"
        },
        weaknesses = {
            "Mana intensive",
            "Less area coverage",
            "Grounded enemies resist",
            "Requires accuracy"
        },
        abilities = {
            "Lightning Bolt - Instant electric strike",
            "Storm Shield - Crackling defense (future)",
            "Thunder Cascade - Multi-target lightning (future)"
        },
        lore = "The Storm Mages draw their power from the Sky Temples, where eternal storms rage. Their magic is swift and precise, striking like judgment from the heavens. They are known for their unpredictable nature and devastating speed."
    },
    ["Earth Mage"] = {
        element = "earth",
        description = "Earth mages who command stone and earth, standing firm as mountains against any threat.",
        strengths = {
            "High defense",
            "Sustained damage",
            "Tanky playstyle",
            "Resource efficient"
        },
        weaknesses = {
            "Slow mobility",
            "Lower burst damage",
            "Weak to magic",
            "Limited range"
        },
        abilities = {
            "Stone Spike - Erupting earthen projectile",
            "Rock Shield - Stone barrier defense (future)",
            "Earthquake - Ground-shaking area attack (future)"
        },
        lore = "Earth Mages are bound to the Deep Roots, ancient places where the earth's power flows strongest. Their magic is steady and enduring, like the mountains themselves. They are the immovable pillars that protect the innocent and crush the wicked."
    }
}

local strategyInfo = {
    ["Tank"] = {
        strategy = "armor",
        description = "Become an unstoppable fortress, reducing all incoming damage through superior defense and endurance.",
        strengths = {
            "Consistent damage reduction",
            "Reliable survivability",
            "Great for beginners",
            "Works against all damage types"
        },
        weaknesses = {
            "Passive only (no active healing)",
            "Lower damage potential",
            "Slow resource recovery",
            "Requires good positioning"
        },
        mechanics = {
            "10% base damage reduction",
            "+5% reduction per spell level",
            "Always active (passive spell)",
            "Stacks with resistance spells"
        },
        lore = "The path of the Tank is ancient and noble. Warriors who choose this path become living bulwarks, their skin as tough as iron. Through meditation and endurance training, they learn to shrug off wounds that would fell lesser mortals. They are the first into battle and the last to fall."
    },
    ["Lifesteal"] = {
        strategy = "drain",
        description = "Siphon the life force from nearby enemies, draining their vitality to sustain yourself in battle.",
        strengths = {
            "Active healing in combat",
            "Scales with enemy count",
            "Effective in prolonged fights",
            "Range increases with level"
        },
        weaknesses = {
            "Requires nearby enemies",
            "Ineffective against single targets",
            "No healing outside combat",
            "Lower total healing per second"
        },
        mechanics = {
            "Drains 2 HP/sec from enemies",
            "+1 HP/sec per spell level",
            "Affects all enemies in range",
            "120 base range (+15/level)"
        },
        lore = "The Lifesteal path walks the edge between life and death. Practitioners learn the forbidden art of soul extraction, drawing the essence of living beings to fuel their own existence. They are feared as vampiric sorcerers, but their power keeps them alive when all else fails."
    },
    ["Soul Reaper"] = {
        strategy = "necromancer",
        description = "Harvest the souls of the fallen, gaining a surge of vitality with each enemy you defeat.",
        strengths = {
            "Large healing bursts",
            "Rewards aggressive play",
            "Scales with spell level",
            "No range limitations"
        },
        weaknesses = {
            "Only heals on kills",
            "No passive healing",
            "Requires killing blows",
            "Risky against bosses"
        },
        mechanics = {
            "Gain 20 HP per enemy kill",
            "+10 HP per spell level",
            "Instant healing on kill",
            "Works from any distance"
        },
        lore = "Soul Reapers are necromancers who have mastered the art of death itself. Each fallen enemy empowers them, their souls absorbed and converted to pure life force. They grow stronger with each kill, becoming increasingly unstoppable. They are both feared and respected for their dark mastery."
    }
}

-- Game state
local player = {
    x = 400,
    y = 300,
    speed = 150,
    direction = "south",
    isMoving = false,
    -- Combat stats
    health = 100,
    maxHealth = 100,
    armor = 0,
    maxArmor = 0,
    armorRegenRate = 0,
    isDead = false,
    wasMoving = false,
    scale = 2,
    -- Collision box offsets (relative to player center)
    collisionLeft = -13,    -- Left edge of hitbox (negative = left of center)
    collisionRight = 13,    -- Right edge of hitbox (positive = right of center)
    collisionTop = -4,      -- Top edge of hitbox (negative = above center, small value = near feet)
    collisionBottom = 28,   -- Bottom edge of hitbox (positive = below center, at feet)
    -- Knockback state
    knockbackVelocityX = 0,
    knockbackVelocityY = 0,
    knockbackDecay = 0.88,  -- How quickly knockback fades (lower = faster fade)
    -- Immunity frames (invincibility after being hit)
    immunityTimer = 0,
    immunityDuration = 1.2  -- Seconds of immunity after being hit
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
local spellSystem
local projectiles = {} -- Active projectiles
local lighting
local saveManager

-- Audio (grouped to reduce upvalue count)
---@class AudioManager
---@field footstepSound any
---@field footstepTargetVolume number
---@field footstepCurrentVolume number
---@field footstepFadeSpeed number
---@field riverSound any
---@field riverTargetVolume number
---@field riverCurrentVolume number
---@field riverFadeSpeed number
---@field riverPreviousTargetVolume number
---@field caveSound any
---@field caveTargetVolume number
---@field caveCurrentVolume number
---@field caveFadeSpeed number
---@field overworldSound any
---@field overworldTargetVolume number
---@field overworldCurrentVolume number
---@field overworldFadeSpeed number
---@field chestCreakSound any
---@field doorCreakSound any
---@field unlockingDoorSound any
---@field pauseMenuOpenSound any
---@field panelSwipeSound any
---@field skeletonChaseSound any
---@field npcTalkingSound any
---@field earthCastSound any
---@field fireCastSound any
---@field stormCastSound any
---@field iceCastSound any
---@field illuminationCastSound any
---@field magicalVoyageMusic any
---@field trialsSpawnSound any
---@field fightSongMusic any
local audio = {
    footstepSound = nil,
    footstepTargetVolume = 0,
    footstepCurrentVolume = 0,
    footstepFadeSpeed = 2.0,
    riverSound = nil,
    riverTargetVolume = 0,
    riverCurrentVolume = 0,
    riverFadeSpeed = 0.5,
    riverPreviousTargetVolume = 0,
    caveSound = nil,
    caveTargetVolume = 0,
    caveCurrentVolume = 0,
    caveFadeSpeed = 0.5,
    overworldSound = nil,
    overworldTargetVolume = 0,
    overworldCurrentVolume = 0,
    overworldFadeSpeed = 0.5,
    chestCreakSound = nil,
    doorCreakSound = nil,
    unlockingDoorSound = nil,
    pauseMenuOpenSound = nil,
    panelSwipeSound = nil,
    skeletonChaseSound = nil,
    npcTalkingSound = nil,
    npcTalkingTargetVolume = 0,
    npcTalkingCurrentVolume = 0,
    npcTalkingFadeSpeed = 2.0,
    earthCastSound = nil,
    fireCastSound = nil,
    stormCastSound = nil,
    iceCastSound = nil,
    illuminationCastSound = nil,
    magicalVoyageMusic = nil,
    magicalVoyageTargetVolume = 0,
    magicalVoyageCurrentVolume = 0,
    magicalVoyageFadeSpeed = 0.5,
    trialsSpawnSound = nil,
    fightSongMusic = nil,
    fightSongTargetVolume = 0,
    fightSongCurrentVolume = 0,
    fightSongFadeSpeed = 0.5
}
local devMode
local currentMessage = nil
local currentMessageItem = nil  -- Store item for message icon
local messageTimer = 0
local messageDuration = 5  -- Increased from 3 to give more time to read

-- UI state
local showFullInventory = false
local inventoryWidth = 0 -- Current animated width
local inventoryTargetWidth = 0 -- Target width to lerp to
local inventoryScrollOffset = 0
local selectedInventoryItem = nil -- Currently selected item for equipping
local showHelp = false
local showDebugPanel = false
local isPaused = false
local pauseMenuState = "main" -- "main", "controls", "settings", or "save_confirm"
local pauseMenuHeight = 280 -- Current animated height
local pauseMenuTargetHeight = 280 -- Target height to lerp to

-- Settings slider state
local draggingMusicSlider = false
local draggingSFXSlider = false

-- Cutscene state
local inCutscene = false
local cutsceneWalkTarget = nil
local cutsceneOnComplete = nil
local cutsceneDelayTimer = 0
local cutsceneDelayCallback = nil

-- Start screen state
local gameStarted = false
local playerNameInput = ""
local showProfileMenu = false
local startScreenState = "menu" -- "menu", "new_game", "loading"
local startMenuSelection = 1 -- 1 = New Game, 2 = Load Game, 3 = Quit
local cursorBlinkTimer = 0
local cursorVisible = true

-- Class selection UI state
local showClassSelection = false
local selectedClassIcon = nil
local classSelectionScrollOffset = 0
local classSelectionConfirmation = false

-- Strategy selection UI state
local showStrategySelection = false
local selectedStrategyIcon = nil
local strategySelectionScrollOffset = 0
local strategySelectionConfirmation = false

-- Skeleton spawn animation state
local skeletonSpawnState = "none" -- none, spawning, combat
local skeletonSpawnTimer = 0
local spawnedSkeletons = {}

-- Fade transition state
local fadeState = "none" -- "none", "fade_out", "fade_in"
local fadeAlpha = 0
local fadeSpeed = 2 -- How fast to fade (alpha per second)
local fadeTargetMap = nil
local fadeSpawnX = nil
local fadeSpawnY = nil

-- Portal animation state
local portalAnimState = "none" -- "none", "shrinking", "growing", "walking_out"
local portalAnimTimer = 0
local portalAnimDuration = 0.8 -- Duration for shrink/grow
local portalWalkDuration = 0.5 -- Duration for walking out
local playerScale = 1
local tempPortal = nil -- Temporary portal object for arrival animation
local portalDespawnTimer = 0
local portalSourceMap = nil -- Track where portal came from

-- Camera pan cutscene state
local cameraPanState = "none" -- "none", "pan_to_target", "pause", "pan_back"
local cameraPanTarget = {x = 0, y = 0}
local cameraPanSpeed = 300 -- Pixels per second
local cameraPanPauseTimer = 0
local cameraPanPauseDuration = 2 -- Seconds to pause at target
local cameraPanOriginal = {x = 0, y = 0}
local cameraPanCutsceneShown = false -- Track if we've shown the cave cutscene
local northPathCutsceneShown = false -- Track if we've shown the northern path cutscene

-- Direction mappings
local directions = {
    "north", "north-east", "east", "south-east",
    "south", "south-west", "west", "north-west"
}

-- Forward declarations
local loadAnimations, getDirection, drawPlayer, drawUI, drawMessage, drawPauseMenu, drawClassSelection, drawStrategySelection
local checkInteraction, getNearestInteractable, getNearestNPC, useItem

function love.load()
    -- Set up window
    love.window.setTitle("RPG Adventure")
    love.window.setMode(800, 600, {resizable=false})
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Enable text input for name entry
    love.keyboard.setTextInput(true)
    
    -- Load UI images
    local success, image = pcall(love.graphics.newImage, "assets/ui/you-died.png")
    if success then
        deathScreenImage = image
    else
        print("Warning: Could not load death screen image")
    end
    
    success, image = pcall(love.graphics.newImage, "assets/ui/rpg.png")
    if success then
        titleScreenImage = image
    else
        print("Warning: Could not load title screen image")
    end
    
    -- Load class images
    local classImageFiles = {
        ["Fire Mage"] = "fire-mage.png",
        ["Ice Mage"] = "ice-mage.png",
        ["Storm Mage"] = "storm-mage.png",
        ["Earth Mage"] = "earth-mage.png"
    }
    
    for className, filename in pairs(classImageFiles) do
        success, image = pcall(love.graphics.newImage, "assets/ui/" .. filename)
        if success then
            classImages[className] = image
        else
            print("Warning: Could not load " .. filename)
        end
    end
    
    -- Initialize game systems
    gameState = GameState:new()
    world = World:new()
    world:setGameState(gameState)
    
    -- Initialize spell system
    spellSystem = SpellSystem:new(gameState)
    
    -- Initialize lighting system
    lighting = Lighting:new()
    
    -- Initialize save manager
    saveManager = SaveManager
    
    -- Initialize dev mode
    devMode = DevMode:new()
    
    -- Load audio
    local audioSuccess, audioError = pcall(function()
        ---@type any
        local footsteps = love.audio.newSource("assets/sounds/footsteps.mp3", "stream")
        audio.footstepSound = footsteps
        footsteps:setLooping(true)
        footsteps:setVolume(0)  -- Start at 0, will fade in when moving
        footsteps:setPitch(2.0)  -- Play twice as fast
    end)
    if not audioSuccess then
        print("Warning: Could not load footsteps.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded footsteps.mp3 successfully. Max Volume: 0.5, Pitch: 2.0x, Looping: true")
        if audio.footstepSound then
            ---@type any
            local fs = audio.footstepSound
            print("[AUDIO] Audio duration: " .. string.format("%.2f", fs:getDuration()) .. "s")
            fs:play()  -- Start playing but at 0 volume
            print("[AUDIO] Footsteps playback started (will fade in when moving)")
        end
    end
    
    -- Load river sound
    audioSuccess, audioError = pcall(function()
        ---@type any
        local river = love.audio.newSource("assets/sounds/river.mp3", "stream")
        audio.riverSound = river
        river:setLooping(true)
        river:setVolume(0)  -- Start at 0, will fade in when visible
    end)
    if not audioSuccess then
        print("Warning: Could not load river.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded river.mp3 successfully. Looping: true, Max Volume: 0.85")
        if audio.riverSound then
            ---@type any
            local rs = audio.riverSound
            print("[AUDIO] River duration: " .. string.format("%.2f", rs:getDuration()) .. "s")
            rs:play()  -- Start playing but at 0 volume
            print("[AUDIO] River playback started (will fade in when water visible)")
        end
    end
    
    -- Load cave ambient sound
    audioSuccess, audioError = pcall(function()
        ---@type any
        local cave = love.audio.newSource("assets/sounds/cave-sounds.mp3", "stream")
        audio.caveSound = cave
        cave:setLooping(true)
        cave:setVolume(0)  -- Start at 0, will fade in when in cave
    end)
    if not audioSuccess then
        print("Warning: Could not load cave-sounds.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded cave-sounds.mp3 successfully. Looping: true, Max Volume: 0.6")
        if audio.caveSound then
            ---@type any
            local cs = audio.caveSound
            print("[AUDIO] Cave duration: " .. string.format("%.2f", cs:getDuration()) .. "s")
            cs:play()  -- Start playing but at 0 volume
            print("[AUDIO] Cave playback started (will fade in when in cave)")
        end
    end
    
    -- Load overworld ambient sound
    audioSuccess, audioError = pcall(function()
        ---@type any
        local overworld = love.audio.newSource("assets/sounds/overworld-sounds.mp3", "stream")
        audio.overworldSound = overworld
        overworld:setLooping(true)
        overworld:setVolume(0)  -- Start at 0, will fade in when in overworld
    end)
    if not audioSuccess then
        print("Warning: Could not load overworld-sounds.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded overworld-sounds.mp3 successfully. Looping: true, Max Volume: 0.225")
        if audio.overworldSound then
            ---@type any
            local ow = audio.overworldSound
            print("[AUDIO] Overworld duration: " .. string.format("%.2f", ow:getDuration()) .. "s")
            ow:play()  -- Start playing but at 0 volume
            print("[AUDIO] Overworld playback started (will fade in when in overworld)")
        end
    end
    
    -- Load chest creak sound effect
    audioSuccess, audioError = pcall(function()
        ---@type any
        local chest = love.audio.newSource("assets/sounds/chest-creak.mp3", "static")
        audio.chestCreakSound = chest
        chest:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load chest-creak.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded chest-creak.mp3 successfully (skips 0.2s initial delay)")
    end
    
    -- Load door creak sound effect
    audioSuccess, audioError = pcall(function()
        ---@type any
        local door = love.audio.newSource("assets/sounds/door-creak.mp3", "static")
        audio.doorCreakSound = door
        door:setVolume(0.45 * gameState.sfxVolume)  -- 25% quieter than 0.6
    end)
    if not audioSuccess then
        print("Warning: Could not load door-creak.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded door-creak.mp3 successfully (volume: 0.45)")
    end
    
    -- Load unlocking door sound effect
    audioSuccess, audioError = pcall(function()
        ---@type any
        local unlocking = love.audio.newSource("assets/sounds/unlocking-door.mp3", "static")
        audio.unlockingDoorSound = unlocking
        unlocking:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load unlocking-door.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded unlocking-door.mp3 successfully. Volume: 0.6 (skips 1.0s initial silence)")
    end
    
    -- Load pause menu open sound effect
    audioSuccess, audioError = pcall(function()
        ---@type any
        local pauseOpen = love.audio.newSource("assets/sounds/pause-menu-open.mp3", "static")
        audio.pauseMenuOpenSound = pauseOpen
        pauseOpen:setVolume(0.5 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load pause-menu-open.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded pause-menu-open.mp3 successfully. Volume: 0.5")
    end
    
    -- Load panel swipe sound effect
    audioSuccess, audioError = pcall(function()
        ---@type any
        local panelSwipe = love.audio.newSource("assets/sounds/panel-swipe.mp3", "static")
        audio.panelSwipeSound = panelSwipe
        panelSwipe:setVolume(0.5 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load panel-swipe.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded panel-swipe.mp3 successfully. Volume: 0.5")
    end
    
    -- Load skeleton chase sound effect
    audioSuccess, audioError = pcall(function()
        ---@type any
        local skeletonChase = love.audio.newSource("assets/sounds/skeleton-chase.mp3", "static")
        audio.skeletonChaseSound = skeletonChase
        skeletonChase:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load skeleton-chase.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded skeleton-chase.mp3 successfully. Volume: 0.6")
    end
    
    -- Load NPC talking sound effect
    audioSuccess, audioError = pcall(function()
        ---@type any
        local npcTalk = love.audio.newSource("assets/sounds/npc-talking.mp3", "static")
        audio.npcTalkingSound = npcTalk
        npcTalk:setVolume(0)  -- Start at 0, will fade in/out
        npcTalk:setLooping(true)  -- Loop so it can play for duration of message
    end)
    if not audioSuccess then
        print("Warning: Could not load npc-talking.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded npc-talking.mp3 successfully. Looping: true, Volume: 0-1.0")
    end
    
    -- Load spell casting sounds
    audioSuccess, audioError = pcall(function()
        audio.earthCastSound = love.audio.newSource("assets/sounds/earth-cast-1.mp3", "static")
        audio.earthCastSound:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load earth-cast-1.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded earth-cast-1.mp3 successfully")
    end
    
    audioSuccess, audioError = pcall(function()
        audio.fireCastSound = love.audio.newSource("assets/sounds/fire-cast-1.mp3", "static")
        audio.fireCastSound:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load fire-cast-1.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded fire-cast-1.mp3 successfully")
    end
    
    audioSuccess, audioError = pcall(function()
        audio.stormCastSound = love.audio.newSource("assets/sounds/storm-cast-1.mp3", "static")
        audio.stormCastSound:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load storm-cast-1.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded storm-cast-1.mp3 successfully")
    end
    
    audioSuccess, audioError = pcall(function()
        audio.iceCastSound = love.audio.newSource("assets/sounds/ice-cast-1.mp3", "static")
        audio.iceCastSound:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load ice-cast-1.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded ice-cast-1.mp3 successfully")
    end
    
    audioSuccess, audioError = pcall(function()
        audio.illuminationCastSound = love.audio.newSource("assets/sounds/illumination-cast.mp3", "static")
        audio.illuminationCastSound:setVolume(0.6 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load illumination-cast.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded illumination-cast.mp3 successfully")
    end
    
    -- Load background music
    audioSuccess, audioError = pcall(function()
        ---@type any
        local voyage = love.audio.newSource("assets/sounds/magical-voyage.mp3", "stream")
        audio.magicalVoyageMusic = voyage
        voyage:setLooping(true)
        voyage:setVolume(0)
    end)
    if not audioSuccess then
        print("Warning: Could not load magical-voyage.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded magical-voyage.mp3 successfully. Looping: true, Volume: 0-0.4")
    end
    
    audioSuccess, audioError = pcall(function()
        audio.trialsSpawnSound = love.audio.newSource("assets/sounds/trials-spawn.mp3", "static")
        audio.trialsSpawnSound:setVolume(0.5 * gameState.sfxVolume)
    end)
    if not audioSuccess then
        print("Warning: Could not load trials-spawn.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded trials-spawn.mp3 successfully")
    end
    
    audioSuccess, audioError = pcall(function()
        ---@type any
        local fight = love.audio.newSource("assets/sounds/fight-song.mp3", "stream")
        audio.fightSongMusic = fight
        fight:setLooping(true)
        fight:setVolume(0)
    end)
    if not audioSuccess then
        print("Warning: Could not load fight-song.mp3: " .. tostring(audioError))
    else
        print("[AUDIO] Loaded fight-song.mp3 successfully. Looping: true, Volume: 0-0.4")
    end
    
    -- Create example maps
    world:createExampleOverworld()
    world:createHouseInterior()
    world:createCaveLevel1()
    world:createClassSelection()
    world:createDefenseTrials()
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
            local path = string.format("assets/player/animations/walk/%s/frame_%03d.png", direction, i)
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
            local path = string.format("assets/player/animations/breathing-idle/%s/frame_%03d.png", direction, i)
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
    -- Update background music (works on start screen and in-game)
    if audio.magicalVoyageMusic and not isPaused then
        local onStartScreen = not gameStarted
        local inMusicMap = gameStarted and gameState and (gameState.currentMap == "class_selection" or gameState.currentMap == "defense_trials")
        local inCombat = (skeletonSpawnState == "spawning" or skeletonSpawnState == "combat")
        
        -- Set target volume for magical voyage (play on start screen, in music maps when not in combat, but not when dead)
        if not player.isDead and (onStartScreen or (inMusicMap and not inCombat)) then
            audio.magicalVoyageTargetVolume = 0.4
        else
            audio.magicalVoyageTargetVolume = 0
        end
        
        -- Smoothly lerp current volume towards target
        if audio.magicalVoyageCurrentVolume < audio.magicalVoyageTargetVolume then
            audio.magicalVoyageCurrentVolume = math.min(audio.magicalVoyageTargetVolume, audio.magicalVoyageCurrentVolume + audio.magicalVoyageFadeSpeed * dt)
        elseif audio.magicalVoyageCurrentVolume > audio.magicalVoyageTargetVolume then
            audio.magicalVoyageCurrentVolume = math.max(audio.magicalVoyageTargetVolume, audio.magicalVoyageCurrentVolume - audio.magicalVoyageFadeSpeed * dt)
        end
        
        ---@type any
        local voyage = audio.magicalVoyageMusic
        voyage:setVolume(audio.magicalVoyageCurrentVolume * gameState.musicVolume)
        
        -- Start or stop playing based on volume
        if audio.magicalVoyageCurrentVolume > 0 and not voyage:isPlaying() then
            voyage:play()
            if DEBUG_MODE then
                print("[AUDIO] Started magical voyage music")
            end
        elseif audio.magicalVoyageCurrentVolume <= 0 and voyage:isPlaying() then
            voyage:stop()
            if DEBUG_MODE then
                print("[AUDIO] Stopped magical voyage music")
            end
        end
    end
    
    -- Update fight song music (for death screen and combat)
    if audio.fightSongMusic and not isPaused then
        -- Set target volume based on death or combat state
        if player.isDead or (gameStarted and (skeletonSpawnState == "spawning" or skeletonSpawnState == "combat")) then
            audio.fightSongTargetVolume = 0.4
        else
            audio.fightSongTargetVolume = 0
        end
        
        -- Smoothly lerp current volume towards target
        if audio.fightSongCurrentVolume < audio.fightSongTargetVolume then
            audio.fightSongCurrentVolume = math.min(audio.fightSongTargetVolume, audio.fightSongCurrentVolume + audio.fightSongFadeSpeed * dt)
        elseif audio.fightSongCurrentVolume > audio.fightSongTargetVolume then
            audio.fightSongCurrentVolume = math.max(audio.fightSongTargetVolume, audio.fightSongCurrentVolume - audio.fightSongFadeSpeed * dt)
        end
        
        ---@type any
        local fight = audio.fightSongMusic
        fight:setVolume(audio.fightSongCurrentVolume * gameState.musicVolume)
        
        -- Start or stop playing based on volume
        if audio.fightSongCurrentVolume > 0 and not fight:isPlaying() then
            fight:play()
            if DEBUG_MODE then
                print("[AUDIO] Started fight song music")
            end
        elseif audio.fightSongCurrentVolume <= 0 and fight:isPlaying() then
            fight:stop()
            if DEBUG_MODE then
                print("[AUDIO] Stopped fight song music")
            end
        end
    end
    
    -- Don't update game if not started (but update cursor blink)
    if not gameStarted then
        -- Update cursor blink timer for name input
        if startScreenState == "new_game" then
            cursorBlinkTimer = cursorBlinkTimer + dt
            if cursorBlinkTimer >= 0.5 then
                cursorVisible = not cursorVisible
                cursorBlinkTimer = 0
            end
        end
        return
    end
    
    -- Always update UI animations even when paused
    if isPaused then
        -- Lerp pause menu height
        local lerpSpeed = 12
        pauseMenuHeight = pauseMenuHeight + (pauseMenuTargetHeight - pauseMenuHeight) * lerpSpeed * dt
        return
    end
    
    -- Lerp inventory width animation
    local lerpSpeed = 12
    inventoryWidth = inventoryWidth + (inventoryTargetWidth - inventoryWidth) * lerpSpeed * dt
    
    -- Apply dev mode speed multiplier
    if devMode and devMode.enabled and devMode.speedMultiplier > 1 then
        dt = dt * devMode.speedMultiplier
    end
    
    gameTime = gameTime + dt
    
    -- Update play time
    gameState.playTime = gameState.playTime + dt
    
    -- Update footstep sound volume with smooth fading
    if audio.footstepSound and gameStarted and not isPaused then
        -- Smoothly lerp current volume towards target
        if audio.footstepCurrentVolume < audio.footstepTargetVolume then
            audio.footstepCurrentVolume = math.min(audio.footstepTargetVolume, audio.footstepCurrentVolume + audio.footstepFadeSpeed * dt)
        elseif audio.footstepCurrentVolume > audio.footstepTargetVolume then
            audio.footstepCurrentVolume = math.max(audio.footstepTargetVolume, audio.footstepCurrentVolume - audio.footstepFadeSpeed * dt)
        end
        
        -- Apply the current volume
        ---@type any
        local fs = audio.footstepSound
        fs:setVolume(audio.footstepCurrentVolume * gameState.sfxVolume)
    end
    
    -- Update river sound volume based on visibility
    if audio.riverSound and gameStarted and world.currentMap and not isPaused then
        local hasWater = world.currentMap:hasVisibleWater(camera)
        
        -- Set target volume based on whether water is visible
        audio.riverTargetVolume = hasWater and 0.85 or 0  -- Max volume of 0.85 when visible
        
        -- Smoothly lerp current volume towards target
        if audio.riverCurrentVolume < audio.riverTargetVolume then
            audio.riverCurrentVolume = math.min(audio.riverTargetVolume, audio.riverCurrentVolume + audio.riverFadeSpeed * dt)
        elseif audio.riverCurrentVolume > audio.riverTargetVolume then
            audio.riverCurrentVolume = math.max(audio.riverTargetVolume, audio.riverCurrentVolume - audio.riverFadeSpeed * dt)
        end
        
        -- Apply the current volume
        ---@type any
        local rs = audio.riverSound
        rs:setVolume(audio.riverCurrentVolume * gameState.sfxVolume)
        
        -- Debug logging for visibility changes
        if DEBUG_MODE and audio.riverTargetVolume ~= audio.riverPreviousTargetVolume then
            print(string.format("[AUDIO] River visibility: %s (target: %.0f%%, current: %.0f%%)", 
                hasWater and "VISIBLE" or "HIDDEN", 
                audio.riverTargetVolume * 100, 
                audio.riverCurrentVolume * 100))
            audio.riverPreviousTargetVolume = audio.riverTargetVolume
        end
    end
    
    -- Update cave sound volume based on current map
    if audio.caveSound and gameStarted and gameState and not isPaused then
        local inCave = gameState.currentMap == "cave_level1"
        
        -- Set target volume based on whether player is in cave
        audio.caveTargetVolume = inCave and 0.6 or 0  -- Max volume of 0.6 when in cave
        
        -- Smoothly lerp current volume towards target
        if audio.caveCurrentVolume < audio.caveTargetVolume then
            audio.caveCurrentVolume = math.min(audio.caveTargetVolume, audio.caveCurrentVolume + audio.caveFadeSpeed * dt)
        elseif audio.caveCurrentVolume > audio.caveTargetVolume then
            audio.caveCurrentVolume = math.max(audio.caveTargetVolume, audio.caveCurrentVolume - audio.caveFadeSpeed * dt)
        end
        
        -- Apply the current volume
        ---@type any
        local cs = audio.caveSound
        cs:setVolume(audio.caveCurrentVolume * gameState.sfxVolume)
        
        -- Debug logging for cave state changes
        if DEBUG_MODE then
            local prevInCave = audio.caveTargetVolume > 0
            if inCave ~= prevInCave then
                print(string.format("[AUDIO] Cave state: %s (target: %.0f%%, current: %.0f%%)", 
                    inCave and "IN CAVE" or "OUTSIDE", 
                    audio.caveTargetVolume * 100, 
                    audio.caveCurrentVolume * 100))
            end
        end
    end
    
    -- Update overworld sound volume based on current map
    if audio.overworldSound and gameStarted and gameState and not isPaused then
        local inOverworld = gameState.currentMap == "overworld"
        
        -- Set target volume based on whether player is in overworld
        audio.overworldTargetVolume = inOverworld and 0.225 or 0  -- Max volume of 0.225 when in overworld
        
        -- Smoothly lerp current volume towards target
        if audio.overworldCurrentVolume < audio.overworldTargetVolume then
            audio.overworldCurrentVolume = math.min(audio.overworldTargetVolume, audio.overworldCurrentVolume + audio.overworldFadeSpeed * dt)
        elseif audio.overworldCurrentVolume > audio.overworldTargetVolume then
            audio.overworldCurrentVolume = math.max(audio.overworldTargetVolume, audio.overworldCurrentVolume - audio.overworldFadeSpeed * dt)
        end
        
        -- Apply the current volume
        ---@type any
        local ow = audio.overworldSound
        ow:setVolume(audio.overworldCurrentVolume * gameState.musicVolume)
        
        -- Debug logging for overworld state changes
        if DEBUG_MODE then
            local prevInOverworld = audio.overworldTargetVolume > 0
            if inOverworld ~= prevInOverworld then
                print(string.format("[AUDIO] Overworld state: %s (target: %.0f%%, current: %.0f%%)", 
                    inOverworld and "IN OVERWORLD" or "LEFT OVERWORLD", 
                    audio.overworldTargetVolume * 100, 
                    audio.overworldCurrentVolume * 100))
            end
        end
    end
    
    -- Update dev mode
    if devMode then
        devMode:update(dt)
    end
    
    -- Update lighting system
    if lighting then
        lighting:update(dt)
        
        -- Update ambient darkness based on current map
        if gameState.currentMap == "cave_level1" then
            lighting:setAmbientDarkness(0.88) -- Very dark - need illumination spell
        else
            lighting:setAmbientDarkness(0) -- No darkness in overworld/house
        end
        
        -- Clear and recreate lights each frame
        lighting:clearLights()
        
        -- Add cave entrance light (if in cave)
        if gameState.currentMap == "cave_level1" then
            -- Light from entrance (modest glow)
            lighting:addLight(2*32, 9*32, 120, 1.2, {0.7, 0.7, 0.6}, 0.1)
            
            -- Light from scroll (if not collected) - bright beacon that reveals cave
            local interactables = world:getCurrentInteractables()
            for _, obj in ipairs(interactables) do
                if obj.type == "scroll" and not obj.isOpen then
                    lighting:addLight(obj.x + obj.width/2, obj.y + obj.height/2, 180, 2.0, {0.95, 0.85, 0.4}, 0.2)
                end
            end
        end
        
        -- Add portal lights (glowing magical energy)
        local interactables = world:getCurrentInteractables()
        for _, obj in ipairs(interactables) do
            if obj.type == "portal" then
                -- Pulsing purple/blue magical light
                local pulse = 1 + math.sin(love.timer.getTime() * 3) * 0.2
                lighting:addLight(obj.x + obj.width/2, obj.y + obj.height/2, 120 * pulse, 1.5, {0.6, 0.5, 0.9}, 0.15)
            end
        end
        
        -- Add active spell lights (illumination spell)
        if spellSystem then
            for slotIndex, spell in pairs(spellSystem.equippedSpells) do
                if spell and spell.isActive and spell.name == "Illumination" then
                    -- Large bright light that fully reveals the cave floor
                    lighting:addLight(player.x, player.y, spell:getCurrentRadius() * 2.5, 2.5, spell.lightColor, 0.05)
                end
            end
        end
    end
    
    -- Update spell system
    if spellSystem then
        spellSystem:update(dt, player.x, player.y, camera)
        
        -- Sync mana with game state
        gameState.currentMana = spellSystem.currentMana
        gameState.maxMana = spellSystem.maxMana
        
        -- Rebuild learned spells from game state (after loading)
        if #spellSystem.learnedSpells == 0 and #gameState.learnedSpells > 0 then
            for _, spellName in ipairs(gameState.learnedSpells) do
                if spellName == "Illumination" then
                    local spell = Spell.createIllumination()
                    spell.level = gameState:getSpellLevel(spellName)
                    spell.experience = gameState:getSpellExperience(spellName)
                    spellSystem:learnSpell(spell)
                end
            end
        end
        
        -- Passive healing strategy mechanics
        -- Auto-detect and initialize armor if Iron Fortitude is learned
        if not gameState.healingStrategy and player.maxArmor == 0 then
            for _, spell in ipairs(spellSystem.learnedSpells) do
                if spell.name == "Iron Fortitude" then
                    gameState.healingStrategy = "armor"
                    player.maxArmor = 50 + (spell.level - 1) * 10
                    player.armor = player.maxArmor
                    player.armorRegenRate = 2 + (spell.level - 1) * 0.5
                    if DEBUG_MODE then
                        print(string.format("[ARMOR] Auto-initialized from learned spell: %d/%d (regen: %.1f/s)", 
                            player.armor, player.maxArmor, player.armorRegenRate))
                    end
                    break
                elseif spell.name == "Soul Siphon" then
                    gameState.healingStrategy = "drain"
                    break
                elseif spell.name == "Death Harvest" then
                    gameState.healingStrategy = "necromancer"
                    break
                end
            end
        end
        
        if gameState.healingStrategy and not player.isDead then
            if gameState.healingStrategy == "armor" then
                -- Iron Fortitude: Regenerate armor over time
                if player.armor < player.maxArmor then
                    player.armor = math.min(player.maxArmor, player.armor + player.armorRegenRate * dt)
                end
                
            elseif gameState.healingStrategy == "drain" then
                -- Soul Siphon: Drain health from nearby enemies
                local drainSpell = nil
                for _, spell in ipairs(spellSystem.learnedSpells) do
                    if spell.name == "Soul Siphon" then
                        drainSpell = spell
                        break
                    end
                end
                
                if drainSpell and player.health < player.maxHealth then
                    local enemies = world:getCurrentEnemies()
                    local drainRange = 120 + (drainSpell.level - 1) * 15
                    local drainPerSecond = 2 + (drainSpell.level - 1) * 1
                    local totalDrain = 0
                    
                    for _, enemy in ipairs(enemies) do
                        if not enemy.isDead then
                            local dx = enemy.x - player.x
                            local dy = enemy.y - player.y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            
                            if dist <= drainRange then
                                local drainAmount = drainPerSecond * dt
                                totalDrain = totalDrain + drainAmount
                            end
                        end
                    end
                    
                    if totalDrain > 0 then
                        player.health = math.min(player.maxHealth, player.health + totalDrain)
                        if DEBUG_MODE then
                            print(string.format("[LIFESTEAL] Drained %.1f HP", totalDrain))
                        end
                    end
                end
            end
        end
    end
    
    -- Update fade transitions
    if fadeState == "fade_out" then
        fadeAlpha = fadeAlpha + fadeSpeed * dt
        if fadeAlpha >= 1 then
            fadeAlpha = 1
            -- Transition to new map
            if fadeTargetMap then
                gameState:changeMap(fadeTargetMap, fadeSpawnX, fadeSpawnY)
                world:loadMap(gameState.currentMap)
                player.x = gameState.playerSpawn.x
                player.y = gameState.playerSpawn.y
            end
            fadeState = "fade_in"
        end
    elseif fadeState == "fade_in" then
        fadeAlpha = fadeAlpha - fadeSpeed * dt
        if fadeAlpha <= 0 then
            fadeAlpha = 0
            fadeState = "none"
            
            -- Check if returning to overworld from class selection via cave (not portal)
            if fadeTargetMap == "overworld" and 
               gameState.currentMap == "overworld" and
               gameState.playerClass and
               not northPathCutsceneShown and
               not gameState.mysteriousCaveHidden then -- Only if cave not already hidden
                northPathCutsceneShown = true
                gameState.mysteriousCaveHidden = true -- Hide the mysterious cave
                
                -- Start camera pan cutscene
                inCutscene = true
                local screenWidth = love.graphics.getWidth()
                local screenHeight = love.graphics.getHeight()
                
                -- Pan to the northern path area (center of archway at 1280, 5)
                local northPathX = 1280
                local northPathY = 5 * 32
                
                cameraPanOriginal.x = player.x - screenWidth / 2
                cameraPanOriginal.y = player.y - screenHeight / 2
                cameraPanTarget.x = northPathX - screenWidth / 2
                cameraPanTarget.y = northPathY - screenHeight / 2
                cameraPanState = "pan_to_target"
                
                currentMessage = "An ancient path to the north has revealed itself!"
                currentMessageItem = nil
                messageTimer = 5
            end
            
            fadeTargetMap = nil
        end
    end
    
    -- Update skeleton spawn animation
    if skeletonSpawnState == "spawning" then
        skeletonSpawnTimer = skeletonSpawnTimer + dt
        local spawnDuration = 1.0 -- Fade in over 1 second
        local roarDuration = 0.5  -- Roar for 0.5 seconds
        
        if skeletonSpawnTimer < spawnDuration then
            -- Fade in (alpha increases, scale stays at 2)
            local progress = skeletonSpawnTimer / spawnDuration
            for _, skeleton in ipairs(spawnedSkeletons) do
                skeleton.scale = 2  -- Full size
                skeleton.spawnAlpha = progress  -- Fade from 0 to 1
            end
        elseif skeletonSpawnTimer < spawnDuration + roarDuration then
            -- Roar/pose animation (full size, full alpha)
            for _, skeleton in ipairs(spawnedSkeletons) do
                skeleton.scale = 2
                skeleton.spawnAlpha = 1
            end
        else
            -- Animation complete, enable AI
            skeletonSpawnState = "combat"
            for _, skeleton in ipairs(spawnedSkeletons) do
                skeleton.scale = 2
                skeleton.spawnAlpha = 1
                skeleton.spawning = false
            end
            currentMessage = "Defend yourself!"
            messageTimer = 3
        end
    elseif skeletonSpawnState == "combat" then
        -- Check if all skeletons defeated
        local allDefeated = true
        for _, skeleton in ipairs(spawnedSkeletons) do
            if not gameState:isEnemyKilled(skeleton.id) then
                allDefeated = false
                break
            end
        end
        
        if allDefeated and not gameState.healingStrategy then
            skeletonSpawnState = "none"
            gameState.questState = "skeletons_defeated"
            currentMessage = "Victory! Choose your path forward..."
            messageTimer = 5
            
            -- Music transition: fade out fight song, fade in magical voyage
            if audio.fightSongMusic then
                audio.fightSongTargetVolume = 0
            end
            if audio.magicalVoyageMusic then
                audio.magicalVoyageTargetVolume = 0.4
                if DEBUG_MODE then
                    print("[AUDIO] Returning to magical voyage (skeletons defeated)")
                end
            end
        end
    end
    
    -- Update portal animations
    if portalAnimState == "shrinking" then
        portalAnimTimer = portalAnimTimer + dt
        local progress = math.min(portalAnimTimer / portalAnimDuration, 1)
        playerScale = 1 - progress -- Shrink from 1 to 0
        
        if progress >= 1 then
            -- Transition to new map
            if fadeTargetMap then
                gameState:changeMap(fadeTargetMap, fadeSpawnX, fadeSpawnY)
                world:loadMap(gameState.currentMap)
                player.x = gameState.playerSpawn.x
                player.y = gameState.playerSpawn.y
                
                -- Create temporary portal at spawn location
                tempPortal = {
                    x = player.x - 32,
                    y = player.y - 32,
                    width = 64,
                    height = 64,
                    type = "portal",
                    swirlTime = 0
                }
                portalDespawnTimer = 2.0 -- Portal lasts 2 seconds after player exits
            end
            
            -- Start growing animation
            portalAnimState = "growing"
            portalAnimTimer = 0
            playerScale = 0
        end
    elseif portalAnimState == "growing" then
        portalAnimTimer = portalAnimTimer + dt
        local progress = math.min(portalAnimTimer / portalAnimDuration, 1)
        playerScale = progress -- Grow from 0 to 1
        
        if progress >= 1 then
            playerScale = 1
            portalAnimState = "walking_out"
            portalAnimTimer = 0
            -- Store original position
            player.wasX = player.x
            player.wasY = player.y
        end
    elseif portalAnimState == "walking_out" then
        portalAnimTimer = portalAnimTimer + dt
        local progress = math.min(portalAnimTimer / portalWalkDuration, 1)
        
        -- Move player forward a bit (based on their spawn direction)
        local moveDistance = 48 * progress
        if player.direction == "north" then
            player.y = player.wasY - moveDistance
        elseif player.direction == "south" then
            player.y = player.wasY + moveDistance
        elseif player.direction == "east" then
            player.x = player.wasX + moveDistance
        elseif player.direction == "west" then
            player.x = player.wasX - moveDistance
        end
        
        if progress >= 1 then
            portalAnimState = "none"
            fadeTargetMap = nil
            
            -- Trigger north path cutscene if returning from class selection to overworld
            if portalSourceMap == "class_selection" and 
               gameState.currentMap == "overworld" and 
               not northPathCutsceneShown and
               gameState.playerClass and -- Only if they actually chose a class
               not gameState.mysteriousCaveHidden then -- Only if cave not already hidden
                northPathCutsceneShown = true
                gameState.mysteriousCaveHidden = true -- Hide the mysterious cave
                
                -- Start camera pan cutscene
                inCutscene = true
                local screenWidth = love.graphics.getWidth()
                local screenHeight = love.graphics.getHeight()
                
                -- Pan to the northern path area (center of archway at 1280, 5)
                local northPathX = 1280
                local northPathY = 5 * 32
                
                cameraPanOriginal.x = player.x - screenWidth / 2
                cameraPanOriginal.y = player.y - screenHeight / 2
                cameraPanTarget.x = northPathX - screenWidth / 2
                cameraPanTarget.y = northPathY - screenHeight / 2
                cameraPanState = "pan_to_target"
                
                currentMessage = "An ancient path to the north has revealed itself!"
                currentMessageItem = nil
                messageTimer = 5
            end
            
            portalSourceMap = nil -- Clear source tracking
        end
    end
    
    -- Update temp portal
    if tempPortal then
        tempPortal.swirlTime = tempPortal.swirlTime + dt
        portalDespawnTimer = portalDespawnTimer - dt
        
        if portalDespawnTimer <= 0 then
            tempPortal = nil
        end
    end
    
    -- Update player immunity timer
    if player.immunityTimer > 0 then
        player.immunityTimer = player.immunityTimer - dt
    end
    
    -- Failsafe: Check if player is stuck in water/collision and teleport to safety
    if world.currentMap and not inCutscene then
        local boxLeft = player.x + player.collisionLeft
        local boxTop = player.y + player.collisionTop
        local boxWidth = player.collisionRight - player.collisionLeft
        local boxHeight = player.collisionBottom - player.collisionTop
        
        if world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight) then
            -- Player is stuck! Cancel all velocity first
            player.knockbackVelocityX = 0
            player.knockbackVelocityY = 0
            
            -- Try to find nearest safe position in all 8 directions
            local tileSize = world.currentMap.tileSize
            local directions = {
                {x = 0, y = -1},  -- North
                {x = 1, y = 0},   -- East
                {x = 0, y = 1},   -- South
                {x = -1, y = 0},  -- West
                {x = 1, y = -1},  -- NE
                {x = 1, y = 1},   -- SE
                {x = -1, y = 1},  -- SW
                {x = -1, y = -1}  -- NW
            }
            
            local found = false
            -- Try increasingly far distances in each direction
            for distance = 1, 5 do
                if found then break end
                for _, dir in ipairs(directions) do
                    local checkX = player.x + (dir.x * tileSize * distance)
                    local checkY = player.y + (dir.y * tileSize * distance)
                    local checkBoxLeft = checkX + player.collisionLeft
                    local checkBoxTop = checkY + player.collisionTop
                    
                    if not world.currentMap:isColliding(checkBoxLeft, checkBoxTop, boxWidth, boxHeight) then
                        player.x = checkX
                        player.y = checkY
                        found = true
                        if DEBUG_MODE then
                            print("Rescued player from collision at distance " .. distance .. " in direction " .. dir.x .. "," .. dir.y)
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- Update all NPCs
    local npcs = world:getCurrentNPCs()
    for _, npc in ipairs(npcs) do
        -- Provide collision checking for interactables
        npc.checkInteractableCollision = function(x, y)
            local npcLeft = x - 16
            local npcRight = x + 16
            local npcTop = y - 16
            local npcBottom = y + 16
            
            local interactables = world:getCurrentInteractables()
            for _, obj in ipairs(interactables) do
                -- Check collision with signs, chests, and closed doors
                local hasCollision = false
                if obj.type == "chest" or obj.type == "sign" then
                    hasCollision = true
                elseif obj.type == "door" then
                    hasCollision = (obj.openProgress == 0)
                end
                
                if hasCollision then
                    if npcLeft < obj.x + obj.width and
                       npcRight > obj.x and
                       npcTop < obj.y + obj.height and
                       npcBottom > obj.y then
                        return true
                    end
                end
            end
            
            return false
        end
        
        local npcResult = npc:update(dt, player.x, player.y)
        
        -- Handle NPC-triggered events
        if npcResult == "enter_house" and not inCutscene and cutsceneDelayTimer <= 0 then
            -- Start cutscene after a delay to let door unlock sound play
            cutsceneDelayTimer = 2.5 -- 2.5 second delay
            cutsceneDelayCallback = function()
            inCutscene = true
            cutsceneWalkTarget = {x = 55 * 32, y = 19 * 32} -- Door position
            cutsceneOnComplete = function()
                -- Transition to house interior
                gameState:changeMap("house_interior", 7*32, 9*32)
                world:loadMap(gameState.currentMap)
                player.x = gameState.playerSpawn.x
                player.y = gameState.playerSpawn.y
                
                currentMessage = "Inside the merchant's house..."
                currentMessageItem = nil
                messageTimer = 2
                
                inCutscene = false
                cutsceneWalkTarget = nil
                cutsceneOnComplete = nil
                end
            end
            
            currentMessage = "Following the merchant inside..."
            currentMessageItem = nil
            messageTimer = 2
        end
    end
    
    -- Update all enemies
    local enemies = world:getCurrentEnemies()
    for _, enemy in ipairs(enemies) do
        -- Provide terrain collision checking (same method as player)
        enemy.checkTerrainCollision = function(x, y)
            if not world.currentMap then return false end
            
            -- Enemy collision box (32x32 centered on position)
            local boxLeft = x - 16
            local boxTop = y - 16
            local boxWidth = 32
            local boxHeight = 32
            
            -- Use the same isColliding method as the player
            return world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight)
        end
        
        -- Track previous chase state to detect when chase starts
        local wasChasing = enemy.isChasing
        
        -- Only check for hits if player doesn't have immunity
        local canBeHit = (player.immunityTimer <= 0)
        local enemyResult = enemy:update(dt, player.x, player.y, gameTime, canBeHit)
        
        -- Play chase sound when enemy starts chasing
        if not wasChasing and enemy.isChasing and audio.skeletonChaseSound then
            ---@type any
            local chase = audio.skeletonChaseSound
            chase:stop()
            chase:play()
            if DEBUG_MODE then
                print("[AUDIO] Playing skeleton chase sound (enemy started chasing)")
            end
        end
        
        -- Handle knockback and damage
        if enemyResult and enemyResult.type == "knockback" and canBeHit then
            local knockDir = enemyResult.direction
            local distance = math.sqrt(knockDir.x * knockDir.x + knockDir.y * knockDir.y)
            
            if distance > 0 then
                -- Apply strong knockback velocity
                local knockbackSpeed = 750 -- Strong initial push
                player.knockbackVelocityX = (knockDir.x / distance) * knockbackSpeed
                player.knockbackVelocityY = (knockDir.y / distance) * knockbackSpeed
                
                -- Grant immunity frames
                player.immunityTimer = player.immunityDuration
                
                -- Take damage from enemy (only if player has selected a class)
                if gameState.playerClass then
                    local damage = enemy.damage
                    
                    -- Apply damage to armor first, then health
                    if player.armor > 0 then
                        if player.armor >= damage then
                            -- Armor absorbs all damage
                            player.armor = player.armor - damage
                            damage = 0
                            if DEBUG_MODE then
                                print(string.format("[DAMAGE] Armor absorbed %.1f damage (armor: %.1f/%.1f)", 
                                    enemy.damage, player.armor, player.maxArmor))
                            end
                        else
                            -- Armor absorbs partial damage, rest goes to health
                            local overflow = damage - player.armor
                            if DEBUG_MODE then
                                print(string.format("[DAMAGE] Armor broke! %.1f absorbed, %.1f to health", 
                                    player.armor, overflow))
                            end
                            player.armor = 0
                            damage = overflow
                        end
                    end
                    
                    -- Apply remaining damage to health
                    if damage > 0 then
                        player.health = player.health - damage
                        if DEBUG_MODE then
                            print(string.format("[DAMAGE] Dealt %.1f damage to health (HP: %.1f/%.1f)", 
                                damage, player.health, player.maxHealth))
                        end
                    end
                    
                    if player.health <= 0 then
                        player.health = 0
                        player.isDead = true
                        -- Fade out footsteps on death
                        audio.footstepTargetVolume = 0
                        -- Stop skeleton chase sound on death
                        if audio.skeletonChaseSound then
                            ---@type any
                            local chase = audio.skeletonChaseSound
                            chase:stop()
                        end
                        -- Stop NPC talking sound on death
                        if audio.npcTalkingSound then
                            ---@type any
                            local npcTalk = audio.npcTalkingSound
                            npcTalk:stop()
                            audio.npcTalkingTargetVolume = 0
                            audio.npcTalkingCurrentVolume = 0
                        end
                        -- Background music on death (handled in update loop)
                    end
                end
            end
        end
    end
    
    -- Update projectiles and check collisions
    for i = #projectiles, 1, -1 do
        local proj = projectiles[i]
        proj:update(dt)
        
        -- Check collision with enemies
        local hitEnemy = proj:checkCollision(enemies)
        if hitEnemy then
            local died = hitEnemy:takeDamage(proj.damage)
            if died then
                -- Mark enemy as killed in gameState for persistence
                gameState:killEnemy(hitEnemy.id)
                
                -- Death Harvest: Heal on kill
                if gameState.healingStrategy == "necromancer" and spellSystem then
                    local necroSpell = nil
                    for _, spell in ipairs(spellSystem.learnedSpells) do
                        if spell.name == "Death Harvest" then
                            necroSpell = spell
                            break
                        end
                    end
                    
                    if necroSpell and player.health < player.maxHealth then
                        local healAmount = 20 + (necroSpell.level - 1) * 10
                        player.health = math.min(player.maxHealth, player.health + healAmount)
                        if DEBUG_MODE then
                            print(string.format("[NECRO] Gained %d HP from kill (HP: %.1f/%.1f)", 
                                healAmount, player.health, player.maxHealth))
                        end
                    end
                end
                
                -- Remove dead enemy from world
                for j, enemy in ipairs(enemies) do
                    if enemy == hitEnemy then
                        table.remove(enemies, j)
                        break
                    end
                end
            end
        end
        
        -- Remove inactive projectiles
        if not proj.active then
            table.remove(projectiles, i)
        end
    end
    
    -- Update environmental hazards
    local hazards = world:getCurrentHazards()
    for _, hazard in ipairs(hazards) do
        -- Initialize hazard timer if not exists
        hazard.timer = hazard.timer or 0
        hazard.timer = hazard.timer + dt
        
        -- Check if player is colliding with hazard
        local playerInHazard = false
        if hazard.type == "fire_zone" or hazard.type == "ice_zone" or hazard.type == "earth_zone" then
            -- Box collision
            if player.x > hazard.x and player.x < hazard.x + hazard.width and
               player.y > hazard.y and player.y < hazard.y + hazard.height then
                playerInHazard = true
            end
        elseif hazard.type == "lightning_trap" then
            -- Point collision (trap at specific location)
            local dist = math.sqrt((player.x - hazard.x)^2 + (player.y - hazard.y)^2)
            if dist < 64 and hazard.timer >= hazard.interval then
                playerInHazard = true
                hazard.timer = 0 -- Reset timer after triggering
            end
        end
        
        -- Apply damage if player is in hazard and not immune
        if playerInHazard and player.immunityTimer <= 0 and gameState.playerClass then
            -- Check if player has active resistance spell for this element
            local hasResistance = false
            local resistanceReduction = 0
            
            if spellSystem then
                for _, spell in ipairs(spellSystem.learnedSpells) do
                    if spell.isActive and spell.damageReduction then
                        -- Check if resistance matches hazard type
                        -- Extract element from hazard type (e.g., "lightning" from "lightning_trap")
                        local hazardElement = hazard.type:match("^(%w+)_") or hazard.type:match("^(%w+)$")
                        
                        if DEBUG_MODE then
                            print(string.format("[RESIST] Checking spell '%s' (active: %s, reduction: %.1f%%) against hazard '%s' (element: %s)", 
                                spell.name, tostring(spell.isActive), (spell.damageReduction or 0) * 100, hazard.type, hazardElement or "none"))
                        end
                        
                        if (hazardElement == "fire" and spell.name == "Fire Ward") or
                           (hazardElement == "ice" and spell.name == "Frost Barrier") or
                           (hazardElement == "lightning" and spell.name == "Storm Shield") or
                           (hazardElement == "earth" and spell.name == "Stone Skin") then
                            hasResistance = true
                            resistanceReduction = spell.damageReduction
                            if DEBUG_MODE then
                                print(string.format("[RESIST] ✓ Resistance active! %s vs %s = %.1f%% reduction", 
                                    spell.name, hazard.type, resistanceReduction * 100))
                            end
                            break
                        end
                    end
                end
            end
            
            -- Calculate final damage
            local damage = hazard.damage
            if hasResistance then
                damage = damage * (1 - resistanceReduction)
            end
            
            if DEBUG_MODE then
                print(string.format("[HAZARD] %s dealing %.1f damage (base: %.1f, has resistance: %s)", 
                    hazard.type, damage, hazard.damage, tostring(hasResistance)))
            end
            
            -- Apply damage to armor first, then health
            if player.armor > 0 then
                if player.armor >= damage then
                    player.armor = player.armor - damage
                    damage = 0
                else
                    local overflow = damage - player.armor
                    player.armor = 0
                    damage = overflow
                end
            end
            
            -- Apply remaining damage to health
            if damage > 0 then
                player.health = player.health - damage
            end
            if player.health <= 0 then
                player.health = 0
                player.isDead = true
                -- Fade out footsteps on death
                audio.footstepTargetVolume = 0
                -- Stop skeleton chase sound on death
                if audio.skeletonChaseSound then
                    ---@type any
                    local chase = audio.skeletonChaseSound
                    chase:stop()
                end
                -- Stop NPC talking sound on death
                if audio.npcTalkingSound then
                    ---@type any
                    local npcTalk = audio.npcTalkingSound
                    npcTalk:stop()
                    audio.npcTalkingTargetVolume = 0
                    audio.npcTalkingCurrentVolume = 0
                end
                -- Background music on death (handled in update loop)
            end
            
            -- Grant brief immunity to prevent rapid damage ticks
            player.immunityTimer = 0.5
        end
    end
    
    -- Update all interactables (for animations)
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        local transitionResult = obj:update(dt, gameState)
        
        -- Handle delayed door transitions
        if transitionResult == "door_transition" then
            -- Stop unlocking door sound when entering house
            if gameState.currentMap == "house_interior" and audio.unlockingDoorSound then
                ---@type any
                local unlocking = audio.unlockingDoorSound
                unlocking:stop()
                if DEBUG_MODE then
                    print("[AUDIO] Stopped unlocking door sound (entered house)")
                end
            end
            
            world:loadMap(gameState.currentMap)
            player.x = gameState.playerSpawn.x
            player.y = gameState.playerSpawn.y
            
            -- Reset all door animations in new map
            local newInteractables = world:getCurrentInteractables()
            for _, interactable in ipairs(newInteractables) do
                if interactable.type == "door" then
                    -- For defense_trials entrance, start door opened
                    if gameState.currentMap == "defense_trials" and interactable.data.destination == "overworld" then
                        interactable.openProgress = 1
                        interactable.targetProgress = 1
                    else
                    interactable.openProgress = 0
                    interactable.targetProgress = 0
                    end
                end
                -- Sync chest states
                interactable:syncWithGameState(gameState)
            end
            
            -- Trigger cave reveal cutscene when exiting house with sword
            local triggerCaveCutscene = false
            if gameState.currentMap == "overworld" and 
               gameState.questState == "sword_collected" and 
               not cameraPanCutsceneShown and
               not gameState.mysteriousCaveHidden then -- Don't trigger if cave already hidden
                cameraPanCutsceneShown = true
                triggerCaveCutscene = true
                
                -- Start a walking cutscene first (player walks out)
                inCutscene = true
                player.isMoving = false -- Stop any current movement
                cutsceneWalkTarget = {x = player.x, y = player.y + 64} -- Walk south a bit
                cutsceneOnComplete = function()
                    -- After walking out, clear cutscene walk state
                    cutsceneWalkTarget = nil
                    cutsceneOnComplete = nil
                    
                    -- Start camera pan
                    local screenWidth = love.graphics.getWidth()
                    local screenHeight = love.graphics.getHeight()
                    local caveX = 80  -- Cave center (new large entrance at x=0, width=160)
                    local caveY = 26*32 + 96  -- Cave center (y=26*32, height=192)
                    
                    cameraPanOriginal.x = player.x - screenWidth / 2
                    cameraPanOriginal.y = player.y - screenHeight / 2
                    cameraPanTarget.x = caveX - screenWidth / 2
                    cameraPanTarget.y = caveY - screenHeight / 2
                    cameraPanState = "pan_to_target"
                    
                    currentMessage = "A mysterious cave has appeared to the west!"
                    currentMessageItem = nil -- Clear any item icon
                    messageTimer = 999 -- Keep message until cutscene ends
                end
            end
            
            -- Better dialogue based on where we're going (skip if cave cutscene)
            if not triggerCaveCutscene then
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
    end
    
    local dx = 0
    local dy = 0
    
    -- Apply knockback velocity (smooth lerping with collision checking)
    if math.abs(player.knockbackVelocityX) > 1 or math.abs(player.knockbackVelocityY) > 1 then
        local oldX = player.x
        local oldY = player.y
        
        -- Calculate new position
        local newX = player.x + player.knockbackVelocityX * dt
        local newY = player.y + player.knockbackVelocityY * dt
        
        -- Check collision before moving
        local boxLeft = newX + player.collisionLeft
        local boxTop = newY + player.collisionTop
        local boxWidth = player.collisionRight - player.collisionLeft
        local boxHeight = player.collisionBottom - player.collisionTop
        
        if world.currentMap and world.currentMap:isColliding(boxLeft, boxTop, boxWidth, boxHeight) then
            -- Would collide, stop knockback immediately
            player.knockbackVelocityX = 0
            player.knockbackVelocityY = 0
        else
            -- Safe to move
            player.x = newX
            player.y = newY
            
            -- Decay knockback velocity for smooth stopping
            player.knockbackVelocityX = player.knockbackVelocityX * player.knockbackDecay
            player.knockbackVelocityY = player.knockbackVelocityY * player.knockbackDecay
        end
    else
        -- Stop knockback if velocity is very small
        player.knockbackVelocityX = 0
        player.knockbackVelocityY = 0
    end
    
    -- Handle cutscene delay timer
    if cutsceneDelayTimer > 0 then
        cutsceneDelayTimer = cutsceneDelayTimer - dt
        if cutsceneDelayTimer <= 0 then
            cutsceneDelayTimer = 0
            if cutsceneDelayCallback then
                cutsceneDelayCallback()
                cutsceneDelayCallback = nil
            end
        end
    end
    
    -- Handle cutscene movement
    if inCutscene and cutsceneWalkTarget then
        -- Calculate direction to target
        local targetDx = cutsceneWalkTarget.x - player.x
        local targetDy = cutsceneWalkTarget.y - player.y
        local distance = math.sqrt(targetDx * targetDx + targetDy * targetDy)
        
        if DEBUG_MODE then
            print(string.format("Cutscene: Distance to door = %.2f, Target = (%.0f, %.0f), Player = (%.0f, %.0f)", 
                distance, cutsceneWalkTarget.x, cutsceneWalkTarget.y, player.x, player.y))
        end
        
        if distance < 20 then -- Increased threshold from 10 to 20
            -- Reached target, complete cutscene
            player.x = cutsceneWalkTarget.x
            player.y = cutsceneWalkTarget.y
            player.isMoving = false
            if cutsceneOnComplete then
                cutsceneOnComplete()
            else
                -- No follow-up action, end cutscene
                inCutscene = false
                cutsceneWalkTarget = nil
            end
        else
            -- Move towards target
            dx = targetDx / distance
            dy = targetDy / distance
            player.isMoving = true
        end
    else
        -- Normal player input (only when not in cutscene, alive, and not in portal animation)
        if not inCutscene and not player.isDead and portalAnimState == "none" then
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
        end
        
        -- Determine if player is moving
        player.isMoving = (dx ~= 0 or dy ~= 0)
    end
    
    -- Reset animation frame when transitioning between states
    if player.isMoving ~= player.wasMoving then
        currentFrame = 1
        frameTimer = 0
        
        -- Handle footstep audio - just set target volume, don't play/stop
        if audio.footstepSound and gameStarted then
            -- Set target volume based on movement
            local newTargetVolume = player.isMoving and 0.5 or 0
            
            -- Randomize position when starting to move
            if player.isMoving and not player.wasMoving then
                local randomStart = love.math.random() * 65  -- Random start in the 1m5s track
                ---@type any
                local fs = audio.footstepSound
                fs:seek(randomStart)
                if DEBUG_MODE then
                    print("[AUDIO] Randomizing footstep position: " .. string.format("%.2f", randomStart) .. "s")
                end
            end
            
            audio.footstepTargetVolume = newTargetVolume
        end
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
            -- Disable collision during cutscenes
            if inCutscene then
                return false
            end
            
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
            
            -- Check collision with NPCs
            local npcs = world:getCurrentNPCs()
            for _, npc in ipairs(npcs) do
                if npc.isSolid and npc:checkCollision(boxLeft, boxTop, boxWidth, boxHeight) then
                    return true
                end
            end
            
            -- Enemies don't block movement (you can walk through them)
            -- Only knockback affects player position
            
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
    
    -- Update camera pan cutscene
    if cameraPanState == "pan_to_target" then
        local dx = cameraPanTarget.x - camera.x
        local dy = cameraPanTarget.y - camera.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 10 then
            -- Reached target
            camera.x = cameraPanTarget.x
            camera.y = cameraPanTarget.y
            cameraPanState = "pause"
            cameraPanPauseTimer = cameraPanPauseDuration
            
            if DEBUG_MODE then
                print("Camera reached cave, pausing...")
            end
        else
            -- Move towards target
            local moveX = (dx / distance) * cameraPanSpeed * dt
            local moveY = (dy / distance) * cameraPanSpeed * dt
            camera.x = camera.x + moveX
            camera.y = camera.y + moveY
        end
    elseif cameraPanState == "pause" then
        cameraPanPauseTimer = cameraPanPauseTimer - dt
        if cameraPanPauseTimer <= 0 then
            cameraPanState = "pan_back"
            
            if DEBUG_MODE then
                print("Panning back to player...")
            end
        end
    elseif cameraPanState == "pan_back" then
        local dx = cameraPanOriginal.x - camera.x
        local dy = cameraPanOriginal.y - camera.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 10 then
            -- Back to player
            camera.x = cameraPanOriginal.x
            camera.y = cameraPanOriginal.y
            cameraPanState = "none"
            inCutscene = false
            player.isMoving = false -- Ensure player stops
            currentMessage = nil
            messageTimer = 0
            
            if DEBUG_MODE then
                print("Cave cutscene completed")
            end
        else
            -- Move back to player
            local moveX = (dx / distance) * cameraPanSpeed * dt
            local moveY = (dy / distance) * cameraPanSpeed * dt
            camera.x = camera.x + moveX
            camera.y = camera.y + moveY
        end
    end
    
    -- Update camera to follow player (only when not in camera pan cutscene)
    if cameraPanState == "none" then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        camera.x = player.x - screenWidth / 2
        camera.y = player.y - screenHeight / 2
    end
    
    -- Update message timer
    if currentMessage and messageTimer > 0 then
        messageTimer = messageTimer - dt
        
        -- Fade out NPC talking sound as message timer runs down (last 1 second)
        if audio.npcTalkingSound and messageTimer <= 1.0 then
            audio.npcTalkingTargetVolume = math.max(0, messageTimer * 1.0) -- Fade to 0 over last second
        end
        
        if messageTimer <= 0 then
            currentMessage = nil
            currentMessageItem = nil
            -- Ensure NPC talking sound fades out
            audio.npcTalkingTargetVolume = 0
        end
    else
        -- No message active, ensure sound is faded out
        if audio.npcTalkingSound then
            audio.npcTalkingTargetVolume = 0
        end
    end
    
    -- Update NPC talking sound volume (smooth fade)
    if audio.npcTalkingSound and not isPaused then
        if audio.npcTalkingCurrentVolume < audio.npcTalkingTargetVolume then
            audio.npcTalkingCurrentVolume = math.min(audio.npcTalkingTargetVolume, audio.npcTalkingCurrentVolume + audio.npcTalkingFadeSpeed * dt)
        elseif audio.npcTalkingCurrentVolume > audio.npcTalkingTargetVolume then
            audio.npcTalkingCurrentVolume = math.max(audio.npcTalkingTargetVolume, audio.npcTalkingCurrentVolume - audio.npcTalkingFadeSpeed * dt)
        end
        
        ---@type any
        local npcTalk = audio.npcTalkingSound
        npcTalk:setVolume(audio.npcTalkingCurrentVolume * gameState.sfxVolume)
        
        -- Stop playing when fully faded out
        if audio.npcTalkingCurrentVolume <= 0 and npcTalk:isPlaying() then
            npcTalk:stop()
            if DEBUG_MODE then
                print("[AUDIO] Stopped NPC talking sound (faded out)")
            end
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
    -- Draw start screen if game hasn't started
    if not gameStarted then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local font = love.graphics.getFont()
        
        -- Background
        love.graphics.setColor(0.05, 0.05, 0.1)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        
        -- Title (image or fallback text)
        love.graphics.setColor(1, 1, 1)
        if titleScreenImage then
            local imageWidth = titleScreenImage:getWidth()
            local imageHeight = titleScreenImage:getHeight()
            local scale = 1.0 -- Adjust scale as needed
            love.graphics.draw(titleScreenImage, 
                screenWidth/2 - (imageWidth * scale)/2, 
                60, 
                0, scale, scale)
        else
            -- Fallback text if image fails to load
            love.graphics.setColor(1, 0.9, 0.6)
            local titleText = "RPG ADVENTURE"
            local titleWidth = font:getWidth(titleText)
            love.graphics.print(titleText, screenWidth/2 - titleWidth/2, 80)
        end
        
        if startScreenState == "menu" then
            -- Main menu
            local menuY = screenHeight/2 - 60
            local lineHeight = 40
            local hasSaveFile = saveManager:saveExists()
            
            -- New Game option
            if startMenuSelection == 1 then
                love.graphics.setColor(1, 0.9, 0.6)
                love.graphics.print("> New Game <", screenWidth/2 - font:getWidth("> New Game <")/2, menuY)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.print("New Game", screenWidth/2 - font:getWidth("New Game")/2, menuY)
            end
            
            -- Load Game option (only if save exists)
            menuY = menuY + lineHeight
            if hasSaveFile then
                if startMenuSelection == 2 then
                    love.graphics.setColor(1, 0.9, 0.6)
                    love.graphics.print("> Load Game <", screenWidth/2 - font:getWidth("> Load Game <")/2, menuY)
                else
                    love.graphics.setColor(0.8, 0.8, 0.8)
                    love.graphics.print("Load Game", screenWidth/2 - font:getWidth("Load Game")/2, menuY)
                end
                menuY = menuY + lineHeight
            end
            
            -- Quit option
            local quitSelection = hasSaveFile and 3 or 2
            if startMenuSelection == quitSelection then
                love.graphics.setColor(1, 0.9, 0.6)
                love.graphics.print("> Quit <", screenWidth/2 - font:getWidth("> Quit <")/2, menuY)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.print("Quit", screenWidth/2 - font:getWidth("Quit")/2, menuY)
            end
            
            -- Controls hint
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print("W/S or Up/Down - Navigate", screenWidth/2 - font:getWidth("W/S or Up/Down - Navigate")/2, screenHeight - 80)
            love.graphics.print("ENTER - Select  |  ESC - Quit", screenWidth/2 - font:getWidth("ENTER - Select  |  ESC - Quit")/2, screenHeight - 50)
            
        elseif startScreenState == "new_game" then
            -- Name entry screen
            love.graphics.setColor(1, 1, 1)
            local promptText = "Enter your name:"
            local promptWidth = font:getWidth(promptText)
            love.graphics.print(promptText, screenWidth/2 - promptWidth/2, screenHeight/2 - 40)
            
            -- Input box (focused appearance)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", screenWidth/2 - 100, screenHeight/2, 200, 30, 3, 3)
            -- Brighter border to indicate focus
            love.graphics.setColor(1, 0.9, 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", screenWidth/2 - 100, screenHeight/2, 200, 30, 3, 3)
            
            -- Player name input
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(playerNameInput, screenWidth/2 - 95, screenHeight/2 + 7)
            
            -- Blinking cursor
            if cursorVisible then
                local textWidth = font:getWidth(playerNameInput)
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("fill", screenWidth/2 - 95 + textWidth + 2, screenHeight/2 + 7, 2, 16)
            end
            
            -- Instructions
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Press ENTER to start", screenWidth/2 - font:getWidth("Press ENTER to start")/2, screenHeight/2 + 50)
            love.graphics.print("ESC - Back to menu", screenWidth/2 - font:getWidth("ESC - Back to menu")/2, screenHeight - 50)
        end
        
        love.graphics.setColor(1, 1, 1)
        return
    end
    
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    
    -- Draw world (ground, water, walls)
    world:draw(camera, gameTime)
    
    -- Draw environmental hazards with particle effects
    local hazards = world:getCurrentHazards()
    for _, hazard in ipairs(hazards) do
        if hazard.type == "fire_zone" then
            -- Fire zone with flickering flames
            local flicker = (math.sin(gameTime * 8 + hazard.x) + 1) / 2
            love.graphics.setColor(1, 0.3 + flicker * 0.3, 0, 0.4 + flicker * 0.2)
            love.graphics.rectangle("fill", hazard.x, hazard.y, hazard.width, hazard.height)
            
            -- Fire particles
            local particleCount = math.floor(hazard.width / 32) * math.floor(hazard.height / 32) * 2
            for i = 1, particleCount do
                local seed = (i * 17 + math.floor(gameTime * 5) * 13) % 1000
                local px = hazard.x + (seed % hazard.width)
                local py = hazard.y + ((seed * 7) % hazard.height)
                local rise = ((gameTime * 60 + i * 11) % 40) - 20
                local flameSize = 3 + math.sin(gameTime * 3 + i) * 2
                
                love.graphics.setColor(1, 0.5 + math.sin(i) * 0.3, 0, 0.7)
                love.graphics.circle("fill", px, py - rise, flameSize)
            end
            
        elseif hazard.type == "ice_zone" then
            -- Ice zone with frost effect
            local pulse = (math.sin(gameTime * 2 + hazard.x) + 1) / 2
            love.graphics.setColor(0.3, 0.5 + pulse * 0.3, 1, 0.3 + pulse * 0.1)
            love.graphics.rectangle("fill", hazard.x, hazard.y, hazard.width, hazard.height)
            
            -- Ice crystals
            local crystalCount = math.floor(hazard.width / 32) * math.floor(hazard.height / 32)
            for i = 1, crystalCount do
                local seed = (i * 23) % 1000
                local cx = hazard.x + (seed % hazard.width)
                local cy = hazard.y + ((seed * 11) % hazard.height)
                local rotation = gameTime * 0.5 + i
                local size = 4 + math.sin(gameTime + i) * 2
                
                love.graphics.setColor(0.7, 0.9, 1, 0.8)
                -- Draw diamond shape for crystals
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(rotation)
                love.graphics.rectangle("fill", -size/2, -size/2, size, size)
                love.graphics.pop()
            end
            
        elseif hazard.type == "earth_zone" then
            -- Earth zone with debris
            love.graphics.setColor(0.4, 0.3, 0.1, 0.35)
            love.graphics.rectangle("fill", hazard.x, hazard.y, hazard.width, hazard.height)
            
            -- Floating rocks
            local rockCount = math.floor(hazard.width / 32) * math.floor(hazard.height / 32)
            for i = 1, rockCount do
                local seed = (i * 19) % 1000
                local rx = hazard.x + (seed % hazard.width)
                local ry = hazard.y + ((seed * 13) % hazard.height)
                local bob = math.sin(gameTime * 1.5 + i) * 3
                local rockSize = 4 + (i % 3)
                
                love.graphics.setColor(0.35, 0.25, 0.15, 0.8)
                love.graphics.rectangle("fill", rx - rockSize/2, ry + bob - rockSize/2, rockSize, rockSize)
                
                -- Rock outline
                love.graphics.setColor(0.2, 0.15, 0.1, 0.9)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", rx - rockSize/2, ry + bob - rockSize/2, rockSize, rockSize)
            end
            
        elseif hazard.type == "lightning_trap" then
            -- Lightning trap with electric sparks
            local pulse = (math.sin(gameTime * 10 + hazard.x) + 1) / 2
            local radius = 20
            
            -- Electric field
            love.graphics.setColor(1, 1, 0.3, 0.2 + pulse * 0.2)
            love.graphics.circle("fill", hazard.x, hazard.y, radius)
            
            -- Lightning bolts
            if pulse > 0.7 then
                love.graphics.setColor(1, 1, 0.8, 0.9)
                love.graphics.setLineWidth(2)
                for i = 1, 4 do
                    local angle = (i / 4) * math.pi * 2 + gameTime * 2
                    local ex = hazard.x + math.cos(angle) * radius
                    local ey = hazard.y + math.sin(angle) * radius
                    love.graphics.line(hazard.x, hazard.y, ex, ey)
                end
            end
            
            -- Core spark
            love.graphics.setColor(1, 1, 1, 0.8 + pulse * 0.2)
            love.graphics.circle("fill", hazard.x, hazard.y, 3 + pulse * 2)
        end
    end
    love.graphics.setLineWidth(1)
    
    -- Y-sort all entities (player, decorations, interactables)
    local entities = {}
    
    -- Add player (sort by feet position for proper depth)
    -- Player sprite is centered, so feet are at y + half the sprite height
    local playerSortY = player.y + 16 -- Approximate feet position
    table.insert(entities, {
        y = playerSortY,
        draw = drawPlayer
    })
    
    -- Add decorations (trees, bushes) - only visible ones
    if world.currentMap then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local startX = math.max(0, math.floor(camera.x / world.currentMap.tileSize) - 2)
        local endX = math.min(world.currentMap.width - 1, math.ceil((camera.x + screenWidth) / world.currentMap.tileSize) + 2)
        local startY = math.max(0, math.floor(camera.y / world.currentMap.tileSize) - 2)
        local endY = math.min(world.currentMap.height - 1, math.ceil((camera.y + screenHeight) / world.currentMap.tileSize) + 2)
        
        for y = startY, endY do
            for x = startX, endX do
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
    
    -- Add temporary portal if it exists
    if tempPortal then
        local sortY = tempPortal.y + tempPortal.height
        table.insert(entities, {
            y = sortY,
            draw = function()
                -- Draw portal using interactable portal draw code
                local obj = tempPortal
                local centerX = obj.x + obj.width/2
                local centerY = obj.y + obj.height/2
                local baseRadius = math.min(obj.width, obj.height) * 0.45
                
                -- Portal swirl animation
                local swirls = 3
                for j = 1, swirls do
                    local swirlSegments = 24
                    local swirlPhase = (obj.swirlTime * 0.8 + (j / swirls) * math.pi * 2) % (math.pi * 2)
                    
                    for i = 0, swirlSegments - 1 do
                        local t1 = i / swirlSegments
                        local t2 = (i + 1) / swirlSegments
                        local angle1 = t1 * math.pi * 2 + swirlPhase
                        local angle2 = t2 * math.pi * 2 + swirlPhase
                        
                        local radius1 = baseRadius * (0.3 + t1 * 0.7)
                        local radius2 = baseRadius * (0.3 + t2 * 0.7)
                        
                        local x1 = centerX + math.cos(angle1) * radius1
                        local y1 = centerY + math.sin(angle1) * radius1
                        local x2 = centerX + math.cos(angle2) * radius2
                        local y2 = centerY + math.sin(angle2) * radius2
                        
                        local alpha = 1 - (portalDespawnTimer > 1.0 and 0 or (1 - portalDespawnTimer))
                        love.graphics.setColor(0.6 + j * 0.1, 0.3 + j * 0.2, 0.9, 0.6 * alpha)
                        love.graphics.setLineWidth(3)
                        love.graphics.line(x1, y1, x2, y2)
                    end
                end
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1)
            end
        })
    end
    
    -- Add interactables
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        if obj.type == "cave" or obj.type == "cave_exit" then
            -- Cave/cave_exit has three-layer drawing for proper depth sorting
            -- Layer 1: Back boulder (furthest back, player walks in front)
            table.insert(entities, {
                y = obj.y + 50,
                draw = function() obj:draw("back_boulder") end
            })
            -- Layer 2: Cave opening (middle layer, player walks in front)
            table.insert(entities, {
                y = obj.y + 90,
                draw = function() obj:draw("opening") end
            })
            -- Layer 3: Front boulder (closest, player walks behind)
            table.insert(entities, {
                y = obj.y + 135,
                draw = function() obj:draw("front_boulder") end
            })
        elseif obj.type == "portal" and gameState.currentMap == "class_selection" then
            -- Portal in class selection always renders behind player
            table.insert(entities, {
                y = -1000, -- Very low Y to always be behind
                draw = function() obj:draw() end
            })
        else
            -- Use bottom of object for sorting
            local sortY = obj.y + obj.height
            table.insert(entities, {
                y = sortY,
                draw = function() obj:draw() end
            })
        end
    end
    
    -- Add NPCs
    local npcs = world:getCurrentNPCs()
    for _, npc in ipairs(npcs) do
        -- Use bottom of NPC for sorting
        local sortY = npc.y + 16
        table.insert(entities, {
            y = sortY,
            draw = function() npc:draw() end
        })
    end
    
    -- Add Enemies
    local enemies = world:getCurrentEnemies()
    for _, enemy in ipairs(enemies) do
        -- Use bottom of enemy for sorting
        local sortY = enemy.y + 16
        table.insert(entities, {
            y = sortY,
            draw = function() enemy:draw() end
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
    
    -- Debug: Draw collision boxes for interactables
    if DEBUG_MODE then
        local interactables = world:getCurrentInteractables()
        for _, obj in ipairs(interactables) do
            -- Check if this object has collision
            local hasCollision = false
            if obj.type == "chest" or obj.type == "sign" then
                hasCollision = true
            elseif obj.type == "door" then
                hasCollision = (obj.openProgress == 0) -- Only closed doors
            end
            
            if hasCollision then
                love.graphics.setColor(1, 0, 0, 0.3)
                love.graphics.rectangle("fill", obj.x, obj.y, obj.width, obj.height)
            else
                -- Draw open doors in different color
                love.graphics.setColor(0, 1, 0, 0.2)
                love.graphics.rectangle("fill", obj.x, obj.y, obj.width, obj.height)
            end
        end
        
        -- Debug: Draw collision boxes for NPCs
        local npcs = world:getCurrentNPCs()
        for _, npc in ipairs(npcs) do
            if npc.isSolid then
                love.graphics.setColor(1, 0.5, 0, 0.3)
                love.graphics.rectangle("fill", npc.x - 16, npc.y - 16, 32, 32)
            end
        end
        
        -- Debug: Draw collision boxes for enemies (distinct red color)
        local enemies = world:getCurrentEnemies()
        for _, enemy in ipairs(enemies) do
            if enemy.isSolid then
                -- Filled collision box
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.rectangle("fill", enemy.x - 16, enemy.y - 16, 32, 32)
                
                -- Thicker outline to distinguish from NPCs
                love.graphics.setColor(1, 0, 0, 0.8)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", enemy.x - 16, enemy.y - 16, 32, 32)
                love.graphics.setLineWidth(1)
            end
        end
        
        -- Debug: Draw collision boxes for tiles (trees, bushes, rocks, walls) - only visible
        if world.currentMap then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local startX = math.max(0, math.floor(camera.x / world.currentMap.tileSize) - 1)
            local endX = math.min(world.currentMap.width - 1, math.ceil((camera.x + screenWidth) / world.currentMap.tileSize) + 1)
            local startY = math.max(0, math.floor(camera.y / world.currentMap.tileSize) - 1)
            local endY = math.min(world.currentMap.height - 1, math.ceil((camera.y + screenHeight) / world.currentMap.tileSize) + 1)
            
            for y = startY, endY do
                for x = startX, endX do
                    local collision = world.currentMap:getTile(x, y, "collision")
                    
                    -- Draw all collision tiles (type 2 = walls/decorations)
                    if collision == 2 then
                        local px = x * world.currentMap.tileSize
                        local py = y * world.currentMap.tileSize
                        love.graphics.setColor(0.6, 0.3, 0, 0.3)
                        love.graphics.rectangle("fill", px, py, world.currentMap.tileSize, world.currentMap.tileSize)
                    end
                end
            end
        end
        
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw interaction indicator (on top of everything)
    local nearObj = getNearestInteractable()
    if nearObj then
        local ex = nearObj.x + nearObj.width/2 - 4
        -- Ancient path needs lower E prompt due to vertical positioning
        local ey = nearObj.y + (nearObj.type == "ancient_path" and 10 or -20)
        -- Subtle dark background
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", ex - 4, ey - 2, 16, 16, 3, 3)
        -- Drop shadow
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print("E", ex + 2, ey + 2)
        -- Yellow "E"
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("E", ex, ey)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw NPC interaction indicator
    local nearNPC = getNearestNPC()
    if nearNPC then
        local ex = nearNPC.x - 4
        local ey = nearNPC.y - 70
        -- Subtle dark background
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", ex - 4, ey - 2, 16, 16, 3, 3)
        -- Drop shadow
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print("E", ex + 2, ey + 2)
        -- Yellow "E"
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("E", ex, ey)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw projectiles
    for _, proj in ipairs(projectiles) do
        proj:draw()
    end
    
    love.graphics.pop()
    
    -- Draw lighting overlay in screen space (after pop) so it covers the world but not UI
    if lighting then
        lighting:draw(camera)
    end
    
    -- Draw UI (screen space)
    drawUI()
    drawMessage()
    
    -- Draw spell system UI (includes particles and spell bar)
    if spellSystem then
        spellSystem:draw(camera, player.x, player.y)
    end
    
    -- Draw dev mode panel
    if devMode and devMode.enabled then
        devMode:draw()
    end
    
    -- Draw pause menu
    if isPaused then
        drawPauseMenu()
    end
    
    -- Draw class selection UI
    if showClassSelection then
        drawClassSelection()
    end
    
    -- Draw strategy selection UI
    if showStrategySelection then
        drawStrategySelection()
    end
    
    -- Draw profile menu
    if showProfileMenu and gameState.playerClass then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local panelWidth = 400
        local panelHeight = 350
        local panelX = (screenWidth - panelWidth) / 2
        local panelY = (screenHeight - panelHeight) / 2
        
        -- Semi-transparent background overlay
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        
        -- Main panel background
        love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
        love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)
        
        -- Border
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 6, 6)
        love.graphics.setLineWidth(1)
        
        -- Title
        love.graphics.setColor(1, 0.9, 0.6)
        local title = "PLAYER PROFILE"
        local font = love.graphics.getFont()
        local titleWidth = font:getWidth(title)
        love.graphics.print(title, panelX + (panelWidth - titleWidth) / 2, panelY + 15)
        
        -- Divider line
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(panelX + 20, panelY + 45, panelX + panelWidth - 20, panelY + 45)
        love.graphics.setLineWidth(1)
        
        -- Player info
        love.graphics.setColor(1, 1, 1)
        local yPos = panelY + 60
        local lineHeight = 25
        
        -- Name
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Name:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(gameState.playerName, panelX + 150, yPos)
        
        -- Class
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Class:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(gameState.playerClass, panelX + 150, yPos)
        
        -- Element
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Element:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.upper(string.sub(gameState.playerElement, 1, 1)) .. string.sub(gameState.playerElement, 2), panelX + 150, yPos)
        
        -- Health
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Health:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%d / %d", player.health, player.maxHealth), panelX + 150, yPos)
        
        -- Mana
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Mana:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%d / %d", spellSystem.currentMana, spellSystem.maxMana), panelX + 150, yPos)
        
        -- Play time
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Play Time:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        local hours = math.floor(gameState.playTime / 3600)
        local minutes = math.floor((gameState.playTime % 3600) / 60)
        local seconds = math.floor(gameState.playTime % 60)
        love.graphics.print(string.format("%02d:%02d:%02d", hours, minutes, seconds), panelX + 150, yPos)
        
        -- Spells learned
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Spells Learned:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(#gameState.learnedSpells, panelX + 150, yPos)
        
        -- Location
        yPos = yPos + lineHeight
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("Location:", panelX + 30, yPos)
        love.graphics.setColor(1, 1, 1)
        local locationName = gameState.currentMap == "class_selection" and "Class Selection" or string.upper(string.sub(gameState.currentMap, 1, 1)) .. string.sub(gameState.currentMap, 2):gsub("_", " ")
        love.graphics.print(locationName, panelX + 150, yPos)
        
        -- Close hint
        love.graphics.setColor(0.7, 0.7, 0.7)
        local closeText = "[P] or [ESC] to close"
        local closeWidth = font:getWidth(closeText)
        love.graphics.print(closeText, panelX + (panelWidth - closeWidth) / 2, panelY + panelHeight - 30)
        
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw fade overlay (for cave transitions)
    if fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function drawPauseMenu()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Pause menu panel (animated height)
    local panelWidth = 300
    local panelHeight = math.floor(pauseMenuHeight) -- Use animated height
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = (screenHeight - panelHeight) / 2
    
    -- Background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
    
    -- Border
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Header
    love.graphics.setColor(0.12, 0.10, 0.08, 0.9)
    love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth - 4, 36, 3, 3)
    
    love.graphics.setColor(1, 0.95, 0.7)
    local font = love.graphics.getFont()
    local titleText = "PAUSED"
    if pauseMenuState == "controls" then
        titleText = "CONTROLS"
    elseif pauseMenuState == "settings" then
        titleText = "SETTINGS"
    elseif pauseMenuState == "save_confirm" then
        titleText = "CONFIRM OVERWRITE"
    end
    local titleWidth = font:getWidth(titleText)
    love.graphics.print(titleText, panelX + (panelWidth - titleWidth) / 2, panelY + 12)
    
    -- Divider
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 8, panelY + 42, panelX + panelWidth - 8, panelY + 42)
    love.graphics.setLineWidth(1)
    
    -- Menu options
    local yPos = panelY + 60
    local padding = 12
    local options = {}
    
    if pauseMenuState == "main" then
        options = {
            "Resume (ESC)",
            "Save Game (S)",
            "Load Game (L)",
            "Settings (T)",
            "Controls (C)",
            "Quit Game (Q)"
        }
        pauseMenuTargetHeight = 280
    elseif pauseMenuState == "save_confirm" then
        -- Save confirmation - will be drawn differently below
        options = {}
        pauseMenuTargetHeight = 200
    elseif pauseMenuState == "controls" then
        -- Controls screen - will be drawn differently below
        options = {"Back (ESC)"}
        pauseMenuTargetHeight = 380 -- Taller for controls list
    elseif pauseMenuState == "settings" then
        -- Settings screen - will be drawn differently below
        options = {"Back (ESC)"}
        pauseMenuTargetHeight = 280
    end
    
    love.graphics.setColor(1, 0.95, 0.8)
    
    if pauseMenuState == "main" then
        -- Main pause menu
        for i, option in ipairs(options) do
            local optionWidth = font:getWidth(option)
            love.graphics.print(option, panelX + (panelWidth - optionWidth) / 2, yPos)
            yPos = yPos + 30
        end
    elseif pauseMenuState == "save_confirm" then
        -- Save confirmation dialog
        love.graphics.setColor(0.9, 0.85, 0.7)
        local msg1 = "A save file already exists."
        local msg2 = "Overwrite it?"
        local msg1Width = font:getWidth(msg1)
        local msg2Width = font:getWidth(msg2)
        love.graphics.print(msg1, panelX + (panelWidth - msg1Width) / 2, yPos)
        love.graphics.print(msg2, panelX + (panelWidth - msg2Width) / 2, yPos + 25)
        
        yPos = yPos + 65
        local confirmOptions = {"Yes (Y)", "No (N)"}
        for _, option in ipairs(confirmOptions) do
            local optionWidth = font:getWidth(option)
            love.graphics.print(option, panelX + (panelWidth - optionWidth) / 2, yPos)
            yPos = yPos + 30
        end
    elseif pauseMenuState == "controls" then
        -- Controls screen
        local controlsList = {
            {"WASD / Arrow Keys", "Move"},
            {"E", "Interact"},
            {"1-5", "Cast Spell (Slot)"},
            {"B", "Spell Book"},
            {"I", "Inventory"},
            {"6-0", "Use Quick Slot"},
            {"ESC / P", "Pause"},
            {"F3", "Debug Info"},
            {"F12", "Dev Mode"}
        }
        
        yPos = yPos + 10
        for _, control in ipairs(controlsList) do
            love.graphics.setColor(0.9, 0.8, 0.4)
            love.graphics.print(control[1], panelX + padding + 10, yPos)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(control[2], panelX + 200, yPos)
            yPos = yPos + 25
        end
        
        yPos = yPos + 20
        love.graphics.setColor(0.6, 0.6, 0.6)
        local backText = "Press ESC to return"
        local backWidth = font:getWidth(backText)
        love.graphics.print(backText, panelX + (panelWidth - backWidth) / 2, yPos)
    elseif pauseMenuState == "settings" then
        -- Settings screen with sliders
        yPos = yPos + 10
        
        -- Music Volume Label
        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.print("Music Volume", panelX + padding + 10, yPos)
        yPos = yPos + 25
        
        -- Music Volume Slider
        local sliderX = panelX + padding + 10
        local sliderWidth = panelWidth - (padding * 2) - 70 -- Reserve space for percentage text
        local sliderHeight = 12
        
        -- Slider background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", sliderX, yPos, sliderWidth, sliderHeight, 4, 4)
        
        -- Slider fill
        local musicFillWidth = sliderWidth * gameState.musicVolume
        love.graphics.setColor(0.4, 0.7, 0.9)
        love.graphics.rectangle("fill", sliderX, yPos, musicFillWidth, sliderHeight, 4, 4)
        
        -- Slider handle
        local musicHandleX = sliderX + musicFillWidth
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.circle("fill", musicHandleX, yPos + sliderHeight/2, 8)
        
        -- Volume percentage
        love.graphics.setColor(0.8, 0.8, 0.8)
        local musicPercent = string.format("%d%%", math.floor(gameState.musicVolume * 100))
        love.graphics.print(musicPercent, sliderX + sliderWidth + 10, yPos - 4)
        
        yPos = yPos + 40
        
        -- SFX Volume Label
        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.print("SFX Volume", panelX + padding + 10, yPos)
        yPos = yPos + 25
        
        -- SFX Volume Slider
        -- Slider background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", sliderX, yPos, sliderWidth, sliderHeight, 4, 4)
        
        -- Slider fill
        local sfxFillWidth = sliderWidth * gameState.sfxVolume
        love.graphics.setColor(0.9, 0.6, 0.3)
        love.graphics.rectangle("fill", sliderX, yPos, sfxFillWidth, sliderHeight, 4, 4)
        
        -- Slider handle
        local sfxHandleX = sliderX + sfxFillWidth
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.circle("fill", sfxHandleX, yPos + sliderHeight/2, 8)
        
        -- Volume percentage
        love.graphics.setColor(0.8, 0.8, 0.8)
        local sfxPercent = string.format("%d%%", math.floor(gameState.sfxVolume * 100))
        love.graphics.print(sfxPercent, sliderX + sliderWidth + 10, yPos - 4)
        
        yPos = yPos + 40
        
        -- Save Button
        local buttonWidth = 120
        local buttonHeight = 30
        local buttonX = panelX + (panelWidth - buttonWidth) / 2
        love.graphics.setColor(0.3, 0.6, 0.4, 0.9)
        love.graphics.rectangle("fill", buttonX, yPos, buttonWidth, buttonHeight, 5, 5)
        love.graphics.setColor(0.5, 0.9, 0.6)
        love.graphics.rectangle("line", buttonX, yPos, buttonWidth, buttonHeight, 5, 5)
        love.graphics.setColor(1, 1, 1)
        local saveText = "Save Settings"
        local saveWidth = font:getWidth(saveText)
        love.graphics.print(saveText, buttonX + (buttonWidth - saveWidth) / 2, yPos + 7)
        
        yPos = yPos + 50
        
        -- Hint
        love.graphics.setColor(0.6, 0.6, 0.6)
        local hintText = "Click and drag sliders to adjust • ESC: Return"
        local hintWidth = font:getWidth(hintText)
        love.graphics.print(hintText, panelX + (panelWidth - hintWidth) / 2, yPos)
    end
    
    -- Footer hint (only in main menu, controls has its own "return" hint)
    if pauseMenuState == "main" then
        love.graphics.setColor(0.6, 0.55, 0.45)
        local hintText = "Press ESC to resume"
        local hintWidth = font:getWidth(hintText)
        love.graphics.print(hintText, panelX + (panelWidth - hintWidth) / 2, panelY + panelHeight - 25)
    end
    
    love.graphics.setColor(1, 1, 1)
end

function drawPlayer()
    local animationType = player.isMoving and "walk" or "idle"
    if animations[animationType][player.direction] and #animations[animationType][player.direction] > 0 then
        local image = animations[animationType][player.direction][currentFrame]
        local imageWidth = image:getWidth()
        local imageHeight = image:getHeight()
        
        -- Flash when immune (invincibility frames)
        if player.immunityTimer > 0 then
            -- Flash effect: alternate between visible and transparent
            local flashRate = 8 -- Flashes per second
            local flashCycle = (gameTime * flashRate) % 1
            if flashCycle < 0.5 then
                love.graphics.setColor(1, 1, 1, 0.4) -- Semi-transparent
            else
                love.graphics.setColor(1, 1, 1, 1) -- Normal
            end
        end
        
        love.graphics.draw(
            image,
            player.x,
            player.y,
            0,
            player.scale * playerScale,
            player.scale * playerScale,
            imageWidth / 2,
            imageHeight / 2
        )
        
        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
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

drawClassSelection = function()
    if not selectedClassIcon then return end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local font = love.graphics.getFont()
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Main panel
    local panelWidth = 600
    local panelHeight = screenHeight - 100
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = 50
    
    -- Panel background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)
    
    -- Panel border
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 6, 6)
    love.graphics.setLineWidth(1)
    
    -- Header image (Class-specific)
    love.graphics.setColor(1, 1, 1)
    local headerY = panelY + 20
    local classImage = classImages[selectedClassIcon.className]
    if classImage then
        local imageWidth = classImage:getWidth()
        local imageHeight = classImage:getHeight()
        local scale = 0.8
        love.graphics.draw(classImage, 
            panelX + (panelWidth - imageWidth * scale) / 2, 
            headerY, 
            0, scale, scale)
        headerY = headerY + (imageHeight * scale) + 10
    else
        -- Fallback text
        love.graphics.setColor(1, 0.9, 0.6)
        local headerText = selectedClassIcon.className
        local textWidth = font:getWidth(headerText)
        love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, headerY, 0, 1.5, 1.5)
        headerY = headerY + 40
    end
    
    -- Divider
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 20, headerY, panelX + panelWidth - 20, headerY)
    love.graphics.setLineWidth(1)
    
    -- Scrollable content area
    local contentY = headerY + 10
    local contentHeight = panelHeight - (headerY - panelY) - 80
    local padding = 30
    local lineHeight = 18
    
    -- Get class info
    local info = classInfo[selectedClassIcon.className]
    if not info then return end
    
    -- Set scissor for scrolling
    love.graphics.setScissor(panelX, contentY, panelWidth, contentHeight)
    
    local yPos = contentY - classSelectionScrollOffset + 10
    local contentX = panelX + padding
    local contentWidth = panelWidth - padding * 2
    
    -- Description
    love.graphics.setColor(0.9, 0.85, 0.7)
    local wrappedDesc, descLines = font:getWrap(info.description, contentWidth)
    for _, line in ipairs(descLines) do
        love.graphics.print(line, contentX, yPos)
        yPos = yPos + lineHeight
    end
    yPos = yPos + 10
    
    -- Strengths section
    love.graphics.setColor(0.4, 0.9, 0.4)
    love.graphics.print("STRENGTHS", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.8, 0.95, 0.8)
    for _, strength in ipairs(info.strengths) do
        love.graphics.print("+ " .. strength, contentX + 10, yPos)
        yPos = yPos + lineHeight
    end
    yPos = yPos + 10
    
    -- Weaknesses section
    love.graphics.setColor(0.9, 0.4, 0.4)
    love.graphics.print("WEAKNESSES", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.95, 0.8, 0.8)
    for _, weakness in ipairs(info.weaknesses) do
        love.graphics.print("- " .. weakness, contentX + 10, yPos)
        yPos = yPos + lineHeight
    end
    yPos = yPos + 10
    
    -- Abilities section
    love.graphics.setColor(0.7, 0.7, 1.0)
    love.graphics.print("ABILITIES", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.85, 0.85, 0.95)
    for _, ability in ipairs(info.abilities) do
        local wrappedAbility, abilityLines = font:getWrap(ability, contentWidth - 10)
        for _, line in ipairs(abilityLines) do
            love.graphics.print("• " .. line, contentX + 10, yPos)
            yPos = yPos + lineHeight
        end
    end
    yPos = yPos + 10
    
    -- Lore section
    love.graphics.setColor(0.9, 0.75, 0.5)
    love.graphics.print("LORE", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.85, 0.75, 0.65)
    local wrappedLore, loreLines = font:getWrap(info.lore, contentWidth)
    for _, line in ipairs(loreLines) do
        love.graphics.print(line, contentX, yPos)
        yPos = yPos + lineHeight
    end
    
    -- Clear scissor
    love.graphics.setScissor()
    
    -- Scroll indicator if needed
    local totalContentHeight = yPos - (contentY - classSelectionScrollOffset)
    if totalContentHeight > contentHeight then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        local scrollBarHeight = contentHeight * (contentHeight / totalContentHeight)
        local scrollBarY = contentY + (classSelectionScrollOffset / totalContentHeight) * contentHeight
        love.graphics.rectangle("fill", panelX + panelWidth - 10, scrollBarY, 6, scrollBarHeight, 3, 3)
    end
    
    -- Bottom buttons area
    local buttonY = panelY + panelHeight - 60
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 20, buttonY - 10, panelX + panelWidth - 20, buttonY - 10)
    love.graphics.setLineWidth(1)
    
    if classSelectionConfirmation then
        -- Confirmation prompt
        love.graphics.setColor(1, 0.9, 0.6)
        local confirmText = "Are you sure? This choice is permanent!"
        local confirmWidth = font:getWidth(confirmText)
        love.graphics.print(confirmText, panelX + (panelWidth - confirmWidth) / 2, buttonY)
        
        love.graphics.setColor(0.4, 0.9, 0.4)
        love.graphics.print("[Y] Yes, choose this class", panelX + 80, buttonY + 25)
        love.graphics.setColor(0.9, 0.4, 0.4)
        love.graphics.print("[N] No, go back", panelX + 320, buttonY + 25)
    else
        -- Initial buttons
        love.graphics.setColor(1, 0.95, 0.7)
        love.graphics.print("[E] Select this class", panelX + 80, buttonY + 10)
        love.graphics.print("[ESC] Cancel", panelX + 380, buttonY + 10)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Scroll: Mouse Wheel", panelX + (panelWidth - font:getWidth("Scroll: Mouse Wheel")) / 2, buttonY + 30)
    end
    
    love.graphics.setColor(1, 1, 1)
end

drawStrategySelection = function()
    if not selectedStrategyIcon then return end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local font = love.graphics.getFont()
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Main panel
    local panelWidth = 600
    local panelHeight = screenHeight - 100
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = 50
    
    -- Panel background
    love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)
    
    -- Panel border
    love.graphics.setColor(0.75, 0.65, 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 6, 6)
    love.graphics.setLineWidth(1)
    
    -- Header
    love.graphics.setColor(1, 0.9, 0.6)
    local headerText = selectedStrategyIcon.strategyName
    local textWidth = font:getWidth(headerText)
    local headerY = panelY + 30
    love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, headerY, 0, 1.5, 1.5)
    headerY = headerY + 40
    
    -- Divider
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 20, headerY, panelX + panelWidth - 20, headerY)
    love.graphics.setLineWidth(1)
    
    -- Scrollable content area
    local contentY = headerY + 10
    local contentHeight = panelHeight - (headerY - panelY) - 80
    local padding = 30
    local lineHeight = 18
    
    -- Get strategy info
    local info = strategyInfo[selectedStrategyIcon.strategyName]
    if not info then return end
    
    -- Set scissor for scrolling
    love.graphics.setScissor(panelX, contentY, panelWidth, contentHeight)
    
    local yPos = contentY - strategySelectionScrollOffset + 10
    local contentX = panelX + padding
    local contentWidth = panelWidth - padding * 2
    
    -- Description
    love.graphics.setColor(0.9, 0.85, 0.7)
    local wrappedDesc, descLines = font:getWrap(info.description, contentWidth)
    for _, line in ipairs(descLines) do
        love.graphics.print(line, contentX, yPos)
        yPos = yPos + lineHeight
    end
    yPos = yPos + 10
    
    -- Strengths section
    love.graphics.setColor(0.4, 0.9, 0.4)
    love.graphics.print("STRENGTHS", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.8, 0.95, 0.8)
    for _, strength in ipairs(info.strengths) do
        love.graphics.print("+ " .. strength, contentX + 10, yPos)
        yPos = yPos + lineHeight
    end
    yPos = yPos + 10
    
    -- Weaknesses section
    love.graphics.setColor(0.9, 0.4, 0.4)
    love.graphics.print("WEAKNESSES", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.95, 0.8, 0.8)
    for _, weakness in ipairs(info.weaknesses) do
        love.graphics.print("- " .. weakness, contentX + 10, yPos)
        yPos = yPos + lineHeight
    end
    yPos = yPos + 10
    
    -- Mechanics section
    love.graphics.setColor(0.7, 0.7, 1.0)
    love.graphics.print("MECHANICS", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.85, 0.85, 0.95)
    for _, mechanic in ipairs(info.mechanics) do
        local wrappedMech, mechLines = font:getWrap(mechanic, contentWidth - 10)
        for _, line in ipairs(mechLines) do
            love.graphics.print("• " .. line, contentX + 10, yPos)
            yPos = yPos + lineHeight
        end
    end
    yPos = yPos + 10
    
    -- Lore section
    love.graphics.setColor(0.9, 0.75, 0.5)
    love.graphics.print("LORE", contentX, yPos, 0, 1.2, 1.2)
    yPos = yPos + 25
    love.graphics.setColor(0.85, 0.75, 0.65)
    local wrappedLore, loreLines = font:getWrap(info.lore, contentWidth)
    for _, line in ipairs(loreLines) do
        love.graphics.print(line, contentX, yPos)
        yPos = yPos + lineHeight
    end
    
    -- Clear scissor
    love.graphics.setScissor()
    
    -- Scroll indicator if needed
    local totalContentHeight = yPos - (contentY - strategySelectionScrollOffset)
    if totalContentHeight > contentHeight then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        local scrollBarHeight = contentHeight * (contentHeight / totalContentHeight)
        local scrollBarY = contentY + (strategySelectionScrollOffset / totalContentHeight) * contentHeight
        love.graphics.rectangle("fill", panelX + panelWidth - 10, scrollBarY, 6, scrollBarHeight, 3, 3)
    end
    
    -- Bottom buttons area
    local buttonY = panelY + panelHeight - 60
    love.graphics.setColor(0.65, 0.55, 0.20)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 20, buttonY - 10, panelX + panelWidth - 20, buttonY - 10)
    love.graphics.setLineWidth(1)
    
    if strategySelectionConfirmation then
        -- Confirmation prompt
        love.graphics.setColor(1, 0.9, 0.6)
        local confirmText = "Are you sure? This choice is permanent!"
        local confirmWidth = font:getWidth(confirmText)
        love.graphics.print(confirmText, panelX + (panelWidth - confirmWidth) / 2, buttonY)
        
        love.graphics.setColor(0.4, 0.9, 0.4)
        love.graphics.print("[Y] Yes, choose this path", panelX + 80, buttonY + 25)
        love.graphics.setColor(0.9, 0.4, 0.4)
        love.graphics.print("[N] No, go back", panelX + 320, buttonY + 25)
    else
        -- Initial buttons
        love.graphics.setColor(1, 0.95, 0.7)
        love.graphics.print("[E] Select this strategy", panelX + 80, buttonY + 10)
        love.graphics.print("[ESC] Cancel", panelX + 380, buttonY + 10)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Scroll: Mouse Wheel", panelX + (panelWidth - font:getWidth("Scroll: Mouse Wheel")) / 2, buttonY + 30)
    end
    
    love.graphics.setColor(1, 1, 1)
end

function drawUI()
    -- Draw player health bar (only if class selected and not dead) - vertical beside mana
    if gameState.playerClass and spellSystem and #gameState.learnedSpells > 0 then
        local healthBarWidth = 20
        local healthBarHeight = 100
        local healthBarX = 10 + 20 + 5  -- Beside mana bar (mana width + gap)
        local healthBarY = 80 + (5 * (48 + 8)) + 20 -- Same Y as mana bar
        
        -- Background
        love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
        love.graphics.rectangle("fill", healthBarX, healthBarY, healthBarWidth, healthBarHeight, 2, 2)
        
        -- Health fill (bottom to top, red)
        local healthPercent = player.health / player.maxHealth
        local fillHeight = healthBarHeight * healthPercent
        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.rectangle("fill", healthBarX, healthBarY + (healthBarHeight - fillHeight), healthBarWidth, fillHeight, 2, 2)
        
        -- Border
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", healthBarX, healthBarY, healthBarWidth, healthBarHeight, 2, 2)
        love.graphics.setLineWidth(1)
        
        -- Draw armor bar if player has armor (beside health bar)
        if gameState.healingStrategy == "armor" and player.maxArmor > 0 then
            local armorBarWidth = 18
            local armorBarHeight = 100
            local armorBarX = healthBarX + healthBarWidth + 5  -- Beside health bar
            local armorBarY = healthBarY
            
            -- Background
            love.graphics.setColor(0.08, 0.08, 0.10, 0.85)
            love.graphics.rectangle("fill", armorBarX, armorBarY, armorBarWidth, armorBarHeight, 2, 2)
            
            -- Armor fill (bottom to top, silver/gray)
            local armorPercent = player.armor / player.maxArmor
            local armorFillHeight = armorBarHeight * armorPercent
            love.graphics.setColor(0.6, 0.65, 0.7)  -- Silver color
            love.graphics.rectangle("fill", armorBarX, armorBarY + (armorBarHeight - armorFillHeight), armorBarWidth, armorFillHeight, 2, 2)
            
            -- Border
            love.graphics.setColor(0.75, 0.65, 0.25)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", armorBarX, armorBarY, armorBarWidth, armorBarHeight, 2, 2)
            love.graphics.setLineWidth(1)
        end
        
        -- Draw Iron Fortitude indicator (thin purple bar when armor strategy is active)
        -- Auto-detect strategy from learned spells if not explicitly set
        local hasArmorStrategy = gameState.healingStrategy == "armor"
        if not hasArmorStrategy and spellSystem then
            for _, spell in ipairs(spellSystem.learnedSpells) do
                if spell.name == "Iron Fortitude" then
                    hasArmorStrategy = true
                    break
                end
            end
        end
        
        if hasArmorStrategy then
            local armorIndicatorWidth = 8
            local armorIndicatorHeight = 100
            local armorIndicatorX = healthBarX + healthBarWidth + (player.maxArmor > 0 and 23 or 5)
            local armorIndicatorY = healthBarY
            
            -- Purple bar for armor strategy
            love.graphics.setColor(0.15, 0.1, 0.2, 0.85)
            love.graphics.rectangle("fill", armorIndicatorX, armorIndicatorY, armorIndicatorWidth, armorIndicatorHeight, 1, 1)
            
            -- Fill (always full - it's a passive buff indicator)
            love.graphics.setColor(0.6, 0.3, 0.8)
            love.graphics.rectangle("fill", armorIndicatorX, armorIndicatorY, armorIndicatorWidth, armorIndicatorHeight, 1, 1)
            
            -- Border
            love.graphics.setColor(0.7, 0.5, 0.9)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", armorIndicatorX, armorIndicatorY, armorIndicatorWidth, armorIndicatorHeight, 1, 1)
        end
        
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw death screen
    if player.isDead then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        -- Dark overlay
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        
        -- Death message (image or fallback text)
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        if deathScreenImage then
            local imageWidth = deathScreenImage:getWidth()
            local imageHeight = deathScreenImage:getHeight()
            local scale = 0.5 -- Adjust scale as needed
            love.graphics.draw(deathScreenImage, 
                screenWidth/2 - (imageWidth * scale)/2, 
                screenHeight/2 - 80, 
                0, scale, scale)
        else
            -- Fallback text if image fails to load
            love.graphics.setColor(0.8, 0.1, 0.1)
            local deathText = "YOU DIED"
            local textWidth = font:getWidth(deathText)
            love.graphics.print(deathText, screenWidth/2 - textWidth/2, screenHeight/2 - 40)
        end
        
        -- Respawn instruction
        love.graphics.setColor(1, 1, 1)
        local respawnText = "Press R to Respawn"
        local respawnWidth = font:getWidth(respawnText)
        love.graphics.print(respawnText, screenWidth/2 - respawnWidth/2, screenHeight/2 + 20)
        
        love.graphics.setColor(1, 1, 1)
        return -- Don't draw other UI when dead
    end
    
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
    
    -- Draw debug panel
    if showDebugPanel then
        local screenWidth = love.graphics.getWidth()
        local panelWidth = 320
        local panelHeight = 340  -- Increased for audio info (footsteps, river, cave, overworld)
        local panelX = screenWidth - panelWidth - 115  -- Moved further left to avoid inventory
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
        local headerText = "Debug Info"
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
        
        -- Debug info
        love.graphics.setColor(1, 1, 1)
        local yPos = panelY + headerHeight + padding + 8
        local lineHeight = 18
        
        -- Player position
        love.graphics.print(string.format("Position: (%.0f, %.0f)", player.x, player.y), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Tile position
        local tileX = math.floor(player.x / 32)
        local tileY = math.floor(player.y / 32)
        love.graphics.print(string.format("Tile: (%d, %d)", tileX, tileY), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Current map
        love.graphics.print(string.format("Map: %s", gameState.currentMap), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Quest state
        love.graphics.print(string.format("Quest: %s", gameState.questState), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Direction & movement
        love.graphics.print(string.format("Direction: %s", player.direction), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        love.graphics.print(string.format("Moving: %s", tostring(player.isMoving)), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Cutscene state
        love.graphics.print(string.format("In Cutscene: %s", tostring(inCutscene)), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- NPC count
        local npcs = world:getCurrentNPCs()
        love.graphics.print(string.format("NPCs: %d", #npcs), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- FPS
        love.graphics.setColor(0.9, 0.85, 0.6)
        love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), panelX + padding + 8, yPos)
        yPos = yPos + lineHeight
        
        -- Audio Debug Info
        love.graphics.setColor(0.7, 0.9, 1.0)
        if audio.footstepSound then
            ---@type any
            local fs = audio.footstepSound
            local isPlaying = fs:isPlaying()
            local volume = fs:getVolume()
            local pitch = fs:getPitch()
            love.graphics.print(string.format("Footsteps: %s (%.0f%% -> %.0f%%)", isPlaying and "PLAYING" or "STOPPED", volume * 100, audio.footstepTargetVolume * 100), panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
            love.graphics.print(string.format("Pitch: %.1fx  Moving: %s", pitch, tostring(player.isMoving)), panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        else
            love.graphics.print("Footsteps: NOT LOADED", panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        end
        
        if audio.riverSound then
            ---@type any
            local rs = audio.riverSound
            local isPlaying = rs:isPlaying()
            local volume = rs:getVolume()
            love.graphics.print(string.format("River: %s (%.0f%% -> %.0f%%)", isPlaying and "PLAYING" or "STOPPED", volume * 100, audio.riverTargetVolume * 100), panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        else
            love.graphics.print("River: NOT LOADED", panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        end
        
        if audio.caveSound then
            ---@type any
            local cs = audio.caveSound
            local isPlaying = cs:isPlaying()
            local volume = cs:getVolume()
            love.graphics.print(string.format("Cave: %s (%.0f%% -> %.0f%%)", isPlaying and "PLAYING" or "STOPPED", volume * 100, audio.caveTargetVolume * 100), panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        else
            love.graphics.print("Cave: NOT LOADED", panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        end
        
        if audio.overworldSound then
            ---@type any
            local ow = audio.overworldSound
            local isPlaying = ow:isPlaying()
            local volume = ow:getVolume()
            love.graphics.print(string.format("Overworld: %s (%.0f%% -> %.0f%%)", isPlaying and "PLAYING" or "STOPPED", volume * 100, audio.overworldTargetVolume * 100), panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        else
            love.graphics.print("Overworld: NOT LOADED", panelX + padding + 8, yPos)
            yPos = yPos + lineHeight
        end
        
        -- Mana (if spells learned)
        if spellSystem and #spellSystem.learnedSpells > 0 then
            love.graphics.setColor(0.3, 0.5, 0.9)
            love.graphics.print(string.format("Mana: %d/%d", 
                math.floor(spellSystem.currentMana), spellSystem.maxMana), panelX + padding + 8, yPos)
        end
        
        -- Note about hitboxes
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("(Collision boxes visible)", panelX + padding + 8, panelY + panelHeight - padding - 12)
    end
    
    -- Draw inventory quick slots (always visible)
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local slotSize = 48
        local slotSpacing = 8
        local totalSlots = 5
        
        -- Position on right side of screen
        local startX = screenWidth - slotSize - 15
        local startY = screenHeight / 2 - ((totalSlots * slotSize + (totalSlots - 1) * slotSpacing) / 2)
        
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Draw each quick slot
        for i = 1, totalSlots do
            local slotX = startX
            local slotY = startY + (i - 1) * (slotSize + slotSpacing)
            local item = gameState.quickSlots[i]
            local key = tostring(i + 5) -- Keys 6-0
            if i == 5 then key = "0" end
            
            -- Check hover
            local isHovered = mouseX >= slotX and mouseX <= slotX + slotSize and
                             mouseY >= slotY and mouseY <= slotY + slotSize
            
            -- Background
            if item then
                love.graphics.setColor(0.15, 0.13, 0.11, 0.9)
            else
                love.graphics.setColor(0.08, 0.08, 0.10, 0.7)
            end
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            
            -- Border
            if isHovered then
                love.graphics.setColor(0.9, 0.8, 0.4)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.35, 0.30, 0.20)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)
            love.graphics.setLineWidth(1)
            
            -- Draw item if equipped
            if item then
                drawItemIcon(item, slotX + 8, slotY + 8, 32, isHovered)
            end
        end
        
        -- Draw full inventory panel (slides from right)
        if inventoryWidth > 5 then
            local panelWidth = math.floor(inventoryWidth)
            local panelHeight = slotSize * 5 + slotSpacing * 4 + 40 -- 5 rows + header
            local panelX = startX - panelWidth - 10
            local panelY = startY - 20
            
            -- Background
            love.graphics.setColor(0.08, 0.08, 0.10, 0.95)
            love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 4, 4)
            
            -- Border
        love.graphics.setColor(0.75, 0.65, 0.25)
        love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 4, 4)
        love.graphics.setLineWidth(1)
        
            -- Header
        love.graphics.setColor(1, 0.95, 0.7)
        local headerText = "Inventory"
        local textWidth = love.graphics.getFont():getWidth(headerText)
            love.graphics.print(headerText, panelX + (panelWidth - textWidth) / 2, panelY + 8)
        
            -- Divider
        love.graphics.setColor(0.65, 0.55, 0.20)
        love.graphics.setLineWidth(2)
            love.graphics.line(panelX + 8, panelY + 32, panelX + panelWidth - 8, panelY + 32)
        love.graphics.setLineWidth(1)
        
            -- Scrollable inventory grid
            local contentY = panelY + 40
            local contentHeight = panelHeight - 48
            local columns = math.max(1, math.floor((panelWidth - 16) / (slotSize + 4)))
            
            -- Only set scissor if dimensions are valid
            if panelWidth > 8 and contentHeight > 0 then
                love.graphics.setScissor(panelX + 4, contentY, panelWidth - 8, contentHeight)
            end
            
            local hoveredItem = nil
            local hoveredItemName = nil
            local i = 0
            
            for itemName, count in pairs(gameState.inventory) do
                local col = i % columns
                local row = math.floor(i / columns)
                local itemX = panelX + 8 + col * (slotSize + 4)
                local itemY = contentY + row * (slotSize + 4) - inventoryScrollOffset
                
                -- Only draw if visible
                if itemY + slotSize >= contentY and itemY <= contentY + contentHeight then
                    local isHovered = mouseX >= itemX and mouseX <= itemX + slotSize and
                                     mouseY >= itemY and mouseY <= itemY + slotSize and
                                     mouseY >= contentY and mouseY <= contentY + contentHeight
            
            if isHovered then
                        hoveredItem = itemName
                        hoveredItemName = itemName
                    end
                    
                    local isSelected = (selectedInventoryItem == itemName)
                    
                    -- Background
                    if isSelected then
                        love.graphics.setColor(0.35, 0.28, 0.18, 0.95) -- Selected color
                    elseif isHovered then
                love.graphics.setColor(0.25, 0.22, 0.18, 0.95)
            else
                love.graphics.setColor(0.15, 0.13, 0.11, 0.8)
            end
                    love.graphics.rectangle("fill", itemX, itemY, slotSize, slotSize, 3, 3)
                    
                    -- Border
                    if isSelected then
                        love.graphics.setColor(1, 0.9, 0.5) -- Bright selected border
                        love.graphics.setLineWidth(3)
                    elseif isHovered then
                love.graphics.setColor(0.9, 0.8, 0.4)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.35, 0.30, 0.20)
                love.graphics.setLineWidth(1)
            end
                    love.graphics.rectangle("line", itemX, itemY, slotSize, slotSize, 3, 3)
            love.graphics.setLineWidth(1)
            
                    -- Draw item
                    drawItemIcon(itemName, itemX + 8, itemY + 8, 32, isHovered)
                    
                    -- Draw count if > 1
                    if count > 1 then
                        local countText = "x" .. count
                        local textWidth = love.graphics.getFont():getWidth(countText)
                        local textHeight = love.graphics.getFont():getHeight()
                        local textX = itemX + slotSize - textWidth - 4
                        local textY = itemY + slotSize - 16
                        
                        -- Background for better visibility
                        love.graphics.setColor(0, 0, 0, 0.7)
                        love.graphics.rectangle("fill", textX - 2, textY - 1, textWidth + 4, textHeight + 2, 2, 2)
                        
                        -- Text
                        love.graphics.setColor(1, 1, 1)
                        love.graphics.print(countText, textX, textY)
                    end
                end
                
                i = i + 1
            end
            
            love.graphics.setScissor()
            
            -- Tooltip
        if hoveredItem then
            local tooltipX = mouseX + 15
            local tooltipY = mouseY
            local tooltipText = hoveredItem
            local tooltipWidth = love.graphics.getFont():getWidth(tooltipText) + 20
            local tooltipHeight = 26
            
            if tooltipX + tooltipWidth > screenWidth then
                tooltipX = mouseX - tooltipWidth - 5
            end
            
            love.graphics.setColor(0.12, 0.10, 0.08, 0.95)
            love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
                love.graphics.setColor(0.75, 0.65, 0.25)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 4, 4)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 0.95, 0.7)
                love.graphics.print(hoveredItem, tooltipX + 10, tooltipY + 5)
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

getNearestInteractable = function()
    local interactables = world:getCurrentInteractables()
    for _, obj in ipairs(interactables) do
        if obj:isPlayerNear(player.x, player.y) then
            return obj
        end
    end
    return nil
end

getNearestNPC = function()
    local npcs = world:getCurrentNPCs()
    for _, npc in ipairs(npcs) do
        if npc:isPlayerNear(player.x, player.y) then
            return npc
        end
    end
    return nil
end

useItem = function(itemName)
    if not itemName then return false end
    
    -- Check if player has the item
    if not gameState:hasItem(itemName) then
        currentMessage = "You don't have that item!"
        messageTimer = 2
        return false
    end
    
    -- Handle different item types
    if itemName == "Health Potion" then
        -- Heal the player
        if player.health >= player.maxHealth then
            currentMessage = "Health is already full!"
            messageTimer = 2
            return false
        end
        
        local healAmount = 50
        local oldHealth = player.health
        player.health = math.min(player.maxHealth, player.health + healAmount)
        local actualHeal = player.health - oldHealth
        
        -- Remove item from inventory
        gameState:removeItem(itemName, 1)
        
        currentMessage = string.format("Healed %d HP!", actualHeal)
        messageTimer = 2
        return true
    else
        -- Other items don't have use functionality yet
        currentMessage = string.format("%s cannot be used", itemName)
        messageTimer = 2
        return false
    end
end

checkInteraction = function()
    -- Check NPC interaction first
    local npc = getNearestNPC()
    if npc then
        -- Play unlocking door sound if player is returning the key to merchant
        if npc.npcType == "merchant" and gameState:hasItem("Gold Key") and audio.unlockingDoorSound then
            ---@type any
            local unlocking = audio.unlockingDoorSound
            unlocking:stop()
            unlocking:seek(1.0) -- Skip 1 second of silence
            unlocking:play()
            if DEBUG_MODE then
                print("[AUDIO] Playing unlocking door sound (merchant receives key, from 1.0s)")
            end
        end
        
        local result = npc:interact(gameState)
        if result then
            currentMessage = result
            messageTimer = messageDuration
            currentMessageItem = nil
            
            -- Start NPC talking sound with fade in
            if audio.npcTalkingSound then
                ---@type any
                local npcTalk = audio.npcTalkingSound
                if not npcTalk:isPlaying() then
                    npcTalk:play()
                end
                audio.npcTalkingTargetVolume = 1.0  -- 100% volume
                if DEBUG_MODE then
                    print("[AUDIO] Starting NPC talking sound (fade in)")
                end
            end
        end
        return
    end
    
    -- Then check interactable objects
    local obj = getNearestInteractable()
    if obj then
        -- Play sound effects BEFORE interaction for instant feedback
        if obj.type == "chest" and not obj.isOpen and audio.chestCreakSound then
            ---@type any
            local chest = audio.chestCreakSound
            chest:stop() -- Stop any currently playing instance
            chest:seek(0.2) -- Skip 200ms initial delay
            chest:play() -- Play from 0.2 seconds
            if DEBUG_MODE then
                print("[AUDIO] Playing chest creak sound (from 0.2s)")
            end
        elseif obj.type == "door" then
            -- Play door creak sound (skip initial silence for instant feedback)
            if audio.doorCreakSound then
                ---@type any
                local door = audio.doorCreakSound
                door:stop() -- Stop any currently playing instance
                door:seek(0.15) -- Skip 150ms initial silence for instant feedback
                door:play()
                if DEBUG_MODE then
                    print("[AUDIO] Playing door creak sound (from 0.15s)")
                end
            end
        end
        
        local result = obj:interact(gameState)
        
        -- Handle class icon interaction (show detailed UI)
        if type(result) == "table" and result.type == "class_icon_interact" then
            selectedClassIcon = result
            showClassSelection = true
            classSelectionScrollOffset = 0
            classSelectionConfirmation = false
            return
        end
        
        -- Handle class selection
        if type(result) == "table" and result.type == "class_selected" then
            -- Give the player their starter attack spell based on element
            if spellSystem and result.element then
                local spell = nil
                if result.element == "fire" then
                    spell = Spell.createFireball()
                elseif result.element == "ice" then
                    spell = Spell.createIceShard()
                elseif result.element == "lightning" then
                    spell = Spell.createLightningBolt()
                elseif result.element == "earth" then
                    spell = Spell.createStoneSpike()
                end
                
                if spell then
                    spellSystem:learnSpell(spell)
                end
            end
            
            currentMessage = result.message
            messageTimer = 5 -- Longer duration for class selection message
            currentMessageItem = nil
            return
        end
        
        -- Handle spell learned (special result type)
        if type(result) == "table" and result.type == "spell_learned" then
            -- Create and learn the spell
            if result.spell == "Illumination" and spellSystem then
                local spell = Spell.createIllumination()
                spellSystem:learnSpell(spell)
            elseif result.spell == "resistance" and spellSystem and gameState.playerElement then
                -- Learn element-specific resistance spell
                local spell = nil
                if gameState.playerElement == "fire" then
                    spell = Spell.createFireResistance()
                elseif gameState.playerElement == "ice" then
                    spell = Spell.createIceResistance()
                elseif gameState.playerElement == "lightning" then
                    spell = Spell.createLightningResistance()
                elseif gameState.playerElement == "earth" then
                    spell = Spell.createEarthResistance()
                end
                
                if spell then
                    spellSystem:learnSpell(spell)
                    gameState.resistanceSpellLearned = true
                    currentMessage = string.format("You learned %s!\n\nThis spell protects you from elemental hazards.", spell.name)
                    messageTimer = 5
                    currentMessageItem = nil
                    return
                end
            end
            
            currentMessage = result.message
            messageTimer = 5 -- Longer duration for tutorial message
            currentMessageItem = nil
            return
        end
        
        -- Handle strategy icon interaction (show detailed UI)
        if type(result) == "table" and result.type == "strategy_icon_interact" then
            selectedStrategyIcon = result
            showStrategySelection = true
            strategySelectionScrollOffset = 0
            strategySelectionConfirmation = false
            return
        end
        
        -- Handle strategy selection
        if type(result) == "table" and result.type == "strategy_selected" then
            -- Give the player their healing strategy spell
            if spellSystem and result.strategy then
                local spell = nil
                if result.strategy == "armor" then
                    spell = Spell.createArmorBuff()
                elseif result.strategy == "drain" then
                    spell = Spell.createDrainBuff()
                elseif result.strategy == "necromancer" then
                    spell = Spell.createNecromancerBuff()
                end
                
                if spell then
                    spellSystem:learnSpell(spell)
                    gameState.healingStrategy = result.strategy
                    gameState.defenseTrialsCompleted = true
                    gameState.questState = "strategy_selected"
                    
                    -- Initialize armor system for tank strategy
                    if result.strategy == "armor" and player.maxArmor == 0 then
                        player.maxArmor = 50 + (spell.level - 1) * 10
                        player.armor = player.maxArmor
                        player.armorRegenRate = 2 + (spell.level - 1) * 0.5
                        if DEBUG_MODE then
                            print(string.format("[ARMOR] Initialized: %d/%d (regen: %.1f/s)", 
                                player.armor, player.maxArmor, player.armorRegenRate))
                        end
                    end
                end
            end
            
            currentMessage = result.message
            messageTimer = 5
            currentMessageItem = nil
            return
        end
        
        -- Handle skeleton spawn trigger
        if type(result) == "table" and result.type == "trigger_skeletons" then
            -- Start skeleton spawn animation
            skeletonSpawnState = "spawning"
            skeletonSpawnTimer = 0
            spawnedSkeletons = {}
            
            -- Music transition: stop magical voyage, play trials spawn, then start fight song
            if audio.magicalVoyageMusic then
                audio.magicalVoyageTargetVolume = 0  -- Fade out magical voyage
            end
            if audio.trialsSpawnSound then
                audio.trialsSpawnSound:stop()
                audio.trialsSpawnSound:play()
            end
            -- Fight song will fade in shortly after spawn sound plays
            if audio.fightSongMusic then
                ---@type any
                local fight = audio.fightSongMusic
                if not fight:isPlaying() then
                    fight:play()
                end
                audio.fightSongTargetVolume = 0.4
                if DEBUG_MODE then
                    print("[AUDIO] Starting fight song (skeleton spawn)")
                end
            end
            
            -- Spawn 2 skeletons at full size but transparent (in north arena)
            local Enemy = require("enemy")
            local spawn1 = Enemy:new(10*32, 6*32, "skeleton", {})
            local spawn2 = Enemy:new(18*32, 6*32, "skeleton", {})
            spawn1.scale = 2
            spawn2.scale = 2
            spawn1.spawnAlpha = 0  -- Start transparent
            spawn2.spawnAlpha = 0
            spawn1.id = "trial_skeleton_1"
            spawn2.id = "trial_skeleton_2"
            spawn1.spawning = true  -- Mark as spawning
            spawn2.spawning = true
            table.insert(spawnedSkeletons, spawn1)
            table.insert(spawnedSkeletons, spawn2)
            
            -- Add to world enemies directly (not via getCurrentEnemies which returns a filtered copy)
            table.insert(world.enemies[gameState.currentMap], spawn1)
            table.insert(world.enemies[gameState.currentMap], spawn2)
            
            currentMessage = result.message
            messageTimer = 3
            currentMessageItem = nil
            return
        end
        
        -- Handle fade transitions (caves and portals)
        if type(result) == "table" and result.type == "fade_transition" then
            -- Check if this is a portal transition
            local isPortalTransition = (obj and obj.type == "portal")
            
            if isPortalTransition then
                -- Start portal shrinking animation
                portalAnimState = "shrinking"
                portalAnimTimer = 0
                playerScale = 1
                portalSourceMap = gameState.currentMap -- Track where we're coming from
                fadeTargetMap = result.targetMap
                fadeSpawnX = result.spawnX
                fadeSpawnY = result.spawnY
            else
                -- Regular fade transition for caves
            fadeState = "fade_out"
            fadeTargetMap = result.targetMap
            fadeSpawnX = result.spawnX
            fadeSpawnY = result.spawnY
            end
            return
        end
        
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
    -- Start screen handling
    if not gameStarted then
        if startScreenState == "menu" then
            local hasSaveFile = saveManager:saveExists()
            local maxSelection = hasSaveFile and 3 or 2
            
            if key == "w" or key == "up" then
                startMenuSelection = startMenuSelection - 1
                if startMenuSelection < 1 then startMenuSelection = maxSelection end
            elseif key == "s" or key == "down" then
                startMenuSelection = startMenuSelection + 1
                if startMenuSelection > maxSelection then startMenuSelection = 1 end
            elseif key == "return" or key == "kpenter" then
                if startMenuSelection == 1 then
                    -- New Game
                    startScreenState = "new_game"
                    playerNameInput = ""
                    cursorBlinkTimer = 0
                    cursorVisible = true
                elseif startMenuSelection == 2 and hasSaveFile then
                    -- Load Game
                    local loadedState, err = saveManager:load()
                    if loadedState then
                        -- Apply loaded state (use applySaveData which properly merges)
                        saveManager:applySaveData(gameState, loadedState)
                        
                        -- Load the saved map FIRST
                        world:loadMap(gameState.currentMap)
                        
                        -- Set player position from playerSpawn (same as pause menu load)
                        player.x = gameState.playerSpawn.x
                        player.y = gameState.playerSpawn.y
                        player.health = gameState.playerHealth or player.maxHealth
                        
                        -- Rebuild spell system with loaded data
                        spellSystem = SpellSystem:new(gameState)
                        spellSystem:rebuildLearnedSpells()
                        
                        -- Restore armor system if player has tank strategy
                        if gameState.healingStrategy == "armor" then
                            for _, spell in ipairs(spellSystem.learnedSpells) do
                                if spell.name == "Iron Fortitude" then
                                    player.maxArmor = 50 + (spell.level - 1) * 10
                                    player.armor = player.maxArmor  -- Start with full armor on load
                                    player.armorRegenRate = 2 + (spell.level - 1) * 0.5
                                    if DEBUG_MODE then
                                        print(string.format("[ARMOR] Restored on load: %d/%d", player.armor, player.maxArmor))
                                    end
                                    break
                                end
                            end
                        end
                        
                        -- Sync interactables
                        local interactables = world:getCurrentInteractables()
                        for _, obj in ipairs(interactables) do
                            obj:syncWithGameState(gameState)
                        end
                        
                        gameStarted = true
                    end
                elseif (startMenuSelection == 2 and not hasSaveFile) or (startMenuSelection == 3 and hasSaveFile) then
                    -- Quit
                    love.event.quit()
                end
            elseif key == "escape" then
                love.event.quit()
            end
        elseif startScreenState == "new_game" then
            if key == "return" or key == "kpenter" then
                if #playerNameInput > 0 then
                    gameState.playerName = playerNameInput
                else
                    gameState.playerName = "Hero"
                end
                gameStarted = true
            elseif key == "backspace" then
                playerNameInput = string.sub(playerNameInput, 1, -2)
                -- Reset cursor to visible when deleting
                cursorBlinkTimer = 0
                cursorVisible = true
            elseif key == "escape" then
                startScreenState = "menu"
                playerNameInput = ""
            end
        end
        return
    end
    
    -- Handle death respawn
    if player.isDead and key == "r" then
        player.health = player.maxHealth
        player.isDead = false
        player.x = gameState.playerSpawn.x
        player.y = gameState.playerSpawn.y
        return
    end
    
    -- Dev mode toggle (works always) - F12 toggles both dev mode and panel
    if key == "f12" then
        if devMode then
            devMode:toggle()
        end
        return
    end
    
    -- Pause handling
    if key == "escape" then
        -- Close class selection if open
        if showClassSelection then
            if classSelectionConfirmation then
                classSelectionConfirmation = false
            else
                showClassSelection = false
                selectedClassIcon = nil
                classSelectionScrollOffset = 0
            end
            return
        end
        
        -- Close strategy selection if open
        if showStrategySelection then
            if strategySelectionConfirmation then
                strategySelectionConfirmation = false
            else
                showStrategySelection = false
                selectedStrategyIcon = nil
                strategySelectionScrollOffset = 0
            end
            return
        end
        
        -- Close profile menu if open
        if showProfileMenu then
            showProfileMenu = false
            return
        end
        
        -- Close spell menu if open
        if spellSystem and spellSystem.showSpellMenu then
            spellSystem:toggleSpellMenu()
            
            -- Play panel swipe sound
            if audio.panelSwipeSound then
                ---@type any
                local swipe = audio.panelSwipeSound
                swipe:stop()
                swipe:play()
                if DEBUG_MODE then
                    print("[AUDIO] Playing panel swipe sound (closing spell book)")
                end
            end
            return
        end
        
        -- Close dev panel if open
        if devMode and devMode.enabled and devMode.showPanel then
            devMode:togglePanel()
            return
        end
        
        -- Close full inventory if open
        if showFullInventory then
            showFullInventory = false
            inventoryTargetWidth = 0
            inventoryScrollOffset = 0
            selectedInventoryItem = nil -- Clear selection
            
            -- Play panel swipe sound
            if audio.panelSwipeSound then
                ---@type any
                local swipe = audio.panelSwipeSound
                swipe:stop()
                swipe:play()
                if DEBUG_MODE then
                    print("[AUDIO] Playing panel swipe sound (closing inventory)")
                end
            end
            return
        end
        
        -- Handle pause menu navigation
        if isPaused and pauseMenuState == "controls" then
            -- Return to main pause menu
            pauseMenuState = "main"
            pauseMenuTargetHeight = 280
            return
        elseif isPaused and pauseMenuState == "settings" then
            -- Return to main pause menu
            pauseMenuState = "main"
            pauseMenuTargetHeight = 280
            return
        elseif isPaused and pauseMenuState == "save_confirm" then
            -- Cancel save confirmation
            pauseMenuState = "main"
            pauseMenuTargetHeight = 280
            return
        end
        
        -- Toggle pause
        isPaused = not isPaused
        if isPaused then
            pauseMenuState = "main" -- Reset to main menu when pausing
            pauseMenuTargetHeight = 280
            pauseMenuHeight = 280 -- Reset animation
            
            -- Play pause menu open sound
            if audio.pauseMenuOpenSound then
                ---@type any
                local pauseOpen = audio.pauseMenuOpenSound
                pauseOpen:stop()
                pauseOpen:seek(0.1) -- Skip 100ms initial lag
                pauseOpen:play()
                if DEBUG_MODE then
                    print("[AUDIO] Playing pause menu open sound (from 0.1s)")
                end
            end
            
            -- Pause all ambient sounds
            if audio.footstepSound then
                ---@type any
                local fs = audio.footstepSound
                fs:pause()
            end
            if audio.riverSound then
                ---@type any
                local rs = audio.riverSound
                rs:pause()
            end
            if audio.caveSound then
                ---@type any
                local cs = audio.caveSound
                cs:pause()
            end
            if audio.overworldSound then
                ---@type any
                local ow = audio.overworldSound
                ow:pause()
            end
            
            -- Stop unlocking door sound if playing
            if audio.unlockingDoorSound then
                ---@type any
                local unlocking = audio.unlockingDoorSound
                unlocking:stop()
            end
            
            -- Stop skeleton chase sound if playing
            if audio.skeletonChaseSound then
                ---@type any
                local chase = audio.skeletonChaseSound
                chase:stop()
            end
            
            -- Stop NPC talking sound if playing
            if audio.npcTalkingSound then
                ---@type any
                local npcTalk = audio.npcTalkingSound
                npcTalk:stop()
                audio.npcTalkingTargetVolume = 0
                audio.npcTalkingCurrentVolume = 0
            end
            
            -- Pause background music
            if audio.magicalVoyageMusic then
                ---@type any
                local voyage = audio.magicalVoyageMusic
                voyage:pause()
            end
            if audio.fightSongMusic then
                ---@type any
                local fight = audio.fightSongMusic
                fight:pause()
            end
        else
            -- Resume all ambient sounds
            if audio.footstepSound then
                ---@type any
                local fs = audio.footstepSound
                fs:play()
            end
            if audio.riverSound then
                ---@type any
                local rs = audio.riverSound
                rs:play()
            end
            if audio.caveSound then
                ---@type any
                local cs = audio.caveSound
                cs:play()
            end
            if audio.overworldSound then
                ---@type any
                local ow = audio.overworldSound
                ow:play()
            end
            
            -- Resume background music
            if audio.magicalVoyageMusic and audio.magicalVoyageCurrentVolume > 0 then
                ---@type any
                local voyage = audio.magicalVoyageMusic
                voyage:play()
            end
            if audio.fightSongMusic and audio.fightSongCurrentVolume > 0 then
                ---@type any
                local fight = audio.fightSongMusic
                fight:play()
            end
        end
        return
    end
    
    -- Pause menu shortcuts
    if isPaused then
        if key == "s" then
            -- Quick save - check if save exists first
            local saveExists = saveManager:saveExists()
            if saveExists then
                -- Show confirmation dialog
                pauseMenuState = "save_confirm"
                pauseMenuTargetHeight = 200
            else
                -- No existing save, just save
                local success, msg = saveManager:save(gameState, player.x, player.y, player.health)
                currentMessage = msg or "Game saved"
                messageTimer = 3
            end
        elseif key == "l" then
            -- Quick load
            local saveData, err = saveManager:load()
            if saveData then
                saveManager:applySaveData(gameState, saveData)
                world:loadMap(gameState.currentMap)
                player.x = gameState.playerSpawn.x
                player.y = gameState.playerSpawn.y
                player.health = gameState.playerHealth or player.maxHealth
                
                -- Rebuild spell system from loaded data
                spellSystem.gameState = gameState
                spellSystem:rebuildLearnedSpells()
                
                -- Sync interactables with loaded state (chests, etc.)
                local interactables = world:getCurrentInteractables()
                for _, obj in ipairs(interactables) do
                    obj:syncWithGameState(gameState)
                end
                
                isPaused = false
                
                -- Resume all ambient sounds
                if audio.footstepSound then
                    ---@type any
                    local fs = audio.footstepSound
                    fs:play()
                end
                if audio.riverSound then
                    ---@type any
                    local rs = audio.riverSound
                    rs:play()
                end
                if audio.caveSound then
                    ---@type any
                    local cs = audio.caveSound
                    cs:play()
                end
                if audio.overworldSound then
                    ---@type any
                    local ow = audio.overworldSound
                    ow:play()
                end
                
                currentMessage = "Game loaded"
                messageTimer = 3
            else
                currentMessage = err or "Failed to load game"
                messageTimer = 3
                print("Load error: " .. tostring(err))
            end
        elseif key == "t" then
            -- Show settings submenu
            pauseMenuState = "settings"
            pauseMenuTargetHeight = 280
        elseif key == "c" then
            -- Show controls submenu
            pauseMenuState = "controls"
            pauseMenuTargetHeight = 380
        elseif key == "y" and pauseMenuState == "save_confirm" then
            -- Confirm overwrite
            local success, msg = saveManager:save(gameState, player.x, player.y, player.health)
            currentMessage = msg or "Game saved"
            messageTimer = 3
            pauseMenuState = "main"
            pauseMenuTargetHeight = 280
        elseif key == "n" and pauseMenuState == "save_confirm" then
            -- Cancel save
            pauseMenuState = "main"
            pauseMenuTargetHeight = 280
        elseif key == "q" then
        love.event.quit()
        end
        return
    end
    
    -- Class selection UI controls
    if showClassSelection then
        if classSelectionConfirmation then
            if key == "y" then
                -- Confirm class selection
                if selectedClassIcon then
                    gameState.playerClass = selectedClassIcon.className
                    gameState.playerElement = selectedClassIcon.element
                    
                    -- Give the player their starter attack spell based on element
                    if spellSystem and selectedClassIcon.element then
                        local spell = nil
                        if selectedClassIcon.element == "fire" then
                            spell = Spell.createFireball()
                        elseif selectedClassIcon.element == "ice" then
                            spell = Spell.createIceShard()
                        elseif selectedClassIcon.element == "lightning" then
                            spell = Spell.createLightningBolt()
                        elseif selectedClassIcon.element == "earth" then
                            spell = Spell.createStoneSpike()
                        end
                        
                        if spell then
                            spellSystem:learnSpell(spell)
                        end
                    end
                    
                    currentMessage = string.format("You have chosen to become a %s!\n\nYou've learned your first attack spell!", selectedClassIcon.className)
                    messageTimer = 5
                    currentMessageItem = nil
                    
                    showClassSelection = false
                    selectedClassIcon = nil
                    classSelectionConfirmation = false
                end
            elseif key == "n" then
                -- Go back to class details
                classSelectionConfirmation = false
            end
        else
            if key == "e" then
                -- Show confirmation
                classSelectionConfirmation = true
            end
        end
        return
    end
    
    -- Strategy selection UI controls
    if showStrategySelection then
        if strategySelectionConfirmation then
            if key == "y" then
                -- Confirm strategy selection
                if selectedStrategyIcon then
                    local info = strategyInfo[selectedStrategyIcon.strategyName]
                    if info then
                        gameState.healingStrategy = info.strategy
                        gameState.defenseTrialsCompleted = true
                        gameState.questState = "strategy_selected"
                        
                        -- Give the player their healing strategy spell
                        if spellSystem then
                            local spell = nil
                            if info.strategy == "armor" then
                                spell = Spell.createArmorBuff()
                            elseif info.strategy == "drain" then
                                spell = Spell.createDrainBuff()
                            elseif info.strategy == "necromancer" then
                                spell = Spell.createNecromancerBuff()
                            end
                            
                            if spell then
                                spellSystem:learnSpell(spell)
                            end
                        end
                        
                        currentMessage = string.format("You have chosen the path of %s!\n\nYour healing strategy is now active.", selectedStrategyIcon.strategyName)
                        messageTimer = 5
                        currentMessageItem = nil
                        
                        showStrategySelection = false
                        selectedStrategyIcon = nil
                        strategySelectionConfirmation = false
                    end
                end
            elseif key == "n" then
                -- Go back to strategy details
                strategySelectionConfirmation = false
            end
        else
            if key == "e" then
                -- Show confirmation
                strategySelectionConfirmation = true
            end
        end
        return
    end
    
    -- Normal game controls (not paused)
    if key == "e" and not inCutscene then
        checkInteraction()
    elseif key == "f3" then
        showDebugPanel = not showDebugPanel
        DEBUG_MODE = showDebugPanel -- Also toggle hitboxes when debug panel is shown
    elseif key == "i" and not inCutscene then
        -- Toggle full inventory (like spell book)
        showFullInventory = not showFullInventory
        if showFullInventory then
            inventoryTargetWidth = 300
        else
            inventoryTargetWidth = 0
            inventoryScrollOffset = 0
            selectedInventoryItem = nil -- Clear selection when closing
        end
        
        -- Play panel swipe sound
        if audio.panelSwipeSound then
            ---@type any
            local swipe = audio.panelSwipeSound
            swipe:stop()
            swipe:play()
            if DEBUG_MODE then
                print("[AUDIO] Playing panel swipe sound (inventory)")
            end
        end
    elseif key == "h" and not inCutscene then
        showHelp = not showHelp
    elseif key == "b" and not inCutscene then
        -- Toggle spell menu (only if spells learned)
        if spellSystem then
            if #gameState.learnedSpells > 0 then
                spellSystem:toggleSpellMenu()
                
                -- Play panel swipe sound
                if audio.panelSwipeSound then
                    ---@type any
                    local swipe = audio.panelSwipeSound
                    swipe:stop()
                    swipe:play()
                    if DEBUG_MODE then
                        print("[AUDIO] Playing panel swipe sound (spell book)")
                    end
                end
            else
                currentMessage = "You haven't learned any spells yet..."
                messageTimer = 2
            end
        end
    elseif key == "1" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(1)
        if success and spell then
            -- Play spell casting sound
            if spell.name == "Illumination" and audio.illuminationCastSound then
                audio.illuminationCastSound:stop()
                audio.illuminationCastSound:play()
            elseif gameState.playerElement == "earth" and audio.earthCastSound then
                audio.earthCastSound:stop()
                audio.earthCastSound:play()
            elseif gameState.playerElement == "fire" and audio.fireCastSound then
                audio.fireCastSound:stop()
                audio.fireCastSound:play()
            elseif gameState.playerElement == "lightning" and audio.stormCastSound then
                audio.stormCastSound:stop()
                audio.stormCastSound:seek(3.0)
                audio.stormCastSound:play()
            elseif gameState.playerElement == "ice" and audio.iceCastSound then
                audio.iceCastSound:stop()
                audio.iceCastSound:play()
            end
            
            if spell.damage then
                -- Create projectile for attack spell
                table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
            end
        end
    elseif key == "2" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(2)
        if success and spell then
            -- Play spell casting sound
            if spell.name == "Illumination" and audio.illuminationCastSound then
                audio.illuminationCastSound:stop()
                audio.illuminationCastSound:play()
            elseif gameState.playerElement == "earth" and audio.earthCastSound then
                audio.earthCastSound:stop()
                audio.earthCastSound:play()
            elseif gameState.playerElement == "fire" and audio.fireCastSound then
                audio.fireCastSound:stop()
                audio.fireCastSound:play()
            elseif gameState.playerElement == "lightning" and audio.stormCastSound then
                audio.stormCastSound:stop()
                audio.stormCastSound:seek(3.0)
                audio.stormCastSound:play()
            elseif gameState.playerElement == "ice" and audio.iceCastSound then
                audio.iceCastSound:stop()
                audio.iceCastSound:play()
            end
            
            if spell.damage then
                table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
            end
        end
    elseif key == "3" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(3)
        if success and spell then
            -- Play spell casting sound
            if spell.name == "Illumination" and audio.illuminationCastSound then
                audio.illuminationCastSound:stop()
                audio.illuminationCastSound:play()
            elseif gameState.playerElement == "earth" and audio.earthCastSound then
                audio.earthCastSound:stop()
                audio.earthCastSound:play()
            elseif gameState.playerElement == "fire" and audio.fireCastSound then
                audio.fireCastSound:stop()
                audio.fireCastSound:play()
            elseif gameState.playerElement == "lightning" and audio.stormCastSound then
                audio.stormCastSound:stop()
                audio.stormCastSound:seek(3.0)
                audio.stormCastSound:play()
            elseif gameState.playerElement == "ice" and audio.iceCastSound then
                audio.iceCastSound:stop()
                audio.iceCastSound:play()
            end
            
            if spell.damage then
                table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
            end
        end
    elseif key == "4" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(4)
        if success and spell then
            -- Play spell casting sound
            if spell.name == "Illumination" and audio.illuminationCastSound then
                audio.illuminationCastSound:stop()
                audio.illuminationCastSound:play()
            elseif gameState.playerElement == "earth" and audio.earthCastSound then
                audio.earthCastSound:stop()
                audio.earthCastSound:play()
            elseif gameState.playerElement == "fire" and audio.fireCastSound then
                audio.fireCastSound:stop()
                audio.fireCastSound:play()
            elseif gameState.playerElement == "lightning" and audio.stormCastSound then
                audio.stormCastSound:stop()
                audio.stormCastSound:seek(3.0)
                audio.stormCastSound:play()
            elseif gameState.playerElement == "ice" and audio.iceCastSound then
                audio.iceCastSound:stop()
                audio.iceCastSound:play()
            end
            
            if spell.damage then
                table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
            end
        end
    elseif key == "5" and not inCutscene and spellSystem then
        local success, spell = spellSystem:activateSlot(5)
        if success and spell then
            -- Play spell casting sound
            if spell.name == "Illumination" and audio.illuminationCastSound then
                audio.illuminationCastSound:stop()
                audio.illuminationCastSound:play()
            elseif gameState.playerElement == "earth" and audio.earthCastSound then
                audio.earthCastSound:stop()
                audio.earthCastSound:play()
            elseif gameState.playerElement == "fire" and audio.fireCastSound then
                audio.fireCastSound:stop()
                audio.fireCastSound:play()
            elseif gameState.playerElement == "lightning" and audio.stormCastSound then
                audio.stormCastSound:stop()
                audio.stormCastSound:seek(3.0)
                audio.stormCastSound:play()
            elseif gameState.playerElement == "ice" and audio.iceCastSound then
                audio.iceCastSound:stop()
                audio.iceCastSound:play()
            end
            
            if spell.damage then
                table.insert(projectiles, Projectile:new(player.x, player.y, player.direction, spell, gameState.playerElement))
            end
        end
    elseif key == "6" and not inCutscene then
        -- Use quick slot 1
        if gameState.quickSlots[1] then
            useItem(gameState.quickSlots[1])
        end
    elseif key == "7" and not inCutscene then
        -- Use quick slot 2
        if gameState.quickSlots[2] then
            useItem(gameState.quickSlots[2])
        end
    elseif key == "8" and not inCutscene then
        -- Use quick slot 3
        if gameState.quickSlots[3] then
            useItem(gameState.quickSlots[3])
        end
    elseif key == "9" and not inCutscene then
        -- Use quick slot 4
        if gameState.quickSlots[4] then
            useItem(gameState.quickSlots[4])
        end
    elseif key == "0" and not inCutscene then
        -- Use quick slot 5
        if gameState.quickSlots[5] then
            useItem(gameState.quickSlots[5])
        end
    elseif key == "p" and not inCutscene then
        -- Profile menu (only available after selecting class)
        if gameState.playerClass then
            showProfileMenu = not showProfileMenu
        else
            currentMessage = "Complete class selection first..."
            messageTimer = 2
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Left click
        -- Settings menu slider clicks
        if isPaused and pauseMenuState == "settings" then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local panelWidth = 350
            local panelHeight = math.floor(pauseMenuHeight)
            local panelX = (screenWidth - panelWidth) / 2
            local panelY = (screenHeight - panelHeight) / 2
            local padding = 12
            local yPos = panelY + 70 -- Start after title
            
            -- Music slider hitbox
            local sliderX = panelX + padding + 10
            local sliderWidth = panelWidth - (padding * 2) - 70 -- Reserve space for percentage text
            local sliderHeight = 12
            local musicSliderY = yPos + 25
            
            if x >= sliderX and x <= sliderX + sliderWidth and
               y >= musicSliderY - 10 and y <= musicSliderY + sliderHeight + 10 then
                draggingMusicSlider = true
                local newVolume = math.max(0, math.min(1, (x - sliderX) / sliderWidth))
                gameState.musicVolume = newVolume
                return
            end
            
            -- SFX slider hitbox
            local sfxSliderY = musicSliderY + 65
            if x >= sliderX and x <= sliderX + sliderWidth and
               y >= sfxSliderY - 10 and y <= sfxSliderY + sliderHeight + 10 then
                draggingSFXSlider = true
                local newVolume = math.max(0, math.min(1, (x - sliderX) / sliderWidth))
                gameState.sfxVolume = newVolume
                return
            end
            
            -- Save button hitbox
            local buttonWidth = 120
            local buttonHeight = 30
            local buttonX = panelX + (panelWidth - buttonWidth) / 2
            local buttonY = sfxSliderY + 52
            if x >= buttonX and x <= buttonX + buttonWidth and
               y >= buttonY and y <= buttonY + buttonHeight then
                -- Save settings to file
                local success, msg = saveManager:save(gameState, player.x, player.y, player.health)
                currentMessage = "Settings saved!"
                messageTimer = 2
                return
            end
        end
        
        -- Dev mode clicks
        if devMode and devMode.enabled and devMode.showPanel then
            devMode:handleClick(x, y, gameState, world, player, spellSystem, Spell)
        end
        
        -- Handle spell menu clicks
        if spellSystem and spellSystem.showSpellMenu then
            spellSystem:handleClick(x, y)
        end
        
        -- Handle inventory clicks (equipping to quick slots)
        if showFullInventory and inventoryWidth > 5 then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local slotSize = 48
            local slotSpacing = 8
            local startX = screenWidth - slotSize - 15
            local startY = screenHeight / 2 - ((5 * slotSize + 4 * slotSpacing) / 2)
            local panelWidth = math.floor(inventoryWidth)
            local panelHeight = slotSize * 5 + slotSpacing * 4 + 40
            local panelX = startX - panelWidth - 10
            local panelY = startY - 20
            local contentY = panelY + 40
            local contentHeight = panelHeight - 48
            local columns = math.floor((panelWidth - 16) / (slotSize + 4))
            
            -- Check if clicking on a quick slot
            for s = 1, 5 do
                local slotX = startX
                local slotY = startY + (s - 1) * (slotSize + slotSpacing)
                if x >= slotX and x <= slotX + slotSize and
                   y >= slotY and y <= slotY + slotSize then
                    if selectedInventoryItem then
                        -- Equip selected item to this slot
                        gameState.quickSlots[s] = selectedInventoryItem
                        currentMessage = string.format("Equipped %s to slot %d", selectedInventoryItem, s + 5)
                        messageTimer = 2
                        selectedInventoryItem = nil -- Deselect after equipping
                    elseif gameState.quickSlots[s] then
                        -- Unequip item from this slot
                        local unequippedItem = gameState.quickSlots[s]
                        gameState.quickSlots[s] = nil
                        currentMessage = string.format("Unequipped %s from slot %d", unequippedItem, s + 5)
                        messageTimer = 2
                    end
                    return
                end
            end
            
            -- Check if clicking on an inventory item (to select it)
            local i = 0
            for itemName, count in pairs(gameState.inventory) do
                local col = i % columns
                local row = math.floor(i / columns)
                local itemX = panelX + 8 + col * (slotSize + 4)
                local itemY = contentY + row * (slotSize + 4) - inventoryScrollOffset
                
                if itemY + slotSize >= contentY and itemY <= contentY + contentHeight then
                    if x >= itemX and x <= itemX + slotSize and
                       y >= itemY and y <= itemY + slotSize and
                       y >= contentY and y <= contentY + contentHeight then
                        -- Toggle selection
                        if selectedInventoryItem == itemName then
                            selectedInventoryItem = nil -- Deselect
                            currentMessage = "Deselected"
                            messageTimer = 1
                        else
                            selectedInventoryItem = itemName -- Select
                            currentMessage = string.format("Selected %s - Click a slot to equip", itemName)
                            messageTimer = 2
                        end
                        return
                    end
                end
                i = i + 1
            end
        end
    end
end

function love.wheelmoved(x, y)
    -- Spell book scrolling
    if spellSystem and spellSystem.showSpellMenu and spellSystem.spellMenuWidth > 400 then
        spellSystem.spellMenuScrollOffset = spellSystem.spellMenuScrollOffset - y * 30
        local totalSpellListHeight = #spellSystem.learnedSpells * 55
        local screenHeight = love.graphics.getHeight()
        local headerHeight = 40
        local contentHeight = screenHeight - headerHeight - 170
        local maxScroll = math.max(0, totalSpellListHeight - contentHeight)
        spellSystem.spellMenuScrollOffset = math.max(0, math.min(spellSystem.spellMenuScrollOffset, maxScroll))
        return
    end
    
    -- Class selection scrolling
    if showClassSelection then
        classSelectionScrollOffset = classSelectionScrollOffset - y * 30
        classSelectionScrollOffset = math.max(0, classSelectionScrollOffset)
        return
    end
    
    -- Strategy selection scrolling
    if showStrategySelection then
        strategySelectionScrollOffset = strategySelectionScrollOffset - y * 30
        strategySelectionScrollOffset = math.max(0, strategySelectionScrollOffset)
        return
    end
    
    if showFullInventory and inventoryWidth > 5 then
        -- Scroll inventory
        local slotSize = 48
        local itemCount = 0
        for _ in pairs(gameState.inventory) do itemCount = itemCount + 1 end
        local inventoryRows = math.ceil(itemCount / math.floor((inventoryWidth - 16) / (slotSize + 4)))
        local maxScroll = math.max(0, inventoryRows * (slotSize + 4) - (slotSize * 5 + 32))
        
        inventoryScrollOffset = inventoryScrollOffset - y * 20
        inventoryScrollOffset = math.max(0, math.min(inventoryScrollOffset, maxScroll))
    end
end

function love.mousemoved(x, y, dx, dy)
    -- Handle settings slider dragging
    if draggingMusicSlider or draggingSFXSlider then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local panelWidth = 350
        local panelHeight = math.floor(pauseMenuHeight)
        local panelX = (screenWidth - panelWidth) / 2
        local panelY = (screenHeight - panelHeight) / 2
        local padding = 12
        local sliderX = panelX + padding + 10
        local sliderWidth = panelWidth - (padding * 2) - 70 -- Reserve space for percentage text
        
        local newVolume = math.max(0, math.min(1, (x - sliderX) / sliderWidth))
        
        if draggingMusicSlider then
            gameState.musicVolume = newVolume
            -- Apply to music immediately
            if audio.magicalVoyageMusic then
                ---@type any
                local music = audio.magicalVoyageMusic
                music:setVolume(audio.magicalVoyageCurrentVolume * gameState.musicVolume)
            end
            if audio.fightSongMusic then
                ---@type any
                local fight = audio.fightSongMusic
                fight:setVolume(audio.fightSongCurrentVolume * gameState.musicVolume)
            end
            if audio.overworldSound then
                ---@type any
                local ow = audio.overworldSound
                ow:setVolume(audio.overworldCurrentVolume * gameState.musicVolume)
            end
        elseif draggingSFXSlider then
            gameState.sfxVolume = newVolume
            -- Apply to all one-shot SFX immediately
            if audio.chestCreakSound then
                ---@type any
                local chest = audio.chestCreakSound
                chest:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.doorCreakSound then
                ---@type any
                local door = audio.doorCreakSound
                door:setVolume(0.45 * gameState.sfxVolume)
            end
            if audio.unlockingDoorSound then
                ---@type any
                local unlock = audio.unlockingDoorSound
                unlock:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.pauseMenuOpenSound then
                ---@type any
                local pause = audio.pauseMenuOpenSound
                pause:setVolume(0.5 * gameState.sfxVolume)
            end
            if audio.panelSwipeSound then
                ---@type any
                local panel = audio.panelSwipeSound
                panel:setVolume(0.5 * gameState.sfxVolume)
            end
            if audio.skeletonChaseSound then
                ---@type any
                local chase = audio.skeletonChaseSound
                chase:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.earthCastSound then
                ---@type any
                local earth = audio.earthCastSound
                earth:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.fireCastSound then
                ---@type any
                local fire = audio.fireCastSound
                fire:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.stormCastSound then
                ---@type any
                local storm = audio.stormCastSound
                storm:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.iceCastSound then
                ---@type any
                local ice = audio.iceCastSound
                ice:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.illuminationCastSound then
                ---@type any
                local illum = audio.illuminationCastSound
                illum:setVolume(0.6 * gameState.sfxVolume)
            end
            if audio.trialsSpawnSound then
                ---@type any
                local trials = audio.trialsSpawnSound
                trials:setVolume(0.5 * gameState.sfxVolume)
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        draggingMusicSlider = false
        draggingSFXSlider = false
    end
end

function love.textinput(text)
    if not gameStarted and startScreenState == "new_game" and #playerNameInput < 15 then
        playerNameInput = playerNameInput .. text
        -- Reset cursor to visible when typing
        cursorBlinkTimer = 0
        cursorVisible = true
    end
end

