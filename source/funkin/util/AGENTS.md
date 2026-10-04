# source/funkin/util — shared utilities (72 hx)

## OVERVIEW
Flat grab-bag of cross-cutting helpers + compile-time macros/plugins. Check here before writing any new helper function.

## STRUCTURE
```
direct (32):  Constants, MathUtil, EaseUtil, FileUtil, PlatformUtil, DeviceUtil,
  MemoryUtil, InputUtil, MouseUtil, TouchUtil, FlxTweenUtil, BitmapUtil, ReflectUtil,
  SerializerUtil, SortUtil, VersionUtil, WindowUtil, ClipboardUtil, DateUtil, TimerUtil,
  HapticUtil, AnsiUtil, CLIUtil, BezierUtil, SRTUtil, SwipeUtil, TrackerUtil, ...
macro/ (13):     compile-time macros (build macros, abstracts, typedef plumbing)
tools/ (12):     developer tools
plugins/ (8):    plugin classes
assets/ (3), logging/ (3), file/ (1)
```

## WHERE TO LOOK
| Task | File |
|------|------|
| FPS constants, sizes, version strings | `Constants.hx` |
| File read/write helpers | `FileUtil.hx` (+ `file/`, `util/assets/`) |
| Platform / mobile detection | `PlatformUtil.hx`, `DeviceUtil.hx` |
| Tween easings | `EaseUtil.hx` |
| Logging | `logging/` |
| New build macro | `macro/` |

## CONVENTIONS / GOTCHAS
- Functions here must be stateless/`static` and dependency-free (no PlayState imports) to avoid cycles.
- Memory/perf helpers (`MemoryUtil`) feed the optimization stream — keep gating unconditional (root: debug AND release).
