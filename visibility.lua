local addonName, LCT = ...

-- Initialize visibility settings
LCT.visibility = {
    shown = LCT.defaults.shown,
    bgOpacity = LCT.defaults.bgOpacity,
    showTimeText = LCT.defaults.showTimeText,
    showIcons = LCT.defaults.showIcons,
    
    -- Function to update icon visibility
    UpdateIconVisibility = function(icon)
        if icon then
            icon:SetShown(LCT.visibility.showIcons)
            if icon.timeText then
                icon.timeText:SetShown(LCT.visibility.showTimeText)
            end
        end
    end,
    
    -- Function to update all icons visibility
    UpdateAllIconsVisibility = function()
        -- Ensure activeCooldowns exists and is a table
        if type(LCT.activeCooldowns) == "table" then
            for _, icon in pairs(LCT.activeCooldowns) do
                LCT.visibility.UpdateIconVisibility(icon)
            end
        end
    end,
    
    -- Function to save visibility settings
    SaveSettings = function()
        if not LoremCTDB then LoremCTDB = {} end
        if not LoremCTDB.visibility then LoremCTDB.visibility = {} end
        
        LoremCTDB.visibility.shown = LCT.frame:IsShown()
        LoremCTDB.visibility.bgOpacity = LCT.frame.bg:GetAlpha()
        LoremCTDB.visibility.showTimeText = LCT.visibility.showTimeText
        LoremCTDB.visibility.showIcons = LCT.visibility.showIcons
        
        -- Save frame position
        local point, relativeTo, relativePoint, xOfs, yOfs = LCT.frame:GetPoint()
        LoremCTDB.visibility.position = {
            point = point,
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
        
        LCT:Debug("Saved visibility settings - shown:", LoremCTDB.visibility.shown, "pos:", xOfs, yOfs)
    end,
    
    -- Function to load visibility settings
    LoadSettings = function()
        LCT:Debug("Loading visibility settings")
        if not LoremCTDB then LoremCTDB = {} end
        if not LoremCTDB.visibility then LoremCTDB.visibility = {} end
        
        local settings = LoremCTDB.visibility
        
        -- Load settings with fallback to defaults
        local shown = settings.shown ~= nil and settings.shown or LCT.defaults.shown
        local bgOpacity = settings.bgOpacity or LCT.defaults.bgOpacity
        local showTimeText = settings.showTimeText ~= nil and settings.showTimeText or LCT.defaults.showTimeText
        local showIcons = settings.showIcons ~= nil and settings.showIcons or LCT.defaults.showIcons
        
        LCT:Debug("Loaded shown value:", shown)
        
        -- Apply settings
        LCT.visibility.shown = shown
        LCT.visibility.bgOpacity = bgOpacity
        LCT.visibility.showTimeText = showTimeText
        LCT.visibility.showIcons = showIcons
        
        -- Apply frame visibility
        if shown then
            LCT:Debug("Showing frame from LoadSettings")
            LCT.frame:Show()
        else
            LCT:Debug("Hiding frame from LoadSettings")
            LCT.frame:Hide()
        end
        
        -- Apply background opacity
        if LCT.frame.bg then
            LCT.frame.bg:SetAlpha(bgOpacity)
        end
        
        -- Restore frame position if saved
        if settings.position then
            local pos = settings.position
            LCT.frame:ClearAllPoints()
            LCT.frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
            LCT:Debug("Restored frame position:", pos.x, pos.y)
        end
        
        -- Update all existing icons
        LCT.visibility.UpdateAllIconsVisibility()
        
        -- Update UI controls if they exist
        if LCT.settings and LCT.settings.UpdateVisibilityControls then
            LCT.settings.UpdateVisibilityControls()
        end
    end,
    
    -- Function to initialize visibility
    Initialize = function()
        LCT:Debug("Initializing visibility")
        -- Show frame by default
        LCT.frame:Show()
        LCT:Debug("Frame shown status after Show():", LCT.frame:IsShown())
        -- Set initial background opacity
        LCT.frame.bg:SetAlpha(LCT.defaults.bgOpacity)
        -- Load saved settings if they exist
        LCT.visibility.LoadSettings()
        LCT:Debug("Frame shown status after LoadSettings:", LCT.frame:IsShown())
    end
}

-- Register for PLAYER_ENTERING_WORLD to ensure frame is shown
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        LCT:Debug("PLAYER_ENTERING_WORLD - Ensuring frame visibility")
        if LCT.visibility.shown then
            LCT.frame:Show()
            LCT:Debug("Frame shown status after PLAYER_ENTERING_WORLD:", LCT.frame:IsShown())
        end
    end
end)

-- Create visibility controls
function LCT.visibility.CreateControls(parent)
    local controls = {}
    
    -- Visibility Header
    controls.header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    controls.header:SetText("Visibility Options")
    
    -- Show/Hide Frame Toggle
    controls.showFrameButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    controls.showFrameButton:SetScript("OnClick", function(self)
        if self:GetChecked() then
            LCT.frame:Show()
        else
            LCT.frame:Hide()
        end
        LCT.visibility.SaveSettings()
    end)
    controls.showFrameButton.text = controls.showFrameButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    controls.showFrameButton.text:SetPoint("LEFT", controls.showFrameButton, "RIGHT", 0, 1)
    controls.showFrameButton.text:SetText("Show Timeline")
    
    -- Background Opacity Controls
    controls.bgOpacitySlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    controls.bgOpacitySlider:SetMinMaxValues(0, 100)
    controls.bgOpacitySlider:SetValue(50)
    controls.bgOpacitySlider:SetValueStep(1)
    controls.bgOpacitySlider:SetObeyStepOnDrag(true)
    controls.bgOpacitySlider.Low:SetText("0%")
    controls.bgOpacitySlider.High:SetText("100%")
    controls.bgOpacitySlider.Text:SetText("Background Opacity")
    
    controls.bgOpacityInput = LCT.settings.CreateInputBox(parent, 50, "50")
    controls.bgOpacityInput:SetPoint("LEFT", controls.bgOpacitySlider, "RIGHT", 10, 0)
    
    controls.bgOpacitySlider:SetScript("OnValueChanged", function(self, value)
        local opacity = value / 100
        LCT.frame.bg:SetAlpha(opacity)
        controls.bgOpacityInput:SetText(math.floor(value))
        LCT.visibility.SaveSettings()
    end)
    
    controls.bgOpacityInput:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(0, math.min(100, value))
            controls.bgOpacitySlider:SetValue(value)
            LCT.frame.bg:SetAlpha(value / 100)
            self:SetText(value)
            LCT.visibility.SaveSettings()
        end
        self:ClearFocus()
    end)
    
    -- Show/Hide Time Text Toggle
    controls.showTimeTextButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    controls.showTimeTextButton:SetScript("OnClick", function(self)
        LCT.visibility.showTimeText = self:GetChecked()
        LCT.visibility.UpdateAllIconsVisibility()
        LCT.visibility.SaveSettings()
    end)
    controls.showTimeTextButton.text = controls.showTimeTextButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    controls.showTimeTextButton.text:SetPoint("LEFT", controls.showTimeTextButton, "RIGHT", 0, 1)
    controls.showTimeTextButton.text:SetText("Show Time Text")
    
    -- Show/Hide Icons Toggle
    controls.showIconsButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    controls.showIconsButton:SetScript("OnClick", function(self)
        LCT.visibility.showIcons = self:GetChecked()
        LCT.visibility.UpdateAllIconsVisibility()
        LCT.visibility.SaveSettings()
    end)
    controls.showIconsButton.text = controls.showIconsButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    controls.showIconsButton.text:SetPoint("LEFT", controls.showIconsButton, "RIGHT", 0, 1)
    controls.showIconsButton.text:SetText("Show Icons")
    
    return controls
end 