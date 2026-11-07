local addonName, LCT = ...

-- Test Framework
LCT.tests = {}
local tests = LCT.tests

-- Module-specific test categories
local testCategories = {
    core = {
        name = "Core Functionality",
        tests = {},
        dependencies = {}
    },
    spells = {
        name = "Spell System",
        tests = {},
        dependencies = {"core"}
    },
    cooldowns = {
        name = "Cooldown Tracking",
        tests = {},
        dependencies = {"core", "spells"}
    },
    timeline = {
        name = "Timeline System",
        tests = {},
        dependencies = {"core", "cooldowns"}
    },
    animations = {
        name = "Animation System",
        tests = {},
        dependencies = {"core", "timeline"}
    },
    settings = {
        name = "Settings & Profiles",
        tests = {},
        dependencies = {"core"}
    },
    visibility = {
        name = "Visibility System",
        tests = {},
        dependencies = {"core", "settings"}
    }
}

-- Performance benchmarking configuration
local PERF_CONFIG = {
    BATCH_SIZE = 5,
    TOTAL_OPS = 50,
    THRESHOLDS = {
        timeline = { good = 50, acceptable = 20 },
        cooldowns = { good = 25, acceptable = 10 },
        animations = { good = 40, acceptable = 20 }
    }
}

-- Performance Benchmarking
local function GetTime()
    return _G.GetTime()
end

local function SafeGetMemoryUsage()
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        pcall(UpdateAddOnMemoryUsage)
        local ok, mem = pcall(GetAddOnMemoryUsage, addonName)
        if ok and type(mem) == "number" then return mem end
    end
    return 0
end

-- Create a mock frame for testing animations
local function CreateMockIcon()
    -- Ensure main frame exists and is properly positioned
    if not LCT.frame then
        LCT.frame = CreateFrame("Frame", "LoremCTFrame", UIParent)
        LCT.frame:SetSize(300, 30)
        LCT.frame:SetPoint("CENTER")
        LCT.frame:Show()
        -- Create background for visibility
        local bg = LCT.frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
        LCT.frame.bg = bg
    end

    -- Clean up any existing test icon
    local existingIcon = _G["LoremCTTestIcon"]
    if existingIcon then
        existingIcon:Hide()
        existingIcon:SetParent(nil)
    end

    -- Create the icon frame with version-aware template
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "LoremCTTestIcon", LCT.frame, template)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    end
    
    -- Set size and initial position
    frame:SetSize(24, 24)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", LCT.frame, "LEFT", 0, 0)
    frame:Show()
    
    -- Create a texture for the icon using Classic-compatible method
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Icons\\Spell_Nature_TimeStop")
    
    -- Create the mock icon with all required properties
    local mockIcon = {
        frame = frame,
        cooldownStart = GetTime(),
        cooldownDuration = 15, -- Use a reasonable test duration
        spellID = -1, -- Use a mock spellID for testing
        point = "CENTER",
        relativePoint = "LEFT",
        xOffset = 0,
        yOffset = 0
    }
    
    -- Store current position
    mockIcon.currentX = 0
    mockIcon.currentY = 0
    
    -- Add frame validation method
    mockIcon.isValid = function(self)
        return self.frame and self.frame:IsObjectType("Frame") and self.frame:GetParent() == LCT.frame
    end
    
    return mockIcon
end

function tests:BenchmarkOperation(operationFunc, maxDuration)
    maxDuration = maxDuration or 0.5 -- Reduced to 0.5 second test window
    local startTime = GetTime()
    local iterations = 0
    local totalMemoryStart = SafeGetMemoryUsage()
    
    -- Run as many operations as we can in the time window
    while (GetTime() - startTime) < maxDuration do
        operationFunc()
        iterations = iterations + 1
        
        -- Break if we're doing too many iterations
        if iterations > 1000 then
            break
        end
    end
    
    local endTime = GetTime()
    local totalMemoryEnd = SafeGetMemoryUsage()
    
    local timeElapsed = endTime - startTime
    local memoryUsed = totalMemoryEnd - totalMemoryStart
    local opsPerSecond = iterations / timeElapsed
    
    return {
        totalTime = timeElapsed,
        iterations = iterations,
        opsPerSecond = opsPerSecond,
        memoryUsed = memoryUsed
    }
end

function tests:RunAll()
    print("=== Lorem Cooldown Tracker Tests ===")
    
    -- Define test order based on dependencies
    local testOrder = {"core", "spells", "cooldowns", "timeline", "animations", "settings", "visibility"}
    
    for _, category in ipairs(testOrder) do
        local info = testCategories[category]
        if info then
            print("\n=== " .. info.name .. " Tests ===")
            local passed, total = 0, 0
            
            -- Check dependencies first
            local dependenciesMet = true
            for _, dep in ipairs(info.dependencies) do
                total = total + 1
                if LCT[dep] then
                    print(string.format("YES - Required module '%s' exists", dep))
                    passed = passed + 1
                else
                    print(string.format("NO - Required module '%s' missing", dep))
                    dependenciesMet = false
                    break -- Skip remaining tests if dependency missing
                end
            end
            
            if dependenciesMet then
                -- Core Tests
                if category == "core" then
                    total = total + 1
                    if LCT.frame and LCT.frame.GetObjectType and LCT.frame:GetObjectType() == "Frame" then
                        print("YES - Main frame exists")
                        passed = passed + 1
                    else
                        print("NO - Main frame missing")
                    end
                    
                    total = total + 1
                    if type(LCT.Debug) == "function" then
                        print("YES - Debug logging system exists")
                        passed = passed + 1
                    else
                        print("NO - Debug logging system missing")
                    end
                    
                    total = total + 1
                    if type(LCT.defaults) == "table" then
                        print("YES - Default settings exist")
                        passed = passed + 1
                    else
                        print("NO - Default settings missing")
                    end
                end
                
                -- Spell Tests
                if category == "spells" then
                    total = total + 1
                    if type(LCT.spells.ScanSpellBook) == "function" then
                        print("YES - Spell scanning function exists")
                        passed = passed + 1
                    else
                        print("NO - Spell scanning function missing")
                    end
                end
                
                -- Cooldown Tests
                if category == "cooldowns" then
                    total = total + 1
                    if type(LCT.cooldowns) == "table" then
                        print("YES - Cooldown module exists")
                        passed = passed + 1
                    else
                        print("NO - Cooldown module missing")
                    end
                    
                    total = total + 1
                    if LCT.cooldowns and type(LCT.cooldowns.UpdateAll) == "function" then
                        print("YES - Cooldown update function exists")
                        passed = passed + 1
                    else
                        print("NO - Cooldown update function missing")
                    end
                    
                    total = total + 1
                    if LCT.activeCooldowns then
                        print("YES - Active cooldowns tracking exists")
                        passed = passed + 1
                    else
                        print("NO - Active cooldowns tracking missing")
                    end
                end
                
                -- Timeline Tests
                if category == "timeline" then
                    total = total + 1
                    if type(LCT.timeline) == "table" then
                        print("YES - Timeline module exists")
                        passed = passed + 1
                    else
                        print("NO - Timeline module missing")
                    end
                    
                    total = total + 1
                    if LCT.timeline and type(LCT.timeline.UpdateMarkers) == "function" then
                        print("YES - Timeline marker update function exists")
                        passed = passed + 1
                    else
                        print("NO - Timeline marker update function missing")
                    end
                end
                
                -- Animation Tests
                if category == "animations" then
                    total = total + 1
                    if type(LCT.animations) == "table" then
                        print("YES - Animation module exists")
                        passed = passed + 1
                    else
                        print("NO - Animation module missing")
                    end
                    
                    total = total + 1
                    if LCT.animations and type(LCT.animations.StartPositionAnimation) == "function" then
                        print("YES - Position animation function exists")
                        passed = passed + 1
                    else
                        print("NO - Position animation function missing")
                    end
                    
                    total = total + 1
                    if LCT.animations and type(LCT.animations.StartFinishAnimation) == "function" then
                        print("YES - Finish animation function exists")
                        passed = passed + 1
                    else
                        print("NO - Finish animation function missing")
                    end
                end
                
                -- Settings Tests
                if category == "settings" then
                    total = total + 1
                    if type(LoremCTDB) == "table" then
                        print("YES - Settings database (SavedVariables) exists")
                        passed = passed + 1
                    else
                        print("NO - Settings database (SavedVariables) missing")
                    end
                    
                    total = total + 1
                    if LCT.settingsFrame then
                        print("YES - Settings UI frame exists")
                        passed = passed + 1
                    else
                        print("NO - Settings UI frame missing")
                    end
                end
                
                -- Visibility Tests
                if category == "visibility" then
                    total = total + 1
                    if type(LCT.visibility) == "table" then
                        print("YES - Visibility module exists")
                        passed = passed + 1
                    else
                        print("NO - Visibility module missing")
                    end
                    
                    total = total + 1
                    if LCT.visibility and type(LCT.visibility.UpdateIconVisibility) == "function" then
                        print("YES - Icon visibility update function exists")
                        passed = passed + 1
                    else
                        print("NO - Icon visibility update function missing")
                    end
                end
            end
            
            print(string.format("Passed: %d/%d tests", passed, total))
        end
    end
    
    print("\n=== Test Summary Complete ===")
end

function tests:RunPerformanceTests()
    print("=== Lorem Cooldown Tracker Performance Tests ===")
    print("Testing operations per second over 0.5-second windows...")
    
    -- Test configuration
    local TEST_BATCH_SIZE = 5
    local TOTAL_OPERATIONS = 50
    local TICK_INTERVAL = 0.05
    
    -- Test state
    local state = {
        currentTest = 1,
        operationsCompleted = 0,
        startTime = nil,
        memoryStart = nil,
        mockIcon = nil,
        ticker = nil
    }
    
    -- Create test frame
    local testFrame = CreateFrame("Frame")
    testFrame:Hide()
    
    local StartTest, FinishTest
    
    function FinishTest()
        if state.ticker then
            state.ticker:Cancel()
            state.ticker = nil
        end
        
        if state.operationsCompleted > 0 then
            local endTime = GetTime()
            local timeElapsed = endTime - state.startTime
            local memoryUsed = SafeGetMemoryUsage() - state.memoryStart
            local opsPerSecond = state.operationsCompleted / timeElapsed
            
            if state.currentTest == 1 then
                print("\nTimeline Update Test:")
                print(string.format("  Time: %.2f seconds", timeElapsed))
                print(string.format("  Speed: %.1f ops/sec", opsPerSecond))
                print(string.format("  Memory: %.2f KB", memoryUsed))
                print(string.format("  Rating: %s", 
                    opsPerSecond >= 50 and "|cFF00FF00Good|r" or
                    opsPerSecond >= 20 and "|cFFFFFF00Acceptable|r" or
                    "|cFFFF0000Concerning|r"
                ))
                
                state.currentTest = 2
                C_Timer.After(0.5, StartTest)
                
            elseif state.currentTest == 2 then
                print("\nCooldown Update Test:")
                print(string.format("  Time: %.2f seconds", timeElapsed))
                print(string.format("  Speed: %.1f ops/sec", opsPerSecond))
                print(string.format("  Memory: %.2f KB", memoryUsed))
                print(string.format("  Rating: %s", 
                    opsPerSecond >= 25 and "|cFF00FF00Good|r" or
                    opsPerSecond >= 10 and "|cFFFFFF00Acceptable|r" or
                    "|cFFFF0000Concerning|r"
                ))
                
                state.currentTest = 3
                state.mockIcon = CreateMockIcon()
                C_Timer.After(0.5, StartTest)
                
            elseif state.currentTest == 3 then
                print("\nAnimation System Test:")
                print(string.format("  Time: %.2f seconds", timeElapsed))
                print(string.format("  Speed: %.1f ops/sec", opsPerSecond))
                print(string.format("  Memory: %.2f KB", memoryUsed))
                print(string.format("  Rating: %s", 
                    opsPerSecond >= 40 and "|cFF00FF00Good|r" or
                    opsPerSecond >= 20 and "|cFFFFFF00Acceptable|r" or
                    "|cFFFF0000Concerning|r"
                ))
                
                if state.mockIcon and state.mockIcon.frame then
                    state.mockIcon.frame:Hide()
                    state.mockIcon.frame:SetParent(nil)
                end
                
                print("\n=== Performance Summary ===")
                print("Timeline Update: Good >= 50 ops/sec")
                print("Cooldown Update: Good >= 25 ops/sec")
                print("Animation System: Good >= 40 ops/sec")
                print("=====================")
                print("Performance tests complete!")
                
                collectgarbage("collect")
            end
        else
            if state.currentTest == 1 then
                print("\nTimeline Update Test: SKIPPED - Timeline module not available")
                state.currentTest = 2
                C_Timer.After(0.5, StartTest)
            elseif state.currentTest == 2 then
                print("\nCooldown Update Test: SKIPPED - Cooldown module not available")
                state.currentTest = 3
                state.mockIcon = CreateMockIcon()
                C_Timer.After(0.5, StartTest)
            elseif state.currentTest == 3 then
                print("\nAnimation System Test: SKIPPED - Animation module not available")
                print("\n=== Performance Summary ===")
                print("All tests skipped - Required modules not available")
                print("=====================")
                print("Performance tests complete!")
            end
        end
    end
    
    function StartTest()
        state.operationsCompleted = 0
        state.startTime = GetTime()
        state.memoryStart = SafeGetMemoryUsage()
        
        local canRunTest = false
        if state.currentTest == 1 then
            canRunTest = LCT.timeline and LCT.timeline.UpdateMarkers
        elseif state.currentTest == 2 then
            canRunTest = LCT.cooldowns and LCT.cooldowns.UpdateAll
        elseif state.currentTest == 3 then
            if state.mockIcon then
                state.mockIcon.frame:Hide()
                state.mockIcon.frame:SetParent(nil)
            end
            state.mockIcon = CreateMockIcon()
            canRunTest = LCT.animations and LCT.animations.StartPositionAnimation and state.mockIcon and state.mockIcon.frame
        end
        
        if not canRunTest then
            FinishTest()
            return
        end
        
        state.ticker = C_Timer.NewTicker(TICK_INTERVAL, function()
            if state.operationsCompleted >= TOTAL_OPERATIONS then 
                state.ticker:Cancel()
                FinishTest()
                return
            end
            
            if state.currentTest == 3 and (not state.mockIcon or not state.mockIcon.frame) then
                state.mockIcon = CreateMockIcon()
                if not state.mockIcon or not state.mockIcon.frame then
                    state.ticker:Cancel()
                    FinishTest()
                    return
                end
            end
            
            for i = 1, TEST_BATCH_SIZE do
                if state.operationsCompleted >= TOTAL_OPERATIONS then break end
                
                if state.currentTest == 1 then
                    if LCT.timeline and LCT.timeline.UpdateMarkers then
                        LCT.timeline.UpdateMarkers()
                    end
                elseif state.currentTest == 2 then
                    if LCT.cooldowns and LCT.cooldowns.UpdateAll then
                        LCT.cooldowns.UpdateAll()
                    end
                elseif state.currentTest == 3 then
                    if LCT.animations and state.mockIcon then
                        if not state.mockIcon:isValid() then
                            state.mockIcon = CreateMockIcon()
                            if not state.mockIcon or not state.mockIcon:isValid() then
                                state.ticker:Cancel()
                                FinishTest()
                                return
                            end
                        end
                        
                        local frame = state.mockIcon.frame
                        if not frame:GetPoint() then
                            frame:ClearAllPoints()
                            frame:SetPoint("CENTER", LCT.frame, "LEFT", 0, 0)
                            if not frame:GetPoint() then
                                state.ticker:Cancel()
                                FinishTest()
                                return
                            end
                        end
                        
                        LCT.animations.StartPositionAnimation(state.mockIcon.frame, 50, 5)
                    end
                end
                
                state.operationsCompleted = state.operationsCompleted + 1
            end
        end)
    end
    
    StartTest()
end

SLASH_LCTPERF1 = "/lctperf"
SlashCmdList["LCTPERF"] = function(msg)
    print("LoremCT: Starting performance tests...")
    local success, err = pcall(function()
        tests:RunPerformanceTests()
    end)
    if not success then
        print("LoremCT Performance Test ERROR: " .. tostring(err))
    end
end

SLASH_LCTTEST1 = "/lcttest"
SlashCmdList["LCTTEST"] = function(msg)
    print("LoremCT: Running tests...")
    local success, err = pcall(function()
        tests:RunAll()
    end)
    if not success then
        print("LoremCT Test ERROR: " .. tostring(err))
    end
end
