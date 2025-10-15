local Transition = {}

function Transition.new(fadeRef, portalRef)
    local self = {
        fade = fadeRef,
        portal = portalRef
    }

    function self:startFade(targetMap, spawnX, spawnY, opts)
        opts = opts or {}
        local isPortal = opts.isPortal == true
        local sourceMap = opts.sourceMap

        -- Configure fade
        self.fade.state = "fade_out"
        self.fade.sourceMap = sourceMap
        self.fade.targetMap = targetMap
        self.fade.spawnX = spawnX
        self.fade.spawnY = spawnY

        if isPortal then
            -- Start portal shrinking animation
            self.portal.animState = "shrinking"
            self.portal.animTimer = 0
            self.portal.playerScale = 1
            self.portal.sourceMap = sourceMap
        end
    end

    return self
end

return Transition


