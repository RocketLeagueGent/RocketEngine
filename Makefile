# ==============================================================================
#  RocketEngine  --  Makefile for Windows
#  Friday Night Funkin' V-Slice fork (Haxe / HaxeFlixel / OpenFL / Lime)
#
#  Project file is project.hxp (NOT Project.xml).  Output goes to
#  export/debug/... and export/release/...  (see project.hxp configureOutputDir)
# ==============================================================================
#
#  USAGE
#    make                    show this help
#    make windows            Windows debug build      <- primary target
#    make windows-release    Windows release build    <- honest FPS numbers
#    make html5-debug        HTML5 debug build        <- secondary target
#    make html5              HTML5 release build
#    make run                build + launch the debug exe
#    make run-release        build + launch the release exe
#    make kill               force-kill a running RocketEngine.exe
#    make clean              clean Windows build output
#    make clean-html5        clean HTML5 build output
#    make distclean          clean both
#    make deps               sync haxelib dependencies from hmm.json
#    make submodules         init/update the assets + art submodules
#    make doctor             report toolchain + submodule state
#    make flags              print the resolved Lime feature-flag table
#
#  ALIASES
#    all = debug, windows = debug, windows-release = release
#
#  EXTRA DEFINES
#    make windows DEFINES="-DGITHUB_BUILD -DFEATURE_DEBUG_DISPLAY"
#    Any -D flag accepted by `lime build` can be passed through DEFINES.
#
#  WHY SHELL IS PINNED
#    Recipes are shell scripts, so the shell must be deterministic.  SHELL is
#    pinned to cmd.exe because the alternative is worse, not better:
#      * SHELL unset -> Make picks sh.exe if Git Bash is on PATH, else cmd.exe,
#        so the SAME Makefile silently behaves differently per machine.
#      * Under sh, `echo` word-splits its arguments and collapses the column
#        alignment used by `make help`, while `echo.`, a bare `echo`, and
#        unquoted `(...)` are syntax errors instead of plain text.
#    Every recipe below shells out only to real .exe programs (haxelib, git,
#    taskkill), so nothing depends on the shell beyond plain `echo`.
#
#    .ONESHELL: is required as well: a Windows-native Make will otherwise try to
#    CreateProcess() a simple recipe line directly instead of handing it to the
#    shell.  Consequence: only the FIRST line of a recipe may carry `@`.
#
# ==============================================================================

SHELL := cmd.exe

# ------------------------------------------------------------------------------
# Toolchain
# ------------------------------------------------------------------------------
LIME     := haxelib run lime
EXE_NAME := RocketEngine

# Output paths come from project.hxp configureOutputDir():
#   app.path = export/{debug|release}[-tracy]/
DEBUG_OUT     := export/debug
RELEASE_OUT   := export/release
DEBUG_EXE     := $(DEBUG_OUT)/windows/bin/$(EXE_NAME).exe
RELEASE_EXE   := $(RELEASE_OUT)/windows/bin/$(EXE_NAME).exe
HTML5_DEBUG   := $(DEBUG_OUT)/html5/bin/index.html
HTML5_RELEASE := $(RELEASE_OUT)/html5/bin/index.html

# Submodules are required for a real build; project.hxp configureAssets() globs
# assets/preload, assets/songs, assets/week1..7, assets/weekend1, assets/sserafim.
# NOTE: probe a path INSIDE each submodule. The bare gitlink directory always
# exists on disk even when uninitialized, which would report a false "present".
ASSETS_SENTINEL := assets/preload
ART_SENTINEL    := art/readme.txt

# ------------------------------------------------------------------------------
# Parse-time sanity warnings (pure make, no shell involved)
# ------------------------------------------------------------------------------
ifeq ($(wildcard $(ASSETS_SENTINEL)),)
$(warning ===========================================================)
$(warning WARNING: assets/ submodule is NOT initialized.)
$(warning   Builds will fail or ship empty. Run:  make submodules)
$(warning ===========================================================)
endif

ifeq ($(wildcard $(ART_SENTINEL)),)
$(warning NOTE: art/ submodule is not initialized - optional, used only for)
$(warning       credits/README/CHANGELOG asset entries.  make submodules)
endif

# ------------------------------------------------------------------------------
# Dependency probe, used by `doctor` and `deps`.
# Pure make string ops over `haxelib list` -> no shell portability traps.
# ------------------------------------------------------------------------------
haxelib_list := $(shell haxelib list 2>&1)

# `hxp` is the project-file runtime itself, so it is mandatory above all else.
# The rest come from project.hxp configureHaxelibs() for a Windows desktop build.
REQUIRED_LIBS := hxp polymod flixel flixel-addons flixel-animate json2object \
	jsonpath jsonpatch thx.core thx.semver hxvlc funkin.vis grig.audio \
	FlxPartialSound haxeui-core haxeui-flixel

missing_libs := $(strip $(foreach l,$(REQUIRED_LIBS),\
	$(if $(findstring $(l):,$(haxelib_list)),,$(l) )))

# ------------------------------------------------------------------------------
# Targets
# ------------------------------------------------------------------------------
.DEFAULT_GOAL := help
.NOTPARALLEL:
.ONESHELL:

.PHONY: help all windows windows-release debug release html5 html5-debug \
        run run-release kill clean clean-html5 distclean deps submodules \
        doctor flags

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
help:
	@echo ==============================================================
	echo  RocketEngine - Windows Makefile
	echo ==============================================================
	echo.
	echo  BUILD
	echo    make windows          Windows debug build (primary target)
	echo    make windows-release  Windows release build (honest FPS numbers)
	echo    make html5-debug      HTML5 debug build (secondary target)
	echo    make html5            HTML5 release build
	echo.
	echo    aliases: all=debug  windows=debug  windows-release=release
	echo.
	echo  RUN
	echo    make run           Build and launch the debug exe
	echo    make run-release   Build and launch the release exe
	echo    make kill          Force-kill a running RocketEngine.exe
	echo.
	echo  CLEAN
	echo    make clean         Clean Windows build output
	echo    make clean-html5   Clean HTML5 build output
	echo    make distclean     Clean both targets
	echo.
	echo  SETUP
	echo    make submodules    Init/update assets + art submodules
	echo    make deps          Sync haxelibs from hmm.json  (needs hmm)
	echo    make doctor        Report toolchain and submodule state
	echo    make flags         Print resolved Lime feature flags
	echo.
	echo  EXTRA DEFINES
	echo    make windows DEFINES=-DGITHUB_BUILD
	echo.
	echo  NOTES
	echo    Build order per AGENTS.md - Windows debug first, then html5.
	echo    Windows debug is hxcpp -Od with pointer checks, so do NOT judge
	echo    FPS from it. Use make windows-release for real numbers.
	echo    project.hxp renders the enabled/disabled feature flag table on
	echo    every build; make flags shows it without building.
	echo ==============================================================

# ------------------------------------------------------------------------------
# Builds
# ------------------------------------------------------------------------------
all: debug

# `make windows` / `make windows-release` are the platform-named spellings of
# `make debug` / `make release`. Windows debug is the primary target per
# AGENTS.md, so `windows` maps to the debug build.
windows: debug

windows-release: release

debug:
	@$(LIME) build . windows -debug $(DEFINES)

release:
	@$(LIME) build . windows $(DEFINES)

html5-debug:
	@$(LIME) build . html5 -debug $(DEFINES)

html5:
	@$(LIME) build . html5 $(DEFINES)

# ------------------------------------------------------------------------------
# Run
# A stale RocketEngine.exe holds a lock on lime.ndll, so always kill first.
# ------------------------------------------------------------------------------
run: kill
	@$(LIME) run . windows -debug $(DEFINES)

run-release: kill
	@$(LIME) run . windows $(DEFINES)

# taskkill exits non-zero when the process is absent, which is the normal case;
# `-` tells Make to ignore the failure so `make run` still proceeds.
kill:
	-taskkill /F /IM $(EXE_NAME).exe

# ------------------------------------------------------------------------------
# Clean
# ------------------------------------------------------------------------------
clean:
	@$(LIME) clean . windows

clean-html5:
	@$(LIME) clean . html5

distclean: clean clean-html5

# ------------------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------------------
submodules:
	@git submodule update --init --recursive

deps:
	@echo Missing haxelibs: $(if $(missing_libs),$(missing_libs),none)
	hmm reinstall

doctor:
	@echo ==============================================================
	echo  RocketEngine doctor
	echo ==============================================================
	echo.
	echo  GIT
	echo    branch: $(shell git rev-parse --abbrev-ref HEAD 2>&1)
	echo    head:   $(shell git rev-parse --short HEAD 2>&1)
	echo.
	echo  SUBMODULES  (a leading - means NOT initialized)
	git submodule status --recursive
	echo.
	echo    assets sentinel: $(ASSETS_SENTINEL) $(if $(wildcard $(ASSETS_SENTINEL)),present,MISSING)
	echo    art sentinel:    $(ART_SENTINEL) $(if $(wildcard $(ART_SENTINEL)),present,MISSING)
	echo.
	echo  HAXELIB DEPS REQUIRED BY project.hxp
	echo    missing: $(if $(missing_libs),$(missing_libs),none)
	echo.
	echo  BUILD OUTPUTS
	echo    debug exe:   $(DEBUG_EXE) $(if $(wildcard $(DEBUG_EXE)),present,not built)
	echo    release exe: $(RELEASE_EXE) $(if $(wildcard $(RELEASE_EXE)),present,not built)
	echo    html5 debug: $(HTML5_DEBUG) $(if $(wildcard $(HTML5_DEBUG)),present,not built)
	echo ==============================================================

# Prints the enabled/disabled feature-flag table project.hxp renders at build time.
flags:
	@$(LIME) display . windows