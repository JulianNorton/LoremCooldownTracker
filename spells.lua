local addonName, LCT = ...

-- Spell tracking module
local spells = {}
LCT.spells = spells

-- Function to scan spellbook and build list of trackable spells
function spells.ScanSpellBook()
    LCT:Debug("Scanning spellbook...")
    local _, playerClass = UnitClass("player")
    LCT:Debug("Player class:", playerClass)
    local trackedSpells = {}
    local count = 0
    
    -- Scan all spellbook tabs
    local numTabs = GetNumSpellTabs()
    LCT:Debug("Found", numTabs, "spellbook tabs")
    
    for tabIndex = 1, numTabs do
        local tabName, _, offset, numSpells = GetSpellTabInfo(tabIndex)
        LCT:Debug("Scanning tab", tabIndex, tabName, "with", numSpells, "spells")
        
        -- Scan all spells in current tab
        for spellIndex = offset + 1, offset + numSpells do
            local spellType, spellID = GetSpellBookItemInfo(spellIndex, "player")
            local spellName = GetSpellBookItemName(spellIndex, "player")
            
            if spellType == "SPELL" and spellID then
                -- Try GetSpellBaseCooldown first, fall back to checking actual cooldown
                local cooldown = GetSpellBaseCooldown and GetSpellBaseCooldown(spellID)
                
                -- TBC PTR fallback: if GetSpellBaseCooldown returns nil, check actual cooldown
                if not cooldown then
                    local start, duration = GetSpellCooldown(spellID)
                    if duration and duration > 0 then
                        cooldown = duration * 1000 -- Convert to milliseconds
                    end
                end
                
                LCT:Debug("Found spell:", spellName, "ID:", spellID, "Cooldown:", cooldown and cooldown/1000 or "nil")
                
                -- Only track spells with cooldowns > 5s (filters GCD)
                if cooldown and cooldown > 5000 then
                    trackedSpells[spellID] = true
                    -- Register the spell with the cooldowns module
                    if LCT.cooldowns and LCT.cooldowns.RegisterSpell then
                        LCT.cooldowns.RegisterSpell(spellID)
                        count = count + 1
                        LCT:Debug("Registered spell:", spellName, "with", cooldown/1000, "second cooldown")
                    else
                        LCT:Debug("ERROR - Could not register spell, cooldowns module not ready")
                    end
                end
            end
        end
    end
    
    -- NOTE: No hardcoded spells - the spellbook scan handles everything dynamically
    -- This makes the addon work across all WoW versions (Classic, TBC, WotLK)
    
    LCT:Debug("Found", count, "spells with cooldowns")
    return trackedSpells
end

-- Initialize spell tracking
function spells.Initialize()
    LCT:Debug("Initializing spell tracking")
    
    -- Create a separate frame for spell events
    local eventFrame = CreateFrame("Frame")
    
    -- Register spell-related events
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Set up event handler
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        LCT:Debug("Spell event fired:", event)
        if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            LCT:Debug("Rescanning spellbook...")
            spells.ScanSpellBook()
        end
    end)
    
    -- Perform initial scan
    -- Using a small delay to ensure spellbook data is ready on TBC PTR
    C_Timer.After(2, function()
        LCT:Debug("Executing initial spell scan")
        spells.ScanSpellBook()
    end)
end

-- Return the module
return spells 