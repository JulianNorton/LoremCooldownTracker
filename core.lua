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

-- Cross-client API compatibility & secret value protection
local issecretvalue = _G.issecretvalue
local function IsReadable(val)
    return not (issecretvalue and issecretvalue(val))
end

LCT.compat = {
    IsReadable = IsReadable,
}

function LCT.compat.GetSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if IsReadable(name) and name and name ~= "" then return name end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and IsReadable(info.name) and info.name and info.name ~= "" then
            return info.name
        end
    end
    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if IsReadable(name) and name and name ~= "" then return name end
    end
    return nil
end

function LCT.compat.GetSpellTexture(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if IsReadable(tex) and tex then return tex end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and IsReadable(info.iconID) and info.iconID then
            return info.iconID
        end
    end
    if _G.GetSpellTexture then
        local tex = _G.GetSpellTexture(spellID)
        if IsReadable(tex) and tex then return tex end
    end
    return nil
end

function LCT.compat.GetSpellBaseCooldown(spellID)
    if not spellID then return nil end
    if _G.GetSpellBaseCooldown then
        local ok, cd = pcall(_G.GetSpellBaseCooldown, spellID)
        if ok and IsReadable(cd) and type(cd) == "number" then return cd end
    end
    if C_Spell and C_Spell.GetSpellBaseCooldown then
        local ok, cd = pcall(C_Spell.GetSpellBaseCooldown, spellID)
        if ok and IsReadable(cd) and type(cd) == "number" then return cd end
    end
    return nil
end

function LCT.compat.GetSpellCooldown(spellID)
    if not spellID then return nil, nil, nil, nil end
    
    -- Try modern C_Spell.GetSpellCooldown first (Forever 16001 / Modern)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            local enabled = IsReadable(info.isEnabled) and (info.isEnabled == true or info.isEnabled == 1) or false
            local start = IsReadable(info.startTime) and type(info.startTime) == "number" and info.startTime or nil
            local duration = IsReadable(info.duration) and type(info.duration) == "number" and info.duration or nil
            local isOnGCD = IsReadable(info.isOnGCD) and (info.isOnGCD == true) or false
            
            -- Fallback if start/duration are secret or missing during combat: try GetSpellCooldownDuration
            if (not start or not duration) and C_Spell.GetSpellCooldownDuration then
                local durObj = C_Spell.GetSpellCooldownDuration(spellID, true)
                if durObj and durObj.GetRemainingDuration then
                    local ok, rem = pcall(durObj.GetRemainingDuration, durObj)
                    if ok and IsReadable(rem) and type(rem) == "number" and rem > 0 then
                        start = GetTime()
                        duration = rem
                        enabled = true
                    end
                end
            end
            
            if start and duration then
                return start, duration, enabled, isOnGCD
            end
        end
    end
    
    -- Legacy fallback: _G.GetSpellCooldown
    if _G.GetSpellCooldown then
        local start, duration, enabled = _G.GetSpellCooldown(spellID)
        if IsReadable(start) and IsReadable(duration) and type(start) == "number" and type(duration) == "number" then
            local isEnabled = (enabled == 1 or enabled == true)
            return start, duration, isEnabled, false
        end
    end
    
    return nil, nil, nil, nil
end

function LCT.compat.GetItemName(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemID)
        if IsReadable(name) and name and name ~= "" then return name end
    end
    if _G.GetItemInfo then
        local name = _G.GetItemInfo(itemID)
        if IsReadable(name) and name and name ~= "" then return name end
    end
    return nil
end

function LCT.compat.GetItemIcon(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if IsReadable(icon) and icon then return icon end
    end
    if _G.GetItemIcon then
        local icon = _G.GetItemIcon(itemID)
        if IsReadable(icon) and icon then return icon end
    end
    return nil
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
    maxTime = 600, -- 10 minutes
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
    local modules = {"visibility", "cooldowns", "spells", "items", "timeline", "settings"}
    for _, moduleName in ipairs(modules) do
        if LCT[moduleName] and LCT[moduleName].Initialize then
            LCT:Debug("Initializing " .. moduleName .. " module")
            LCT[moduleName].Initialize()
        else
            LCT:Debug("ERROR - " .. moduleName .. " module not found or missing Initialize")
        end
    end
    
    self.initialized = true
    LCT:Debug("Frame shown status after module initialization:", frame:IsShown())
end

-- Register events for addon initialization
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Fallback for when ADDON_LOADED is unreliable

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        LCT:Debug("ADDON_LOADED fired - attempting initialization")
        LCT:EnsureInitialized()
    elseif event == "PLAYER_ENTERING_WORLD" then
        LCT:Debug("PLAYER_ENTERING_WORLD fired - attempting initialization")
        LCT:EnsureInitialized()
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
        frame:EnableMouse(not frame.locked)
        if LCT.settings and LCT.settings.SaveDimensionSettings then
            LCT.settings.SaveDimensionSettings()
        end
        if LCT.settings and LCT.settings.UpdateDimensionControls then
            LCT.settings.UpdateDimensionControls()
        end
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
