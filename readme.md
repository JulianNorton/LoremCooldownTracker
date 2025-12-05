# Lorem's Cooldown Tracker
A World of Warcraft Classic addon that provides an intuitive visual timeline for tracking ability and item cooldowns.

## Key Features

### Visual Timeline Bar
* Displays active cooldowns on a horizontal/vertical timeline
* Shows remaining time both numerically and positionally on the bar
* Cooldowns move along the bar as they progress
* Different sections for short (<10s), medium (10-30s) and long (30s+) cooldowns

### Smart Cooldown Tracking
* Tracks spell abilities, items, and pet abilities
* Filters out very short cooldowns (global cooldown)
* Option to ignore specific spells/items
* Shows cooldown icons alongside the timeline

### Customization Options
* Adjustable size, position and orientation
* Customizable colors and transparency
* Font and texture options
* Lock/unlock frame for positioning
* Option to show/hide specific types of cooldowns

### User Experience
* Clear visual and optional audio indicators when abilities are ready
* Smooth animations and transitions
* Minimal performance impact
* Easy configuration through in-game options

## Purpose
This addon aims to help players better track and anticipate their cooldowns by providing:
* A more visual and intuitive way to monitor multiple cooldowns simultaneously
* Clear indication of when abilities will become available
* Better cooldown planning through the timeline view
* Reduced need to watch individual ability icons
* Improved situational awareness in combat

## Installation
1. Download the latest release
2. Extract the LoremCooldownTracker folder to your `World of Warcraft\_classic_\Interface\AddOns` directory
3. Restart World of Warcraft if it's running

## Commands

| Command | Description |
|---------|-------------|
| `/lct` | Open settings panel |
| `/lct toggle` | Show/hide the timeline frame |
| `/lct lock` | Lock/unlock frame (locked = click-through) |
| `/lct scan` | Rescan spellbook for abilities |
| `/lct debug` | Toggle debug mode |
| `/lcttest` | Run functionality tests |
| `/lctperf` | Run performance benchmarks |

### Performance Testing

The addon includes built-in performance benchmarks accessible via `/lctperf`:

1. **Timeline Update Test** - Measures ops/sec for timeline marker updates
   - Good: ≥50 ops/sec
   - Acceptable: ≥20 ops/sec

2. **Cooldown Update Test** - Measures ops/sec for cooldown tracking
   - Good: ≥25 ops/sec
   - Acceptable: ≥10 ops/sec

3. **Animation System Test** - Measures ops/sec for icon animations
   - Good: ≥40 ops/sec
   - Acceptable: ≥20 ops/sec

**Idle Performance**: When no cooldowns are active, the addon uses 0% CPU (OnUpdate handlers are disabled).

## Supported Versions
- WoW Classic Era (1.15.x)
- Burning Crusade Classic (2.5.x)
- Wrath of the Lich King Classic (3.4.x)

## Modifications
* Feel free to modify and fork this project, checkout the license.txt for details