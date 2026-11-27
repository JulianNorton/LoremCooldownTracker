# Lorem's Cooldown Tracker
A World of Warcraft Classic addon that shows your ability and item cooldowns on one horizontal timeline.

## What it does
* Each cooldown is an icon that slides left along the bar as it runs down, with the time left under it
* The scale is non-linear, so the last seconds get the most room
* Tracks spells, equipped items and bag items; ignores anything of five seconds or less, including the global cooldown
* When a cooldown finishes, its icon grows and fades; the size of that burst is adjustable

## Settings
Open with `/lct` or the minimap button.

* Bar width and height, icon size, finish burst size
* Background opacity
* Show or hide the bar, the icons and the time text
* Lock the bar (click-through) or drag it to move

## Commands

| Command | Description |
|---------|-------------|
| `/lct` | Open settings panel |
| `/lct toggle` | Show/hide the timeline frame |
| `/lct lock` | Lock/unlock frame (locked = click-through) |
| `/lct scan` | Rescan spellbook for abilities |
| `/lct test` | Run a three-second sample cooldown |
| `/lct debug` | Toggle debug mode |

## Installation
1. Download the latest release
2. Extract the LoremCooldownTracker folder to the `Interface\AddOns` directory of your game version, for example `World of Warcraft\_classic_\Interface\AddOns`
3. Restart World of Warcraft if it's running

## Supported Versions
- WoW Forever (1.60.x)
- WoW Classic Era (1.15.x)
- Burning Crusade Classic (2.5.x)
- Wrath of the Lich King Classic (3.4.x)

## Modifications
* Feel free to modify and fork this project, checkout the license.txt for details
