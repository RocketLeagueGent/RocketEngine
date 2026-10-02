package funkin.api.leaderboard;

import haxe.Http;
import haxe.Json;
import funkin.save.Save.SaveScoreTallyData;
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
    if (payload == null || payload.username == '') return;

    if (!isEnabled())
    {
      mockSubmit(payload);
      trace('[Leaderboard] MOCK submit: ${payload.username} ${payload.songId} score=${payload.score} tier=${payload.comboTier}');
      return;
    }

    var url:String = '${Constants.LEADERBOARD_API_BASE}/api/submit';
    var body:String = Json.stringify(payload);

    var http:Http = new Http(url);
    http.setHeader('Content-Type', 'application/json');
    http.setPostData(body);
    http.onData = function(_) {
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
