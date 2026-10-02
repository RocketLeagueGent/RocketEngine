# Directory Reorganization Plan — RocketEngine

**Status: PROPOSAL. Nothing has been moved. Approval required before any file operations.**

## Why this is risky (read first)

Asset paths in this project are resolved by **convention in three coupled places**:

1. `project.hxp` `configureAssets()` — defines ~13 asset libraries
   (`default`, `songs`, `shared`, `videos`, `tutorial`, `week1`…`week7`,
   `weekend1`, `sserafim`) and their source roots.
2. `funkin.Paths` + `PolymodHandler` — resolve `Paths.image()` /
   `Paths.file()` etc. by relative convention.
3. **Polymod mods** — installed mods mirror `assets/…` paths. Moving anything
   under `assets/` **breaks every existing V-Slice mod.**

Generated dirs (`build/`, `export/`) are gitignored and out of scope.

---

## Findings

### 1. Newgrounds remnants (safe to delete — NG removal is complete)

| Item | Notes |
|---|---|
| `art/newgrounds/` | directory left over from NG integration |
| `art/genNGEvents.py` | NG event-registration script (duplicated) |
| `scripts/genNGEvents.py` | identical NG script (duplicated) |

### 2. `art/` vs `scripts/` duplication

These exist in **both** directories and are candidates for a single home:

- `convertOGGToMP3.sh`, `Postbuild.hx`, `SongConverter.hx`
- `macos-codesign.sh`, `macos-universal.sh`
- `optimizePNG.sh`, `resizeHealthIcons.sh`, `genNGEvents.py`

Before deleting any copy, references must be grepped across `project.hxp`,
`.github/`, `docs/`, and `*.md` — only the **unreferenced** duplicates go.

The remaining `art/` content (`banner.png`, `favicon`-style art,
`preloaderArt.png`, `weekend1Seperated.psd`, `icons/`, `flashFiles/`, …) is
design-source material and **stays put**.

### 3. Bug found & fixed (code change, not a move)

`project.hxp` `EXCLUDE_ASSETS_CENSORED` / `EXCLUDE_ASSETS_UNCENSORED`
referenced `stressCutscene.mp4` / `stressPicoCutscene.mp4` /
`stress*-censored.mp4`, but those files ship as **`.mkv`**. The globs could
never match, so censorship-platform asset filtering was silently broken.
**Fixed in this change** (`.mkv` extensions corrected).

### 4. `assets/videos/videos/` double nesting — by design, leave alone

`project.hxp` does `addAssetPath("assets/videos", …, "videos", …)`: the
library root is `assets/videos` **and** the loader prepends `videos/`, which
is why files live in `assets/videos/videos/`. Renaming this would require a
coordinated `project.hxp` + `Paths` change and would break mods referencing
the path. **No action.**

### 5. Root layout (current)

```
.github/  art/  assets/  build/  docs/  example_mods/  export/
scripts/  source/  templates/  tools/          (+ .codegraph/.omo/.vscode tool state)
```

`source/funkin/` is well-organized — **out of scope entirely.**

---

## Proposed phases (each individually approved before execution)

### Phase 1 — zero-risk cleanup (recommended)
1. Delete `art/newgrounds/`.
2. Delete both `genNGEvents.py` copies.
3. Grep references for the 7 duplicated build scripts listed in §2;
   delete only the unreferenced duplicates (prefer keeping `scripts/` copies).
- **Verify:** grep shows zero dangling references → `lime build html5 -debug`
  exits 0 → git diff reviewed.

### Phase 2 — root tidy (optional, low value, higher risk)
- Only if desired: `templates/` and `tools/` have never been audited for
  references; a mistake here breaks CI/build. Default recommendation:
  **skip Phase 2** — the current root layout is conventional for FNF projects.

### Phase 3 — `assets/` restructuring
- **Recommendation: none.** Mod compatibility outranks tidiness.

---

## Verification checklist (per phase)

- [ ] `Select-String` reference grep over `project.hxp`, `.github/`, `docs/`, `*.md`
- [ ] `lime build html5 -debug` exit 0
- [ ] Git diff reviewed file-by-file (moves as renames, nothing unexpected)
- [ ] Game boots + freeplay loads a song (user-run)
