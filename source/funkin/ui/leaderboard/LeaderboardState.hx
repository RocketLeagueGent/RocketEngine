package funkin.ui.leaderboard;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import flixel.FlxSubState;
import funkin.api.leaderboard.LeaderboardClient;
import funkin.api.leaderboard.LeaderboardClient.LeaderboardEntry;
import funkin.util.WindowUtil;

/**
 * Leaderboard viewer for the currently selected song, opened from Freeplay with L.
 *
 * With an empty `Constants.LEADERBOARD_API_BASE` the client runs in MOCK mode:
 * canned rows plus anything submitted this session, and the header shows "(MOCK)".
 *
 * Keys:
 * - UP/DOWN: scroll (only when there are more than 10 entries)
 * - M: open the mod's URL (only when the API returned one)
 * - ESC: close
 */
class LeaderboardState extends FlxSubState
{
  final songId:String;
  final difficultyId:String;
  final variationId:String;

  var entries:Array<LeaderboardEntry> = [];
  var modUrl:Null<String> = null;
  var fetched:Bool = false;

  var headerText:FlxText;
  var subHeaderText:FlxText;
  var statusText:FlxText;
  var hintText:FlxText;
  var rowTexts:Array<FlxText> = [];

  var scrollIndex:Int = 0;
  var closing:Bool = false;

  static final MAX_ROWS:Int = 10;
  static final ROW_Y_START:Int = 190;
  static final ROW_HEIGHT:Int = 44;

  public function new(songId:String, difficultyId:String, variationId:String)
  {
    super(0xE6000000);

    this.songId = songId;
    this.difficultyId = difficultyId;
    this.variationId = variationId;
  }

  override function create():Void
  {
    super.create();

    headerText = new FlxText(0, 44, FlxG.width, 'LEADERBOARD');
    headerText.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, CENTER);
    add(headerText);

    final mockBadge:String = LeaderboardClient.isEnabled() ? '' : ' (MOCK)';
    subHeaderText = new FlxText(0, 96, FlxG.width, '$songId  •  $difficultyId  •  $variationId$mockBadge');
    subHeaderText.setFormat(Paths.font('vcr.ttf'), 24, mockBadge.length > 0 ? 0xFFFFBB33 : FlxColor.WHITE, CENTER);
    add(subHeaderText);

    statusText = new FlxText(0, 300, FlxG.width, 'Loading...');
    statusText.setFormat(Paths.font('vcr.ttf'), 28, 0xAAAAAA, CENTER);
    add(statusText);

    for (i in 0...MAX_ROWS)
    {
      final row:FlxText = new FlxText(140, ROW_Y_START + i * ROW_HEIGHT, FlxG.width - 280, '');
      row.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, LEFT);
      row.visible = false;
      add(row);
      rowTexts.push(row);
    }

    hintText = new FlxText(0, FlxG.height - 56, FlxG.width, 'UP/DOWN: scroll   M: open mod page   ESC: close');
    hintText.setFormat(Paths.font('vcr.ttf'), 22, 0xAAAAAA, CENTER);
    add(hintText);

    LeaderboardClient.fetchScores(songId, difficultyId, variationId, function(got:Array<LeaderboardEntry>, url:Null<String>) {
      if (closing) return;
      fetched = true;
      entries = (got != null) ? got : [];
      modUrl = url;
      refreshRows();
    });
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (closing) return;

    if (FlxG.keys.justPressed.ESCAPE)
    {
      close();
      return;
    }

    if (FlxG.keys.justPressed.M && modUrl != null && modUrl.length > 0)
    {
      WindowUtil.openURL(modUrl);
    }

    if (entries.length > MAX_ROWS)
    {
      if (FlxG.keys.justPressed.UP)
      {
        scrollIndex--;
        refreshRows();
      }
      else if (FlxG.keys.justPressed.DOWN)
      {
        scrollIndex++;
        refreshRows();
      }
    }
  }

  /**
   * Rebuild the visible rows from `entries` at the current scroll position.
   */
  function refreshRows():Void
  {
    if (entries.length == 0)
    {
      statusText.visible = true;
      statusText.text = fetched ? 'No scores yet.' : 'Loading...';
      for (row in rowTexts) row.visible = false;
      return;
    }

    statusText.visible = false;

    final maxScroll:Int = Std.int(Math.max(0, entries.length - MAX_ROWS));
    if (scrollIndex > maxScroll) scrollIndex = maxScroll;
    if (scrollIndex < 0) scrollIndex = 0;

    for (i in 0...MAX_ROWS)
    {
      final idx:Int = scrollIndex + i;
      final row:FlxText = rowTexts[i];

      if (idx < entries.length)
      {
        final e:LeaderboardEntry = entries[idx];
        final rank:String = (e.rank != null && e.rank.length > 0) ? e.rank : '-';
        final acc:Float = Math.round(e.accuracy * 10) / 10;
        final place:String = Std.string(idx + 1);
        final name:String = e.username.lpad(' ', 16);
        final score:String = FlxStringUtil.formatMoney(e.score, false, true).lpad(' ', 9);
        final tier:String = e.comboTier.lpad(' ', 6);
        row.text = '$place.  $name  $score  $acc%  $rank  $tier';
        row.visible = true;
      }
      else
      {
        row.visible = false;
      }
    }

    if (entries.length > MAX_ROWS)
    {
      hintText.text = 'UP/DOWN: scroll (${scrollIndex + 1}-${Math.min(scrollIndex + MAX_ROWS, entries.length)} of ${entries.length})   M: open mod page   ESC: close';
    }
  }

  override function close():Void
  {
    closing = true;
    // Restoring the parent's persistentUpdate is handled by the opener
    // via closeCallback (set in FreeplayState.openLeaderboard).
    super.close();
  }
}
