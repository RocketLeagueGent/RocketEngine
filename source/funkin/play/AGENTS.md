# source/funkin/play — gameplay core (77 hx)

## OVERVIEW
The gameplay loop: PlayState, notes, characters, events, cutscenes, scoring, pause/game-over.

## STRUCTURE
```
PlayState.hx        # THE gameplay state (largest file — read in sections)
event/ (24)         # per-song event system (dispatch + handlers)
notes/ (16)         # note types, strumlines, holds
character/ (7)      # character parsing/animation wrapper
cutscene/ (8)       # dialogue/cutscene playback
stage/ (6), components/ (5), song/ (2), scoring/ (1)
Countdown, PauseSubState, GameOverSubState, GitarooPause,
ResultState, ResultScore, PlayStatePlaylist  # direct
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Note behavior / new note types | `notes/` |
| Song events | `event/` + registry glue in `data/event/` (`SongEventRegistry` warns on unhandled kinds) |
| Character logic | `character/` (JSON format work goes to `data/character/`) |
| Results/pause/game-over UI | direct files above |

## CONVENTIONS / GOTCHAS
- Gameplay timing = `Conductor` (root code map) — never re-derive BPM/step math locally.
- Events with no handler trace `WARNING: No event handler for event with kind` — add handlers in `event/`, not inline in PlayState.
- Psych-parity event mapping (future backlog) belongs in `event/` + `data/event/`.
