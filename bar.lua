local _, LCT = ...

local GetTime, pairs, ipairs, next = GetTime, pairs, ipairs, next
local floor, min, max, sqrt, format = math.floor, math.min, math.max, math.sqrt, string.format

-- What is drawn on the bar: the time markers, one icon per running cooldown, and the
-- pop an icon makes when its cooldown finishes.
local bar = {}
LCT.bar = bar

-- seconds, height as a fraction of the bar, alpha, label
local MARKERS = {
    { 0, 0.5, 0.3 },
    { 10, 0.3, 0.2, "10s" },
    { 30, 0.4, 0.25 },
    { 60, 0.5, 0.3, "1m" },
    { 300, 0.4, 0.25, "5m" },
    { 600, 0.5, 0.3, "10m" },
}
local GROW, FADE = 0.3, 0.15 -- seconds: the finish pop grows, then fades
local PREVIEW_ICON = "Interface\\Icons\\Spell_Nature_TimeStop"

local markers = {}   -- textures, in MARKERS order
local icons = {}     -- [key] = icon frame, created once and reused
local active = {}    -- [key] = { start, duration } for every cooldown on the bar
local finishing = {} -- [icon] = time its pop started
bar.markers, bar.icons, bar.finishing = markers, icons, finishing

-- Not the bar itself: timers must keep running while the bar is hidden
local driver = CreateFrame("Frame")
local updating, lastFullUpdate = false, 0
local OnUpdate

-- Square-root scale, so the last seconds get the most room
local function TimeToX(seconds)
    local db = LCT.db
    return sqrt(min(seconds, LCT.maxTime) / LCT.maxTime) * (db.barWidth - db.iconSize) + db.iconSize / 2
end

local function FormatTime(remaining)
    if remaining > 60 then
        return format("%.0fm", remaining / 60)
    elseif remaining > 10 then
        return format("%.0f", remaining)
    end
    return format("%.1f", remaining)
end

local function LayoutMarkers()
    local frame, db = LCT.frame, LCT.db
    for i, def in ipairs(MARKERS) do
        local marker = markers[i]
        if not marker then
            marker = frame:CreateTexture(nil, "ARTWORK")
            marker:SetColorTexture(1, 1, 1, def[3])
            if def[4] then
                marker.label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                marker.label:SetText(def[4])
                marker.label:SetTextColor(1, 1, 1, 0.3)
                marker.label:SetPoint("BOTTOM", marker, "TOP", 0, 1)
            end
            markers[i] = marker
        end
        marker:SetSize(1, db.barHeight * def[2])
        marker:ClearAllPoints()
        marker:SetPoint("TOP", frame, "TOPLEFT", TimeToX(def[1]), 0)
        if marker.label then
            marker.label:SetShown(db.showTimeText)
        end
    end
end

local function GetIcon(key, texture)
    local icon = icons[key]
    if not icon then
        if not texture then return nil end
        icon = CreateFrame("Frame", nil, LCT.frame)
        icon:SetSize(LCT.db.iconSize, LCT.db.iconSize)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()

        -- Only here for the end-of-cooldown flash; swipe and numbers are off, and
        -- noCooldownCount keeps ElvUI and OmniCC from adding their own text.
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints()
        icon.cooldown:SetDrawEdge(false)
        icon.cooldown:SetDrawSwipe(false)
        if icon.cooldown.SetHideCountdownNumbers then
            icon.cooldown:SetHideCountdownNumbers(true)
        end
        icon.cooldown.noCooldownCount = true

        icon.timeText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.timeText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 2)
        icons[key] = icon
    end
    if texture then
        icon.texture:SetTexture(texture)
    end
    return icon
end

local function StartUpdating()
    if not updating then
        updating = true
        driver:SetScript("OnUpdate", OnUpdate)
    end
end

-- Take a cooldown off the bar. It pops if it was running and visible, unless silent.
function bar.Stop(key, silent)
    local wasActive = active[key] ~= nil
    active[key] = nil
    local icon = icons[key]
    if not icon or finishing[icon] then return end
    if wasActive and not silent and icon:IsVisible() then
        finishing[icon] = GetTime()
        icon.timeText:Hide()
        StartUpdating()
    else
        icon:Hide()
    end
end

local function EndPop(icon)
    finishing[icon] = nil
    icon:SetSize(LCT.db.iconSize, LCT.db.iconSize)
    icon:SetAlpha(1)
end

local function Place(key, info, now)
    local remaining = info.start + info.duration - now
    if remaining <= 0 then
        return bar.Stop(key)
    end
    local icon, db = icons[key], LCT.db
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", LCT.frame, "LEFT", TimeToX(remaining), 0)
    -- Icons closer to finishing draw on top
    local elapsedShare = floor((LCT.maxTime - min(remaining, LCT.maxTime)) / 3)
    icon:SetFrameLevel(max(1, LCT.frame:GetFrameLevel() + 1 + elapsedShare))
    icon:SetShown(db.showIcons)
    icon.timeText:SetShown(db.showTimeText)
    icon.timeText:SetText(FormatTime(remaining))
end

OnUpdate = function(self)
    local now = GetTime()

    -- Full pass ten times a second; icons in their last five seconds move every frame
    local fullUpdate = now - lastFullUpdate >= 0.1
    if fullUpdate then
        lastFullUpdate = now
    end
    for key, info in pairs(active) do
        if fullUpdate or info.start + info.duration - now <= 5 then
            Place(key, info, now)
        end
    end

    -- Finish pops. They grow by size, not SetScale: scale would also multiply the icon's
    -- x-offset and slide it sideways.
    local size, burst = LCT.db.iconSize, LCT.db.burstScale
    for icon, started in pairs(finishing) do
        local t = now - started
        if t >= GROW + FADE then
            EndPop(icon)
            icon:Hide()
        else
            local p = min(t / GROW, 1)
            local grown = size * (1 + (burst - 1) * (1 - (1 - p) * (1 - p)))
            icon:SetSize(grown, grown)
            icon:SetAlpha(t < GROW and 1 or 1 - (t - GROW) / FADE)
        end
    end

    if not next(active) and not next(finishing) then
        updating = false
        self:SetScript("OnUpdate", nil)
    end
end

-- Put a cooldown on the bar, or update one that is already there
function bar.Start(key, texture, start, duration)
    local now = GetTime()
    if start + duration <= now then
        return bar.Stop(key)
    end
    local icon = GetIcon(key, texture)
    if not icon then return end

    local info = active[key]
    if not info then
        info = {}
        active[key] = info
    end
    if info.start ~= start or info.duration ~= duration then
        info.start, info.duration = start, duration
        icon.cooldown:SetCooldown(start, duration)
    end
    if finishing[icon] then
        EndPop(icon) -- restarted during its own pop
    end
    Place(key, info, now)
    StartUpdating()
end

-- The running timer for key ({ start, duration }), or nil
function bar.Get(key)
    return active[key]
end

-- Re-apply size, visibility and marker settings to everything on the bar
function bar.Refresh()
    LayoutMarkers()
    local now, size = GetTime(), LCT.db.iconSize
    for key, icon in pairs(icons) do
        if not finishing[icon] then
            icon:SetSize(size, size)
            if active[key] then
                Place(key, active[key], now)
            else
                icon:Hide()
            end
        end
    end
end

-- A three-second sample cooldown, for trying out the burst size
function bar.Preview()
    bar.Start("preview", PREVIEW_ICON, GetTime(), 3)
end
