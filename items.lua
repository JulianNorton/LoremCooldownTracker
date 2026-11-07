local addonName, LCT = ...

-- Performance: Cache global functions with API compatibility
-- Detect modern C_Container API (Dragonflight/Classic Era 1.15+) vs Legacy Globals
local C_Container = C_Container
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetContainerItemCooldown = (C_Container and C_Container.GetContainerItemCooldown) or _G.GetContainerItemCooldown
local GetContainerItemInfo = (C_Container and C_Container.GetContainerItemInfo) or _G.GetContainerItemInfo

-- Other globals
local GetInventoryItemID = GetInventoryItemID
local pairs = pairs
local ipairs = ipairs

-- Item tracking module
local items = {}
LCT.items = items

-- Constants
-- All equipment slots that could have cooldowns (1-19)
local EQUIPMENT_SLOTS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19}
local MIN_COOLDOWN_DURATION = 5  -- Only track cooldowns > 5 seconds
local BAG_SCAN_THROTTLE = 0.5    -- Minimum seconds between bag scans

-- Bag item tracking
local trackedBagItems = {}       -- [itemID] = true
local lastBagScanTime = 0        -- Throttle bag scanning

-- Function to clean up unequipped items
local function CleanupEquippedItems()
    if not LCT.cooldowns or not LCT.cooldowns.trackedItems then
        LCT:Debug("ERROR - Cannot cleanup equipped items, cooldowns module not initialized")
        return
    end

    -- Unregister any positive slot IDs that no longer have an item equipped
    for slotID in pairs(LCT.cooldowns.trackedItems) do
        if slotID > 0 then
            local currentItemID = GetInventoryItemID("player", slotID)
            if not currentItemID then
                LCT.cooldowns.UnregisterItem(slotID)
                LCT:Debug("Cleaned up unequipped slot:", slotID)
            end
        end
    end
end

-- Function to check equipment slots and register them for tracking
local function UpdateEquippedItems()
    if not LCT.cooldowns or not LCT.cooldowns.RegisterItem then
        LCT:Debug("ERROR - Cannot update equipped items, cooldowns module not initialized")
        return
    end

    -- Clean up old entries first
    CleanupEquippedItems()

    -- Check all equipment slots
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            -- Register the slot number for cooldown tracking
            LCT.cooldowns.RegisterItem(slot)
            local itemName = LCT.compat.GetItemName(itemID)
            LCT:Debug("Registered equipped item in slot", slot, ":", itemName, "(ID:", itemID, ")")
            
            -- If cooldown module is active, update cooldown check
            if LCT.cooldowns.UpdateCooldown then
                LCT.cooldowns.UpdateCooldown(slot, true)
            end
        end
    end
end

-- Function to register a bag item for tracking
local function RegisterBagItem(itemID)
    if not LCT.cooldowns then return end
    
    local trackingKey = -itemID
    
    if not trackedBagItems[itemID] then
        trackedBagItems[itemID] = true
        LCT.cooldowns.RegisterItem(trackingKey)
        local itemName = LCT.compat.GetItemName(itemID)
        LCT:Debug("Registered bag item for tracking:", itemName, "(ID:", itemID, ")")
        if LCT.cooldowns.UpdateCooldown then
            LCT.cooldowns.UpdateCooldown(trackingKey, true)
        end
    end
end

-- Function to unregister a bag item
local function UnregisterBagItem(itemID)
    if not LCT.cooldowns then return end
    
    local trackingKey = -itemID
    
    if trackedBagItems[itemID] then
        trackedBagItems[itemID] = nil
        LCT.cooldowns.UnregisterItem(trackingKey)
        local itemName = LCT.compat.GetItemName(itemID)
        LCT:Debug("Unregistered bag item:", itemName, "(ID:", itemID, ")")
    end
end

-- Function to scan bags for items with active cooldowns
-- Performance: Throttled to avoid excessive scanning
local function ScanBagItemCooldowns()
    if not LCT.cooldowns then return end
    
    local now = GetTime()
    
    -- Performance: Throttle scans
    if now - lastBagScanTime < BAG_SCAN_THROTTLE then
        return
    end
    lastBagScanTime = now
    
    LCT:Debug("Scanning bags for item cooldowns...")
    
    -- Track which items we found with active cooldowns this scan
    local foundItems = {}
    
    -- Scan all bags (0 = backpack, 1-4 = bags)
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local start, duration, enable = GetContainerItemCooldown(bagID, slotID)
                
                if LCT.compat.IsReadable(start) and LCT.compat.IsReadable(duration) and LCT.compat.IsReadable(enable) then
                    local isEnabled = (enable == 1 or enable == true)
                    -- Check if item has an active cooldown > 5 seconds
                    if start and start > 0 and duration and duration > MIN_COOLDOWN_DURATION and isEnabled then
                        local itemID = GetContainerItemID(bagID, slotID)
                        
                        if itemID then
                            foundItems[itemID] = true
                            
                            -- Register if not already tracked
                            if not trackedBagItems[itemID] then
                                RegisterBagItem(itemID)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Clean up items that no longer have active cooldowns
    for itemID in pairs(trackedBagItems) do
        if not foundItems[itemID] then
            -- Check if it's currently on cooldown before removing
            local isActive = false
            if LCT.cooldowns and LCT.cooldowns.HasActiveCooldown then
                isActive = LCT.cooldowns.HasActiveCooldown(-itemID, true)
            end
            
            -- Only unregister if it's not currently tracking a valid cooldown
            if not isActive then
                UnregisterBagItem(itemID)
            else
                LCT:Debug("Item missing from bags but cooldown active, keeping:", itemID)
            end
        end
    end
end

-- Initialize item tracking
function items.Initialize()
    LCT:Debug("Initializing item tracking")
    
    -- Ensure cooldowns module is initialized
    if not LCT.cooldowns or not LCT.cooldowns.RegisterItem then
        LCT:Debug("ERROR - Cannot initialize items module, cooldowns module not ready")
        return
    end
    
    -- Create a separate frame for item events
    local eventFrame = CreateFrame("Frame")
    
    -- Register equipment change events
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    
    -- Register bag cooldown events
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    
    -- Set up event handler
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            local slot = ...
            if slot and slot >= 1 and slot <= 19 then
                LCT:Debug("Equipment slot changed:", slot)
                UpdateEquippedItems()
            end
        elseif event == "UNIT_INVENTORY_CHANGED" then
            local unit = ...
            if unit == "player" then
                LCT:Debug("Player inventory changed")
                UpdateEquippedItems()
            end
        elseif event == "BAG_UPDATE_COOLDOWN" then
            ScanBagItemCooldowns()
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            LCT:Debug("Player entered world/logged in")
            C_Timer.After(0.5, function()
                UpdateEquippedItems()
                ScanBagItemCooldowns()
            end)
        end
    end)
    
    -- Initial checks with a short delay
    C_Timer.After(1.5, function()
        LCT:Debug("Performing initial item check")
        UpdateEquippedItems()
        ScanBagItemCooldowns()
    end)
end

return items
