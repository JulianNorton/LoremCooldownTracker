local _, LCT = ...

local GetTime, pairs, ipairs, next = GetTime, pairs, ipairs, next
local compat, bar = LCT.compat, LCT.bar

-- C_Container on modern clients, globals on legacy ones
local C_Container = C_Container
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetContainerItemCooldown = (C_Container and C_Container.GetContainerItemCooldown) or _G.GetContainerItemCooldown

local MIN_DURATION = 5 -- seconds; anything shorter is the GCD or not worth showing
local CAST_RETRY_DELAYS = { 0.05, 0.15, 0.35, 0.75 }
local LAST_BAG = NUM_BAG_SLOTS or 4
local MAX_SCAN_RETRIES = 10

-- Finds what is on cooldown (known spells, equipped items, bag items) and tells the bar.
local tracker = {}
LCT.tracker = tracker

local spellIDByName = {} -- lowercased name -> highest-rank spell ID; ranks share one cooldown
local trackedSpells = {} -- [spellID] = true
local confirmed = {}     -- [spellID] = true once the API itself has reported the running timer
local bagTimers = {}     -- [itemID] = true for bag items with a timer on the bar
local inBags = {}        -- scratch: item IDs seen in the current bag pass
local scanRetries = 0

local function IsRunning(start, duration)
    return start and duration and start > 0 and duration > MIN_DURATION
end

----------------------------------------------------------------------------------------
-- Spells
----------------------------------------------------------------------------------------
local function RefreshSpell(id)
    local key = "spell_" .. id
    local start, duration, _, isOnGCD = compat.GetSpellCooldown(id)
    if not isOnGCD and IsRunning(start, duration) then
        confirmed[id] = true
        bar.Start(key, compat.GetSpellTexture(id), start, duration)
    elseif duration == 0 and confirmed[id] then
        -- The API reported this cooldown earlier and now reports none: it finished or was reset
        confirmed[id] = nil
        bar.Stop(key)
    end
    -- Otherwise the API shows only the GCD, or nothing readable, or has never reported a
    -- timer that was started from the base cooldown. A running timer is left to finish.
end

local RefreshItems -- defined under Items

function tracker.Refresh()
    for id in pairs(trackedSpells) do
        RefreshSpell(id)
    end
    RefreshItems()
end

-- Cooldown events arrive in bursts; one pass on the next frame covers them all
local refreshQueued = false
local function RunQueuedRefresh()
    refreshQueued = false
    tracker.Refresh()
end
local function QueueRefresh()
    if not refreshQueued then
        refreshQueued = true
        C_Timer.After(0, RunQueuedRefresh)
    end
end

local function OnCast(event, unit, arg2, arg3)
    local spellID = (type(arg3) == "number" and arg3) or (type(arg2) == "number" and arg2)
    if not spellID and type(arg2) == "string" and C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
        spellID = C_Spell.GetSpellIDForSpellIdentifier(arg2)
    end
    if unit ~= "player" or not spellID or not compat.IsReadable(spellID) then return end

    -- Track the highest known rank: lower ranks share its cooldown
    local name = compat.GetSpellName(spellID)
    local id = name and spellIDByName[name:lower()]
    if not id then
        -- Not in the spellbook. Item use-spells end up here, and their items are tracked
        -- directly, so only accept spells the client says the player knows. Before the
        -- first spellbook scan there is nothing to compare against, so accept anything.
        local known = (IsSpellKnown and IsSpellKnown(spellID)) or (IsPlayerSpell and IsPlayerSpell(spellID))
        if next(spellIDByName) and not known then return end
        id = spellID
    end
    trackedSpells[id] = true
    LCT:Debug("Cast", event, spellID, name, "tracked as", id)

    -- Right after a cast the API can still report only the GCD. If the spell has a real base
    -- cooldown, start its timer now; the refreshes below replace it with the API's values.
    -- Not on UNIT_SPELLCAST_START: cast-time spells start their cooldown on completion, and
    -- a cancelled cast would leave a phantom timer. Channels start theirs immediately.
    if event ~= "UNIT_SPELLCAST_START" then
        local base = compat.GetSpellBaseCooldown(id) or (spellID ~= id and compat.GetSpellBaseCooldown(spellID))
        if type(base) == "number" and base > MIN_DURATION * 1000
            and not IsRunning(compat.GetSpellCooldown(id)) then
            confirmed[id] = nil
            bar.Start("spell_" .. id, compat.GetSpellTexture(id), GetTime(), base / 1000)
        end
    end

    local function Refresh()
        RefreshSpell(id)
    end
    Refresh()
    for _, delay in ipairs(CAST_RETRY_DELAYS) do
        C_Timer.After(delay, Refresh)
    end
end

-- Builds the list of spells to watch from the action bars and the spellbook
function tracker.ScanSpells()
    local best = {} -- [lowercased name] = { id, rank }: the highest rank seen of each spell
    local found = 0

    local function Add(id, name, subtext)
        if type(id) ~= "number" then return end
        if not name or name == "" then
            name = compat.GetSpellName(id)
        end
        if not name then return end
        local rank = tonumber((subtext or ""):match("%d+")) or 0
        local key = name:lower()
        local current = best[key]
        if not current then
            found = found + 1
        end
        if not current or rank > current.rank or (rank == current.rank and id > current.id) then
            best[key] = { id = id, rank = rank }
        end
    end

    local Subtext = C_Spell and C_Spell.GetSpellSubtext

    -- Action bars, including the extra bars ElvUI and others use
    if GetActionInfo then
        for slot = 1, 180 do
            local actionType, id = GetActionInfo(slot)
            if type(id) == "number" then
                if actionType == "spell" then
                    Add(id, nil, Subtext and Subtext(id))
                elseif actionType == "macro" and GetMacroSpell then
                    -- Older clients return name, rank, id; newer ones return the id first
                    local ret1, _, ret3 = GetMacroSpell(id)
                    local macroSpell = (type(ret3) == "number" and ret3) or (type(ret1) == "number" and ret1)
                    local macroName = type(ret1) == "string" and ret1 ~= "" and ret1 or nil
                    if not macroSpell and macroName and C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
                        macroSpell = C_Spell.GetSpellIDForSpellIdentifier(macroName)
                    end
                    if type(macroSpell) == "number" then
                        Add(macroSpell, macroName, Subtext and Subtext(macroSpell))
                    end
                end
            end
        end
    end

    -- Spellbook, modern API
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and C_SpellBook.GetSpellBookSkillLineInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local lines = (C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines()) or 10
        for line = 1, lines do
            local skill = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if skill and skill.numSpellBookItems then
                for offset = 1, skill.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(skill.itemIndexOffset + offset, bank)
                    if item and not item.isPassive and item.spellID then
                        Add(item.spellID, item.name, item.subName or (Subtext and Subtext(item.spellID)))
                    end
                end
            end
        end
    end

    -- Spellbook, legacy API
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            if offset and count then
                for index = offset + 1, offset + count do
                    local itemType, id = GetSpellBookItemInfo(index, "player")
                    if itemType == "SPELL" and id then
                        Add(id, GetSpellBookItemName and GetSpellBookItemName(index, "player"),
                            GetSpellSubtext and GetSpellSubtext(index, "BOOKTYPE_SPELL"))
                    end
                end
            end
        end
    end

    -- Nothing found means the spellbook is not loaded yet. Keep what we have and try again.
    if found == 0 then
        scanRetries = scanRetries + 1
        if scanRetries <= MAX_SCAN_RETRIES then
            C_Timer.After(1, tracker.ScanSpells)
        end
        return
    end
    scanRetries = 0

    local known = {}
    spellIDByName = {}
    for name, spell in pairs(best) do
        spellIDByName[name] = spell.id
        known[spell.id] = true
        trackedSpells[spell.id] = true
    end
    -- Drop spells that are no longer known, unless their cooldown is still on the bar
    for id in pairs(trackedSpells) do
        if not known[id] and not bar.Get("spell_" .. id) then
            trackedSpells[id] = nil
            confirmed[id] = nil
        end
    end
    LCT:Debug("Spell scan found", found, "spells")
    QueueRefresh()
end

local scanQueued = false
local function RunQueuedScan()
    scanQueued = false
    tracker.ScanSpells()
end
local function QueueScan()
    if not scanQueued then
        scanQueued = true
        C_Timer.After(0.5, RunQueuedScan)
    end
end

----------------------------------------------------------------------------------------
-- Items
----------------------------------------------------------------------------------------
-- An item cooldown that disappears early means the item was unequipped or moved, not
-- that it finished, so it goes without the pop.
local function StopItem(key)
    local info = bar.Get(key)
    bar.Stop(key, info ~= nil and info.start + info.duration - GetTime() > 1)
end

RefreshItems = function()
    local IsReadable = compat.IsReadable

    for slot = 1, 19 do
        local start, duration, enable = GetInventoryItemCooldown("player", slot)
        if IsReadable(start) and IsReadable(duration) and IsReadable(enable) then
            local key = "slot_" .. slot
            if IsRunning(start, duration) and (enable == 1 or enable == true) then
                bar.Start(key, GetInventoryItemTexture("player", slot), start, duration)
            else
                StopItem(key)
            end
        end
    end

    -- One pass over the bags. Stacks of the same item share a cooldown, so the first
    -- slot of each item is enough.
    wipe(inBags)
    for bag = 0, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local itemID = GetContainerItemID(bag, slot)
            if IsReadable(itemID) and itemID and not inBags[itemID] then
                inBags[itemID] = true
                local start, duration, enable = GetContainerItemCooldown(bag, slot)
                if IsReadable(start) and IsReadable(duration) and IsReadable(enable) then
                    if IsRunning(start, duration) and (enable == 1 or enable == true) then
                        bagTimers[itemID] = true
                        bar.Start("bag_" .. itemID, compat.GetItemIcon(itemID), start, duration)
                    elseif bagTimers[itemID] then
                        bagTimers[itemID] = nil
                        StopItem("bag_" .. itemID)
                    end
                end
            end
        end
    end
    -- An item that left the bags (the last one was used) keeps its timer until it runs out
    for itemID in pairs(bagTimers) do
        if not bar.Get("bag_" .. itemID) then
            bagTimers[itemID] = nil
        end
    end
end

----------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------
function tracker.Initialize()
    local frame = CreateFrame("Frame")
    local handlers = {}

    local function On(events, handler)
        for _, event in ipairs(events) do
            -- Not every client has every event, and registering an unknown one throws
            if pcall(frame.RegisterEvent, frame, event) then
                handlers[event] = handlers[event] or {}
                table.insert(handlers[event], handler)
            end
        end
    end

    On({ "SPELLS_CHANGED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
         "ACTIONBAR_SLOT_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE" }, QueueScan)
    On({ "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED",
         "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
         "PLAYER_REGEN_DISABLED" }, QueueRefresh)
    On({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_START" }, OnCast)

    frame:SetScript("OnEvent", function(_, event, ...)
        for _, handler in ipairs(handlers[event]) do
            handler(event, ...)
        end
    end)

    QueueScan()
    C_Timer.After(3, tracker.Refresh) -- cooldown data can arrive late after login
end
