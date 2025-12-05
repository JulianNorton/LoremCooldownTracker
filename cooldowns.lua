local addonName, LCT = ...

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

-- Helper: Generate unique key for cooldown (prevents spell/item ID collision)
local function GetCooldownKey(id, isItem)
    return (isItem and "item_" or "spell_") .. id
end

-- Function to format time text
local function FormatTimeText(remaining)
    if remaining > 60 then
        return string.format("%.0fm", remaining/60)
    elseif remaining > 10 then
        return string.format("%.0f", remaining)
    else
        return string.format("%.1f", remaining)
    end
end

-- Performance: OnUpdate handler (defined here, set in Initialize)
local function OnUpdateHandler(self, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed >= 0.1 then
        local hasActive = false
        for key, info in pairs(activeCooldownList) do
            hasActive = true
            -- Use info.id (the actual spell/item ID), not key (which is prefixed like "spell_100")
            cooldowns.UpdateCooldown(info.id, info.isItem)
        end
        updateElapsed = 0
        
        -- Performance: Stop updating if no active cooldowns
        if not hasActive then
            cooldowns.StopUpdating()
        end
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
            -- For equipped items, get the item texture from the inventory slot
            texture = GetInventoryItemTexture("player", id)
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
        icon.cooldown:SetDrawEdge(true)
        icon.cooldown:SetDrawSwipe(true)
        
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

-- Function to update a cooldown
function cooldowns.UpdateCooldown(id, isItem)
    if not id then return end
    
    local start, duration, enabled
    local key = GetCooldownKey(id, isItem)
    
    if isItem then
        start, duration, enabled = GetInventoryItemCooldown("player", id)
        if not start or not duration then return end
        
        -- Only update if there's an actual cooldown or if we need to hide the icon
        if (start == 0 and duration == 0) or enabled == 0 then
            if activeCooldowns[key] then
                activeCooldowns[key]:Hide()
                activeCooldownList[key] = nil -- Remove from active tracking
            end
            return
        end
    else
        start, duration, enabled = GetSpellCooldown(id)
        if not start or enabled == 0 then return end
    end
    
    local icon = GetCooldownIcon(id, isItem)
    if not icon then return end
    
    if start > 0 and duration > 5 then -- Only track cooldowns longer than five seconds
        local currentTime = GetTime()
        local remaining = (start + duration) - currentTime
        
        if remaining <= 0 then
            if icon:IsVisible() then
                if LCT.animations and LCT.animations.StartFinishAnimation then
                    LCT.animations.StartFinishAnimation(icon)
                else
                    icon:Hide()
                end
                activeCooldownList[key] = nil -- Remove from active tracking
            end
            return
        end
        
        -- Add to active cooldown list if not already there
        if not activeCooldownList[key] then
            activeCooldownList[key] = {
                id = id,
                start = start,
                duration = duration,
                isItem = isItem
            }
            -- Performance: Start updating when first cooldown is added
            cooldowns.StartUpdating()
        end
        
        -- Calculate position
        local width = LCT.frame:GetWidth()
        local iconSize = LCT.iconSize
        
        -- Clamp remaining time to maxTime (default 300s = 5min)
        remaining = math.min(remaining, LCT.maxTime)
        
        -- Calculate the actual position
        local xPos = (remaining / LCT.maxTime) * (width - iconSize) + (iconSize/2)
        
        -- Direct position update (updates every 0.1s for smooth movement)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", LCT.frame, "LEFT", xPos, 0)
        icon:Show()
        
        -- Update cooldown swipe
        if icon.cooldown then
            icon.cooldown:SetCooldown(start, duration)
        end
        
        -- Update time text
        icon.timeText:SetText(FormatTimeText(remaining))
    else
        if LCT.animations and LCT.animations.CancelAnimation then
            LCT.animations.CancelAnimation(icon)
        end
        icon:Hide()
        activeCooldownList[key] = nil -- Remove from active tracking
    end
end

-- Function to update all cooldowns
function cooldowns.UpdateAll()
    for spellID in pairs(trackedSpells) do
        cooldowns.UpdateCooldown(spellID, false)
    end
    for itemID in pairs(trackedItems) do
        cooldowns.UpdateCooldown(itemID, true)
    end
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
    local key = GetCooldownKey(spellID, false)
    if activeCooldowns[key] then
        activeCooldowns[key]:Hide()
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
    local key = GetCooldownKey(itemID, true)
    if activeCooldowns[key] then
        activeCooldowns[key]:Hide()
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