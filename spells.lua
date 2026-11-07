local addonName, LCT = ...

-- Spell tracking module
local spells = {}
LCT.spells = spells

spells.nameToCanonicalSpellID = {}
spells.canonicalSpells = {}

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
    
    -- Path A: Modern C_SpellBook (WoW Forever 16001 / Modern clients)
    if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local numLines = (C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines()) or 10
        LCT:Debug("Scanning modern C_SpellBook skill lines:", numLines)
        
        for lineIdx = 1, numLines do
            local skillInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
            if skillInfo and skillInfo.numSpellBookItems then
                for offset = 1, skillInfo.numSpellBookItems do
                    local slotIndex = skillInfo.itemIndexOffset + offset
                    local itemInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, bank)
                    if itemInfo and not itemInfo.isPassive and not itemInfo.isOffSpec and itemInfo.spellID then
                        local spellID = itemInfo.spellID
                        local spellName = itemInfo.name or LCT.compat.GetSpellName(spellID)
                        if spellName and spellName ~= "" then
                            local subName = itemInfo.subName or (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)) or ""
                            local rankNum = tonumber(subName:match("(%d+)")) or 0
                            rawCandidates[#rawCandidates + 1] = {
                                spellID = spellID,
                                name = spellName,
                                rank = rankNum,
                            }
                        end
                    end
                end
            end
        end
    -- Path B: Legacy GetNumSpellTabs fallback (Classic Era / TBC / WotLK)
    elseif GetNumSpellTabs then
        local numTabs = GetNumSpellTabs()
        LCT:Debug("Scanning legacy spellbook tabs:", numTabs)
        
        for tabIndex = 1, numTabs do
            local tabName, _, offset, numSpells = GetSpellTabInfo(tabIndex)
            for spellIndex = offset + 1, offset + numSpells do
                local spellType, spellID = GetSpellBookItemInfo(spellIndex, "player")
                if spellType == "SPELL" and spellID then
                    local spellName = (GetSpellBookItemName and GetSpellBookItemName(spellIndex, "player")) or LCT.compat.GetSpellName(spellID)
                    if spellName and spellName ~= "" then
                        local subName = (GetSpellSubtext and GetSpellSubtext(spellIndex, "BOOKTYPE_SPELL")) or ""
                        local rankNum = tonumber(subName:match("(%d+)")) or 0
                        rawCandidates[#rawCandidates + 1] = {
                            spellID = spellID,
                            name = spellName,
                            rank = rankNum,
                        }
                    end
                end
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

    local newCanonicalSpells = {}
    local nameToCanonical = {}
    local count = 0

    for nameLower, best in pairs(bestByName) do
        local spellID = best.spellID
        local spellName = best.name
        nameToCanonical[nameLower] = spellID

        -- Check base cooldown
        local cooldown = LCT.compat.GetSpellBaseCooldown(spellID)
        if not cooldown or cooldown <= 0 then
            local start, duration, enabled, isOnGCD = LCT.compat.GetSpellCooldown(spellID)
            if duration and duration > 0 and not isOnGCD then
                cooldown = duration * 1000
            end
        end

        LCT:Debug("Spell candidate:", spellName, "ID:", spellID, "Cooldown:", cooldown and (cooldown/1000) or "nil")

        -- Only track cooldowns > 5s (filters GCD)
        if cooldown and cooldown > 5000 then
            newCanonicalSpells[spellID] = true
            if LCT.cooldowns and LCT.cooldowns.RegisterSpell then
                LCT.cooldowns.RegisterSpell(spellID)
                count = count + 1
                LCT:Debug("Registered canonical spell:", spellName, "with", cooldown/1000, "second cooldown")
            end
        end
    end

    -- Unregister spells that were previously tracked but are no longer canonical/known
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

    LCT:Debug("Spellbook scan complete - found", count, "spells with cooldowns > 5s")
    return newCanonicalSpells
end

-- Initialize spell tracking
function spells.Initialize()
    LCT:Debug("Initializing spell tracking")
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        LCT:Debug("Spell event fired:", event)
        if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            LCT:Debug("Rescanning spellbook...")
            spells.ScanSpellBook()
        end
    end)
    
    -- Small delay to ensure spellbook data is ready
    C_Timer.After(1, function()
        LCT:Debug("Executing initial spell scan")
        spells.ScanSpellBook()
    end)
end

return spells
