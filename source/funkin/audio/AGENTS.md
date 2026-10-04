# source/funkin/audio — sound & music (17 hx)

## OVERVIEW
Sound wrappers, channel grouping, waveform/spectrum visualization.

## STRUCTURE
```
FunkinSound.hx    # main sound wrapper: cache, Psych filesystem-audio fallback,
                  # waveformData, loadEmbedded probe bypass
FlxStreamSound.hx # streamed large audio (songs)
SoundGroup.hx     # SFX channel group (playing/volume bookkeeping)
VoicesGroup.hx    # vocals; legacy shared-Voices.ogg path still supported
visualize/ (10)   # spectrum/spectrogram visualizers (SpectogramSprite etc.)
waveform/ (3)     # waveform rendering
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Play a game sound | `FunkinSound.play`/`playMusic` patterns (callers across `ui/`) |
| Psych mod audio (filesystem .ogg) | `FunkinSound` fallback + `Assets.hx` / `Paths.sound` |
| Song streaming | `FlxStreamSound` + `play/song/` |
| Visualizer | `visualize/` |

## CONVENTIONS / GOTCHAS
- `FunkinSound` deliberately bypasses flixel's `Assets.exists` probe for filesystem audio (comments at :444/:526) — don't "fix" it back; Psych mods depend on it.
- Volumes are centralized in `SoundGroup`/`VoicesGroup`; `Preferences` writes go through them (no raw `FlxG.sound` in UI code).
