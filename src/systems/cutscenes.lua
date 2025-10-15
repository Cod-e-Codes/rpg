local Cutscenes = {}

-- Start the north path reveal pan (after returning from class selection)
function Cutscenes.startNorthPathReveal(cameraPan, gameState, player, messageState)
    if cameraPan.northPathCutsceneShown or gameState.mysteriousCaveHidden then return end
    cameraPan.northPathCutsceneShown = true
    gameState.mysteriousCaveHidden = true -- Hide the mysterious cave
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local northPathX = 1280
    local northPathY = 5 * 32
    cameraPan.original.x = player.x - screenWidth / 2
    cameraPan.original.y = player.y - screenHeight / 2
    cameraPan.target.x = northPathX - screenWidth / 2
    cameraPan.target.y = northPathY - screenHeight / 2
    cameraPan.state = "pan_to_target"
    
    messageState.currentMessage = "An ancient path to the north has revealed itself!"
    messageState.currentMessageItem = nil
    messageState.messageTimer = 5
end

-- Start the cave reveal sequence when exiting house with sword
function Cutscenes.startCaveReveal(cameraPan, cutsceneState, player, messageState)
    cameraPan.caveCutsceneShown = true
    cutsceneState.inCutscene = true
    player.isMoving = false
    cutsceneState.cutsceneWalkTarget = {x = player.x, y = player.y + 64}
    cutsceneState.cutsceneOnComplete = function()
        cutsceneState.cutsceneWalkTarget = nil
        cutsceneState.cutsceneOnComplete = nil
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local caveX = 80
        local caveY = 26*32 + 96
        cameraPan.original.x = player.x - screenWidth / 2
        cameraPan.original.y = player.y - screenHeight / 2
        cameraPan.target.x = caveX - screenWidth / 2
        cameraPan.target.y = caveY - screenHeight / 2
        cameraPan.state = "pan_to_target"
        messageState.currentMessage = "A mysterious cave has appeared to the west!"
        messageState.currentMessageItem = nil
        messageState.messageTimer = 999
    end
end

-- Start town greeting if not shown; finds the greeter NPC in current map
function Cutscenes.tryStartTownGreeting(townGreeting, world, player)
    if world.gameState.townGreetingShown then return end
    local npcs = world:getCurrentNPCs()
    for _, npc in ipairs(npcs) do
        if npc.questState == "town_greeter" then
            townGreeting.npc = npc
            townGreeting.npcStartX = npc.x
            townGreeting.npcStartY = npc.y
            townGreeting.npcTargetX = player.x
            townGreeting.npcTargetY = player.y - 80
            townGreeting.state = "player_walk"
            townGreeting.timer = 0
            townGreeting.duration = 1.0
            return true
        end
    end
    return false
end

return Cutscenes


