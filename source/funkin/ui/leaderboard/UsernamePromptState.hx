package funkin.ui.leaderboard;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.save.Save;
import openfl.events.KeyboardEvent;

/**
 * A substate that asks the player to type a username for leaderboard submissions.
 *
 * Raw keyboard input is captured via an openfl KEY_DOWN listener on the stage
 * (same pattern as PreciseInputManager), because the engine has no generic
 * in-game text field. The result is persisted to
 * `Save.instance.leaderboardUsername`.
 *
 * Keys:
 * - Printable characters (whitelisted) append to the username (max 16 chars)
 * - Backspace deletes the last character
 * - Enter confirms and saves
 * - Escape closes without saving (keeps previous username)
 */
class UsernamePromptState extends flixel.FlxSubState
{
  /**
   * Set once the player has been prompted this session,
   * so we don't nag them again when returning to the main menu.
   */
  public static var promptedThisSession:Bool = false;

  static final MAX_LENGTH:Int = 16;

  var titleText:FlxText;
  var inputBg:FlxText;
  var inputText:FlxText;
  var hintText:FlxText;

  /**
   * The username being typed.
   */
  var buffer:String = '';

  /**
   * Set once close() is called, so key events landing between close and
   * destroy don't touch a dead UI.
   */
  var closing:Bool = false;

  public function new()
  {
    super(0xCC000000);

    buffer = Save.instance.leaderboardUsername.value ?? '';
  }

  override function create():Void
  {
    super.create();

    titleText = new FlxText(0, 130, FlxG.width, 'Choose a leaderboard username');
    titleText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
    titleText.screenCenter(X);
    add(titleText);

    inputBg = new FlxText(0, 220, FlxG.width, '[' + ''.lpad(' ', MAX_LENGTH) + ']');
    inputBg.setFormat(Paths.font('vcr.ttf'), 40, 0xFF555555, CENTER);
    inputBg.screenCenter(X);
    add(inputBg);

    inputText = new FlxText(0, 220, FlxG.width, '');
    inputText.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, CENTER);
    inputText.screenCenter(X);
    add(inputText);

    hintText = new FlxText(0, 320, FlxG.width,
      'Type a name (max ${MAX_LENGTH} chars)\nENTER: confirm   BACKSPACE: delete   ESC: cancel');
    hintText.setFormat(Paths.font('vcr.ttf'), 20, 0xAAAAAA, CENTER);
    hintText.screenCenter(X);
    add(hintText);

    refreshDisplay();

    FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
  }

  override function destroy():Void
  {
    FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    super.destroy();
  }

  function onKeyDown(e:KeyboardEvent):Void
  {
    if (closing) return;

    switch (e.keyCode)
    {
      case 8: // Backspace
        if (buffer.length > 0)
        {
          buffer = buffer.substr(0, buffer.length - 1);
          refreshDisplay();
        }
        e.preventDefault();
      case 13: // Enter
        confirm();
        e.preventDefault();
      case 27: // Escape
        close();
        e.preventDefault();
      default:
        var char:String = charFromEvent(e);
        if (char != null && buffer.length < MAX_LENGTH)
        {
          buffer += char;
          refreshDisplay();
          e.preventDefault();
        }
    }
  }

  /**
   * Convert a keyboard event into a single whitelisted printable character.
   * Returns null if the key isn't allowed (or the username is full).
   */
  function charFromEvent(e:KeyboardEvent):Null<String>
  {
    var charCode:Int = e.charCode;

    // Some platforms report charCode 0 for letter/digit keys; fall back to keyCode.
    if (charCode == 0)
    {
      if (e.keyCode >= 65 && e.keyCode <= 90) // A-Z
        charCode = e.keyCode + 32; // lowercase
      else if (e.keyCode >= 48 && e.keyCode <= 57) // 0-9
        charCode = e.keyCode;
      else
        return null;
    }

    if (charCode < 32 || charCode > 126) return null;

    var char:String = String.fromCharCode(charCode);

    // Whitelist: letters, digits, space, underscore, hyphen.
    if (!~/[A-Za-z0-9 _-]/.match(char)) return null;

    return char;
  }

  function confirm():Void
  {
    var trimmed:String = buffer.trim();
    if (trimmed.length > 0)
    {
      Save.instance.leaderboardUsername.value = trimmed;
    }
    promptedThisSession = true;
    close();
  }

  function refreshDisplay():Void
  {
    inputText.text = buffer;
    inputText.screenCenter(X);
  }

  override function close():Void
  {
    // Counts as seen for this session whether confirmed or cancelled.
    // (No parent persistentUpdate restore needed: flixel resumes parent
    // updates as soon as subState becomes null.)
    closing = true;
    promptedThisSession = true;
    super.close();
  }
}
