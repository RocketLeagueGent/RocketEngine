package funkin.ui.mainmenu;

import flixel.addons.transition.FlxTransitionableState;
#if FEATURE_DEBUG_MENU
import funkin.ui.debug.DebugMenuSubState;
#end
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.typeLimit.NextState;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import funkin.graphics.FunkinCamera;
import funkin.audio.FunkinSound;
import funkin.util.InputUtil;
import flixel.tweens.FlxTween;
import funkin.ui.MusicBeatState;
import funkin.ui.UIStateMachine;
import funkin.ui.UIStateMachine.UIState;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxTimer;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.title.TitleState;
import funkin.ui.story.StoryMenuState;
import funkin.ui.Prompt;
import funkin.save.Save;
import funkin.ui.leaderboard.UsernamePromptState;
import funkin.util.WindowUtil;
import funkin.util.MathUtil;
#if mobile
import funkin.mobile.input.ControlsHandler;
import funkin.mobile.util.InAppPurchasesUtil;
#end

/**
 * Main menu, ported from Psych Engine 1.0.4's `states/MainMenuState.hx`.
 *
 * Psych's three-column layout:
 * - CENTER: story_mode, freeplay, credits (Psych also has `mods`; our mods
 *   browser lives inside Options as the ModMenu page instead)
 * - LEFT: achievements (wired to our AwardsMenuState)
 * - RIGHT: options
 *
 * Psych's interaction model is preserved: idle/selected sparrow animations,
 * camera parallax follow on the background, mouse hover with nearest-item
 * detection, column switching with left/right, flicker-confirm on accept.
 * Our engine's state machine, Freeplay substate flow, mobile buttons and
 * username prompt are kept on top of it.
 */
enum MainMenuColumn
{
  LEFT;
  CENTER;
  RIGHT;
}

@:nullSafety
class MainMenuState extends MusicBeatState
{
  public static var curSelected:Int = 0;
  public static var curColumn:MainMenuColumn = CENTER;
  var allowMouse:Bool = !Preferences.tvMode; // Turn this off to block mouse movement in menus

  var centerItems:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
  var leftItem:Null<FlxSprite>;
  var rightItem:Null<FlxSprite>;

  // Centered/Text options (Psych's optionShit)
  var optionShit:Array<String> = [
    'story_mode',
    'freeplay',
    'credits'
  ];

  var leftOption:String = 'achievements';
  var rightOption:String = 'options';

  var magenta:FlxSprite;
  var camFollow:FlxObject;

  var bg:Null<FlxSprite>;
  var overrideMusic:Bool = false;
  var uiStateMachine:UIStateMachine = new UIStateMachine();
  var canInteract(get, never):Bool;

  // Equivalent of Psych's `selectedSomethin`: blocks input while confirming.
  var selectedSomethin:Bool = false;

  /**
   * Set when a substate (e.g. the username prompt) closes: the Enter/Esc that
   * dismissed it is still registered by flixel for this frame, and would
   * otherwise immediately trigger accept/back on the menu underneath.
   * Cleared once the accept/back controls are released.
   */
  var blockAcceptUntilRelease:Bool = false;

  var timeNotMoving:Float = 0;

  #if mobile
  var gyroPan:Null<FlxPoint>;
  #end

  static var rememberedSelectedIndex:Int = 0;

  // This should never be false on non-mobile targets.
  var hasUpgraded:Bool = false;

  function get_canInteract():Bool
  {
    return uiStateMachine.canInteract();
  }

  public function new(_overrideMusic:Bool = false)
  {
    super();
    overrideMusic = _overrideMusic;

    // Start in Entering state during screen fade in
    uiStateMachine.transition(EnteringMainMenu);

    magenta = new FlxSprite(Paths.image('menuDesat'));
    camFollow = new FlxObject(0, 0, 1, 1);

    // TODO: enabling and disabling keys is a lil quirky,
    // we should move towards unifying the UI and it's inputs into this UIStateMachine managed system
    FlxG.keys.enabled = true;
  }

  override function create():Void
  {
    FlxG.cameras.reset(new FunkinCamera('mainMenu'));

    transIn = FlxTransitionableState.defaultTransIn;
    transOut = FlxTransitionableState.defaultTransOut;

    #if FEATURE_MOBILE_IAP
    trace("hasInitialized: " + InAppPurchasesUtil.hasInitialized);
    if (InAppPurchasesUtil.hasInitialized) Preferences.noAds = InAppPurchasesUtil.isPurchased(InAppPurchasesUtil.UPGRADE_PRODUCT_ID);
    // If the user is faster than their shit wifi, it gets the saved noAds instead.
    hasUpgraded = Preferences.noAds;
    #else
    // just to make sure its never accidentally turned off
    hasUpgraded = true;
    #end

    if (!overrideMusic) playMenuMusic();

    // We want the state to always be able to begin with being able to accept inputs and show the anims of the menu items.
    persistentUpdate = true;
    persistentDraw = true;

    // --- Psych layout: background with vertical parallax ---
    var yScroll:Float = 0.25;
    bg = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
    bg.antialiasing = true;
    bg.scrollFactor.set(0, yScroll);
    bg.setGraphicSize(Std.int(bg.width * 1.175));
    bg.updateHitbox();
    bg.screenCenter();
    add(bg);

    add(camFollow);

    // Psych's desaturated overlay, tinted pink; flickered on confirm.
    magenta.antialiasing = true;
    magenta.scrollFactor.set(0, yScroll);
    magenta.setGraphicSize(Std.int(magenta.width * 1.175));
    magenta.updateHitbox();
    magenta.screenCenter();
    magenta.visible = false;
    magenta.color = 0xFFfd719b;
    add(magenta);

    centerItems = new FlxTypedGroup<FlxSprite>();
    add(centerItems);

    // Restore the previously selected center item.
    curSelected = FlxMath.wrap(rememberedSelectedIndex, 0, optionShit.length - 1);
    curColumn = CENTER;

    for (num => option in optionShit)
    {
      var item:FlxSprite = createMenuItem(option, 0, (num * 140) + 90);
      item.y += (4 - optionShit.length) * 70; // Offsets for when you have anything other than 4 items
      item.screenCenter(X);
    }

    if (leftOption != null) leftItem = createMenuItem(leftOption, 60, 490);
    if (rightOption != null)
    {
      rightItem = createMenuItem(rightOption, FlxG.width - 60, 490);
      rightItem.x -= rightItem.width;
    }

    // Bottom-left version watermark, Psych style.
    var engineVer:FlxText = new FlxText(12, FlxG.height - 44, 0, '${Constants.TITLE} ${Constants.VERSION}', 12);
    engineVer.scrollFactor.set();
    engineVer.setFormat(Paths.font(), 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(engineVer);

    changeItem();

    FlxG.camera.follow(camFollow, null, 0.15);

    #if mobile
    gyroPan = new FlxPoint();

    camFollow.y = bg.getGraphicMidpoint().y;

    // TODO: This is absolutely disgusting but what the hell sure, fix it later -Zack
    addBackButton(FlxG.width - 230, FlxG.height - 200, FlxColor.WHITE, goBack, 1.0);

    if (!ControlsHandler.usingExternalInputDevice)
    {
      addOptionsButton(35, FlxG.height - 210, goOptions);
    }

    backButton?.onConfirmStart.add(() ->
    {
      uiStateMachine.transition(Interacting);
      trace('BACK: Interact Start');
    });

    optionsButton?.onConfirmStart.add(() ->
    {
      uiStateMachine.transition(Interacting);
      trace('OPTIONS: Interact Start');
    });
    #end

    super.create();

    // This has to come AFTER!
    initLeftWatermarkText();

    // First-launch prompt: ask for a leaderboard username once per session.
    FlxTimer.wait(1.0, maybePromptForUsername);
  }

  /**
   * Logical menu option -> shipped atlas name in `assets/images/mainmenu`.
   *
   * The option ids drive routing in `confirmMenu`, so they aren't always the atlas
   * names: Psych's `menu_*` atlases were never added to the assets repo, so we use
   * the V-Slice art that does ship. `story_mode` is `storymode`, and there is no
   * `achievements` art at all -- the `merch` atlas stands in for the left slot.
   */
  static function menuAtlasFor(option:String):String
  {
    switch (option)
    {
      case 'story_mode':
        return 'storymode';
      case 'achievements':
        return 'merch';
      default:
        return option;
    }
  }

  /**
   * Build a Psych menu item from the `mainmenu/<atlas>` sparrow atlas,
   * with `'<atlas> idle'` / `'<atlas> selected'` animations.
   */
  function createMenuItem(name:String, x:Float, y:Float):FlxSprite
  {
    var atlas:String = menuAtlasFor(name);
    var menuItem:FlxSprite = new FlxSprite(x, y);
    menuItem.frames = Paths.getSparrowAtlas('mainmenu/$atlas');
    menuItem.animation.addByPrefix('idle', '$atlas idle', 24, true);
    menuItem.animation.addByPrefix('selected', '$atlas selected', 24, true);
    menuItem.animation.play('idle');
    menuItem.updateHitbox();

    menuItem.antialiasing = true;
    menuItem.scrollFactor.set();
    centerItems.add(menuItem);
    return menuItem;
  }

  /**
   * On first launch (empty leaderboard username), ask the player to pick one.
   * Retries briefly until the menu is fully interactive and no other substate is open.
   * Web builds never prompt: they submit as UUID-backed guests.
   */
  function maybePromptForUsername():Void
  {
    #if html5
    // Guest-only on the web: no custom usernames.
    UsernamePromptState.promptedThisSession = true;
    return;
    #end

    if (UsernamePromptState.promptedThisSession) return;

    if ((Save.instance.leaderboardUsername.value ?? '').trim().length > 0)
    {
      UsernamePromptState.promptedThisSession = true;
      return;
    }

    // Wait until the entering transition (and any other substate) is done.
    if (subState != null || !canInteract)
    {
      FlxTimer.wait(0.5, maybePromptForUsername);
      return;
    }

    uiStateMachine.transition(Interacting);
    persistentUpdate = false;

    var prompt = new UsernamePromptState();
    prompt.closeCallback = function()
    {
      // Our closeSubState() override transitions the UI state machine back to Idle.
    };
    openSubState(prompt);
  }

  function initLeftWatermarkText():Void
  {
    if (leftWatermarkText == null) return;

    leftWatermarkText.text = Constants.VERSION;
  }

  function playMenuMusic():Void
  {
    FunkinSound.playMusic('freakyMenu', {
      overrideExisting: true,
      restartTrack: false,
      // Continue playing this music between states, until a different music track gets played.
      persist: true
    });
  }

  function resetCamStuff(snap:Bool = true):Void
  {
    FlxG.camera.follow(camFollow, null, 0.15);

    if (snap) FlxG.camera.snapToTarget();
  }

  override function closeSubState():Void
  {
    magenta.visible = false;

    // when we are in Transition (fade in on new FlxState) we don't really care about substate closing
    // this fixes issue when Entering w/ fade -> interacting -> fade ends, so it transitions to Idle on our substate end here
    if (!(subState is flixel.addons.transition.Transition))
    {
      uiStateMachine.transition(Idle);
      // Re-enable Psych-style input handling now that we're back from a substate.
      selectedSomethin = false;
      // Swallow the keypress that just dismissed the substate (see field docs).
      blockAcceptUntilRelease = true;

      // Confirming an option tweens every other menu item's alpha to 0.
      // Restore all items when returning from a substate (e.g. backing out of
      // Freeplay) so the menu isn't left with invisible buttons.
      for (memb in centerItems)
      {
        if (memb == null) continue;
        memb.alpha = 1;
        memb.visible = true;
      }
      if (leftItem != null)
      {
        leftItem.alpha = 1;
        leftItem.visible = true;
      }
      if (rightItem != null)
      {
        rightItem.alpha = 1;
        rightItem.visible = true;
      }

      #if FEATURE_TOUCH_CONTROLS
      // we want to reset our backButton + optionsButton if we are returning to the main menu from a substate like freeplay
      // however, we dont want to trigger these resets if we are entering the state

      backButton?.animation.play('idle');
      backButton?.resetCallbacks();

      optionsButton?.animation.play('idle');
      optionsButton?.resetCallbacks();
      #end
    }

    super.closeSubState();
  }

  #if FEATURE_OPEN_URL
  function selectMerch()
  {
    WindowUtil.openURL(Constants.URL_MERCH_FALLBACK);
    uiStateMachine.transition(Idle);
  }
  #end

  public function openPrompt(prompt:Prompt, onClose:Void->Void):Void
  {
    uiStateMachine.transition(Interacting);
    persistentUpdate = false;

    prompt.closeCallback = function()
    {
      // in our closeSubState override, we set the uiStateMachine, so no need to set here
      if (onClose != null) onClose();
    }

    openSubState(prompt);
  }

  /**
   * Run the accept flow for the currently selected option: confirm sound,
   * Psych's magenta flicker (when flashing lights are enabled), item flicker
   * and fade-out of the remaining items, then fire the option's callback.
   */
  function acceptCurrentOption():Void
  {
    FunkinSound.playOnce(Paths.sound('confirmMenu'));
    uiStateMachine.transition(Interacting);
    selectedSomethin = true;
    FlxG.mouse.visible = false;
    rememberedSelectedIndex = curSelected;

    if (Preferences.flashingLights)
    {
      FlxFlicker.flicker(magenta, 1.1, 0.15, false);
    }

    var item:Null<FlxSprite>;
    var option:String;
    switch (curColumn)
    {
      case CENTER:
        option = optionShit[curSelected];
        item = centerItems.members[curSelected];
      case LEFT:
        option = leftOption;
        item = leftItem;
      case RIGHT:
        option = rightOption;
        item = rightItem;
    }

    if (item == null)
    {
      selectedSomethin = false;
      uiStateMachine.transition(Idle);
      return;
    }

    FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
    {
      switch (option)
      {
        case 'story_mode':
          FlxG.signals.preStateSwitch.addOnce(() ->
          {
            funkin.FunkinMemory.clearFreeplay();
            funkin.FunkinMemory.purgeCache();
          });
          startExitState(() -> new StoryMenuState());

        case 'freeplay':
          openFreeplay();

        case 'achievements':
          startExitState(() -> new funkin.ui.awards.AwardsMenuState());

        case 'credits':
          startExitState(() -> new funkin.ui.credits.CreditsState());

        case 'options':
          startExitState(() -> new funkin.ui.options.OptionsState());

        default:
          trace('Menu Item ${option} doesn\'t do anything');
          selectedSomethin = false;
          item.visible = true;
          uiStateMachine.transition(Idle);
      }
    });

    for (memb in centerItems)
    {
      if (memb == null || memb == item) continue;
      FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
    }
    if (leftItem != null && leftItem != item) FlxTween.tween(leftItem, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
    if (rightItem != null && rightItem != item) FlxTween.tween(rightItem, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
  }

  /** Freeplay has its own custom flow: it opens as a substate with character select. */
  function openFreeplay():Void
  {
    persistentDraw = true;
    persistentUpdate = false;

    // Freeplay has its own custom transition
    FlxTransitionableState.skipNextTransIn = true;
    FlxTransitionableState.skipNextTransOut = true;

    // Since CUTOUT_WIDTH is static it might retain some old incorrect values so we update it before loading freeplay
    FreeplayState.CUTOUT_WIDTH = funkin.ui.FullScreenScaleMode.gameCutoutSize.x / 1.5;

    #if FEATURE_DEBUG_FUNCTIONS
    // Debug function: Hold SHIFT when selecting Freeplay to swap character without the char select menu
    var targetCharacter:Null<String> = FlxG.keys.pressed.SHIFT ? (FreeplayState.rememberedCharacterId == "pico" ? "bf" : "pico") : FreeplayState.rememberedCharacterId;
    #else
    var targetCharacter:Null<String> = FreeplayState.rememberedCharacterId;
    #end

    openSubState(new FreeplayState({
      character: targetCharacter
    }));
  }

  function startExitState(state:NextState):Void
  {
    uiStateMachine.transition(Exiting); // Start fade out

    // The alpha fade of the other items already happened during the confirm flicker.
    var fadeOutDuration:Float = 0.4;

    #if mobile
    if (optionsButton != null) FlxTween.tween(optionsButton, {alpha: 0}, fadeOutDuration, {ease: FlxEase.quadOut});
    if (backButton != null) FlxTween.tween(backButton, {alpha: 0}, fadeOutDuration, {ease: FlxEase.quadOut});
    #end

    FlxTimer.wait(fadeOutDuration, () ->
    {
      trace('Exiting MainMenuState...');
      FlxG.switchState(state);
    });
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    Conductor.instance.update();

    #if mobile
    if (gyroPan != null && bg != null && !ControlsHandler.usingExternalInputDevice)
    {
      gyroPan.add(FlxG.gyroscope.pitch * -1.25, FlxG.gyroscope.roll * -1.25);

      // our pseudo damping
      gyroPan.x = MathUtil.smoothLerpPrecision(gyroPan.x, 0, elapsed, 2.5);
      gyroPan.y = MathUtil.smoothLerpPrecision(gyroPan.y, 0, elapsed, 2.5);

      // how far away from bg mid do we want to pan via gyroPan
      camFollow.x = bg.getGraphicMidpoint().x - gyroPan.x;
      camFollow.y = bg.getGraphicMidpoint().y - gyroPan.y;
    }
    #end

    if ((FlxG.sound.music?.volume ?? 1.0) < 0.8)
    {
      FlxG.sound.music.volume += 0.5 * elapsed;
    }

    handleInputs(elapsed);

    #if mobile
    if (optionsButton != null)
    {
      optionsButton.active = canInteract || optionsButton.confirming;
      optionsButton.enabled = optionsButton.active;
    }
    if (backButton != null)
    {
      backButton.active = canInteract || backButton.confirming;
      backButton.enabled = backButton.active;
    }
    #end
  }

  function handleInputs(elapsed:Float):Void
  {
    if (!canInteract) return;

    #if FEATURE_DEBUG_MENU
    // Open the debug menu, defaults to ` / ~
    // This includes stuff like the Chart Editor, so it should be present on all builds.
    if (controls.DEBUG_MENU)
    {
      persistentUpdate = false;
      uiStateMachine.transition(Interacting);

      FlxG.state.openSubState(new DebugMenuSubState());
    }
    #end

    #if FEATURE_DEBUG_FUNCTIONS
    // Ctrl+Alt+Shift+P = Character Unlock screen
    // Ctrl+Alt+Shift+W = Meet requirements for Pico Unlock
    // Ctrl+Alt+Shift+M = Revoke requirements for Pico Unlock
    // Ctrl+Alt+Shift+R = Score/Rank conflict test
    // Ctrl+Alt+Shift+N = Mark all characters as not seen
    // Ctrl+Alt+Shift+E = Dump save data
    // Ctrl+Alt+Shift+L = Force crash and create a log dump

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, P]))
    {
      FlxG.switchState(() -> new funkin.ui.charSelect.CharacterUnlockState('pico'));
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, W]))
    {
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
      // Give the user a score of 1 point on Weekend 1 story mode (Easy difficulty).
      // This makes the level count as cleared and displays the songs in Freeplay.
      funkin.save.Save.instance.setLevelScore('weekend1', 'easy', {
        score: 1,
        tallies: {
          sick: 0,
          good: 0,
          bad: 0,
          shit: 0,
          missed: 0,
          combo: 0,
          maxCombo: 0,
          totalNotesHit: 0,
          totalNotes: 0,
        }
      });
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, M]))
    {
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
      // Give the user a score of 0 points on Weekend 1 story mode (all difficulties).
      // This makes the level count as uncleared and no longer displays the songs in Freeplay.
      for (diff in ['easy', 'normal', 'hard'])
      {
        funkin.save.Save.instance.setLevelScore('weekend1', diff, {
          score: 0,
          tallies: {
            sick: 0,
            good: 0,
            bad: 0,
            shit: 0,
            missed: 0,
            combo: 0,
            maxCombo: 0,
            totalNotesHit: 0,
            totalNotes: 0,
          }
        });
      }
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, R]))
    {
      // Give the user a hypothetical overridden score,
      // and see if we can maintain that golden P rank.
      funkin.save.Save.instance.setSongScore('tutorial', 'easy', {
        score: 1234567,
        tallies: {
          sick: 0,
          good: 0,
          bad: 0,
          shit: 1,
          missed: 0,
          combo: 0,
          maxCombo: 0,
          totalNotesHit: 1,
          totalNotes: 10,
        }
      });
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, N]))
    {
      @:privateAccess
      {
        funkin.save.Save.instance.data.unlocks.charactersSeen = ["bf"];
        funkin.save.Save.instance.oldChar.value = false;
      }
    }

    if (InputUtil.allPressedWithDebounce([CONTROL, ALT, SHIFT, E]))
    {
      funkin.save.Save.instance.debug_dumpSaveJsonSave();
    }
    #end

    if (selectedSomethin) return;

    // --- Psych input handling, ported ---

    if (controls.UI_UP_P) changeItem(-1);
    if (controls.UI_DOWN_P) changeItem(1);

    var allowMouse:Bool = allowMouse;
    if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) // FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
    {
      allowMouse = false;
      FlxG.mouse.visible = true;
      timeNotMoving = 0;

      var selectedItem:Null<FlxSprite> = switch (curColumn)
      {
        case CENTER: centerItems.members[curSelected];
        case LEFT: leftItem;
        case RIGHT: rightItem;
      }

      if (leftItem != null && FlxG.mouse.overlaps(leftItem))
      {
        allowMouse = true;
        if (selectedItem != leftItem)
        {
          curColumn = LEFT;
          changeItem();
        }
      }
      else if (rightItem != null && FlxG.mouse.overlaps(rightItem))
      {
        allowMouse = true;
        if (selectedItem != rightItem)
        {
          curColumn = RIGHT;
          changeItem();
        }
      }
      else
      {
        var dist:Float = -1;
        var distItem:Int = -1;
        for (i in 0...optionShit.length)
        {
          var memb:FlxSprite = centerItems.members[i];
          if (FlxG.mouse.overlaps(memb))
          {
            var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2)
              + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
            if (dist < 0 || distance < dist)
            {
              dist = distance;
              distItem = i;
              allowMouse = true;
            }
          }
        }

        if (distItem != -1 && selectedItem != centerItems.members[distItem])
        {
          curColumn = CENTER;
          curSelected = distItem;
          changeItem();
        }
      }
    }
    else
    {
      timeNotMoving += elapsed;
      if (timeNotMoving > 2) FlxG.mouse.visible = false;
    }

    switch (curColumn)
    {
      case CENTER:
        if (controls.UI_LEFT_P && leftOption != null)
        {
          curColumn = LEFT;
          changeItem();
        }
        else if (controls.UI_RIGHT_P && rightOption != null)
        {
          curColumn = RIGHT;
          changeItem();
        }

      case LEFT:
        if (controls.UI_RIGHT_P)
        {
          curColumn = CENTER;
          changeItem();
        }

      case RIGHT:
        if (controls.UI_LEFT_P)
        {
          curColumn = CENTER;
          changeItem();
        }
    }

    // Consume the keypress that dismissed the previous substate: wait until
    // accept/back are released before letting them act on the menu again.
    if (blockAcceptUntilRelease && !controls.ACCEPT && !controls.BACK && !FlxG.keys.pressed.ENTER
      && !FlxG.keys.pressed.ESCAPE && !FlxG.keys.pressed.BACKSPACE)
    {
      blockAcceptUntilRelease = false;
    }

    if (controls.BACK_P && !blockAcceptUntilRelease)
    {
      selectedSomethin = true;
      FlxG.mouse.visible = false;
      goBack();
      return;
    }

    if ((controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse)) && !blockAcceptUntilRelease)
    {
      acceptCurrentOption();
    }
  }

  /**
   * Psych's `changeItem`: swap the selected item's animation to `selected`,
   * reset the rest to `idle`, and move the camera parallax target.
   */
  function changeItem(change:Int = 0):Void
  {
    if (change != 0) curColumn = CENTER;
    curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
    FunkinSound.playOnce(Paths.sound('scrollMenu'));

    for (item in centerItems)
    {
      if (item == null) continue;
      item.animation.play('idle');
      item.centerOffsets();
    }

    if (leftItem != null)
    {
      leftItem.animation.play('idle');
      leftItem.centerOffsets();
    }
    if (rightItem != null)
    {
      rightItem.animation.play('idle');
      rightItem.centerOffsets();
    }

    var selectedItem:Null<FlxSprite> = switch (curColumn)
    {
      case CENTER: centerItems.members[curSelected];
      case LEFT: leftItem;
      case RIGHT: rightItem;
    }

    if (selectedItem != null)
    {
      selectedItem.animation.play('selected');
      selectedItem.centerOffsets();
      camFollow.y = selectedItem.getGraphicMidpoint().y;
    }
  }
  function goOptions():Void
  {
    trace("OPTIONS: Interact complete.");
    startExitState(() -> new funkin.ui.options.OptionsState());
  }

  function goBack():Void
  {
    uiStateMachine.transition(Exiting);
    rememberedSelectedIndex = curSelected;
    FunkinSound.playOnce(Paths.sound('cancelMenu'));

    FlxG.switchState(() -> new TitleState());
  }
}
