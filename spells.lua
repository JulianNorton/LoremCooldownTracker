local addonName, LCT = ...

-- Spell tracking module
local spells = {}
LCT.spells = spells

spells.nameToCanonicalSpellID = {}
spells.canonicalSpells = {}
spells.scanRetries = 0

-- Helper to find canonical spellID from spellID or spellName
function spells.GetCanonicalSpellID(spellID)
    if not spellID then return nil end
    local name = LCT.compat.GetSpellName(spellID)
    if name then
        local canonical = spells.nameToCanonicalSpellID[name:lower()]
        if canonical then return canonical end
    end
    return spellID
end

-- Function to scan spellbook and build list of trackable spells
function spells.ScanSpellBook()
    LCT:Debug("Scanning spellbook...")
    local _, playerClass = UnitClass("player")
    LCT:Debug("Player class:", playerClass)
    
    local rawCandidates = {} -- list of { spellID = ..., name = ..., rank = ... }

    local function AddCandidate(spellID, spellName, rankNum)
        if not spellID or type(spellID) ~= "number" then return end
        if not spellName or spellName == "" then
            spellName = LCT.compat.GetSpellName(spellID)
        end
        if not spellName or spellName == "" then return end
        rankNum = rankNum or 0
        rawCandidates[#rawCandidates + 1] = {
            spellID = spellID,
            name = spellName,
            rank = rankNum,
        }
    end

    -- Path 1: Action Bar slots 1 to 180 (covers standard bars and ElvUI extended bars)
    if GetActionInfo then
        for slot = 1, 180 do
            local actionType, id, subType = GetActionInfo(slot)
            if actionType == "spell" and id and type(id) == "number" then
                local spellName = LCT.compat.GetSpellName(id)
                local subName = (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)) or ""
                local rankNum = tonumber(subName:match("(%d+)")) or 0
                AddCandidate(id, spellName, rankNum)
            elseif actionType == "macro" and id and type(id) == "number" then
                if GetMacroSpell then
                    local ret1, ret2, ret3 = GetMacroSpell(id)
                    local macroSpellID = (type(ret3) == "number" and ret3) or (type(ret1) == "number" and ret1)
                    local spellName = (type(ret1) == "string" and ret1 ~= "" and ret1) or (macroSpellID and LCT.compat.GetSpellName(macroSpellID))
                    if not macroSpellID and spellName and C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
                        macroSpellID = C_Spell.GetSpellIDForSpellIdentifier(spellName)
                    end
                    if macroSpellID and type(macroSpellID) == "number" then
                        local subName = (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(macroSpellID)) or ""
                        local rankNum = tonumber(subName:match("(%d+)")) or 0
                        AddCandidate(macroSpellID, spellName or LCT.compat.GetSpellName(macroSpellID), rankNum)
                    end
                end
            end
        end
    end
    
    -- Path 2: Modern C_SpellBook (WoW Forever 16001 / Modern clients)
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local numLines = (C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines()) or 10
        LCT:Debug("Scanning modern C_SpellBook skill lines:", numLines)
        
        for lineIdx = 1, numLines do
            local skillInfo = C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
            if skillInfo and skillInfo.numSpellBookItems then
                for offset = 1, skillInfo.numSpellBookItems do
                    local slotIndex = skillInfo.itemIndexOffset + offset
                    local itemInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, bank)
                    -- In Classic / WoW Forever, spells across all tabs (Arcane, Fire, Frost) are valid and usable
                    if itemInfo and not itemInfo.isPassive and itemInfo.spellID then
                        local spellID = itemInfo.spellID
                        local spellName = itemInfo.name or LCT.compat.GetSpellName(spellID)
                        local subName = itemInfo.subName or (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)) or ""
                        local rankNum = tonumber(subName:match("(%d+)")) or 0
                        AddCandidate(spellID, spellName, rankNum)
                    end
                end
            end
        end
    end

    -- Path 3: Legacy GetNumSpellTabs fallback (Classic Era / TBC / WotLK / Hybrid)
    if GetNumSpellTabs then
        local numTabs = GetNumSpellTabs()
        LCT:Debug("Scanning legacy spellbook tabs:", numTabs)
        
        for tabIndex = 1, numTabs do
            local tabName, _, offset, numSpells = GetSpellTabInfo(tabIndex)
            if offset and numSpells then
                for spellIndex = offset + 1, offset + numSpells do
                    local spellType, spellID = GetSpellBookItemInfo(spellIndex, "player")
                    if spellType == "SPELL" and spellID then
                        local spellName = (GetSpellBookItemName and GetSpellBookItemName(spellIndex, "player")) or LCT.compat.GetSpellName(spellID)
                        local subName = (GetSpellSubtext and GetSpellSubtext(spellIndex, "BOOKTYPE_SPELL")) or ""
                        local rankNum = tonumber(subName:match("(%d+)")) or 0
                        AddCandidate(spellID, spellName, rankNum)
                    end
                end
            end
        end
    end

    -- Path 4: Direct index fallback if no candidates found yet
    if #rawCandidates == 0 and GetSpellBookItemInfo then
        for i = 1, 500 do
            local spellType, spellID = GetSpellBookItemInfo(i, "player")
            if not spellType then break end
            if spellType == "SPELL" and spellID then
                local spellName = (GetSpellBookItemName and GetSpellBookItemName(i, "player")) or LCT.compat.GetSpellName(spellID)
                local subName = (GetSpellSubtext and GetSpellSubtext(i, "BOOKTYPE_SPELL")) or ""
                local rankNum = tonumber(subName:match("(%d+)")) or 0
                AddCandidate(spellID, spellName, rankNum)
            end
        end
    end

    -- Group and select highest rank per spell name to avoid duplicate tracker icons
    local bestByName = {}
    for _, item in ipairs(rawCandidates) do
        local key = item.name:lower()
        local existing = bestByName[key]
        if not existing or item.rank > existing.rank or (item.rank == existing.rank and item.spellID > existing.spellID) then
            bestByName[key] = item
        end
    end

    local count = 0
    for _ in pairs(bestByName) do
        count = count + 1
    end

    -- SAFETY: If no spells were found (e.g. spellbook not yet loaded at login),
    -- do NOT clear existing registered spells! Retry later instead.
    if count == 0 then
        LCT:Debug("Spellbook scan found 0 spells (data may not be ready yet)")
        spells.scanRetries = (spells.scanRetries or 0) + 1
        if spells.scanRetries <= 10 then
            C_Timer.After(1, spells.ScanSpellBook)
        end
        return spells.canonicalSpells
    end

    spells.scanRetries = 0

    local newCanonicalSpells = {}
    local nameToCanonical = {}

    for nameLower, best in pairs(bestByName) do
        local spellID = best.spellID
        local spellName = best.name
        nameToCanonical[nameLower] = spellID
        newCanonicalSpells[spellID] = true

        -- Register all canonical spells so UpdateAll() can check them when cooldowns trigger
        if LCT.cooldowns and LCT.cooldowns.RegisterSpell then
            LCT.cooldowns.RegisterSpell(spellID)
            LCT:Debug("Registered canonical spell:", spellName, "ID:", spellID)
        end
    end

    -- Unregister spells that were previously tracked but are no longer canonical/known
    -- ONLY do this when we have a valid non-empty scan!
    if LCT.cooldowns and LCT.cooldowns.UnregisterSpell then
        for oldSpellID in pairs(spells.canonicalSpells) do
            if not newCanonicalSpells[oldSpellID] then
                local isActive = LCT.cooldowns.HasActiveCooldown and LCT.cooldowns.HasActiveCooldown(oldSpellID, false)
                if not isActive then
                    LCT.cooldowns.UnregisterSpell(oldSpellID)
                end
            end
        end
    end

    spells.canonicalSpells = newCanonicalSpells
    spells.nameToCanonicalSpellID = nameToCanonical

    LCT:Debug("Spellbook scan complete - found", count, "canonical spells")

    -- Immediately trigger a cooldown update so any already-cooling spells display
    if LCT.cooldowns and LCT.cooldowns.UpdateAll then
        LCT.cooldowns.UpdateAll()
    end

    return newCanonicalSpells
end

local scanPending = false
function spells.RequestScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.1, function()
        scanPending = false
        spells.ScanSpellBook()
    end)
end

-- Initialize spell tracking
function spells.Initialize()
    LCT:Debug("Initializing spell tracking")
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        LCT:Debug("Spell event fired:", event)
        spells.RequestScan()
    end)
    
    -- Staged scans to ensure spellbook data is ready
    spells.ScanSpellBook()
    C_Timer.After(0.5, spells.ScanSpellBook)
    C_Timer.After(1.5, spells.ScanSpellBook)
    C_Timer.After(3.0, spells.ScanSpellBook)
end

return spells
