package funkin.api.leaderboard;

import haxe.Http;
import haxe.Json;
import funkin.save.Save.SaveScoreTallyData;
import funkin.save.Save;
import funkin.modding.PolymodHandler;

/**
 * Client for the leaderboard API (a serverless/Vercel-compatible backend).
 *
 * Endpoints (relative to `Constants.LEADERBOARD_API_BASE`):
 * - `POST /api/submit`     body: `LeaderboardSubmitPayload` JSON
 * - `GET  /api/leaderboard?song=...&difficulty=...&variation=...&mod=...`
 *
 * When `Constants.LEADERBOARD_API_BASE` is empty, the client runs in MOCK mode:
 * submissions are kept in an in-memory list and `fetchScores` returns the
 * canned entries plus anything submitted this session.
 *
 * NOTE (real API): when the game is served from a different origin than the API,
 * the server must send CORS headers (`Access-Control-Allow-Origin: *`), or the
 * API must be deployed same-origin with the HTML5 build.
 */
class LeaderboardClient
{
  /**
   * Whether a real API endpoint is configured (otherwise mock mode).
   */
  public static function isEnabled():Bool
  {
    return Constants.LEADERBOARD_API_BASE != '';
  }

  /**
   * The username to submit scores under on this platform.
   *
   * - HTML5 (web): guest-only. Custom usernames are never used; guests are
   *   identified by their backend-assigned UUID instead.
   * - Desktop: the username the player picked (persisted in the save file),
   *   or '' if they never picked one.
   */
  public static function currentUsername():String
  {
    #if html5
    return guestName();
    #else
    return Save.instance.leaderboardUsername.value ?? '';
    #end
  }

  /**
   * Display name for a guest (web) identity: `Guest` until the backend
   * assigns a UUID, then `Guest#<uuid>`.
   */
  public static function guestName():String
  {
    var uuid:Null<Int> = Save.instance.leaderboardUuid.value;
    return uuid == null ? 'Guest' : 'Guest#$uuid';
  }

  /**
   * The backend-assigned account UUID for this save, or null if none yet.
   */
  public static function currentUuid():Null<Int>
  {
    return Save.instance.leaderboardUuid.value;
  }

  /**
   * Classify the player's combo/full-clear tier from the judgement tallies.
   *
   * Mapping:
   * - 1-9 misses  -> 'SDCB'
   * - 10+ misses  -> 'CLEAR'
   * - all sick    -> 'PFC' (perfect full clear / golden P)
   * - sick+good only (0 misses, no bad/shit) -> 'GFC'
   * - 0 misses otherwise -> 'FC'
   */
  public static function calculateComboTier(tallies:SaveScoreTallyData):String
  {
    if (tallies == null || tallies.totalNotes == 0) return 'CLEAR';

    if (tallies.missed > 0)
    {
      return (tallies.missed < 10) ? 'SDCB' : 'CLEAR';
    }

    // No misses from here on.
    if (tallies.sick == tallies.totalNotes) return 'PFC';
    if (tallies.bad == 0 && tallies.shit == 0) return 'GFC';
    return 'FC';
  }

  /**
   * Submit a score to the leaderboard.
   * Fire-and-forget: network failures are traced but never interrupt gameplay.
   */
  public static function submitScore(payload:LeaderboardSubmitPayload):Void
  {
    if (payload == null) return;

    // Never submit an empty identity.
    if (payload.username == '' && payload.uuid == null) return;

    if (!isEnabled())
    {
      mockSubmit(payload);
      trace('[Leaderboard] MOCK submit: ${payload.username} uuid=${payload.uuid} ${payload.songId} score=${payload.score} tier=${payload.comboTier}');
      return;
    }

    var url:String = '${Constants.LEADERBOARD_API_BASE}/api/submit';
    var body:String = Json.stringify(payload);

    var http:Http = new Http(url);
    http.setHeader('Content-Type', 'application/json');
    http.setPostData(body);
    http.onData = function(raw:String) {
      // The backend may respond with the account identity, e.g.
      // {"ok":true,"uuid":0}. Persist it so future submissions are
      // linked to the same account.
      try
      {
        var parsed:Dynamic = Json.parse(raw);
        if (parsed != null && parsed.uuid != null && Std.isOfType(parsed.uuid, Int))
        {
          Save.instance.leaderboardUuid.value = cast parsed.uuid;
        }
      }
      catch (e:Dynamic)
      {
        // Non-JSON responses are fine; just ignore.
      }
      trace('[Leaderboard] Submit OK: ${payload.songId} (${payload.score})');
    };
    http.onError = function(msg:String) {
      // Most likely CORS or network unavailable; never block the game for this.
      trace('[Leaderboard] Submit failed: $msg');
    };
    http.request(true); // POST
  }

  /**
   * Fetch leaderboard entries for a song.
   * @param onDone Called with (entries, modUrl) on success, or ([], null) on failure.
   */
  public static function fetchScores(songId:String, difficultyId:String, variationId:String,
      onDone:Array<LeaderboardEntry>->Null<String>->Void):Void
  {
    if (onDone == null) return;

    if (!isEnabled())
    {
      onDone(mockFetch(songId, difficultyId, variationId), null);
      return;
    }

    var modParam:String = PolymodHandler.loadedModIds.join(',');
    var url:String = '${Constants.LEADERBOARD_API_BASE}/api/leaderboard'
      + '?song=' + StringTools.urlEncode(songId)
      + '&difficulty=' + StringTools.urlEncode(difficultyId)
      + '&variation=' + StringTools.urlEncode(variationId)
      + '&mod=' + StringTools.urlEncode(modParam);

    var http:Http = new Http(url);
    http.onData = function(raw:String) {
      var entries:Array<LeaderboardEntry> = [];
      var modUrl:Null<String> = null;
      try
      {
        var parsed:Dynamic = Json.parse(raw);
        if (Std.isOfType(parsed, Array))
        {
          entries = cast parsed;
        }
        else if (parsed != null)
        {
          if (parsed.entries != null) entries = cast parsed.entries;
          if (parsed.modUrl != null) modUrl = parsed.modUrl;
        }
      }
      catch (e:Dynamic)
      {
        trace('[Leaderboard] Failed to parse response: $e');
        onDone([], null);
        return;
      }
      onDone(entries, modUrl);
    };
    http.onError = function(msg:String) {
      trace('[Leaderboard] Fetch failed: $msg');
      onDone([], null);
    };
    http.request(false); // GET
  }

  ///
  /// MOCK MODE
  ///

  static var mockEntries:Array<LeaderboardEntry> = [
    // Canned rows so the UI has something to show before any submission.
    {username: 'Pana', score: 350000, accuracy: 100.0, rank: 'PERFECT_GOLD', comboTier: 'PFC'},
    {username: 'EliteEric', score: 320000, accuracy: 97.5, rank: 'EXCELLENT', comboTier: 'GFC'},
    {username: 'ninjamuffin99', score: 280000, accuracy: 94.2, rank: 'GREAT', comboTier: 'FC'},
    {username: 'KadeDev', score: 210000, accuracy: 88.1, rank: 'GOOD', comboTier: 'SDCB'},
    {username: 'ShadowMario', score: 150000, accuracy: 79.3, rank: 'GOOD', comboTier: 'CLEAR'},
  ];

  static function mockSubmit(payload:LeaderboardSubmitPayload):Void
  {
    // Assign an account UUID on first submission, mirroring the real
    // backend: first account gets 0, second gets 1, and so on.
    if (payload.uuid == null)
    {
      payload.uuid = mockNextUuid();
      Save.instance.leaderboardUuid.value = payload.uuid;
      // Guests get their display name from the UUID.
      if (payload.username.startsWith('Guest')) payload.username = guestName();
    }

    mockEntries.push({
      username: payload.username,
      score: payload.score,
      accuracy: payload.accuracy,
      rank: payload.rank,
      comboTier: payload.comboTier,
    });
    mockEntries.sort(function(a, b) return b.score - a.score);
    // Keep the mock list bounded.
    if (mockEntries.length > 50) mockEntries = mockEntries.slice(0, 50);
  }

  /**
   * Next UUID to hand out in mock mode. Counts existing mock submissions
   * that already carry an account so numbering stays stable in-session,
   * offset by any UUID the save file already owns.
   */
  static function mockNextUuid():Int
  {
    var saved:Null<Int> = Save.instance.leaderboardUuid.value;
    if (saved != null) return saved;

    // First unclaimed id: 0, then 1, ... (Rocket = 0, Pana = 1).
    var used:Map<Int, Bool> = new Map<Int, Bool>();
    for (entry in mockEntries)
    {
      // Mock entries don't carry uuids; track via distinct guest names.
      if (entry.username.startsWith('Guest#'))
      {
        var id:Null<Int> = Std.parseInt(entry.username.split('#')[1]);
        if (id != null) used[id] = true;
      }
    }
    var next:Int = 0;
    while (used[next]) next++;
    return next;
  }

  static function mockFetch(songId:String, difficultyId:String, variationId:String):Array<LeaderboardEntry>
  {
    // Mock mode ignores song/difficulty/variation; everything shares one list.
    return mockEntries.copy();
  }
}

/**
 * Payload sent to `POST /api/submit`.
 * The server stores this into a sorted set keyed by (songId, difficultyId, variationId).
 */
typedef LeaderboardSubmitPayload =
{
  var username:String;

  /**
   * Backend-assigned account UUID. Null on the very first submission;
   * the backend replies with the assigned id (0 = first account, 1 = second, ...)
   * which the client persists to its save file.
   */
  var uuid:Null<Int>;

  var songId:String;
  var difficultyId:String;
  var variationId:String;
  var score:Int;

  /**
   * Percentage 0-100.
   */
  var accuracy:Float;

  /**
   * Scoring rank string, e.g. 'PERFECT_GOLD', 'EXCELLENT'. Null if unranked.
   */
  var rank:Null<String>;

  /**
   * Combo tier: 'FC' | 'GFC' | 'PFC' | 'SDCB' | 'CLEAR'.
   */
  var comboTier:String;
}

/**
 * A single leaderboard row.
 */
typedef LeaderboardEntry =
{
  var username:String;
  var score:Int;

  /**
   * Percentage 0-100.
   */
  var accuracy:Float;

  /**
   * Scoring rank string, may be null.
   */
  var rank:Null<String>;

  /**
   * Combo tier: 'FC' | 'GFC' | 'PFC' | 'SDCB' | 'CLEAR'.
   */
  var comboTier:String;
}
