-- Offline smoke test: loads the addon against a minimal mocked WoW API.
-- It checks the addon's own logic. It cannot tell whether a real client behaves like the mock,
-- so a release still needs a reload in game.
--
-- Run from the addon folder with Lua 5.1:  lua tests/offline.lua
-- Exits 0 when every check passes.
local ADDON = arg[1] or "."
local now, frames, timers, failures = 100, {}, {}, 0
local function check(cond, msg)
    if cond then print("  ok   " .. msg) else failures = failures + 1; print("  FAIL " .. msg) end
end

local MISSING_EVENTS = { LEARNED_SPELL_IN_TAB = true } -- this client lacks it
local METHOD = { Set = 1, Get = 1, Is = 1, Enable = 1, Clear = 1, Start = 1, Stop = 1, Register = 1, Refresh = 1, Add = 1, Unregister = 1 }
local Frame = {}
Frame.__index = function(t, k)
    if Frame[k] then return Frame[k] end
    if type(k) == "string" and METHOD[k:match("^%u%l+") or ""] then return function() end end
end
local function new(parent, ftype, name)
    local f = setmetatable({ shown = true, parent = parent, ftype = ftype, name = name, w = 0, h = 0, alpha = 1, scripts = {}, events = {} }, Frame)
    frames[#frames + 1] = f
    return f
end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:GetWidth() return self.w end
function Frame:GetHeight() return self.h end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(s) self.shown = not not s end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetAlpha() return self.alpha end
function Frame:EnableMouse(v) self.mouse = v end
function Frame:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
function Frame:GetPoint() local p = self.point or {}; return p[1], p[2], p[3], p[4], p[5] end
function Frame:GetFrameLevel() return 1 end
function Frame:SetScript(n, fn) self.scripts[n] = fn end
function Frame:RegisterEvent(e)
    if MISSING_EVENTS[e] then error("Attempt to register unknown event " .. e) end
    self.events[e] = true
end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:CreateTexture() return new(self, "Texture") end
function Frame:CreateFontString() return new(self, "FontString") end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:GetChecked() return self.checked end
function Frame:SetChecked(c) self.checked = c end
function Frame:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
function Frame:IsRegistered() return false end
function Frame:NewDataObject(_, t) return t end

UIParent = new(nil, "Frame", "UIParent")
function CreateFrame(ftype, name, parent) return new(parent, ftype, name) end
function GetTime() return now end
C_Timer = { After = function(d, fn) timers[#timers + 1] = { at = now + d, fn = fn } end }
SlashCmdList = {}
LibStub = function() return new() end
NUM_BAG_SLOTS = 4
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

-- Game state the tests drive
local spellCD, slotCD, bags = {}, {}, {}
local spellNames = { [100] = "Frost Nova", [101] = "Frost Nova", [200] = "Evocation", [300] = "Blink", [900] = "Trinket Use" }
local baseCD = { [100] = 25000, [101] = 25000, [200] = 480000, [300] = 15000, [900] = 120000 }
local book = { 100, 101, 200, 300 }
local ranks = { "Rank 1", "Rank 2" }
function GetSpellInfo(id) return spellNames[id] end
function GetSpellTexture(id) return spellNames[id] and ("tex" .. id) end
function GetSpellBaseCooldown(id) return baseCD[id] or 0 end
function GetSpellCooldown(id) local c = spellCD[id]; if c then return c[1], c[2], 1 end return 0, 0, 1 end
function IsSpellKnown(id) for _, known in ipairs(book) do if known == id then return true end end return false end
function GetInventoryItemCooldown(_, slot) local c = slotCD[slot]; if c then return c[1], c[2], 1 end return 0, 0, 1 end
function GetInventoryItemTexture(_, slot) return "slot" .. slot end
function GetItemIcon(id) return "item" .. id end
function GetContainerNumSlots(bag) return bag == 0 and #bags or 0 end
function GetContainerItemID(_, slot) return bags[slot] and bags[slot].id end
function GetContainerItemCooldown(_, slot) local b = bags[slot]; return b.start or 0, b.duration or 0, 1 end
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return "Frost", nil, 0, #book end
function GetSpellBookItemInfo(i) if book[i] then return "SPELL", book[i] end end
function GetSpellBookItemName(i) return spellNames[book[i]] end
function GetSpellSubtext(i) return ranks[i] or "" end

-- Saved variables exactly as the 2.5 layout wrote them
LoremCTDB = {
    dimensions = { iconSize = 30, barHeight = 23.00000381469727, locked = false, barWidth = 766.0000610351562 },
    visibility = { bgOpacity = 0.549, shown = true, showTimeText = true, showIcons = true,
        position = { y = 103, x = 366, point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT" } },
    minimap = { minimapPos = 45 },
}

local function fire(event, ...)
    for i = 1, #frames do
        local f = frames[i]
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
local function tick(seconds)
    local stop = now + seconds
    while now < stop - 1e-9 do
        now = now + 0.02
        for i = #timers, 1, -1 do
            if timers[i] and timers[i].at <= now then local t = table.remove(timers, i); t.fn() end
        end
        for i = 1, #frames do
            local f = frames[i]
            if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.02) end
        end
    end
end

local realPrint, printed = print, {}
print = function(...) printed[#printed + 1] = tostring((...)); realPrint(...) end

local LCT = {}
for _, file in ipairs({ "core", "bar", "tracker", "settings" }) do
    assert(loadfile(ADDON .. "/" .. file .. ".lua"))("LoremCooldownTracker", LCT)
end
local bar = LCT.bar
local icons, finishing = bar.icons, bar.finishing
local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", id) end

print("startup")
fire("ADDON_LOADED", "SomeOtherAddon")
check(LCT.db == nil, "ignores other addons loading")
fire("ADDON_LOADED", "LoremCooldownTracker"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD")
tick(4)
local db = LCT.db
local startFail = false
for _, s in ipairs(printed) do if s:find("failed to start") then startFail = true end end
check(not startFail, "both modules start on a client without LEARNED_SPELL_IN_TAB")
check(math.floor(LCT.frame.w) == 766 and db.iconSize == 30, "settings saved by 2.5 are applied")
check(LCT.frame.point[1] == "BOTTOMLEFT" and LCT.frame.point[4] == 366, "saved position restored")
check(LoremCTDB.dimensions.barWidth == 766.0000610351562, "2.5 settings left in place for rollback")
check(db.burstScale == 1.5, "new setting gets its default")
local size = db.iconSize

print("spell cooldown, then pop")
spellCD[101] = { now, 8 }; fire("SPELL_UPDATE_COOLDOWN"); fire("ACTIONBAR_UPDATE_COOLDOWN"); tick(0.04)
local nova = icons["spell_101"]
check(nova and nova:IsShown(), "highest-rank Frost Nova icon shown")
check(icons["spell_100"] == nil, "no second icon for rank 1")
tick(7.5); check(nova:IsShown() and nova.w == size, "still running at 7.5s")
spellCD[101] = nil; tick(0.6)
check(finishing[nova], "pop running just after expiry")
fire("SPELL_UPDATE_COOLDOWN"); fire("BAG_UPDATE_COOLDOWN"); tick(0.04)
check(nova:IsShown() and finishing[nova], "cooldown events during the pop do not hide it")
local peak = nova.w
tick(0.14); if nova.w > peak then peak = nova.w end
check(math.abs(peak - size * db.burstScale) < size * 0.2, ("pop peaks near burst size (%.1f of %.1f)"):format(peak, size * db.burstScale))
tick(0.5)
check(not nova:IsShown() and nova.w == size and nova.alpha == 1, "hidden and reset after the pop")

print("burst size setting")
db.burstScale = 3; SlashCmdList.LCT("test"); tick(3.28)
local pv = icons["preview"]
check(pv.w > size * 2.5, ("preview grows toward 3x (%.1f of %.1f)"):format(pv.w, size * 3))
check(pv.point[4] < size, "pop stays at the left end (no sideways slide)")
tick(1); check(not pv:IsShown() and pv.w == size, "preview hidden and reset")
db.burstScale = 1; bar.Preview(); tick(3.2)
check(pv.w == size, "burst 100% does not grow"); tick(1)
db.burstScale = 1.5

print("casts")
cast(100); tick(0.04)
check(icons["spell_101"]:IsShown() and icons["spell_100"] == nil, "rank 1 cast shows one icon, under the highest rank")
check(math.abs(bar.Get("spell_101").duration - 25) < 0.01, "timer starts from the base cooldown before the API reports it")
cast(900); tick(1)
check(icons["spell_900"] == nil, "an item's use-spell does not get its own icon")
cast(200); tick(0.04)
fire("SPELL_UPDATE_COOLDOWN"); tick(2)
check(bar.Get("spell_200") ~= nil, "a timer the API never reports keeps running (Evocation)")

print("API-confirmed cooldowns")
spellCD[300] = { now, 15 }; fire("SPELL_UPDATE_COOLDOWN"); tick(0.1)
local blink = icons["spell_300"]
spellCD[300] = { now, 1.5 }; fire("SPELL_UPDATE_COOLDOWN"); tick(0.1)
check(bar.Get("spell_300") and bar.Get("spell_300").duration == 15, "a GCD-only report does not disturb a running timer")
tick(3); spellCD[300] = nil; fire("SPELL_UPDATE_COOLDOWN"); tick(0.04)
check(bar.Get("spell_300") == nil and finishing[blink], "a reset cooldown pops straight away instead of running on")
tick(1)

print("equipped item")
slotCD[13] = { now, 20 }; fire("BAG_UPDATE_COOLDOWN"); tick(0.04)
local trinket = icons["slot_13"]
check(trinket and trinket:IsShown(), "trinket in slot 13 tracked")
tick(19.9); slotCD[13] = nil; fire("BAG_UPDATE_COOLDOWN"); tick(0.2)
check(finishing[trinket], "item pops when its cooldown ends"); tick(1)
slotCD[13] = { now, 20 }; fire("BAG_UPDATE_COOLDOWN"); tick(5)
slotCD[13] = nil; fire("PLAYER_EQUIPMENT_CHANGED"); tick(0.04)
check(not trinket:IsShown() and not finishing[trinket], "unequipped mid-cooldown: hidden without a pop")

print("bag item")
bags[1] = { id = 7000 }; fire("BAG_UPDATE_COOLDOWN")
bags[1].start, bags[1].duration = now, 30; fire("BAG_UPDATE_COOLDOWN"); tick(0.04)
check(icons["bag_7000"] and icons["bag_7000"]:IsShown(), "two bag events in a row: the later state is not dropped")
table.remove(bags, 1); fire("BAG_UPDATE_DELAYED"); tick(0.04)
check(bar.Get("bag_7000") ~= nil, "last one used: timer keeps running")

print("bar hidden")
spellCD[300] = { now, 6 }; fire("SPELL_UPDATE_COOLDOWN"); tick(0.1)
SlashCmdList.LCT("toggle"); check(not LCT.frame:IsShown() and db.shown == false, "/lct toggle hides and saves")
tick(6.5); spellCD[300] = nil
SlashCmdList.LCT("toggle"); tick(0.04)
check(LCT.frame:IsShown() and not blink:IsShown() and not finishing[blink], "no frozen or late-popping icon when shown again")

print("settings panel")
local sliders, checks = {}, {}
for _, f in ipairs(frames) do
    if f.ftype == "Slider" then sliders[#sliders + 1] = f elseif f.ftype == "CheckButton" then checks[#checks + 1] = f end
end
check(#sliders == 5 and #checks == 5, "five sliders and five checkboxes")
check(sliders[1].value == 766 and sliders[4].value == 150 and sliders[5].value == 55, "controls show the saved values")
sliders[1]:SetValue(600)
check(db.barWidth == 600 and LCT.frame.w == 600, "width slider resizes the bar and saves")
check(math.abs(bar.markers[6].point[4] - (600 - db.iconSize / 2)) < 0.01, "10m marker follows the new width")
sliders[3]:SetValue(40)
check(db.iconSize == 40 and icons["spell_200"].w == 40, "icon size slider resizes icons on the bar")
check(math.abs(bar.markers[6].point[4] - 580) < 0.01, "markers follow the icon size")
sliders[4]:SetValue(250); check(db.burstScale == 2.5, "burst slider saves as a multiple")
checks[3].checked = false; checks[3].scripts.OnClick(checks[3])
check(db.showTimeText == false and not bar.markers[2].label:IsShown() and not icons["spell_200"].timeText:IsShown(), "time text toggle hides labels and icon text")
SlashCmdList.LCT("lock"); check(db.locked and LCT.frame.mouse == false and checks[1].checked == true, "/lct lock makes the bar click-through and ticks the box")

print(failures == 0 and "\nALL PASSED" or ("\n" .. failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
