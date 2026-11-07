local addonName, LCT = ...

-- Initialize settings namespace
LCT.settings = {}

local isRefreshing = false

-- Function to save dimension settings
local function SaveDimensionSettings()
    if not LoremCTDB then LoremCTDB = {} end
    if not LoremCTDB.dimensions then LoremCTDB.dimensions = {} end
    
    LoremCTDB.dimensions.barWidth = LCT.frame:GetWidth()
    LoremCTDB.dimensions.barHeight = LCT.frame:GetHeight()
    LoremCTDB.dimensions.iconSize = LCT.iconSize
    LoremCTDB.dimensions.locked = LCT.frame.locked
end
LCT.settings.SaveDimensionSettings = SaveDimensionSettings

-- Function to load dimension settings
local function LoadDimensionSettings()
    if not LoremCTDB then LoremCTDB = {} end
    if not LoremCTDB.dimensions then LoremCTDB.dimensions = {} end
    
    local settings = LoremCTDB.dimensions
    
    -- Apply settings with fallback to defaults
    local width = settings.barWidth or LCT.defaults.barWidth
    local height = settings.barHeight or LCT.defaults.barHeight
    local iconSize = settings.iconSize or LCT.defaults.iconSize
    local locked = settings.locked ~= nil and settings.locked or LCT.defaults.locked
    
    -- Apply the settings
    LCT.frame:SetWidth(width)
    LCT.frame:SetHeight(height)
    LCT.iconSize = iconSize
    LCT.frame.locked = locked
    LCT.frame:EnableMouse(not locked)
    
    -- Update existing cooldown icons size
    if LCT.activeCooldowns then
        for _, icon in pairs(LCT.activeCooldowns) do
            icon:SetSize(iconSize, iconSize)
        end
    end
    
    -- Update UI controls when settings frame exists
    if LCT.settings.UpdateDimensionControls then
        LCT.settings.UpdateDimensionControls()
    end
end
LCT.settings.LoadDimensionSettings = LoadDimensionSettings

-- Helper function to create input box (made accessible to visibility module)
function LCT.settings.CreateInputBox(parent, width, initialValue)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetText(initialValue)
    return box
end

local sliderCounter = 0
-- Helper function to create slider with input box
function LCT.settings.CreateSliderControl(parent, label, min, max, initialValue, callback)
    sliderCounter = sliderCounter + 1
    local sliderName = "LoremCTSlider_" .. sliderCounter
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(min, max)
    slider:SetValue(initialValue)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local low = slider.Low or _G[sliderName .. "Low"]
    local high = slider.High or _G[sliderName .. "High"]
    local text = slider.Text or _G[sliderName .. "Text"]
    if low then low:SetText(min) end
    if high then high:SetText(max) end
    if text then text:SetText(label) end

    local input = LCT.settings.CreateInputBox(parent, 50, tostring(initialValue))
    input:SetPoint("LEFT", slider, "RIGHT", 10, 0)

    slider:SetScript("OnValueChanged", function(self, value)
        input:SetText(math.floor(value))
        if not isRefreshing then
            callback(value)
        end
    end)

    input:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(min, math.min(max, value))
            slider:SetValue(value)
            self:SetText(value)
            if not isRefreshing then
                callback(value)
            end
        end
        self:ClearFocus()
    end)

    return slider, input
end

-- Create settings frame
local settingsFrame = CreateFrame("Frame", "LoremCTSettings", UIParent, "BasicFrameTemplateWithInset")
settingsFrame:SetSize(300, 600)
settingsFrame:SetPoint("CENTER")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
settingsFrame:Hide()

-- Set title
if settingsFrame.TitleText then
    settingsFrame.TitleText:SetText("Lorem Cooldown Tracker")
end

-- Create dimension controls
local dimensionControls = {}

-- Lock Frame Toggle
dimensionControls.lockButton = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
dimensionControls.lockButton:SetPoint("TOPLEFT", 20, -40)
dimensionControls.lockButton:SetScript("OnClick", function(self)
    LCT.frame.locked = self:GetChecked()
    LCT.frame:EnableMouse(not LCT.frame.locked)
    if not isRefreshing then
        SaveDimensionSettings()
    end
end)
dimensionControls.lockButton.text = dimensionControls.lockButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
dimensionControls.lockButton.text:SetPoint("LEFT", dimensionControls.lockButton, "RIGHT", 0, 1)
dimensionControls.lockButton.text:SetText("Lock Frame")

-- Bar Width Controls
dimensionControls.barWidthSlider, dimensionControls.barWidthInput = LCT.settings.CreateSliderControl(
    settingsFrame, "Bar Width", 100, 1000, 300, function(value)
        LCT.frame:SetWidth(value)
        SaveDimensionSettings()
    end
)
dimensionControls.barWidthSlider:SetPoint("TOPLEFT", dimensionControls.lockButton, "BOTTOMLEFT", 0, -30)

-- Bar Height Controls
dimensionControls.barHeightSlider, dimensionControls.barHeightInput = LCT.settings.CreateSliderControl(
    settingsFrame, "Bar Height", 10, 100, 30, function(value)
        LCT.frame:SetHeight(value)
        SaveDimensionSettings()
    end
)
dimensionControls.barHeightSlider:SetPoint("TOPLEFT", dimensionControls.barWidthSlider, "BOTTOMLEFT", 0, -30)

-- Icon Size Controls
dimensionControls.iconSizeSlider, dimensionControls.iconSizeInput = LCT.settings.CreateSliderControl(
    settingsFrame, "Icon Size", 8, 64, 24, function(value)
        LCT.iconSize = value
        -- Update existing cooldown icons
        if LCT.activeCooldowns then
            for _, icon in pairs(LCT.activeCooldowns) do
                icon:SetSize(value, value)
            end
        end
        SaveDimensionSettings()
    end
)
dimensionControls.iconSizeSlider:SetPoint("TOPLEFT", dimensionControls.barHeightSlider, "BOTTOMLEFT", 0, -30)

-- Create visibility controls
local visibilityControls = LCT.visibility.CreateControls(settingsFrame)
visibilityControls.header:SetPoint("TOPLEFT", dimensionControls.iconSizeSlider, "BOTTOMLEFT", 0, -30)
visibilityControls.showFrameButton:SetPoint("TOPLEFT", visibilityControls.header, "BOTTOMLEFT", 0, -10)
visibilityControls.bgOpacitySlider:SetPoint("TOPLEFT", visibilityControls.showFrameButton, "BOTTOMLEFT", 0, -30)
visibilityControls.showTimeTextButton:SetPoint("TOPLEFT", visibilityControls.bgOpacitySlider, "BOTTOMLEFT", 0, -20)
visibilityControls.showIconsButton:SetPoint("TOPLEFT", visibilityControls.showTimeTextButton, "BOTTOMLEFT", 0, -10)

-- Create advanced controls
local advancedControls = {}

-- Advanced header
advancedControls.header = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
advancedControls.header:SetText("Advanced")
advancedControls.header:SetPoint("TOPLEFT", visibilityControls.showIconsButton, "BOTTOMLEFT", 0, -20)

-- Debug mode toggle
advancedControls.debugButton = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
advancedControls.debugButton:SetPoint("TOPLEFT", advancedControls.header, "BOTTOMLEFT", 0, -10)
advancedControls.debugButton:SetScript("OnClick", function(self)
    LCT.debug = self:GetChecked()
    -- Save to database
    if not LoremCTDB then LoremCTDB = {} end
    LoremCTDB.debug = LCT.debug
    print("LoremCT: Debug mode", LCT.debug and "enabled" or "disabled")
end)
advancedControls.debugButton.text = advancedControls.debugButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
advancedControls.debugButton.text:SetPoint("LEFT", advancedControls.debugButton, "RIGHT", 0, 1)
advancedControls.debugButton.text:SetText("Debug Mode")

-- Scan spellbook button
advancedControls.scanButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
advancedControls.scanButton:SetSize(120, 25)
advancedControls.scanButton:SetPoint("TOPLEFT", advancedControls.debugButton, "BOTTOMLEFT", 0, -15)
advancedControls.scanButton:SetText("Scan Spellbook")
advancedControls.scanButton:SetScript("OnClick", function()
    if LCT.spells and LCT.spells.ScanSpellBook then
        LCT:Debug("Manual spell scan requested from settings UI")
        LCT.spells.ScanSpellBook()
        print("LoremCT: Rescanned spellbook")
    else
        print("LoremCT: Error - Could not scan spellbook")
    end
end)

-- Function to update dimension controls
function LCT.settings.UpdateDimensionControls()
    isRefreshing = true
    dimensionControls.lockButton:SetChecked(LCT.frame.locked)
    dimensionControls.barWidthSlider:SetValue(LCT.frame:GetWidth())
    dimensionControls.barWidthInput:SetText(math.floor(LCT.frame:GetWidth()))
    dimensionControls.barHeightSlider:SetValue(LCT.frame:GetHeight())
    dimensionControls.barHeightInput:SetText(math.floor(LCT.frame:GetHeight()))
    dimensionControls.iconSizeSlider:SetValue(LCT.iconSize)
    dimensionControls.iconSizeInput:SetText(math.floor(LCT.iconSize))
    isRefreshing = false
end

-- Function to update visibility controls
function LCT.settings.UpdateVisibilityControls()
    if LCT.visibility and LCT.visibility.SetRefreshing then
        LCT.visibility.SetRefreshing(true)
    end
    visibilityControls.showFrameButton:SetChecked(LCT.frame:IsShown())
    visibilityControls.bgOpacitySlider:SetValue(LCT.frame.bg:GetAlpha() * 100)
    visibilityControls.bgOpacityInput:SetText(math.floor(LCT.frame.bg:GetAlpha() * 100))
    visibilityControls.showTimeTextButton:SetChecked(LCT.visibility.showTimeText)
    visibilityControls.showIconsButton:SetChecked(LCT.visibility.showIcons)
    if LCT.visibility and LCT.visibility.SetRefreshing then
        LCT.visibility.SetRefreshing(false)
    end
end

-- Function to update advanced controls
function LCT.settings.UpdateAdvancedControls()
    advancedControls.debugButton:SetChecked(LCT.debug)
end

-- Create minimap icon data
local minimapIcon = LibStub("LibDataBroker-1.1"):NewDataObject("LoremCT", {
    type = "launcher",
    icon = "Interface\\Icons\\Spell_Nature_TimeStop",
    OnClick = function(self, button)
        if button == "LeftButton" then
            if settingsFrame:IsShown() then
                settingsFrame:Hide()
            else
                settingsFrame:Show()
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Lorem Cooldown Tracker")
        tooltip:AddLine("Click to open settings", 1, 1, 1)
    end,
})

local minimapButton = LibStub("LibDBIcon-1.0")

function LCT.settings.Initialize()
    LCT:Debug("Initializing settings module")
    if not LoremCTDB then LoremCTDB = {} end
    if not LoremCTDB.minimap then LoremCTDB.minimap = { minimapPos = 45 } end
    
    if not minimapButton:IsRegistered("LoremCT") then
        minimapButton:Register("LoremCT", minimapIcon, LoremCTDB.minimap)
    else
        minimapButton:Refresh("LoremCT", LoremCTDB.minimap)
    end
    
    LoadDimensionSettings()
    
    if LoremCTDB and LoremCTDB.debug ~= nil then
        LCT.debug = LoremCTDB.debug
    end
    if LCT.settings.UpdateAdvancedControls then
        LCT.settings.UpdateAdvancedControls()
    end
end

-- Make settings frame accessible to core
LCT.settingsFrame = settingsFrame
