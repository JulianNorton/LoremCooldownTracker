# LoremCooldownTracker Development Plan

## Project Assessment (v1.1.0)

**Architecture:** Modular with 9 Lua files (~1,900 lines total)  
**Libraries:** Ace3 (AceGUI, AceConfig, AceConsole), LibDBIcon, LibDataBroker  
**Persistence:** SavedVariables (`LoremCTDB`)  
**WoW Support:** Classic Era, TBC, Wrath, Cata (multi-interface TOC)

### What's Working ✅
- Modular architecture with clear separation of concerns
- Dynamic spell scanning from spellbook (>5s cooldowns)
- Trinket slot tracking (slots 13 & 14)
- Timeline with time markers (0s, 10s, 30s, 1m, 5m)
- Smooth icon animations with FPS-aware throttling
- Settings panel with sliders for dimensions/opacity
- Minimap button integration
- Built-in test framework (`/lcttest`, `/lctperf`)
- Debug mode (`/lct debug`)

### Known Bugs 🐛

| Priority | Bug | Root Cause | Location |
|----------|-----|------------|----------|
| 🔴 High | Items not tracking | Only monitors trinket slots 13/14 | `items.lua:59` |
| 🔴 High | Icons overlapping | No collision detection/offset | `cooldowns.lua:143` |
| 🟡 Medium | Performance | OnUpdate always active | `cooldowns.lua:218-226` |
| 🟡 Medium | Spells missed | Only tracks >5s cooldowns | `spells.lua:33` |

---

## Phase 1: Bug Fixes (Priority)

### 1.1 Fix Icon Overlapping
**File:** `cooldowns.lua`

**Problem:** Icons positioned by remaining time only - if two cooldowns have similar remaining times, they overlap.

**Solution:** Add vertical stacking when icons would overlap.

```lua
-- Proposed change in UpdateCooldown() around line 139-143
-- Track occupancy at each x position
-- Stack icons vertically when collision detected
```

**Changes needed:**
- [ ] Add `iconPositions` table to track occupied positions
- [ ] Calculate Y offset when X position is occupied
- [ ] Reset positions when cooldowns expire

---

### 1.2 Fix Item Tracking
**File:** `items.lua`

**Problem:** Only tracks equipped trinkets (slots 13-14), not bag items like potions.

**Solution:** Add bag scanning for items with cooldowns.

**Changes needed:**
- [ ] Add `BAG_UPDATE` event handler
- [ ] Scan bag items for cooldowns using `GetContainerItemCooldown`
- [ ] Register bag items with cooldown module
- [ ] Handle consumable items that disappear after use

---

### 1.3 Performance Optimization ✅ COMPLETED
**File:** `cooldowns.lua`

**Problem:** OnUpdate at line 218-226 runs every 0.1s even with no active cooldowns.

**Solution implemented:**
- Added `isUpdating` flag and `cooldownEventFrame` reference
- Created `StartUpdating()` / `StopUpdating()` functions
- OnUpdate now only runs when `activeCooldownList` has entries
- Debug messages show when updates start/stop

**Changes made:**
- [x] Add `StartUpdating()` / `StopUpdating()` functions
- [x] Call `StopUpdating()` when last cooldown expires
- [x] Call `StartUpdating()` when new cooldown registers
- [x] OnUpdate disabled by default at initialization

---

### 1.4 Lower Spell Cooldown Threshold
**File:** `spells.lua`

**Problem:** Only tracks spells with >5s cooldowns, missing many important abilities.

**Current code (line 33):**
```lua
if cooldown and cooldown > 5000 then
```

**Solution:** Lower to 2s threshold to catch more abilities while still filtering GCD.

---

## Phase 2: Improvements

### 2.1 Consolidate Event Frames
Multiple modules create their own event frames. Consider consolidating to reduce overhead.

### 2.2 Add More Item Sources
- Main hand/Off-hand (engineering tinkers)
- Head slot items (engineering goggles)
- Consumables in specific bag slots

### 2.3 Icon Grouping
Group icons by type (spells vs items) or by cooldown range.

---

## Verification Plan

### Built-in Tests
The addon includes a test framework. Run in-game:
```
/lcttest     - Run functionality tests
/lctperf    - Run performance benchmarks
```

### Manual Testing
1. **Icon Overlap Test:**
   - Use two abilities with similar cooldown durations
   - Verify icons don't stack on top of each other

2. **Item Tracking Test:**
   - Equip trinkets and use them
   - Use consumables from bags (potions)
   - Verify all show on timeline

3. **Performance Test:**
   - Enable debug: `/lct debug`
   - Watch for excessive logging
   - Monitor frame rate during combat with many cooldowns

---

## File Structure

```
LoremCooldownTracker/
├── LoremCooldownTracker.toc   # Multi-interface (Classic/TBC/Wrath/Cata)
├── core.lua                    # Main frame, init, slash commands
├── animations.lua              # Position/finish animations
├── timeline.lua                # Time markers
├── cooldowns.lua               # Cooldown tracking, icons
├── spells.lua                  # Spellbook scanning
├── items.lua                   # Trinket/item tracking
├── visibility.lua              # Show/hide, opacity
├── settings.lua                # Settings panel, minimap
├── tests.lua                   # Test framework
├── Libs/                       # Ace3, LibDBIcon
└── media/                      # Fonts, sounds
```
