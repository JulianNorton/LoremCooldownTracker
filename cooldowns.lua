local addonName, LCT = ...

-- Performance: Cache global functions
local GetTime = GetTime
local pairs = pairs
local floor = math.floor
local min = math.min
local sqrt = math.sqrt
local format = string.format

-- Cache bag-related functions for bag item support
-- Detect modern C_Container API (Dragonflight/Classic Era 1.15+) vs Legacy Globals
local C_Container = C_Container
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetContainerItemCooldown = (C_Container and C_Container.GetContainerItemCooldown) or _G.GetContainerItemCooldown
local GetItemIcon = GetItemIcon

-- Pre-formatted time strings
local FORMAT_MINUTES = "%.0fm"
local FORMAT_SECONDS = "%.0f"
local FORMAT_DECIMAL = "%.1f"

-- Cooldown tracking module
local cooldowns = {}
LCT.cooldowns = cooldowns

-- Tables to store active cooldowns
local activeCooldowns = {}
local trackedSpells = {}
local trackedItems = {}
local activeCooldownList = {} -- Track which cooldowns are currently active

-- Performance: Track update state
local isUpdating = false
local cooldownEventFrame = nil
local updateElapsed = 0

-- Make tables accessible to other modules
LCT.activeCooldowns = activeCooldowns
LCT.cooldowns.trackedItems = trackedItems  -- Expose trackedItems table

-- Helper: Check if an ID is a bag item (negative = bag item)
local function IsBagItem(id)
    return id < 0
end

-- Helper: Get actual itemID from tracking key (negative -> positive)
local function GetActualItemID(id)
    return id < 0 and -id or id
end

-- Helper: Find a bag item by itemID and return its cooldown
-- Performance: Searches bags for the specified itemID
local function GetBagItemCooldown(itemID)
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        for slotID = 1, numSlots do
            local bagItemID = GetContainerItemID(bagID, slotID)
            if bagItemID == itemID then
                local start, duration, enable = GetContainerItemCooldown(bagID, slotID)
                return start, duration, enable
            end
        end
    end
    return nil, nil, nil
end

-- Helper: Generate unique key for cooldown (prevents spell/item ID collision)
local function GetCooldownKey(id, isItem)
    return (isItem and "item_" or "spell_") .. id
end

-- Function to format time text (uses pre-cached format strings)
local function FormatTimeText(remaining)
    if remaining > 60 then
        return format(FORMAT_MINUTES, remaining/60)
    elseif remaining > 10 then
        return format(FORMAT_SECONDS, remaining)
    else
        return format(FORMAT_DECIMAL, remaining)
    end
end

-- Function to create or get cooldown icon
local function GetCooldownIcon(id, isItem)
    local key = GetCooldownKey(id, isItem)
    if not activeCooldowns[key] then
        local icon = CreateFrame("Frame", nil, LCT.frame)
        icon:SetSize(LCT.iconSize, LCT.iconSize)
        
        -- Create cooldown texture
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        
        -- Get the correct texture
        local texture
        if isItem then
            if IsBagItem(id) then
                -- Bag item: use actual itemID to get icon
                local actualItemID = GetActualItemID(id)
                texture = GetItemIcon(actualItemID)
            else
                -- Equipped item: get texture from inventory slot
                texture = GetInventoryItemTexture("player", id)
            end
        else
            texture = GetSpellTexture(id)
        end
        
        if not texture then
            LCT:Debug("No texture found for", isItem and "item" or "spell", id)
            return nil
        end
        
        icon.texture:SetTexture(texture)
        
        -- Create cooldown model
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints()
        icon.cooldown:SetDrawEdge(false) 
        icon.cooldown:SetDrawSwipe(false)
        
        -- Create time text
        icon.timeText = icon:CreateFontString(nil, "OVERLAY")
        icon.timeText:SetFontObject("GameFontNormalSmall")
        icon.timeText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 2)
        icon.timeText:SetShown(LCT.showTimeText)
        
        activeCooldowns[key] = icon
        LCT:Debug("Created new icon for", isItem and "item slot" or "spell", id, "key:", key)
    end
    
    return activeCooldowns[key]
end

-- Helper: Update a single icon's position and text
local function UpdateIconPosition(key, info, currentTime)
    local icon = activeCooldowns[key]
    if not icon then return false end
    
    local remaining = (info.start + info.duration) - currentTime
    
    if remaining <= 0 then
        if icon:IsVisible() then
            if LCT.animations and LCT.animations.StartFinishAnimation then
                LCT.animations.StartFinishAnimation(icon)
            else
                icon:Hide()
            end
        end
        return false -- Request removal from active list
    end
    
    -- Calculate position with non-linear scaling (square root)
    local effectiveRemaining = min(remaining, LCT.maxTime)
    local width = LCT.frame:GetWidth()
    local iconSize = LCT.iconSize
    
    local timeRatio = effectiveRemaining / LCT.maxTime
    local scale = sqrt(timeRatio)
    local xPos = scale * (width - iconSize) + (iconSize/2)
    
    -- Direct position update
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", LCT.frame, "LEFT", xPos, 0)
    
    -- Z-index
    local baseLevel = LCT.frame:GetFrameLevel() + 1
    local zIndex = baseLevel + floor(LCT.maxTime - effectiveRemaining)
    icon:SetFrameLevel(zIndex)
    
    icon:Show()
    icon.timeText:SetText(FormatTimeText(remaining))
    
    return true -- Keep in active list
end

-- Performance: OnUpdate handler
local lastGlobalUpdate = 0
local function OnUpdateHandler(self, elapsed)
    local currentTime = GetTime()
    
    -- Optimization: Only full update every 0.1s, unless items are in critical range (< 5s)
    local doFullUpdate = false
    if currentTime - lastGlobalUpdate >= 0.1 then
        doFullUpdate = true
        lastGlobalUpdate = currentTime
    end
    
    local hasActive = false
    
    for key, info in pairs(activeCooldownList) do
        local remaining = (info.start + info.duration) - currentTime
        
        -- Update if in critical window (last 5s) OR it's time for a full update
        if remaining <= 5 or doFullUpdate then
             local isActive = UpdateIconPosition(key, info, currentTime)
             if isActive then 
                 hasActive = true 
             else 
                 activeCooldownList[key] = nil 
             end
        else
             hasActive = true -- Still active, just waiting for throttle
        end
    end
    
    if not hasActive then
        cooldowns.StopUpdating()
    end
end

-- Performance: Start the OnUpdate timer
function cooldowns.StartUpdating()
    if not isUpdating and cooldownEventFrame then
        isUpdating = true
        cooldownEventFrame:SetScript("OnUpdate", OnUpdateHandler)
        LCT:Debug("Cooldown updates STARTED")
    end
end

-- Performance: Stop the OnUpdate timer
function cooldowns.StopUpdating()
    if isUpdating and cooldownEventFrame then
        isUpdating = false
        cooldownEventFrame:SetScript("OnUpdate", nil)
        LCT:Debug("Cooldown updates STOPPED (idle)")
    end
end

-- Function to update a cooldown (Lightweight: Logic only)
function cooldowns.UpdateCooldown(id, isItem)
    if not id then return end
    
    local start, duration, enabled
    local key = GetCooldownKey(id, isItem)
    
    if isItem then
        if IsBagItem(id) then
            local actualItemID = GetActualItemID(id)
            start, duration, enabled = GetBagItemCooldown(actualItemID)
            if not start or not duration then
                if activeCooldownList[key] then
                    -- Keep cached info if item temporarily missing but known
                    local info = activeCooldownList[key]
                    start = info.start
                    duration = info.duration
                    enabled = 1
                else
                    if activeCooldowns[key] then activeCooldowns[key]:Hide() end
                    return
                end
            end
        else
            start, duration, enabled = GetInventoryItemCooldown("player", id)
            if not start or not duration then return end
        end
        
        if (start == 0 and duration == 0) or enabled == 0 then
            -- Cooldown cleared
            if activeCooldowns[key] then activeCooldowns[key]:Hide() end
            activeCooldownList[key] = nil
            return
        end
    else
        start, duration, enabled = GetSpellCooldown(id)
        if not start or enabled == 0 then return end
    end
    
    local icon = GetCooldownIcon(id, isItem)
    if not icon then return end
    
    if start > 0 and duration > 5 then -- Only track cooldowns longer than five seconds
        -- Add/Update to active cooldown list
        activeCooldownList[key] = {
            id = id,
            start = start,
            duration = duration,
            isItem = isItem
        }
        
        local currentTime = GetTime()
        local remaining = (start + duration) - currentTime
        
        if remaining > 0 then
             -- Force initial update
             UpdateIconPosition(key, activeCooldownList[key], currentTime)
             
             if icon.cooldown then
                icon.cooldown:SetCooldown(start, duration)
             end
             
             cooldowns.StartUpdating()
        end
    else
        -- Cooldown finished or too short
        if activeCooldownList[key] then
            local icon = activeCooldowns[key]
            if icon and icon:IsVisible() then
                 if LCT.animations and LCT.animations.StartFinishAnimation then
                     LCT.animations.StartFinishAnimation(icon)
                 else
                     icon:Hide()
                 end
            else
                 activeCooldowns[key]:Hide()
            end
            activeCooldownList[key] = nil
        else
             if icon then icon:Hide() end
        end
    end
end
function cooldowns.UpdateAll()
    for spellID in pairs(trackedSpells) do
        cooldowns.UpdateCooldown(spellID, false)
    end
    for itemID in pairs(trackedItems) do
        cooldowns.UpdateCooldown(itemID, true)
    end
end

-- Function to check if a cooldown is currently active
function cooldowns.HasActiveCooldown(id, isItem)
    local key = GetCooldownKey(id, isItem)
    return activeCooldownList[key] ~= nil
end

-- Function to register a spell
function cooldowns.RegisterSpell(spellID)
    if not spellID then return end
    trackedSpells[spellID] = true
    local name = GetSpellInfo(spellID)
    LCT:Debug("Registered spell:", spellID, name)
end

-- Function to unregister a spell
function cooldowns.UnregisterSpell(spellID)
    trackedSpells[spellID] = nil
    LCT:Debug("Unregistering spell:", spellID)
    local key = GetCooldownKey(spellID, false)
    if activeCooldowns[key] then
        local icon = activeCooldowns[key]
        -- Don't hide if animation is finishing
        local isFinishing = LCT.animations and LCT.animations.IsFinishing and LCT.animations.IsFinishing(icon)
        
        if not isFinishing then
            icon:Hide()
        else
            LCT:Debug("UnregisterSpell deferred hide for animation")
        end
        activeCooldowns[key] = nil
    end
    activeCooldownList[key] = nil
end

-- Function to register an item
function cooldowns.RegisterItem(itemID)
    if not itemID then return end
    trackedItems[itemID] = true
    local name = GetItemInfo(itemID)
    LCT:Debug("Registered item:", itemID, name)
end

-- Function to unregister an item
function cooldowns.UnregisterItem(itemID)
    trackedItems[itemID] = nil
    LCT:Debug("Unregistering item:", itemID)
    local key = GetCooldownKey(itemID, true)
    if activeCooldowns[key] then
        local icon = activeCooldowns[key]
        -- Don't hide if animation is finishing
        local isFinishing = LCT.animations and LCT.animations.IsFinishing and LCT.animations.IsFinishing(icon)
        
        if not isFinishing then
            icon:Hide()
        else
            LCT:Debug("UnregisterItem deferred hide for animation")
        end
        activeCooldowns[key] = nil
    end
    activeCooldownList[key] = nil
end

-- Initialize cooldown tracking
function cooldowns.Initialize()
    LCT:Debug("Initializing cooldown tracking")
    
    -- Create event frame for cooldown updates
    cooldownEventFrame = CreateFrame("Frame")
    cooldownEventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    cooldownEventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    cooldownEventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    cooldownEventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    cooldownEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    -- Performance: OnUpdate is NOT set here - it only activates when cooldowns are tracked
    -- This is controlled by StartUpdating() / StopUpdating()
    
    cooldownEventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "SPELL_UPDATE_COOLDOWN" or 
           event == "ACTIONBAR_UPDATE_COOLDOWN" or
           event == "BAG_UPDATE_COOLDOWN" then
            cooldowns.UpdateAll()
        elseif event == "ITEM_LOCK_CHANGED" then
            local bagOrSlot, slot = ...
            -- If it's an equipped item (slot is nil)
            if not slot and bagOrSlot >= 13 and bagOrSlot <= 14 then
                cooldowns.UpdateCooldown(bagOrSlot, true)
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            if unit == "player" and trackedSpells[spellID] then
                -- Force an immediate update for this spell
                cooldowns.UpdateCooldown(spellID, false)
            end
        end
    end)
    
    -- Initial check after a short delay
    C_Timer.After(0.5, cooldowns.UpdateAll)
    
    LCT:Debug("Cooldown tracking initialized (OnUpdate disabled until cooldowns active)")
end

-- Return the module
return cooldowns 