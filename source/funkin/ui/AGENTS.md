# source/funkin/ui — UI screens & shared widgets (202 hx)

## OVERVIEW
Every menu/screen state plus the shared widget kit they build on.

## STRUCTURE
```
*.hx (direct)   # shared kit: MusicBeatState(+SubState, Scripted*), Alphabet,
                # AtlasText, AtlasMenuList, AlphabetMenuList, MenuList, TextMenuList,
                # MenuItem, Prompt, Page, UIStateMachine, Codex, FullScreenScaleMode
freeplay/ (27)  # FreeplayState (substate flow, capsule art paths, letterSort)
options/ (12)   # OptionsState + PreferencesMenu (FPS/vsync menu items removed — see root)
debug/ (109)    # chart editor + stage editor → its own AGENTS.md
charSelect/ (9) # character select screen
transition/ (7) # state transition effects (BaseTransition hooks: purgeCache/refreshLocal)
story/ (5)      # story/week menu
haxeui/ (5)     # haxeui integration (feature-flagged)
credits/ (4), mainmenu/ (2), title/ (2), leaderboard/ (2), awards/ (1)
```

## WHERE TO LOOK
| Task | File |
|------|------|
| New menu screen | extend `MusicBeatState`; sprite via `Paths.getSparrowAtlas('mainmenu/menu_$name')` pattern |
| Text widgets | `AtlasText` (atlas-based), `Alphabet` (classic), `MenuList` family |
| Main menu items | `mainmenu/MainMenuState.hx` — `optionShit` list (:76 area); story-mode entry purges freeplay art (`purgeCache` hook ~:449) |
| Freeplay list/art | `freeplay/FreeplayState.hx` — capsule/selector paths in `getPortraitAsset`-style code |
| Preferences UI | `options/PreferencesMenu.hx` — no VSync/FPS items anymore (forced by Preferences) |

## CONVENTIONS / GOTCHAS
- Menu graphics are NOT persistent: entering story-mode fires `FunkinMemory.purgeCache()` — boot warmup in `FunkinMemory.initialCache` preloads menuBG + mainmenu atlases + freeplay art.
- Options loads `Paths.image('menuBG')` on create; slow menu transitions = flixel `removeUnused` destroying graphics, not the create code itself.
- Do not re-add framerate/vsync menu items — caps are force-removed (root: ANTI-PATTERNS / Preferences).
