# Audit and get-well plan

Written 2026-11-26 against commit `793f120`, the unreleased tip of `fix/wow-forever-16001-compatibility`, on client `_forever_` (Interface 16001). The last release was v2.5. The result is version 2.6.0.

## Result

One line broke most of the addon. `spells.lua:219` registered `LEARNED_SPELL_IN_TAB`, which this client does not have. `RegisterEvent` threw, startup aborted, and three of the six modules never started.

| Never started | What you saw |
| --- | --- |
| `items` | Equipped and bag items not tracked, except by accident through their use-spell |
| `timeline` (resize handler) | Markers did not follow the bar when resized |
| `settings` | Saved width, height and icon size not applied at login; no minimap button |
| `spells` (events and first scans) | Spells only appeared after you cast them |

`cooldowns` also started up to three times per login, once per login event.

**Evidence.** `Logs/General.log` holds seven copies of `Attempt to register unknown event "LEARNED_SPELL_IN_TAB"` between 21:34 and 21:52, each with the trace `spells.lua:219 → core.lua:260 EnsureInitialized`. Before the fix the markers were laid out for the default 420 width while the saved width was 766. After the fix and a reload they span 766.

The last four commits before this work patched symptoms of that error (register on cast, pre-populated timers, retry timers). They were all measured against a half-started addon.

## Findings

Status: **fixed** means changed and seen working in game. **changed** means changed and passing the offline test, but not yet seen in game. **open** means not changed.

| # | Severity | Finding | Status |
| --- | --- | --- | --- |
| 1 | Critical | Unknown event aborts startup (above). | fixed |
| 2 | High | One failing module silently stopped the rest, and Lua errors are not shown on screen. Each module now starts under `pcall` and reports a failure in chat. Every event is registered under `pcall`. | changed |
| 3 | High | The finish pop was unreliable. Any cooldown event hid an icon that had no running timer, including one mid-pop, and those events fire as a cooldown ends. Items the API reported as cleared were hidden with no pop. | fixed |
| 4 | Medium | The pop used `SetScale` on an icon placed by an x-offset. Scale multiplies the offset too, so the icon slid right as it grew. It now grows by size. | fixed |
| 5 | Medium | The cast handler registered every spell cast, including item use-spells, so an item use could get a second icon. It now accepts only spells in the spellbook or known to the client, and tracks one ID per spell (the highest rank). | changed |
| 6 | Medium | A cooldown that was reset early kept running to its end, because a running timer was kept whenever the API reported zero. A timer the API has confirmed now ends when the API reports none. A timer the API never reported still runs out on its own, as before. | changed |
| 7 | Medium | The bag scan dropped any event within 0.5 s of the last scan, and bag items were only found by that scan. Bags are now read in the same pass as everything else, once per frame at most. | changed |
| 8 | Low | A cooldown that ended while the bar was hidden left its icon frozen until the next cooldown event. | changed |
| 9 | Low | Marker positions depend on icon size but were not refreshed when it changed. | fixed |
| 10 | Debt | Each setting lived in three places with five save, load and refresh functions. There is now one table (`LCT.db`) and one function that applies it (`LCT:Apply`). | changed |
| 11 | Debt | One hand-written block per marker and per settings control. Both are now built from a list. | changed |
| 12 | Dead | `Libs/Ace3`: 67 files, two of them loaded, both duplicated under `Libs/LibDBIcon-1.0`. Removed. | fixed |
| 13 | Dead | `tests.lua`: 572 lines of module-exists checks and micro-benchmarks that did not catch finding 1. Removed, with `/lcttest` and `/lctperf`. | fixed |
| 14 | Docs | The readme listed features that do not exist. `core.lua` said 1.1.0, the TOC said 2.0.0 and the last release was tagged v2.5. | changed |

Left alone on purpose:

- `compat.GetSpellCooldown` is unchanged. It has a `GetTotalDuration` fallback that would restart a timer at full length; it looks unreachable. Nothing here shows what this client returns in combat, so its behaviour stays as it was until an in-game `/dump` says otherwise.
- The background is drawn at half strength: the texture is 50% black and the opacity setting multiplies that, so "100%" is 50%. Fixing it would darken every existing user's bar.

## Size

| | Before | After |
| --- | --- | --- |
| Own Lua | 2,896 lines in 9 files | 986 lines in 4 files |
| Files shipped | 88 | 16 |

| File | Holds |
| --- | --- |
| `core.lua` | Saved settings, client compatibility, the bar frame, `/lct`, startup |
| `bar.lua` | Markers, icons, the per-frame update, the finish pop |
| `tracker.lua` | Spellbook scan, cast handling, equipped and bag items, events |
| `settings.lua` | Settings panel and minimap button |

## New: burst size

`Finish Burst Size (%)` in the settings panel, 100 to 400, default 150. 100 turns the grow off and leaves the fade. `Test` next to it, or `/lct test`, runs a three-second sample cooldown.

## Verification

- In game, by reload and screenshot: the startup fix, the bar at its saved size, the new settings panel with the burst slider.
- Offline: a 41-check script that loads the four files against a mocked WoW API. It covers startup on a client missing the event, the 2.5 settings carrying over, the pop and burst size, casts, resets, items, bags and the settings panel. An earlier version of the script, run against `793f120`, failed with the error from the client log. It only proves the addon's own logic; it cannot show how a real client behaves.
- Not verified: any client other than `_forever_`.

## Ideas raised, not tried

- Poll running timers once a second so a missed event cannot leave a stuck icon.
- Show one icon for bag items that share a cooldown (potions).
- Stop a base-cooldown timer when the API says the cooldown has not started (Stealth, Presence of Mind).
- Track pet abilities.
- Keep the offline test in the repo and run it before each release.
- Remove the old `dimensions` and `visibility` tables from the saved variables once rollback to 2.5 no longer matters.

## Rollback

`git checkout 793f120 -- .` restores the code as it was before this work (with finding 1). The saved variables keep their old layout alongside the new keys, so older code still finds its settings.

Local snapshots from this work: `refs/backup/pre-audit` (before any change), `refs/backup/startup-fix` (one-line fix only), `refs/backup/stage-1` (dead files removed, pop fix, burst setting; seen working in game).
