local addonName, LCT = ...

function LCT:Debug(...)
    if self.db and self.db.debug then
        print("LoremCT Debug:", ...)
    end
end

-- Saved settings (LoremCTDB) and their defaults
LCT.defaults = {
    barWidth = 420,
    barHeight = 23,
    iconSize = 24,
    burstScale = 1.5, -- finish pop: the icon grows to this multiple of its size (1 = fade only)
    locked = false,
    shown = true,
    bgOpacity = 0.5,
    showTimeText = true,
    showIcons = true,
    debug = false,
}
LCT.maxTime = 600 -- seconds covered by the bar; longer cooldowns wait at the right edge

----------------------------------------------------------------------------------------
-- Client compatibility. The same call exists under different names across clients, and
-- on modern ones a value can be "secret" (unreadable by addons), which must be checked
-- before it is compared or used.
----------------------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue
local function IsReadable(val)
    return not (issecretvalue and issecretvalue(val))
end

-- The value if an addon may read it and it is not empty, otherwise nil
local function Usable(val)
    if IsReadable(val) and val and val ~= "" then
        return val
    end
end

LCT.compat = { IsReadable = IsReadable }

function LCT.compat.GetSpellName(spellID)
    if not spellID then return nil end
    local name = C_Spell and C_Spell.GetSpellName and Usable(C_Spell.GetSpellName(spellID))
    if not name and C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        name = info and Usable(info.name)
    end
    return name or (_G.GetSpellInfo and Usable((_G.GetSpellInfo(spellID)))) or nil
end

function LCT.compat.GetSpellTexture(spellID)
    if not spellID then return nil end
    local texture = C_Spell and C_Spell.GetSpellTexture and Usable((C_Spell.GetSpellTexture(spellID)))
    if not texture and C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        texture = info and Usable(info.iconID)
    end
    return texture or (_G.GetSpellTexture and Usable((_G.GetSpellTexture(spellID)))) or nil
end

-- Base cooldown in milliseconds, or nil
function LCT.compat.GetSpellBaseCooldown(spellID)
    if not spellID then return nil end
    local function Try(get)
        if not get then return nil end
        local ok, cd = pcall(get, spellID)
        if ok and IsReadable(cd) and type(cd) == "number" then return cd end
    end
    return Try(_G.GetSpellBaseCooldown) or Try(C_Spell and C_Spell.GetSpellBaseCooldown)
end

function LCT.compat.GetItemIcon(itemID)
    if not itemID then return nil end
    return (C_Item and C_Item.GetItemIconByID and Usable(C_Item.GetItemIconByID(itemID)))
        or (_G.GetItemIcon and Usable(_G.GetItemIcon(itemID)))
        or nil
end

-- Returns start, duration, enabled, isOnGCD, or nil when nothing is readable.
function LCT.compat.GetSpellCooldown(spellID)
    if not spellID then return nil, nil, nil, nil end

    local cStart, cDuration, cEnabled, cIsOnGCD

    -- Try modern C_Spell.GetSpellCooldown first (Forever 16001 / Modern)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            cEnabled = IsReadable(info.isEnabled) and (info.isEnabled == true or info.isEnabled == 1) or false
            cStart = IsReadable(info.startTime) and type(info.startTime) == "number" and info.startTime or nil
            cDuration = IsReadable(info.duration) and type(info.duration) == "number" and info.duration or nil
            cIsOnGCD = IsReadable(info.isOnGCD) and (info.isOnGCD == true) or false

            -- If duration is missing, or is only reporting GCD (<= 5s), check non-GCD duration
            if (not cStart or not cDuration or cDuration <= 5 or cIsOnGCD) and C_Spell.GetSpellCooldownDuration then
                local durObj = C_Spell.GetSpellCooldownDuration(spellID, true)
                if durObj then
                    if durObj.GetRemainingDuration then
                        local ok, rem = pcall(durObj.GetRemainingDuration, durObj)
                        if ok and IsReadable(rem) and type(rem) == "number" and rem > 5 then
                            cStart = GetTime()
                            cDuration = rem
                            cEnabled = true
                            cIsOnGCD = false
                        end
                    end
                    if (not cDuration or cDuration <= 5) and durObj.GetTotalDuration then
                        local ok, tot = pcall(durObj.GetTotalDuration, durObj)
                        if ok and IsReadable(tot) and type(tot) == "number" and tot > 5 then
                            cStart = GetTime()
                            cDuration = tot
                            cEnabled = true
                            cIsOnGCD = false
                        end
                    end
                end
            end

            -- If we have a genuine non-GCD cooldown (> 5s), return it immediately
            if cStart and cDuration and cDuration > 5 then
                return cStart, cDuration, cEnabled, false
            end
        end
    end

    -- Legacy fallback / check _G.GetSpellCooldown
    if _G.GetSpellCooldown then
        local start, duration, enabled = _G.GetSpellCooldown(spellID)
        if IsReadable(start) and IsReadable(duration) and type(start) == "number" and type(duration) == "number" then
            local isEnabled = (enabled == 1 or enabled == true)
            -- If legacy reports a real cooldown (> 5s), prefer it over GCD
            if duration > 5 then
                return start, duration, isEnabled, false
            end
            -- If C_Spell didn't find anything, or legacy has a positive duration while C_Spell has 0
            if not cStart then
                cStart = start
                cDuration = duration
                cEnabled = isEnabled
                cIsOnGCD = false
            elseif cDuration == 0 and duration > 0 then
                return start, duration, isEnabled, false
            end
        end
    end

    if cStart and cDuration then
        return cStart, cDuration, cEnabled, cIsOnGCD
    end

    return nil, nil, nil, nil
end

----------------------------------------------------------------------------------------
-- The bar frame
----------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "LoremCTFrame", UIParent)
LCT.frame = frame
frame:SetSize(LCT.defaults.barWidth, LCT.defaults.barHeight)
frame:SetPoint("CENTER")
frame:SetMovable(true)

frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints()
frame.bg:SetColorTexture(0, 0, 0, 0.5)

-- Drag to move. A locked bar has its mouse disabled, so these never fire for it.
frame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self:StartMoving()
    end
end)
frame:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    LCT.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end)

-- Push every saved setting to the screen. Called at login and after any change.
function LCT:Apply()
    local db = self.db
    frame:SetSize(db.barWidth, db.barHeight)
    frame:EnableMouse(not db.locked)
    frame:SetShown(db.shown)
    frame.bg:SetAlpha(db.bgOpacity)
    self.bar.Refresh()
    self.settings.Refresh()
end

local function LoadSettings()
    LoremCTDB = LoremCTDB or {}
    local db = LoremCTDB

    -- Up to 2.5 the settings sat in these two sub-tables. Copy them up once. They are left
    -- in place so that an older version of the addon still finds its settings.
    for _, old in ipairs({ "dimensions", "visibility" }) do
        if type(db[old]) == "table" then
            for key, value in pairs(db[old]) do
                if db[key] == nil then db[key] = value end
            end
        end
    end
    for key, value in pairs(LCT.defaults) do
        if db[key] == nil then db[key] = value end
    end
    LCT.db = db

    local pos = db.position
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    LoadSettings()

    -- Each module starts on its own, so a failure in one is reported in chat and cannot
    -- stop the other. (An unknown event once silently took out most of the addon.)
    for _, module in ipairs({ "tracker", "settings" }) do
        local ok, err = pcall(LCT[module].Initialize)
        if not ok then
            print("|cffff5555LoremCT:|r " .. module .. " failed to start: " .. tostring(err))
        end
    end
    LCT:Apply()
end)

SLASH_LCT1 = "/lct"
SlashCmdList["LCT"] = function(msg)
    local db = LCT.db
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "scan" then
        LCT.tracker.ScanSpells()
        print("LoremCT: Rescanned spellbook")
    elseif msg == "lock" then
        db.locked = not db.locked
        print("LoremCT: Frame " .. (db.locked and "locked (click-through)" or "unlocked (draggable)"))
    elseif msg == "toggle" then
        db.shown = not db.shown
        print("LoremCT: Frame " .. (db.shown and "shown" or "hidden"))
    elseif msg == "debug" then
        db.debug = not db.debug
        print("LoremCT: Debug mode " .. (db.debug and "enabled" or "disabled"))
    elseif msg == "test" then
        LCT.bar.Preview()
    else
        LCT.settings.Toggle()
        return
    end
    LCT:Apply()
end
