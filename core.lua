-- Create addon namespace
local addonName, LCT = ...
LCT.version = "1.1.0"
LCT.core = true  -- Mark core module as loaded for test framework

-- Debug print function
function LCT:Debug(...)
    if self.debug then
        print("LoremCT Debug:", ...)
    end
end

-- Set default options
LCT.defaults = {
    -- Debug
    debug = false,
    
    -- Frame dimensions
    barWidth = 420,
    barHeight = 23,
    iconSize = 24,
    locked = false,
    
    -- Visibility
    shown = true,
    bgOpacity = 0.5,
    showTimeText = true,
    showIcons = true,
    
    -- Timeline
    maxTime = 300, -- 5 minutes
    updateFrequency = 0.1 -- 10 times per second
}

-- Initialize current settings from defaults
for key, value in pairs(LCT.defaults) do
    LCT[key] = value
end

-- Main frame
local frame = CreateFrame("Frame", "LoremCTFrame", UIParent)
LCT.frame = frame  -- Make frame accessible to other modules

-- Set frame properties
frame:SetSize(LCT.defaults.barWidth, LCT.defaults.barHeight)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)

-- Add frame locking property
frame.locked = LCT.defaults.locked

-- Modify dragging behavior to respect lock
frame:SetScript("OnMouseDown", function(self, button)
    if not self.locked and button == "LeftButton" then
        self:StartMoving()
    end
end)
frame:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    -- Save position after moving
    if LCT.visibility and LCT.visibility.SaveSettings then
        LCT.visibility.SaveSettings()
    end
end)

-- Create timeline background
frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints()
frame.bg:SetColorTexture(0, 0, 0, LCT.defaults.bgOpacity)

LCT:Debug("Frame created with dimensions", frame:GetWidth(), frame:GetHeight())

-- Initialize frame visibility
frame:Show()
LCT:Debug("Frame shown status after initial Show():", frame:IsShown())

-- Load modules
LCT:Debug("Loading modules...")

-- Load animations module
LCT.animations = LCT.animations or {}
LCT.animations.StartPositionAnimation = LCT.animations.StartPositionAnimation or function() end
LCT.animations.StartFinishAnimation = LCT.animations.StartFinishAnimation or function() end
LCT.animations.CancelAnimation = LCT.animations.CancelAnimation or function() end

-- Register events for addon initialization
-- Helper to ensure modules are initialized only once
function LCT:EnsureInitialized()
    if self.initialized then return end
    
    LCT:Debug("Initializing modules...")
    
    -- Initialize modules in correct order
    if LCT.visibility then
        LCT:Debug("Initializing visibility module")
        LCT.visibility.Initialize()
    else
        LCT:Debug("ERROR - Visibility module not found")
    end
    
    if LCT.cooldowns then
        LCT:Debug("Initializing cooldowns module")
        LCT.cooldowns.Initialize()
    else
        LCT:Debug("ERROR - Cooldowns module not found")
    end
    
    if LCT.spells then
        LCT:Debug("Initializing spells module")
        LCT.spells.Initialize()
    else
        LCT:Debug("ERROR - Spells module not found")
    end
    
    if LCT.items then
        LCT:Debug("Initializing items module")
        LCT.items.Initialize()
    else
        LCT:Debug("ERROR - Items module not found")
    end
    
    if LCT.timeline then
        LCT:Debug("Initializing timeline module")
        LCT.timeline.Initialize()
    else
        LCT:Debug("ERROR - Timeline module not found")
    end
    
    self.initialized = true
    LCT:Debug("Frame shown status after module initialization:", frame:IsShown())
end

-- Register events for addon initialization
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Fallback for when ADDON_LOADED is unreliable (TBC PTR)

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        LCT:Debug("ADDON_LOADED fired - attempting initialization")
        LCT:EnsureInitialized()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- This serves as a fail-safe backup for initialization
        -- and also ensures visibility is correct
        LCT:Debug("PLAYER_ENTERING_WORLD fired - attempting initialization")
        LCT:EnsureInitialized()
        
        -- Also let visibility module handle its specific logic if needed
        -- (Though visibility module has its own event handler too)
    elseif event == "PLAYER_LOGIN" then
        LCT:Debug("PLAYER_LOGIN - Checking frame visibility")
        LCT:Debug("Frame shown status:", frame:IsShown())
        if not frame:IsShown() and LCT.visibility and LCT.visibility.shown then
            LCT:Debug("Frame should be shown but isn't, showing now")
            frame:Show()
        end
    end
end)

-- Basic slash command registration
SLASH_LCT1 = "/lct"
SlashCmdList["LCT"] = function(msg)
    if msg == "scan" then
        if LCT.spells and LCT.spells.ScanSpellBook then
            LCT:Debug("Manual spell scan requested")
            LCT.spells.ScanSpellBook()
            print("LoremCT: Rescanned spellbook")
        else
            LCT:Debug("ERROR - Could not scan spellbook, spells module not found")
        end
    elseif msg == "lock" then
        frame.locked = not frame.locked
        -- When locked: disable mouse so clicks pass through
        -- When unlocked: enable mouse for dragging
        frame:EnableMouse(not frame.locked)
        print("LoremCT: Frame " .. (frame.locked and "locked (click-through)" or "unlocked (draggable)"))
    elseif msg == "toggle" then
        if frame:IsVisible() then
            frame:Hide()
            print("LoremCT: Frame hidden")
        else
            frame:Show()
            print("LoremCT: Frame shown")
        end
        -- Save visibility state
        if LCT.visibility and LCT.visibility.SaveSettings then
            LCT.visibility.SaveSettings()
        end
        LCT:Debug("Frame shown status after toggle:", frame:IsShown())
    elseif msg == "debug" then
        LCT.debug = not LCT.debug
        print("LoremCT: Debug mode", LCT.debug and "enabled" or "disabled")
    else
        if LCT.settingsFrame and LCT.settingsFrame:IsShown() then
            LCT.settingsFrame:Hide()
        elseif LCT.settingsFrame then
            LCT.settingsFrame:Show()
        end
    end
end 