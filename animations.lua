local addonName, LCT = ...

-- Initialize animations namespace
LCT.animations = {}

-- Animation settings
local ANIMATION_DURATION = 0.1     -- Smooth 100ms transitions
local FINISH_ANIMATION_DURATION = 0.2
local FINAL_SECONDS_SCALE = 1.0    -- No scaling (was 2.0, caused overlap)
local FINAL_SECONDS_THRESHOLD = 10
local MIN_UPDATE_INTERVAL = 0.016  -- ~60 FPS max
local FPS_THRESHOLD = 30  -- FPS threshold for reduced updates
local POSITION_THRESHOLD = 0.5    -- Minimum position change to update (was 0.1)
local SCALE_THRESHOLD = 0.05   -- Minimum scale change to update
local ALPHA_THRESHOLD = 0.05   -- Minimum alpha change to update

-- Table to store active animations
local activeAnimations = {}
local finishAnimations = {}

-- Optimization: Pre-calculate common values
local function GetProgressAndElapsed(startTime, now, duration)
    local elapsed = now - startTime
    if elapsed >= duration then
        return 1, elapsed
    end
    return elapsed / duration, elapsed
end

-- Optimization: Efficient position calculation
local function CalculatePosition(progress, startX, targetX)
    -- Linear interpolation
    return startX + ((targetX - startX) * progress)
end

-- Optimization: Efficient scale calculation
local function CalculateScale(remaining)
    if not remaining or remaining > FINAL_SECONDS_THRESHOLD then
        return 1
    end
    -- Pre-calculate 1/FINAL_SECONDS_THRESHOLD
    local factor = 1 / FINAL_SECONDS_THRESHOLD
    return 1 + (FINAL_SECONDS_SCALE - 1) * (1 - remaining * factor)
end

-- Create animation frame
LCT.animations.updateFrame = CreateFrame("Frame")
LCT.animations.updateFrame.lastUpdate = 0
LCT.animations.updateFrame.isAnimating = false

-- OnUpdate handler function (separate so we can set/unset it)
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
    
    -- Update position animations
    for icon, anim in pairs(activeAnimations) do
        if icon:IsVisible() then
            local progress, elapsed = GetProgressAndElapsed(anim.startTime, now, anim.duration)
            
            if progress >= 1 then
                -- Animation complete - single update
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", LCT.frame, "LEFT", anim.targetX, 0)
                if anim.remaining and anim.remaining <= FINAL_SECONDS_THRESHOLD then
                    icon:SetScale(1)
                end
                activeAnimations[icon] = nil
            else
                -- Calculate position only if needed
                local currentX = CalculatePosition(progress, anim.startX, anim.targetX)
                
                -- Update position only if change is significant
                if not anim.lastX or math.abs(currentX - anim.lastX) > POSITION_THRESHOLD then
                    icon:ClearAllPoints()
                    icon:SetPoint("CENTER", LCT.frame, "LEFT", currentX, 0)
                    anim.lastX = currentX
                end
                
                -- Update scale only if in final seconds threshold
                if anim.remaining and anim.remaining <= FINAL_SECONDS_THRESHOLD then
                    local newScale = CalculateScale(anim.remaining)
                    if not anim.lastScale or math.abs(newScale - anim.lastScale) > SCALE_THRESHOLD then
                        icon:SetScale(newScale)
                        anim.lastScale = newScale
                    end
                end
                
                hasActiveAnimations = true
            end
        else
            activeAnimations[icon] = nil
        end
    end
    
    -- Update finish animations
    for icon, anim in pairs(finishAnimations) do
        local progress, elapsed = GetProgressAndElapsed(anim.startTime, now, FINISH_ANIMATION_DURATION)
        
        if progress >= 1 then
            -- Animation complete - single update
            icon:Hide()
            icon:SetScale(1)
            icon:SetAlpha(1)
            finishAnimations[icon] = nil
        else
            -- Calculate alpha only if needed
            local newAlpha = 1 - progress
            
            -- Update alpha only if change is significant
            if not anim.lastAlpha or math.abs(newAlpha - anim.lastAlpha) > ALPHA_THRESHOLD then
                icon:SetAlpha(newAlpha)
                anim.lastAlpha = newAlpha
            end
            
            hasActiveAnimations = true
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
        frame:SetScript("OnUpdate", AnimationOnUpdate)
        LCT:Debug("Animations STARTED")
    end
end

-- NOTE: OnUpdate is NOT set here - starts disabled for performance
-- It only activates when StartPositionAnimation or StartFinishAnimation is called

-- Function to start position animation
function LCT.animations.StartPositionAnimation(frame, targetX, remaining)
    if not frame or not frame:IsObjectType("Frame") then return end
    
    -- Ensure frame has a valid point
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    if not point then
        -- If no point exists, set a default one
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", LCT.frame, "LEFT", 0, 0)
        x = 0
    end
    
    activeAnimations[frame] = {
        startTime = GetTime(),
        duration = ANIMATION_DURATION,
        startX = x or 0,
        targetX = targetX,
        remaining = remaining
    }
    
    StartAnimating()
end

-- Function to start freeze-fade animation
function LCT.animations.StartFinishAnimation(icon)
    if not icon then return end
    
    finishAnimations[icon] = {
        startTime = GetTime()
    }
    
    StartAnimating()
end

-- Function to cancel animation
function LCT.animations.CancelAnimation(icon)
    if not icon then return end
    
    activeAnimations[icon] = nil
    finishAnimations[icon] = nil
    icon:SetScale(1)
    icon:SetAlpha(1)
end 