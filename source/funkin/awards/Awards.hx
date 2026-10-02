package funkin.awards;

import funkin.audio.FunkinSound;
import funkin.save.Save;
import funkin.save.Save.SaveDataAwardProgress;

/**
 * An award definition, ported from Psych Engine 1.0.4's `Achievement` typedef.
 *
 * Fields:
 * `name` - The display name shown in the Awards menu.
 * `description` - The hint text shown in the Awards menu.
 * `hidden` - Hidden awards don't appear in the menu until unlocked.
 * `maxScore` - When set, the award tracks progress toward this value.
 * `maxDecimals` - Decimal places used when displaying progress.
 * `ID` - Sort order, assigned automatically on registration.
 */
typedef Award =
{
  var name:String;
  var description:String;
  @:optional var hidden:Bool;
  @:optional var maxScore:Float;
  @:optional var maxDecimals:Int;
  @:optional var ID:Int;
}

/**
 * Backend for Psych Engine style awards (AKA achievements).
 *
 * - `Awards.unlock(name)` registers an unlock, plays a sound, and persists to save data.
 * - Progress-tracked awards (like `roadkill_enthusiast`) go through `addScore`/`setScore`.
 * - The Awards menu reads `awards`, `unlockedIds`, and `progress` to draw the grid.
 *
 * Persistence goes through `Save.instance.awardsUnlocked` / `Save.instance.awardsProgress`.
 * SaveProperty assignment detects reference changes, so we always assign fresh copies.
 */
class Awards
{
  /**
   * Every registered award, keyed by internal name (matches the icon filename).
   */
  public static var awards:Map<String, Award> = new Map<String, Award>();

  /**
   * The names of every award the user has unlocked, in unlock order.
   */
  public static var unlockedIds:Array<String> = [];

  /**
   * Progress values for awards that track a score, keyed by award name.
   */
  public static var progress:Map<String, Float> = new Map<String, Float>();

  static var _initialized:Bool = false;
  static var _sortID:Int = 0;
  static var _lastUnlock:Float = -999;

  /**
   * Register all built-in awards and hydrate state from save data.
   * Lazy and idempotent; safe to call from anywhere.
   */
  public static function init():Void
  {
    if (_initialized) return;
    _initialized = true;

    createAward('friday_night_play', {name: "Freaky on a Friday Night", description: "Play on a Friday... Night.", hidden: true});
    createAward('week1_nomiss', {name: "She Calls Me Daddy Too", description: "Beat Week 1 on Hard with no Misses."});
    createAward('week2_nomiss', {name: "No More Tricks", description: "Beat Week 2 on Hard with no Misses."});
    createAward('week3_nomiss', {name: "Call Me The Hitman", description: "Beat Week 3 on Hard with no Misses."});
    createAward('week4_nomiss', {name: "Lady Killer", description: "Beat Week 4 on Hard with no Misses."});
    createAward('week5_nomiss', {name: "Missless Christmas", description: "Beat Week 5 on Hard with no Misses."});
    createAward('week6_nomiss', {name: "Highscore!!", description: "Beat Week 6 on Hard with no Misses."});
    createAward('week7_nomiss', {name: "God Effing Damn It!", description: "Beat Week 7 on Hard with no Misses."});
    createAward('weekend1_nomiss', {name: "Just a Friendly Sparring", description: "Beat Weekend 1 on Hard with no Misses."});
    createAward('ur_bad', {name: "What a Funkin' Disaster!", description: "Complete a Song with a rating lower than 20%."});
    createAward('ur_good', {name: "Perfectionist", description: "Complete a Song with a rating of 100%."});
    createAward('roadkill_enthusiast', {name: "Roadkill Enthusiast", description: "Watch the Henchmen die 50 times.", maxScore: 50, maxDecimals: 0});
    createAward('oversinging', {name: "Oversinging Much...?", description: "Sing for 10 seconds without going back to Idle."});
    createAward('hype', {name: "Hyperactive", description: "Finish a Song without going back to Idle."});
    createAward('two_keys', {name: "Just the Two of Us", description: "Finish a Song pressing only two keys."});
    createAward('toastie', {name: "Toaster Gamer", description: "Have you tried to run the game on a toaster?"});
    createAward('debugger', {name: "Debugger", description: "Beat the \"Test\" Stage from the Chart Editor.", hidden: true});
    createAward('pessy_easter_egg', {name: "Engine Gal Pal", description: "Teehee, you found me~!", hidden: true});

    // Hydrate from save data.
    var store = Save.instance;
    var savedUnlocked = store.awardsUnlocked.value;
    if (savedUnlocked != null) unlockedIds = savedUnlocked.copy();
    var savedProgress = store.awardsProgress.value;
    if (savedProgress != null)
    {
      for (record in savedProgress)
      {
        if (record != null) progress.set(record.name, record.value);
      }
    }
  }

  /**
   * @return Whether an award with this name is registered.
   */
  public static function exists(name:String):Bool
  {
    init();
    return awards.exists(name);
  }

  /**
   * @return The award definition, or `null` if it doesn't exist.
   */
  public static function get(name:String):Null<Award>
  {
    init();
    return awards.get(name);
  }

  /**
   * @return Whether the user has unlocked this award.
   */
  public static function isUnlocked(name:String):Bool
  {
    init();
    return unlockedIds.contains(name);
  }

  /**
   * Every award name, sorted by registration order (menu display order).
   */
  public static function sortedNames():Array<String>
  {
    init();
    var names:Array<String> = [for (key in awards.keys()) key];
    names.sort(function(a:String, b:String):Int
    {
      var awardA = awards.get(a);
      var awardB = awards.get(b);
      var idA:Int = awardA == null ? 0 : (awardA.ID ?? 0);
      var idB:Int = awardB == null ? 0 : (awardB.ID ?? 0);
      return idA - idB;
    });
    return names;
  }

  /**
   * Unlock an award. Plays a confirmation sound (rate-limited to prevent spam)
   * and persists the new state to save data.
   *
   * @param name The internal award name.
   * @return Whether the award was newly unlocked (false if missing or already unlocked).
   */
  public static function unlock(name:String):Bool
  {
    init();
    if (!awards.exists(name))
    {
      trace('Award "$name" does not exist!');
      return false;
    }
    if (unlockedIds.contains(name)) return false;

    trace('Completed award "$name"');
    unlockedIds.push(name);

    // Earrape prevention: skip the sound if we unlocked something within the last 100ms.
    var time:Float = openfl.Lib.getTimer();
    if (Math.abs(time - _lastUnlock) >= 100)
    {
      FunkinSound.playOnce(Paths.sound('confirmMenu'), 0.5);
      _lastUnlock = time;
    }

    // Assign a fresh array so SaveProperty's change detection triggers an auto-flush.
    Save.instance.awardsUnlocked.value = unlockedIds.copy();
    return true;
  }

  /**
   * Get the current progress value for a score-tracked award.
   *
   * @return The progress value, `0` when no progress was made, or `-1` when the award is missing.
   */
  public static function getScore(name:String):Float
  {
    init();
    if (!awards.exists(name)) return -1;
    return progress.exists(name) ? progress.get(name) : 0.0;
  }

  /**
   * Set the progress value for a score-tracked award.
   * Automatically unlocks the award when the value reaches `maxScore`.
   *
   * @return The clamped progress value, or `-1` when the award doesn't track a score.
   */
  public static function setScore(name:String, value:Float):Float
  {
    init();
    var award = awards.get(name);
    if (award == null || award.maxScore == null || award.maxScore < 1) return -1;
    if (unlockedIds.contains(name)) return award.maxScore;

    var val:Float = value;
    if (val >= award.maxScore)
    {
      unlock(name);
      val = award.maxScore;
    }
    progress.set(name, val);
    persistProgress();
    return val;
  }

  /**
   * Add to the progress value for a score-tracked award.
   *
   * @return The clamped progress value, or `-1` when the award doesn't track a score.
   */
  public static function addScore(name:String, value:Float = 1):Float
  {
    return setScore(name, getScore(name) + value);
  }

  /**
   * Reset an award: removes the unlock and any progress, then persists.
   * Used by the reset confirmation in the Awards menu.
   */
  public static function reset(name:String):Void
  {
    init();
    unlockedIds.remove(name);
    progress.remove(name);
    Save.instance.awardsUnlocked.value = unlockedIds.copy();
    persistProgress();
  }

  static function persistProgress():Void
  {
    var records:Array<SaveDataAwardProgress> = [];
    for (key in progress.keys())
    {
      var value:Null<Float> = progress.get(key);
      records.push({name: key, value: value ?? 0.0});
    }
    Save.instance.awardsProgress.value = records;
  }

  static function createAward(name:String, award:Award):Void
  {
    award.ID = _sortID++;
    awards.set(name, award);
  }
}
