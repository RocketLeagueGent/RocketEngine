package funkin.audio;

import openfl.utils.Assets;

/**
 * Tracks every sound/music key `Paths` hands out so they can be evicted from
 * openfl's asset cache when the state switches. Ported from FPS Plus (AudioCache).
 *
 * Why: `FlxSound.loadEmbedded` → `Assets.getSound(key, true)` stores the decoded
 * Sound in openfl's cache, but those keys never enter FunkinMemory's maps, so
 * `purgeSoundCache` never saw them — they accumulated for the whole session.
 */
class AudioCache
{
  /** Keys returned by Paths.sound since the last clear(). */
  public static var trackedSounds:Array<String> = [];

  /** Keys returned by Paths.music since the last clear(). */
  public static var trackedMusic:Array<String> = [];

  public static function trackSound(key:String):Void
  {
    if (!trackedSounds.contains(key)) trackedSounds.push(key);
  }

  public static function trackMusic(key:String):Void
  {
    if (!trackedMusic.contains(key)) trackedMusic.push(key);
  }

  /**
   * Drops every tracked key from openfl's asset cache, then forgets them.
   * Keys still owned by FunkinMemory's permanent cache (freakyMenu, menu SFX…)
   * must be filtered out by `isPermanent`, or they reload from disk every purge.
   *
   * @param isPermanent Return true for keys that must stay resident.
   */
  public static function clear(isPermanent:String->Bool):Void
  {
    for (sound in trackedSounds)
    {
      if (!isPermanent(sound)) Assets.cache.clear(sound);
    }
    for (music in trackedMusic)
    {
      if (!isPermanent(music)) Assets.cache.clear(music);
    }

    trackedSounds = [];
    trackedMusic = [];
  }
}
