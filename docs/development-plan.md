# LoremCooldownTracker Development Plan

## Project Assessment (v1.1.0)

**Architecture:** Modular with 9 Lua files (~1,900 lines total)  
**Libraries:** Ace3 (AceGUI, AceConfig, AceConsole), LibDBIcon, LibDataBroker  
**Persistence:** SavedVariables (`LoremCTDB`)  
**WoW Support:** Classic Era, TBC, Wrath, Cata (multi-interface TOC)


## Built-in Tests
The addon includes a test framework. Run in-game:
```
/lcttest     - Run functionality tests
/lctperf    - Run performance benchmarks
```
### Performance Test:
   - Enable debug: `/lct debug`
   - Watch for excessive logging
   - Monitor frame rate during combat with many cooldowns

---

## File Structure

```
LoremCooldownTracker/
├── LoremCooldownTracker.toc   # Multi-interface (Classic/TBC/Wrath/Cata)
├── core.lua                    # Main frame, init, slash commands
├── items.lua                   # Trinket/item tracking
├── animations.lua              # Position/finish animations
├── timeline.lua                # Time markers
├── cooldowns.lua               # Cooldown tracking, icons
├── spells.lua                  # Spellbook scanning
├── visibility.lua              # Show/hide, opacity
├── settings.lua                # Settings panel, minimap
├── tests.lua                   # Test framework
├── Libs/                       # Ace3, LibDBIcon
```
