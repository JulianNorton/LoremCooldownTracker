local addonName, LCT = ...

-- Performance: Cache global functions
local GetFramerate = GetFramerate
local abs = math.abs

-- Timeline functions
local timeline = {}
LCT.timeline = timeline

-- Function to update timeline markers
function timeline.UpdateMarkers()
    local frame = LCT.frame
    LCT:Debug("Updating timeline markers")
    
    -- Initialize marker tables if they don't exist
    frame.markers = frame.markers or {}
    frame.texts = frame.texts or {}
    
    -- Function to get or create marker
    local function GetMarker(index)
        if not frame.markers[index] then
            local marker = frame:CreateTexture(nil, "ARTWORK")
            frame.markers[index] = marker
        end
        return frame.markers[index]
    end
    
    -- Function to get or create text
    local function GetText(index)
        if not frame.texts[index] then
            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            frame.texts[index] = text
        end
        return frame.texts[index]
    end
    
    local width = frame:GetWidth()
    local iconSize = LCT.iconSize
    
    -- Function to calculate marker position
    local function GetMarkerPosition(timeRemaining)
        return (timeRemaining / LCT.maxTime) * (width - iconSize) + (iconSize/2)
    end
    
    -- Update 0-second marker (left)
    local startMarker = GetMarker(1)
    startMarker:SetSize(1, frame:GetHeight() * 0.5)
    startMarker:SetColorTexture(1, 1, 1, 0.3)
    startMarker:ClearAllPoints()
    startMarker:SetPoint("TOP", frame, "TOPLEFT", GetMarkerPosition(0), 0)
    startMarker:Show()
    
    -- Update 10-second marker
    local tenSecMarker = GetMarker(2)
    tenSecMarker:SetSize(1, frame:GetHeight() * 0.3)
    tenSecMarker:SetColorTexture(1, 1, 1, 0.2)
    tenSecMarker:ClearAllPoints()
    tenSecMarker:SetPoint("TOP", frame, "TOPLEFT", GetMarkerPosition(10), 0)
    tenSecMarker:Show()
    
    -- Update 30-second marker
    local halfMinMarker = GetMarker(3)
    halfMinMarker:SetSize(1, frame:GetHeight() * 0.4)
    halfMinMarker:SetColorTexture(1, 1, 1, 0.25)
    halfMinMarker:ClearAllPoints()
    halfMinMarker:SetPoint("TOP", frame, "TOPLEFT", GetMarkerPosition(30), 0)
    halfMinMarker:Show()
    
    -- Update 1-minute marker
    local minuteMarker = GetMarker(4)
    minuteMarker:SetSize(1, frame:GetHeight() * 0.5)
    minuteMarker:SetColorTexture(1, 1, 1, 0.3)
    minuteMarker:ClearAllPoints()
    minuteMarker:SetPoint("TOP", frame, "TOPLEFT", GetMarkerPosition(60), 0)
    minuteMarker:Show()
    
    -- Update 1m text
    local minuteText = GetText(1)
    minuteText:SetText("1m")
    minuteText:ClearAllPoints()
    minuteText:SetPoint("BOTTOM", minuteMarker, "TOP", 0, 1)
    minuteText:SetTextColor(1, 1, 1, 0.3)
    minuteText:Show()
    
    -- Update 5-minute marker (right)
    local endMarker = GetMarker(5)
    endMarker:SetSize(1, frame:GetHeight() * 0.5)
    endMarker:SetColorTexture(1, 1, 1, 0.3)
    endMarker:ClearAllPoints()
    endMarker:SetPoint("TOP", frame, "TOPLEFT", GetMarkerPosition(LCT.maxTime), 0)
    endMarker:Show()
    
    -- Update 5m text
    local endText = GetText(2)
    endText:SetText("5m")
    endText:ClearAllPoints()
    endText:SetPoint("BOTTOM", endMarker, "TOP", 0, 1)
    endText:SetTextColor(1, 1, 1, 0.3)
    endText:Show()
    
    LCT:Debug("Updated timeline markers")
end

-- Initialize timeline
function timeline.Initialize()
    LCT:Debug("Initializing timeline module")
    
    -- Throttle resize updates
    local resizeElapsed = 0
    local isResizing = false
    local BASE_RESIZE_THROTTLE = 0.1  -- Base: 100ms during resize
    local lastWidth = 0
    local lastHeight = 0
    
    -- Create resize update frame
    local resizeFrame = CreateFrame("Frame")
    resizeFrame:Hide()
    
    -- Set up throttled resize handler with FPS awareness
    resizeFrame:SetScript("OnUpdate", function(self, elapsed)
        resizeElapsed = resizeElapsed + elapsed
        
        -- Adjust throttle based on FPS
        local fps = GetFramerate()
        local targetThrottle = BASE_RESIZE_THROTTLE
        if fps < 30 then
            targetThrottle = BASE_RESIZE_THROTTLE * 1.5
        end
        
        if resizeElapsed >= targetThrottle then
            -- Only update if dimensions actually changed
            local currentWidth = LCT.frame:GetWidth()
            local currentHeight = LCT.frame:GetHeight()
            
            if currentWidth ~= lastWidth or currentHeight ~= lastHeight then
                timeline.UpdateMarkers()
                lastWidth = currentWidth
                lastHeight = currentHeight
            end
            
            resizeElapsed = 0
            
            -- If we're not resizing anymore, hide the frame
            if not isResizing then
                self:Hide()
            end
        end
    end)
    
    -- Set up resize handler with throttling
    LCT.frame:SetScript("OnSizeChanged", function()
        if not isResizing then
            isResizing = true
            resizeFrame:Show()
            
            -- Force an immediate first update if dimensions changed significantly
            local currentWidth = LCT.frame:GetWidth()
            local currentHeight = LCT.frame:GetHeight()
            
            if abs(currentWidth - lastWidth) > 5 or abs(currentHeight - lastHeight) > 5 then
                timeline.UpdateMarkers()
                lastWidth = currentWidth
                lastHeight = currentHeight
            end
        end
        
        -- Reset resize state after a delay
        C_Timer.After(0.2, function()
            isResizing = false
        end)
    end)
    
    -- Create initial markers
    timeline.UpdateMarkers()
    lastWidth = LCT.frame:GetWidth()
    lastHeight = LCT.frame:GetHeight()
end

-- Return the module
return timeline 