# source/funkin/graphics — sprites, cameras, shaders (39 hx)

## OVERVIEW
Drawing primitives: FunkinSprite family, camera stack, GLSL shaders, framebuffer effects, video.

## STRUCTURE
```
direct: FunkinSprite, ScriptedFunkinSprite, FunkinAnimationController,
        FunkinCamera, FunkinCameraFrontEnd
shaders/ (24)     # GLSL — acid/grayscale/graphics-dunce-style filters, wormhole, etc.
framebuffer/ (6)  # render-to-texture helpers
video/ (3)        # video playback (FEATURE_VIDEO_PLAYBACK, hxvlc)
rendering/ (1)
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Custom sprite class | extend `FunkinSprite` (not raw FlxSprite) |
| New shader / camera filter | `shaders/` |
| FPS-Plus GPUBitmap port (pending) | new caching class here; wire via `Paths`/`FunkinMemory` (root code map) |

## CONVENTIONS / GOTCHAS
- Non-persistent sprites get destroyed on state switch (flixel `removeUnused`) — graphics must be re-cacheable via `FunkinMemory`; that's exactly why the GPUBitmap/ImageCache port targets this dir.
- Shader uniforms follow the existing `shaders/` naming (`uTime`, `uCameraBounds`) — match it.
