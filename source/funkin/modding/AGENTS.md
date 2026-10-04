# source/funkin/modding — mod loading (22 hx)

## OVERVIEW
Two parallel mod systems: V-Slice (Polymod) and the in-progress Psych 1.0.4 port.

## STRUCTURE
```
PolymodHandler.hx    # V-Slice mod lifecycle; rules mirror assets/ paths
PsychModHandler.hx   # Psych 1.0.4 parity (NEW — ongoing)
ModStore.hx, PolymodErrorHandler.hx, IScriptedClass.hx
base/ (11)           # scripted-class base plumbing
module/ (3)          # hscript module glue
events/ (3)          # mod-facing event hooks
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| V-Slice mod rules / precedence | `PolymodHandler.hx` |
| Psych mod support (folders, data, audio) | `PsychModHandler.hx` + audio fallback in `audio/FunkinSound.hx`, `Assets.hx` |
| Scripted state/class API | `base/`, `IScriptedClass` |

## CONVENTIONS / GOTCHAS
- Mod paths mirror `assets/` exactly — a Psych folder layout differs from V-Slice; keep them isolated so both can coexist.
- Never break existing V-Slice mods when adding Psych support (root: DIRECTORY_REORG_PLAN warning applies here too).
- Example mods to test against: `example_mods/introMod`, `example_mods/testing123`.
