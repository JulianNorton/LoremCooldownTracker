local _, LCT = ...

-- The settings panel and the minimap button. Every control edits one key of LCT.db and
-- then calls LCT:Apply(), which is the only place settings are pushed to the screen.
local settings = {}
LCT.settings = settings

local panel
local refreshers = {} -- one function per control: copies its value from the db into the control
local refreshing = false
local sliderCount = 0
local y = -36 -- where the next control goes, measured down from the top of the panel

local function Changed(key, value)
    if refreshing then return end -- the control is being set from the db, not by the user
    LCT.db[key] = value
    LCT:Apply()
end

local function Place(region, height)
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
    y = y - height
end

local function Header(text)
    y = y - 8
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetText(text)
    Place(header, 24)
end

local function Check(key, text)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check.label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    check.label:SetPoint("LEFT", check, "RIGHT", 0, 1)
    check.label:SetText(text)
    check:SetScript("OnClick", function(self)
        Changed(key, not not self:GetChecked())
    end)
    refreshers[#refreshers + 1] = function(db)
        check:SetChecked(db[key])
    end
    Place(check, 34)
end

-- scale converts the saved value to the slider's: 100 shows a 0-1 setting as a percentage
local function Slider(key, text, minValue, maxValue, scale)
    scale = scale or 1
    sliderCount = sliderCount + 1
    local name = "LoremCTSlider" .. sliderCount -- older clients find the labels by global name
    local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    for suffix, label in pairs({ Low = minValue, High = maxValue, Text = text }) do
        local region = slider[suffix] or _G[name .. suffix]
        if region then region:SetText(label) end
    end

    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(50, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetPoint("LEFT", slider, "RIGHT", 10, 0)

    local function Set(value)
        value = math.floor(math.max(minValue, math.min(maxValue, value)) + 0.5)
        box:SetText(value)
        Changed(key, value / scale)
    end
    slider:SetScript("OnValueChanged", function(_, value)
        Set(value)
    end)
    box:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then Set(value) end
        self:ClearFocus()
    end)
    refreshers[#refreshers + 1] = function(db)
        local value = math.floor(db[key] * scale + 0.5)
        slider:SetValue(value)
        box:SetText(value)
    end

    y = y - 16 -- room for the slider's title above it
    Place(slider, 34)
    return box
end

local function Button(text, width, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreatePanel()
    panel = CreateFrame("Frame", "LoremCTSettings", UIParent, "BasicFrameTemplateWithInset")
    panel:SetWidth(300)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()
    if panel.TitleText then
        panel.TitleText:SetText("Lorem Cooldown Tracker")
    end

    Check("locked", "Lock Frame")
    Slider("barWidth", "Bar Width", 100, 1000)
    Slider("barHeight", "Bar Height", 10, 100)
    Slider("iconSize", "Icon Size", 8, 64)
    local burstBox = Slider("burstScale", "Finish Burst Size (%)", 100, 400, 100)
    Button("Test", 48, LCT.bar.Preview):SetPoint("LEFT", burstBox, "RIGHT", 6, 0)

    Header("Visibility Options")
    Check("shown", "Show Timeline")
    Slider("bgOpacity", "Background Opacity (%)", 0, 100, 100)
    Check("showTimeText", "Show Time Text")
    Check("showIcons", "Show Icons")

    Header("Advanced")
    Check("debug", "Debug Mode")
    y = y - 4
    Place(Button("Scan Spellbook", 120, function()
        LCT.tracker.ScanSpells()
        print("LoremCT: Rescanned spellbook")
    end), 22)

    panel:SetHeight(20 - y)
end

-- Copy the saved settings into the controls
function settings.Refresh()
    if not panel then return end
    refreshing = true
    for _, refresh in ipairs(refreshers) do
        refresh(LCT.db)
    end
    refreshing = false
end

function settings.Toggle()
    if panel then
        panel:SetShown(not panel:IsShown())
    end
end

function settings.Initialize()
    -- Minimap button first, so it is there even if the panel cannot be built
    local launcher = LibStub("LibDataBroker-1.1"):NewDataObject("LoremCT", {
        type = "launcher",
        icon = "Interface\\Icons\\Spell_Nature_TimeStop",
        OnClick = function(_, button)
            if button == "LeftButton" then
                settings.Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Lorem Cooldown Tracker")
            tooltip:AddLine("Click to open settings", 1, 1, 1)
        end,
    })
    LCT.db.minimap = LCT.db.minimap or { minimapPos = 45 }
    local minimapIcon = LibStub("LibDBIcon-1.0")
    if not minimapIcon:IsRegistered("LoremCT") then
        minimapIcon:Register("LoremCT", launcher, LCT.db.minimap)
    end

    CreatePanel()
end
