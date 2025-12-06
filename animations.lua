local addonName, LCT = ...

-- Performance: Cache global functions
local GetTime = GetTime
local GetFramerate = GetFramerate
local pairs = pairs

-- Initialize animations namespace
LCT.animations = {}

-- Animation settings
local FINISH_POP_DURATION = 0.3    -- Scale up over 0.3 seconds
local FINISH_FADE_DURATION = 0.15   -- Fade out in final 0.15 seconds
local FINISH_TOTAL_DURATION = FINISH_POP_DURATION + FINISH_FADE_DURATION  -- 0.6s total
local POP_SCALE = 1.5              -- Scale up to 150% at peak
local MIN_UPDATE_INTERVAL = 0.016  -- ~60 FPS max
local FPS_THRESHOLD = 30           -- FPS threshold for reduced updates

-- Table to store active finish animations
local finishAnimations = {}

-- Create animation frame
LCT.animations.updateFrame = CreateFrame("Frame")
LCT.animations.updateFrame.lastUpdate = 0
LCT.animations.updateFrame.isAnimating = false

-- Easing function: ease-out for smooth pop
local function EaseOut(t)
    return 1 - (1 - t) * (1 - t)
end

-- OnUpdate handler for animations
local function AnimationOnUpdate(self, elapsed)
    -- FPS-aware update throttling
    local now = GetTime()
    local timeSinceLastUpdate = now - self.lastUpdate
    local fps = GetFramerate()
    
    -- Adjust update interval based on FPS
    local targetInterval = MIN_UPDATE_INTERVAL
    if fps < FPS_THRESHOLD then
        targetInterval = targetInterval * (FPS_THRESHOLD / fps)
    end
    
    if timeSinceLastUpdate < targetInterval then
        return
    end
    self.lastUpdate = now
    
    local hasActiveAnimations = false
    
    -- Update finish animations (pop + fade)
    for icon, anim in pairs(finishAnimations) do
        local elapsed = now - anim.startTime
        
        if elapsed >= FINISH_TOTAL_DURATION then
            -- Animation complete - reset and hide
            icon:Hide()
            icon:SetScale(1)
            icon:SetAlpha(1)
            finishAnimations[icon] = nil
        else
            hasActiveAnimations = true
            
            if elapsed < FINISH_POP_DURATION then
                -- Pop phase: scale up with easing
                local popProgress = elapsed / FINISH_POP_DURATION
                local easedProgress = EaseOut(popProgress)
                local scale = 1 + (POP_SCALE - 1) * easedProgress
                icon:SetScale(scale)
                icon:SetAlpha(1)
            else
                -- Fade phase: stay at peak scale, fade out
                local fadeElapsed = elapsed - FINISH_POP_DURATION
                local fadeProgress = fadeElapsed / FINISH_FADE_DURATION
                icon:SetScale(POP_SCALE)
                icon:SetAlpha(1 - fadeProgress)
            end
        end
    end
    
    -- Performance: Stop OnUpdate when no active animations
    if not hasActiveAnimations then
        self:SetScript("OnUpdate", nil)
        self.isAnimating = false
        LCT:Debug("Animations STOPPED (idle)")
    end
end

-- Performance: Start animations OnUpdate
local function StartAnimating()
    local frame = LCT.animations.updateFrame
    if not frame.isAnimating then
        frame.isAnimating = true
        frame.lastUpdate = GetTime()
        frame:SetScript("OnUpdate", AnimationOnUpdate)
        LCT:Debug("Animations STARTED")
    end
end

-- Function to start pop-and-fade finish animation
function LCT.animations.StartFinishAnimation(icon)
    if not icon then return end
    
    finishAnimations[icon] = {
        startTime = GetTime()
    }
    
    -- Ensure visible for animation
    icon:Show()
    icon:SetAlpha(1)
    
    StartAnimating()
end

-- Function to check if icon is currently finishing
function LCT.animations.IsFinishing(icon)
    return icon and finishAnimations[icon] ~= nil
end

-- Function to cancel animation
function LCT.animations.CancelAnimation(icon)
    if not icon then return end
    
    finishAnimations[icon] = nil
    icon:SetScale(1)
    icon:SetAlpha(1)
end

-- Legacy function (kept for compatibility, no longer used)
function LCT.animations.StartPositionAnimation(frame, targetX, remaining)
    -- Position animations removed - cooldowns.lua handles position directly
    -- This stub prevents errors if called
end 