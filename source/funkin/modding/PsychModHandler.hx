package funkin.modding;

import funkin.data.song.SongData.SongChartData;
import funkin.data.song.SongData.SongMetadata;
import funkin.data.song.importer.FNFLegacyData;
import funkin.data.song.importer.FNFLegacyImporter;
import funkin.play.song.Song;
import funkin.util.Constants;
import funkin.util.FileUtil;

using StringTools;

/**
 * Metadata describing a Psych Engine format mod discovered in the mods folder.
 *
 * Psych mods are plain folders WITHOUT a `_polymod_meta.json` (that manifest marks a
 * V-Slice mod, which Polymod already handles). Psych mods use `pack.json` for optional
 * metadata and ship content in Psych's folder layout:
 *
 * ```
 * mods/<id>/pack.json
 * mods/<id>/songs/<song>/Inst.ogg         (+ Voices.ogg)
 * mods/<id>/data/<song>/<song>-<diff>.json
 * mods/<id>/characters/<char>.json
 * mods/<id>/stages/<stage>.json
 * mods/<id>/scripts/*.lua|*.hx            (runs everywhere)
 * mods/<id>/songs/<song>/*.lua|*.hx       (runs for that song only)
 * ```
 */
typedef PsychModMetadata =
{
  var id:String;
  var title:String;
  var description:String;
  var runsGlobally:Bool;
  var rootPath:String;
  var songs:Array<String>;
  var characters:Array<String>;
  var stages:Array<String>;
  var scripts:Array<String>;
}

/**
 * Discovers and indexes Psych Engine 1.0.x mods living in the same mods folder as
 * V-Slice mods, so Psych content can be surfaced (Freeplay songs, characters, stages)
 * without going through Polymod, which cannot load folders that lack a manifest.
 *
 * Mirrors Psych's `backend/Mods.hx` folder rules.
 */
class PsychModHandler
{
  /**
   * Folders inside the mods ROOT that are shared content rather than mods.
   * Matches Psych's `Mods.ignoreModFolders`.
   */
  public static final IGNORED_FOLDERS:Array<String> = [
    'characters', 'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds', 'shaders', 'videos',
    'images', 'stages', 'weeks', 'fonts', 'scripts', 'achievements'
  ];

  /** Content folders that mark a directory as containing Psych-style files. */
  static final PSYCH_CONTENT_MARKERS:Array<String> = [
    'songs', 'data', 'characters', 'stages', 'scripts', 'weeks', 'custom_events', 'custom_notetypes', 'images'
  ];

  static final AUDIO_EXTENSIONS:Array<String> = ['ogg', 'mp3', 'wav'];

  /** All successfully indexed Psych mods, in scan order. */
  public static var loadedMods:Array<PsychModMetadata> = [];

  /** Normalized song id -> folder containing `<song>-<diff>.json` charts. */
  public static var chartDirs:Map<String, String> = [];

  /** Normalized song id -> folder containing `Inst.*`/`Voices.*` audio. */
  public static var audioDirs:Map<String, String> = [];

  /** Normalized song id -> absolute path of the owning mod folder. */
  public static var songMods:Map<String, String> = [];

  /** Normalized song id -> script files inside `songs/<song>/`. */
  public static var songScripts:Map<String, Array<String>> = [];

  /** Normalized song ids in scan order (stable for list UIs). */
  public static var allSongIds:Array<String> = [];

  /** Normalized character id -> absolute path of its `.json` definition. */
  public static var characterFiles:Map<String, String> = [];

  /** Normalized stage id -> absolute path of its `.json` definition. */
  public static var stageFiles:Map<String, String> = [];

  /** Scripts inside `scripts/` that run everywhere (Psych global scripts). */
  public static var globalScripts:Array<String> = [];

  /**
   * Scan the mods folder(s) for Psych Engine format mods.
   * Safe to call multiple times (e.g. on hot reload); replaces the previous index.
   */
  public static function scanMods():Void
  {
    loadedMods = [];
    chartDirs = [];
    audioDirs = [];
    songMods = [];
    songScripts = [];
    allSongIds = [];
    characterFiles = [];
    stageFiles = [];
    globalScripts = [];

    for (root in getModRoots())
    {
      for (entry in safeReadDir(root))
      {
        var modPath:String = '$root/$entry';
        if (!safeIsDirectory(modPath)) continue;
        if (IGNORED_FOLDERS.contains(entry.toLowerCase())) continue;

        // V-Slice mods carry a Polymod manifest; those belong to Polymod, not us.
        if (safeFileExists('$modPath/_polymod_meta.json')) continue;
        if (!looksLikePsychMod(modPath)) continue;

        var meta:Null<PsychModMetadata> = indexMod(entry, modPath);
        if (meta != null) loadedMods.push(meta);
      }
    }

    trace('PsychModHandler: indexed ${loadedMods.length} Psych mod(s) with ${allSongIds.length} song(s), '
      + '${countKeys(characterFiles)} character(s), ${countKeys(stageFiles)} stage(s).');
  }

  public static function hasMods():Bool
  {
    return loadedMods.length > 0;
  }

  /**
   * Build registry entries for every indexed Psych Engine song by converting
   * each difficulty chart through `FNFLegacyImporter`.
   *
   * Each `<song>-<diff>.json` is parsed as FNF Legacy format; the first
   * successful parse provides the metadata, and every difficulty's chart data
   * is merged into one `SongChartData`. Songs that fail to parse are skipped
   * (with a trace) so one bad chart can't block the rest.
   * @return Songs ready to insert into `SongRegistry.entries`.
   */
  public static function buildSongEntries():Array<Song>
  {
    var result:Array<Song> = [];

    for (songId in allSongIds)
    {
      try
      {
        var diffs:Array<String> = listChartDifficulties(songId);
        if (diffs.length == 0) continue;

        // Default difficulties first, then custom ones alphabetically.
        diffs.sort(function(a:String, b:String):Int
        {
          var ia:Int = Constants.DEFAULT_DIFFICULTY_LIST.indexOf(a);
          var ib:Int = Constants.DEFAULT_DIFFICULTY_LIST.indexOf(b);
          if (ia == -1) ia = Constants.DEFAULT_DIFFICULTY_LIST.length * 10;
          if (ib == -1) ib = Constants.DEFAULT_DIFFICULTY_LIST.length * 10;
          if (ia != ib) return ia - ib;
          return a < b ? -1 : 1;
        });

        var metadata:Null<SongMetadata> = null;
        var chart:Null<SongChartData> = null;
        var parsedDiffs:Array<String> = [];

        for (diff in diffs)
        {
          var chartPath:Null<String> = getChartPath(songId, diff);
          if (chartPath == null) continue;

          var raw:Null<String> = FileUtil.readStringFromPath(chartPath);
          if (raw == null || raw.length == 0) continue;

          var legacy:Null<FNFLegacyData> = FNFLegacyImporter.parseLegacyDataRaw(raw, chartPath);
          if (legacy == null) continue;

          var parsedChart:SongChartData = FNFLegacyImporter.migrateChartData(legacy, diff);

          if (metadata == null || chart == null)
          {
            metadata = FNFLegacyImporter.migrateMetadata(legacy, diff);
            chart = parsedChart;
          }
          else
          {
            // Merge additional difficulty files into the shared chart data.
            for (k => v in parsedChart.notes) chart.notes.set(k, v);
            for (k => v in parsedChart.scrollSpeed) chart.scrollSpeed.set(k, v);
            if (chart.events.length == 0) chart.events = parsedChart.events;
          }
          parsedDiffs.push(diff);
        }

        if (metadata == null || chart == null || parsedDiffs.length == 0) continue;

        metadata.playData.difficulties = parsedDiffs;

        result.push(Song.buildRaw(songId, [metadata], Constants.DEFAULT_VARIATION, [Constants.DEFAULT_VARIATION => chart], false, false));
      }
      catch (e:Dynamic)
      {
        trace('PsychModHandler: failed to register song ($songId): $e');
        continue;
      }
    }

    return result;
  }

  /**
   * Resolve a relative Psych-style key (`songs/x/Inst.ogg`, `characters/bf.json`, ...)
   * against the Psych mods folder, mirroring `Paths.modFolders()` lookup order:
   * current mod, then global mods, then every mod, then the mods root itself.
   * @return An absolute path, or null if no mod provides the key.
   */
  public static function resolve(key:String):Null<String>
  {
    #if sys
    var roots:Array<String> = [];
    if (currentModDirectory != null && currentModDirectory != '') roots.push(currentModDirectory);
    for (mod in loadedMods)
    {
      if (mod.runsGlobally && !roots.contains(mod.id)) roots.push(mod.id);
    }
    for (mod in loadedMods)
    {
      if (!roots.contains(mod.id)) roots.push(mod.id);
    }

    for (root in getModRoots())
    {
      for (modId in roots)
      {
        var candidate:String = '$root/$modId/$key';
        if (safeFileExists(candidate) || safeIsDirectory(candidate)) return candidate;
      }
      var loose:String = '$root/$key';
      if (safeFileExists(loose)) return loose;
    }
    #end

    return null;
  }

  /** The mod whose content should resolve first (mirrors Psych's `Mods.currentModDirectory`). */
  public static var currentModDirectory:String = '';

  public static function getModForSong(songId:String):Null<String>
  {
    return songMods.get(normalizeId(songId));
  }

  /**
   * Locate a chart file for a song, e.g. `data/bopeebo/bopeebo-hard.json`.
   * Falls back to `<song>.json` (Psych's default-difficulty naming) when no
   * difficulty-suffixed file exists.
   * @return An absolute path, or null if this engine has no chart for the song.
   */
  public static function getChartPath(songId:String, difficulty:String):Null<String>
  {
    var dir:Null<String> = chartDirs.get(normalizeId(songId));
    if (dir == null) return null;

    var lcId:String = normalizeId(songId);
    var lcDiff:String = difficulty.toLowerCase().trim();
    for (file in safeReadDir(dir))
    {
      var lc:String = file.toLowerCase();
      if (lc == '$lcId-$lcDiff.json') return '$dir/$file';
    }
    for (file in safeReadDir(dir))
    {
      var lc:String = file.toLowerCase();
      if (lc == '$lcId.json') return '$dir/$file';
    }
    return null;
  }

  /** List the difficulty suffixes found on disk for a song (e.g. easy, normal, hard). */
  public static function listChartDifficulties(songId:String):Array<String>
  {
    var result:Array<String> = [];
    var dir:Null<String> = chartDirs.get(normalizeId(songId));
    if (dir == null) return result;

    var lcId:String = normalizeId(songId);
    for (file in safeReadDir(dir))
    {
      var lc:String = file.toLowerCase();
      if (!lc.endsWith('.json') || !lc.startsWith(lcId)) continue;
      var diff:String = lc.substr(lcId.length, lc.length - lcId.length - 5);
      if (diff.startsWith('-')) diff = diff.substr(1);
      if (diff == '') diff = 'normal';
      if (!result.contains(diff)) result.push(diff);
    }
    return result;
  }

  /** Locate `Inst.*` audio for a song inside `songs/<song>/`. Null if absent. */
  public static function getInstPath(songId:String):Null<String>
  {
    return findAudio(songId, 'inst');
  }

  /** Locate `Voices.*` audio for a song inside `songs/<song>/`. Null if absent. */
  public static function getVoicesPath(songId:String):Null<String>
  {
    return findAudio(songId, 'voices');
  }

  /**
   * Resolve an engine-style audio request (`Inst`, `Voices`, `Voices-bf`, `Inst-erect`, ...)
   * against a Psych mod's `songs/<song>/` folder.
   *
   * Only an EXACT (case-insensitive) filename-stem match counts. Deliberately no fallback
   * to the unsuffixed file: `Song.buildPlayerVoiceList()` probes `Assets.exists(Paths.voices(id, '-bf'))`
   * and strips suffixes while the probe fails. If a missing `-bf` resolved to `Voices.ogg`,
   * both the player and opponent voice lists would resolve to the same file and it would
   * play twice.
   *
   * @param songId   Song id (normalized like Psych's `formatToSongPath`).
   * @param baseName Requested file stem without extension, e.g. `Inst`, `Voices-bf`.
   * @return The full filesystem path, or null when this mod has no exact match (callers
   *         then fall through to the manifest path, preserving vanilla behavior).
   */
  public static function getAudioPath(songId:String, baseName:String):Null<String>
  {
    var dir:Null<String> = audioDirs.get(normalizeId(songId));
    if (dir == null) return null;

    var lcTarget:String = baseName.toLowerCase();
    for (file in safeReadDir(dir))
    {
      var lc:String = file.toLowerCase();
      var dot:Int = lc.lastIndexOf('.');
      if (dot == -1) continue;
      if (!AUDIO_EXTENSIONS.contains(lc.substr(dot + 1))) continue;
      if (lc.substr(0, dot) == lcTarget) return '$dir/$file';
    }
    return null;
  }

  public static function getCharacterPath(charId:String):Null<String>
  {
    return characterFiles.get(normalizeId(charId));
  }

  public static function getStagePath(stageId:String):Null<String>
  {
    return stageFiles.get(normalizeId(stageId));
  }

  public static function getSongScripts(songId:String):Array<String>
  {
    var scripts:Null<Array<String>> = songScripts.get(normalizeId(songId));
    return scripts == null ? [] : scripts;
  }

  /** Normalize an id the way Psych's `Paths.formatToSongPath()` does. */
  public static function normalizeId(id:String):String
  {
    if (id == null) return '';
    return id.trim().toLowerCase().replace(' ', '-');
  }

  // ------------------------------------------------------------------ internals

  static function looksLikePsychMod(modPath:String):Bool
  {
    if (safeFileExists('$modPath/pack.json')) return true;
    for (folder in PSYCH_CONTENT_MARKERS)
    {
      if (safeIsDirectory('$modPath/$folder')) return true;
    }
    return false;
  }

  static function indexMod(id:String, modPath:String):Null<PsychModMetadata>
  {
    var title:String = id;
    var description:String = '';
    var runsGlobally:Bool = false;

    var packPath:String = '$modPath/pack.json';
    if (safeFileExists(packPath))
    {
      var pack:Null<Dynamic> = safeReadJson(packPath);
      if (pack != null)
      {
        if (pack.name != null) title = Std.string(pack.name);
        if (pack.description != null) description = Std.string(pack.description);
        if (pack.runsGlobally != null) runsGlobally = pack.runsGlobally == true;
      }
    }

    var meta:PsychModMetadata = {
      id: id,
      title: title,
      description: description,
      runsGlobally: runsGlobally,
      rootPath: modPath,
      songs: [],
      characters: [],
      stages: [],
      scripts: []
    };

    // Audio-bearing song folders: songs/<song>/Inst.*
    for (songFolder in safeReadDir('$modPath/songs'))
    {
      var songPath:String = '$modPath/songs/$songFolder';
      if (!safeIsDirectory(songPath)) continue;
      var songId:String = normalizeId(songFolder);
      if (songId == '') continue;
      if (!hasAudioWithPrefix(songPath, 'inst')) continue;

      if (!meta.songs.contains(songId)) meta.songs.push(songId);
      if (!audioDirs.exists(songId)) audioDirs.set(songId, songPath);
      registerSong(songId, modPath);

      var scripts:Array<String> = [];
      for (file in safeReadDir(songPath))
      {
        var lc:String = file.toLowerCase();
        if (lc.endsWith('.lua') || lc.endsWith('.hx')) scripts.push('$songPath/$file');
      }
      if (scripts.length > 0 && !songScripts.exists(songId)) songScripts.set(songId, scripts);
    }

    // Chart-bearing song folders: data/<song>/<song>[-diff].json
    for (chartFolder in safeReadDir('$modPath/data'))
    {
      var chartPath:String = '$modPath/data/$chartFolder';
      if (!safeIsDirectory(chartPath)) continue;
      var songId:String = normalizeId(chartFolder);
      if (songId == '') continue;
      if (!hasChartFiles(chartPath, songId)) continue;

      if (!meta.songs.contains(songId)) meta.songs.push(songId);
      if (!chartDirs.exists(songId)) chartDirs.set(songId, chartPath);
      registerSong(songId, modPath);
    }

    // Characters: characters/*.json
    for (file in safeReadDir('$modPath/characters'))
    {
      if (!file.toLowerCase().endsWith('.json')) continue;
      var charId:String = normalizeId(file.substr(0, file.length - 5));
      if (charId == '') continue;
      if (!characterFiles.exists(charId)) characterFiles.set(charId, '$modPath/characters/$file');
      if (!meta.characters.contains(charId)) meta.characters.push(charId);
    }

    // Stages: stages/*.json
    for (file in safeReadDir('$modPath/stages'))
    {
      if (!file.toLowerCase().endsWith('.json')) continue;
      var stageId:String = normalizeId(file.substr(0, file.length - 5));
      if (stageId == '') continue;
      if (!stageFiles.exists(stageId)) stageFiles.set(stageId, '$modPath/stages/$file');
      if (!meta.stages.contains(stageId)) meta.stages.push(stageId);
    }

    // Global scripts: scripts/*.lua|*.hx
    for (file in safeReadDir('$modPath/scripts'))
    {
      var lc:String = file.toLowerCase();
      if (lc.endsWith('.lua') || lc.endsWith('.hx')) meta.scripts.push('$modPath/scripts/$file');
    }
    globalScripts = globalScripts.concat(meta.scripts);

    return meta;
  }

  static function registerSong(songId:String, modRoot:String):Void
  {
    if (!songMods.exists(songId))
    {
      songMods.set(songId, modRoot);
      allSongIds.push(songId);
    }
    else if (songMods.get(songId) != modRoot)
    {
      trace('PsychModHandler: duplicate song id "$songId" in "$modRoot" '
        + 'conflicts with "${songMods.get(songId)}", keeping the first one.');
    }
  }

  static function hasChartFiles(dir:String, songId:String):Bool
  {
    var lcId:String = songId.toLowerCase();
    for (file in safeReadDir(dir))
    {
      var lc:String = file.toLowerCase();
      if (!lc.endsWith('.json')) continue;
      if (lc == '$lcId.json' || lc.startsWith('$lcId-')) return true;
    }
    return false;
  }

  static function findAudio(songId:String, prefix:String):Null<String>
  {
    var dir:Null<String> = audioDirs.get(normalizeId(songId));
    if (dir == null) return null;

    for (ext in AUDIO_EXTENSIONS)
    {
      var candidate:String = '$dir/${prefix.charAt(0).toUpperCase()}${prefix.substr(1)}.$ext';
      if (safeFileExists(candidate)) return candidate;
    }

    // Fall back to a case-insensitive prefix scan (e.g. `inst-erect.ogg`).
    for (file in safeReadDir(dir))
    {
      var lc:String = file.toLowerCase();
      if (!lc.startsWith(prefix)) continue;
      var dot:Int = lc.lastIndexOf('.');
      if (dot == -1) continue;
      if (AUDIO_EXTENSIONS.contains(lc.substr(dot + 1))) return '$dir/$file';
    }
    return null;
  }

  static function hasAudioWithPrefix(dir:String, prefix:String):Bool
  {
    return findAudioInDir(dir, prefix) != null;
  }

  static function findAudioInDir(dir:String, prefix:String):Null<String>
  {
    for (file in safeReadDir(dir))
    {
      var lc:String = file.toLowerCase();
      if (!lc.startsWith(prefix)) continue;
      var dot:Int = lc.lastIndexOf('.');
      if (dot == -1) continue;
      if (AUDIO_EXTENSIONS.contains(lc.substr(dot + 1))) return '$dir/$file';
    }
    return null;
  }

  /**
   * The mods root(s) to scan. Uses the same folder as Polymod (so one mods folder
   * holds both formats) plus a plain `mods` folder next to the executable, which is
   * where Psych players expect to drop content.
   */
  static function getModRoots():Array<String>
  {
    var roots:Array<String> = [];
    var official:String = PolymodHandler.getModFolder();
    if (safeIsDirectory(official)) roots.push(official);
    if (official != 'mods' && safeIsDirectory('mods')) roots.push('mods');
    return roots;
  }

  static function countKeys(map:Map<String, String>):Int
  {
    var count:Int = 0;
    for (_ in map.keys()) count++;
    return count;
  }

  static function safeReadDir(path:String):Array<String>
  {
    #if sys
    try
    {
      return FileUtil.directoryExists(path) ? FileUtil.readDir(path) : [];
    }
    catch (e:Dynamic)
    {
      return [];
    }
    #else
    return [];
    #end
  }

  static function safeIsDirectory(path:String):Bool
  {
    #if sys
    try
    {
      return FileUtil.directoryExists(path);
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }

  static function safeFileExists(path:String):Bool
  {
    #if sys
    try
    {
      return FileUtil.fileExists(path);
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }

  static function safeReadJson(path:String):Null<Dynamic>
  {
    #if sys
    try
    {
      return FileUtil.readJSONFromPath(path);
    }
    catch (e:Dynamic)
    {
      trace('PsychModHandler: failed to parse "$path": $e');
      return null;
    }
    #else
    return null;
    #end
  }
}
