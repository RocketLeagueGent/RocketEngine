# PROJECT KNOWLEDGE BASE

**Generated:** 2026-10-04 **Commit:** 21d925cc8 **Branch:** main

## OVERVIEW
RocketEngine — Friday Night Funkin' 0.8.6 V-Slice fork (Haxe 4.3.7 / HaxeFlixel / OpenFL / Lime) adding Psych 1.0.4 mod parity and performance work. Targets: Windows (hxcpp debug+release) and HTML5.

## STRUCTURE
```
source/        # all game code: funkin/ (game), haxe/ (stubs), cpp/ (native glue)
assets/        # GITLINK — NOT committed from this repo (see ANTI-PATTERNS)
example_mods/  # Polymod sample mods (introMod, testing123)
scripts/       # dev utilities (SongConverter.hx, chartingSheets/, asset scripts)
docs/          # COMPILING.md, INSTALLING_MODS.md, TRACY.md, FNFC-SPEC.md
tools/, art/   # misc tooling; DIRECTORY_REORG_PLAN.md = PROPOSAL ONLY (nothing moved)
project.hxp    # THE project file (not Project.xml) — libs, assets libs, feature flags
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Boot / game loop | `source/Main.hx`, `source/funkin/InitState.hx` | InitState wires prefs, VSync, framerate, calls `initialCache` (#if !html5) |
| State flow / menus | `source/funkin/ui/MusicBeatState.hx` | ALL states extend it; `ScriptedMusicBeatState` = hscript variant |
| Asset loading | `source/funkin/Paths.hx` + `source/funkin/Assets.hx` | `Paths.image/.getSparrowAtlas/ sound`; Psych filesystem-audio fallback lives here |
| Memory / caching | `source/funkin/FunkinMemory.hx` | `initialCache` boot warmup, `purgeCache`, `fromFile` fallback |
| Preferences / FPS | `source/funkin/Preferences.hx` | FPS fully uncapped (commit 21d925cc8): framerate getters force 0, VSync forced OFF |
| Mods (V-Slice) | `source/funkin/modding/PolymodHandler.hx` | rules mirror `assets/` paths |
| Mods (Psych 1.0.4) | `source/funkin/modding/PsychModHandler.hx` | NEW parity work in progress |
| Chart/song data | `source/funkin/data/` (registry pattern) | see data/AGENTS.md |
| Gameplay core | `source/funkin/play/PlayState.hx` | see play/AGENTS.md |
| UI screens | `source/funkin/ui/` | see ui/AGENTS.md |
| Chart editor | `source/funkin/ui/debug/charting/` | gated by `FEATURE_CHART_EDITOR` flag |
| Audio | `source/funkin/audio/` | see audio/AGENTS.md |

## CODE MAP
(LSP: Haxe server NOT installed; codegraph index returns noise for `.hx` — verify with Read.)
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `main` | entry | `source/Main.hx` | constructs FlxGame, sets VSync/framerate |
| `InitState` | state | `source/funkin/InitState.hx` | boot, focus handling, cache warmup |
| `FunkinMemory` | static | `source/funkin/FunkinMemory.hx` | graphic/audio cache, purge on state switch |
| `Paths` | static | `source/funkin/Paths.hx` | asset path resolution (3 coupled conventions) |
| `Preferences` | static | `source/funkin/Preferences.hx` | save-backed settings |
| `PlayState` | state | `source/funkin/play/PlayState.hx` | the gameplay state |
| `Conductor` | static | `source/funkin/Conductor.hx` | BPM/beat/step timing, offsets |
| `FunkinSound` | class | `source/funkin/audio/FunkinSound.hx` | sound cache + Psych FS-audio fallback |
| `PolymodHandler` | static | `source/funkin/modding/PolymodHandler.hx` | V-Slice mod lifecycle |

## CONVENTIONS
- Format: `hxformat.json` — 2-space indent, 160 max line; JSON via Prettier (`.prettierrc.js`); quality via `checkstyle.json`. See `CODESTYLE.md`.
- Build order: **Windows debug first, then html5**. Commit ONLY after Windows build green; html5 commit only if fixes were needed.
- Commit after every successful build/feature: short imperative subject, **never push unless explicitly asked**.
- Optimizations must be active in **debug AND release** builds (no `#if !debug` gating).
- Deps pinned in `hmm.json` (`hmm reinstall [lib]` to sync).

## ANTI-PATTERNS (THIS PROJECT)
- Never `git add` `.omo/`, `build/`, `export/`, or `assets/` (gitlink — asset edits don't belong in this repo's git).
- Never touch/delete `assets\songs\finale\` or `assets\preload\data\songs\finale\` (protected song).
- No type suppression (`cast ... null`, `untyped` abuse) to silence errors — fix the type.
- Do NOT execute `DIRECTORY_REORG_PLAN.md` — asset paths are coupled in 3 places (project.hxp `configureAssets()`, Paths/PolymodHandler, mod mirroring); moving `assets/` breaks every mod.
- Do NOT use subagents/task delegation (user ban for this project) — work directly.

## UNIQUE STYLES
- Feature flags in `project.hxp` (e.g. `FEATURE_CHART_EDITOR`, `FEATURE_VIDEO_PLAYBACK`, `FEATURE_DEBUG_DISPLAY` = FPS counter) — checked in build log output.
- flixel `removeUnused` destroys non-persistent graphics on EVERY state switch → menus reload from disk; mitigated by `FunkinMemory.initialCache` warmup (menuBG, mainmenu atlases, freeplay art).
- States usually opened as substates to preserve parent graphics (Freeplay from menu).

## COMMANDS
```bash
haxelib run lime build windows -debug    # primary; kill stale RocketEngine.exe first if lime.ndll locked
haxelib run lime build windows           # release (use for honest FPS numbers)
haxelib run lime build html5 -debug      # secondary target
git add source/ project.hxp              # NEVER assets/ or .omo/
```

## NOTES
- Windows debug builds are slower than HTML5 JIT (hxcpp -Od + pointer checks) — don't judge FPS from debug.
- Measure FPS in-game via `FEATURE_DEBUG_DISPLAY` counter.
- PowerShell 5.1 shell: no `&&`, no `rg` (use `Select-String`).
- Ongoing streams (as of this commit): FPS Plus port (GPUBitmap/ImageCache/AudioCache), menu-load optimization, then: Shaggy mod port, Shaggy×Matt (Kade) port, multikey + V-slice↔Psych chart converter.
