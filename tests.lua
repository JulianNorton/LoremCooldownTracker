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
    -- Just use WoW's GetTime() directly, it's reliable enough for our tests
    return _G.GetTime()
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
    local frame
    if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        -- In Classic Era, we need to use the template
        frame = CreateFrame("Frame", "LoremCTTestIcon", LCT.frame, "BackdropTemplate")
        if frame.SetBackdrop then -- Check if SetBackdrop is available
            frame:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
        end
    else
        frame = CreateFrame("Frame", "LoremCTTestIcon", LCT.frame, "BackdropTemplate")
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
    UpdateAddOnMemoryUsage()
    local totalMemoryStart = GetAddOnMemoryUsage(addonName)
    
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
    UpdateAddOnMemoryUsage()
    local totalMemoryEnd = GetAddOnMemoryUsage(addonName)
    
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
    local TEST_BATCH_SIZE = 5  -- Number of operations per OnUpdate
    local TOTAL_OPERATIONS = 50  -- Total operations to perform per test
    local TICK_INTERVAL = 0.05  -- Increase tick interval for better stability
    
    -- Test state
    local state = {
        currentTest = 1,
        operationsCompleted = 0,
        startTime = nil,
        memoryStart = nil,
        mockIcon = nil,
        ticker = nil -- Store ticker reference
    }
    
    -- Create test frame
    local testFrame = CreateFrame("Frame")
    testFrame:Hide()
    
    -- Pre-declare functions so they're in scope
    local StartTest, FinishTest
    
    function FinishTest()
        print("FinishTest called for test", state.currentTest)
        if state.ticker then
            print("Cancelling ticker")
            state.ticker:Cancel()
            state.ticker = nil
        end
        
        if state.operationsCompleted > 0 then
            local endTime = GetTime()
            local timeElapsed = endTime - state.startTime
            print(string.format("Test completed with %d operations in %.2f seconds", state.operationsCompleted, timeElapsed))
            UpdateAddOnMemoryUsage()
            local memoryUsed = GetAddOnMemoryUsage(addonName) - state.memoryStart
            local opsPerSecond = state.operationsCompleted / timeElapsed
            
            -- Print results based on current test
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
                
                -- Start next test after a delay
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
                
                -- Start next test after a delay
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
                
                -- Clean up
                if state.mockIcon and state.mockIcon.frame then
                    state.mockIcon.frame:Hide()
                    state.mockIcon.frame:SetParent(nil)
                end
                
                -- Print summary
                print("\n=== Performance Summary ===")
                print("Timeline Update: Good >= 50 ops/sec")
                print("Cooldown Update: Good >= 25 ops/sec")
                print("Animation System: Good >= 40 ops/sec")
                print("=====================")
                print("Performance tests complete!")
                
                collectgarbage("collect")
            end
        else
            -- Handle case where test was skipped
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
        print(string.format("\nStarting test %d...", state.currentTest))
        state.operationsCompleted = 0
        state.startTime = GetTime()
        UpdateAddOnMemoryUsage()
        state.memoryStart = GetAddOnMemoryUsage(addonName)
        
        -- Check if required module exists before starting test
        local canRunTest = false
        if state.currentTest == 1 then
            print("Checking timeline module...")
            canRunTest = LCT.timeline and LCT.timeline.UpdateMarkers
            print("Timeline module available:", canRunTest and "yes" or "no")
        elseif state.currentTest == 2 then
            print("Checking cooldowns module...")
            canRunTest = LCT.cooldowns and LCT.cooldowns.UpdateAll
            print("Cooldowns module available:", canRunTest and "yes" or "no")
        elseif state.currentTest == 3 then
            print("Checking animations module...")
            -- Create mock icon before checking animation module
            if state.mockIcon then
                state.mockIcon.frame:Hide()
                state.mockIcon.frame:SetParent(nil)
            end
            state.mockIcon = CreateMockIcon()
            canRunTest = LCT.animations and LCT.animations.StartPositionAnimation and state.mockIcon and state.mockIcon.frame
            print("Animations module available:", canRunTest and "yes" or "no")
        end
        
        if not canRunTest then
            print("Module not available, skipping test", state.currentTest)
            FinishTest() -- Skip to next test
            return
        end
        
        print("Starting ticker for test", state.currentTest)
        print(string.format("Will run %d operations in batches of %d", TOTAL_OPERATIONS, TEST_BATCH_SIZE))
        
        -- Use C_Timer for better Classic compatibility
        state.ticker = C_Timer.NewTicker(TICK_INTERVAL, function()
            -- Check if we're done before doing any operations
            if state.operationsCompleted >= TOTAL_OPERATIONS then 
                print("Operations complete for test", state.currentTest)
                state.ticker:Cancel()
                FinishTest()
                return
            end
            
            -- For animation test, verify mock icon is still valid
            if state.currentTest == 3 and (not state.mockIcon or not state.mockIcon.frame) then
                print("Mock icon became invalid, recreating...")
                state.mockIcon = CreateMockIcon()
                if not state.mockIcon or not state.mockIcon.frame then
                    print("Failed to recreate mock icon, stopping test")
                    state.ticker:Cancel()
                    FinishTest()
                    return
                end
            end
            
            -- Perform a batch of operations
            for i = 1, TEST_BATCH_SIZE do
                if state.operationsCompleted >= TOTAL_OPERATIONS then break end
                
                if state.currentTest == 1 then
                    -- Timeline Update Test
                    if LCT.timeline and LCT.timeline.UpdateMarkers then
                        LCT.timeline.UpdateMarkers()
                    end
                elseif state.currentTest == 2 then
                    -- Cooldown Update Test
                    if LCT.cooldowns and LCT.cooldowns.UpdateAll then
                        LCT.cooldowns.UpdateAll()
                    end
                elseif state.currentTest == 3 then
                    -- Animation System Test
                    if LCT.animations and state.mockIcon then
                        -- Verify frame is still valid
                        if not state.mockIcon:isValid() then
                            print("Frame became invalid, recreating...")
                            state.mockIcon = CreateMockIcon()
                            if not state.mockIcon or not state.mockIcon:isValid() then
                                print("Failed to recreate mock icon, stopping test")
                                state.ticker:Cancel()
                                FinishTest()
                                return
                            end
                        end
                        
                        -- Ensure frame has a valid point before animation
                        local frame = state.mockIcon.frame
                        if not frame:GetPoint() then
                            print("Frame lost its point, resetting...")
                            frame:ClearAllPoints()
                            frame:SetPoint("CENTER", LCT.frame, "LEFT", 0, 0)
                            if not frame:GetPoint() then
                                print("Failed to set frame point, stopping test")
                                state.ticker:Cancel()
                                FinishTest()
                                return
                            end
                        end
                        
                        -- Use smaller movements for testing to reduce strain
                        LCT.animations.StartPositionAnimation(state.mockIcon.frame, 50, 5)
                    end
                end
                
                state.operationsCompleted = state.operationsCompleted + 1
                if state.operationsCompleted % TEST_BATCH_SIZE == 0 then
                    print(string.format("Completed %d/%d operations", state.operationsCompleted, TOTAL_OPERATIONS))
                end
            end
        end)  -- Remove TOTAL_TICKS limit, we'll control it via operationsCompleted
    end
    
    -- Start the first test
    StartTest()
end

-- Add performance test slash command
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

-- Add slash command for testing
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