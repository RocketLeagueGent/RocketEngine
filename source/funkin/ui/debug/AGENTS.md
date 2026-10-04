# source/funkin/ui/debug — editors & debug overlays (109 hx)

## OVERVIEW
In-game editors and debug tools. The chart editor (69 hx) is where chart-conversion work (V-slice↔Psych) must land.

## STRUCTURE
```
charting/ (69)      # chart editor: main state, components/, toolboxes/, dialogs/, handlers/
stageeditor/ (21)   # stage editor (+ components/)
anim/ (2), playtest/ (2), results/ (2), stage/ (6), dialogue/ (1), latency/ (1), stats/ (1)
DebugMenuSubState, FunkinDebugDisplay, WaveformTestState, GraphicCursorCross  # direct
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Chart editor UI/behavior | `charting/` — entry state + `components/`, `toolboxes/`, `dialogs/`, `handlers/` |
| Chart conversion (future) | `charting/` handlers/dialogs — add Psych↔V-slice converter here |
| Stage editing | `stageeditor/` |
| FPS/debug overlay | `FunkinDebugDisplay` (FEATURE_DEBUG_DISPLAY) |

## CONVENTIONS / GOTCHAS
- Gated by project.hxp feature flags (`FEATURE_CHART_EDITOR`, `FEATURE_ANIMATION_EDITOR`, `FEATURE_STAGE_EDITOR`) — current debug build ships some flags OFF; verify the flag before assuming code is reachable.
- Chart data itself lives in `source/funkin/data/song/` (parsers) — editor only manipulates it.
- Do not duplicate data-parsing logic here; call `data/` APIs (see data/AGENTS.md).
