package funkin.graphics;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.Texture;
import openfl.utils.Assets;

/**
 * Moves a cached graphic's pixels out of system RAM and into a Stage3D texture,
 * then drops the CPU copy — the RAM win from FPS Plus's GPUBitmap port.
 *
 * Native (cpp/hl) only: flixel renders through Stage3D there, so a texture-backed
 * BitmapData draws directly from VRAM. html5 keeps CPU bitmaps (no-op stub).
 *
 * The replacement BitmapData is created with `shared = false`, so when
 * FunkinMemory purges the graphic, `BitmapData.dispose()` frees the GL texture too
 * (openfl only skips the GPU free for shared textures — FPS Plus leaked here).
 */
class GPUBitmap
{
  /** Set to false to restore CPU-backed bitmaps everywhere (debug flip). */
  public static var enabled:Bool = true;

  /**
   * Uploads `graphic.bitmap` to a Stage3D texture and replaces it with a
   * texture-backed BitmapData, freeing the system-RAM pixel buffer.
   *
   * @return True if the graphic now lives in VRAM; false if it was skipped
   *         (disabled, already GPU-backed, no 3D context, or upload failed —
   *         in every failure case the CPU bitmap stays intact).
   */
  public static function toGPU(graphic:FlxGraphic):Bool
  {
    #if (cpp || hl)
    if (!enabled) return false;

    var old:Null<BitmapData> = graphic.bitmap;
    // readable == false / image == null ⇒ already texture-backed or disposed.
    if (old == null || !old.readable || old.image == null) return false;

    var context = FlxG.stage.context3D;
    if (context == null) return false;

    try
    {
      var texture:Texture = context.createTexture(old.width, old.height, Context3DTextureFormat.BGRA, true);
      texture.uploadFromBitmapData(old);

      // shared = false: owns the texture, so a later dispose() frees the VRAM too.
      var gpu:BitmapData = BitmapData.fromTexture(texture, false);

      // Never let openfl's asset cache keep the CPU instance alive after the swap.
      if (Assets.cache != null && Assets.cache.getBitmapData(graphic.key) == old) Assets.cache.removeBitmapData(graphic.key);

      graphic.bitmap = gpu; // FlxGraphic's setter refreshes width/height.
      old.dispose(); // Frees the system-RAM pixel buffer — the point of all this.
      old.disposeImage(); // Belt-and-suspenders, same as FPS Plus does.
      return true;
    }
    catch (e:Dynamic)
    {
      FlxG.log.warn('GPUBitmap: keeping CPU copy of "${graphic.key}" - $e');
      return false;
    }
    #else
    return false;
    #end
  }
}
