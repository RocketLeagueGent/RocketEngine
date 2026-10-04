# source/funkin/data — registries & parsers (45 hx)

## OVERVIEW
Registry pattern + JSON parse/write for every game data type. This is the chart/song data home — the V-slice↔Psych converter's data layer lives here.

## STRUCTURE
```
BaseRegistry.hx, DefaultRegistryImpl.hx, IRegistryEntry.hx  # registry core
JsonFile.hx, DataParse.hx, DataWrite.hx, DataError.hx       # JSON plumbing
song/ (14)      # song/charts/metadata parse+write — converter source & target
dialogue/ (6), freeplay/ (6), event/ (2), notestyle/ (2),
stage/ (2), stickers/ (2), story/ (2), animation/ (1), character/ (1)
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Song/chart parsing | `song/` (see also root `docs/FNFC-SPEC.md`) |
| Event data definitions | `event/` (runtime handlers are in `play/event/`) |
| Add a new data type | implement `IRegistryEntry`, register in `DefaultRegistryImpl` |
| Character/stage JSON shape | `character/`, `stage/` |

## CONVENTIONS / GOTCHAS
- Every entry carries a version rule — "if a version rule is not specified, do not check against it" (BaseRegistry/SongRegistry comments); respect it when extending.
- Parse errors throw `DataError` — do not swallow; callers decide fallback.
- Round-trip safety: anything you `parse` you must also be able to `write` back without losing fields (converter requirement).
