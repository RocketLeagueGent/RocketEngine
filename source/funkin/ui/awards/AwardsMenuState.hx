package funkin.ui.awards;

import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxRect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.group.FlxSpriteGroup;
import flixel.addons.transition.FlxTransitionableState;
import funkin.awards.Awards;
import funkin.awards.Awards.Award;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinCamera;
import funkin.ui.MusicBeatState;
import funkin.ui.MusicBeatSubState;
import funkin.ui.mainmenu.MainMenuState;

/**
 * A single row in the Awards menu grid, resolved from an `Award` definition.
 */
typedef AwardOption =
{
  var name:String;
  var displayName:String;
  var description:String;
  var curProgress:Float;
  var maxProgress:Float;
  var decProgress:Int;
  var unlocked:Bool;
  var ID:Int;
}

/**
 * Awards menu, ported from Psych Engine 1.0.4's `AchievementsMenuState`.
 *
 * Shows a grid of award icons (4 per row), with the selected award's name,
 * description, and progress bar in a panel at the bottom of the screen.
 * RESET opens a confirmation substate that wipes the selected award.
 */
class AwardsMenuState extends MusicBeatState
{
  public var curSelected:Int = 0;

  public var options:Array<AwardOption> = [];
  public var grpOptions:FlxSpriteGroup;
  public var nameText:FlxText;
  public var descText:FlxText;
  public var progressTxt:FlxText;

  public var barTween:FlxTween = null;
  public var barDisplayValue:Float = 0;

  var barBG:FlxSprite;
  var barFill:FlxSprite;

  var camFollow:FlxObject;

  static final MAX_PER_ROW:Int = 4;

  var goingBack:Bool = false;

  public function new()
  {
    super();
  }

  override public function create():Void
  {
    super.create();

    FlxG.cameras.reset(new FunkinCamera('awardsMenu'));
    transIn = FlxTransitionableState.defaultTransIn;
    transOut = FlxTransitionableState.defaultTransOut;

    // Prepare the award list. Hidden awards only show up once unlocked.
    for (awardName in Awards.sortedNames())
    {
      var data:Award = Awards.get(awardName);
      if (data == null) continue;
      var unlocked:Bool = Awards.isUnlocked(awardName);
      if (data.hidden == true && !unlocked) continue;
      options.push(makeAwardOption(awardName, data, unlocked));
    }
    options.sort(function(a:AwardOption, b:AwardOption):Int return a.ID - b.ID);

    camFollow = new FlxObject(0, 0, 1, 1);
    add(camFollow);

    // Background.
    var menuBG:FlxSprite = new FlxSprite(Paths.image('menuDesat'));
    menuBG.antialiasing = true;
    menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set();
    menuBG.color = 0xFF31B0D1;
    add(menuBG);

    // Award icon grid.
    grpOptions = new FlxSpriteGroup();
    grpOptions.scrollFactor.x = 0;

    for (option in options)
    {
      var hasAntialias:Bool = true;
      var graphicKey:String;

      if (option.unlocked)
      {
        // Prefer the pixel-art variant when it exists (Week 6).
        final pixelKey:String = 'achievements/${option.name}-pixel';
        if (Assets.exists(Paths.image(pixelKey)))
        {
          graphicKey = pixelKey;
          hasAntialias = false;
        }
        else
        {
          graphicKey = 'achievements/${option.name}';
        }

        if (!Assets.exists(Paths.image(graphicKey))) graphicKey = 'achievements/lockedachievement';
      }
      else
      {
        graphicKey = 'achievements/lockedachievement';
      }

      var spr:FlxSprite = new FlxSprite(0, Math.floor(grpOptions.members.length / MAX_PER_ROW) * 180)
        .loadGraphic(Paths.image(graphicKey));
      spr.scrollFactor.x = 0;
      spr.screenCenter(X);
      spr.x += 180 * ((grpOptions.members.length % MAX_PER_ROW) - MAX_PER_ROW / 2) + spr.width / 2 + 15;
      spr.ID = grpOptions.members.length;
      spr.antialiasing = hasAntialias;
      grpOptions.add(spr);
    }

    // Dark panel behind the icon grid.
    var box:FlxSprite = new FlxSprite(0, -30).makeGraphic(1, 1, FlxColor.BLACK);
    box.scale.set(grpOptions.width + 60, grpOptions.height + 60);
    box.updateHitbox();
    box.alpha = 0.6;
    box.scrollFactor.x = 0;
    box.screenCenter(X);
    add(box);
    add(grpOptions);

    // Bottom info panel.
    var bottomBox:FlxSprite = new FlxSprite(0, 570).makeGraphic(1, 1, FlxColor.BLACK);
    bottomBox.scale.set(FlxG.width, FlxG.height - bottomBox.y);
    bottomBox.updateHitbox();
    bottomBox.alpha = 0.6;
    bottomBox.scrollFactor.set();
    add(bottomBox);

    nameText = new FlxText(50, bottomBox.y + 10, FlxG.width - 100, '', 32);
    nameText.setFormat(Paths.font(), 32, FlxColor.WHITE, FlxTextAlign.CENTER);
    nameText.scrollFactor.set();

    descText = new FlxText(50, nameText.y + 38, FlxG.width - 100, '', 24);
    descText.setFormat(Paths.font(), 24, FlxColor.WHITE, FlxTextAlign.CENTER);
    descText.scrollFactor.set();

    // Progress bar (this engine has no Bar class, so we roll our own).
    final barWidth:Int = 500;
    final barHeight:Int = 32;
    barBG = new FlxSprite(0, descText.y + 52).makeGraphic(barWidth, barHeight, FlxColor.BLACK);
    barBG.screenCenter(X);
    barBG.scrollFactor.set();
    barBG.alpha = 0.8;

    barFill = new FlxSprite(barBG.x, barBG.y).makeGraphic(barWidth, barHeight, FlxColor.WHITE);
    barFill.scrollFactor.set();
    barFill.clipRect = new FlxRect(0, 0, 0, barHeight);

    progressTxt = new FlxText(50, barBG.y - 6, FlxG.width - 100, '', 32);
    progressTxt.setFormat(Paths.font(), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    progressTxt.borderSize = 2;
    progressTxt.scrollFactor.set();

    add(barBG);
    add(barFill);
    add(progressTxt);
    add(descText);
    add(nameText);

    _changeSelection();

    FlxG.camera.follow(camFollow, null, 0.15);
    FlxG.camera.scroll.y = -FlxG.height;
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (goingBack) return;

    if (options.length > 1)
    {
      var add:Int = 0;
      if (controls.UI_LEFT_P) add = -1;
      else if (controls.UI_RIGHT_P) add = 1;

      if (add != 0)
      {
        var oldRow:Int = Math.floor(curSelected / MAX_PER_ROW);
        var rowSize:Int = Std.int(Math.min(MAX_PER_ROW, options.length - oldRow * MAX_PER_ROW));

        curSelected += add;
        var curRow:Int = Math.floor(curSelected / MAX_PER_ROW);
        if (curSelected >= options.length) curRow++;

        if (curRow != oldRow)
        {
          if (curRow < oldRow) curSelected += rowSize;
          else curSelected -= rowSize;
        }
        _changeSelection();
      }

      if (options.length > MAX_PER_ROW)
      {
        var add:Int = 0;
        if (controls.UI_UP_P) add = -1;
        else if (controls.UI_DOWN_P) add = 1;

        if (add != 0)
        {
          var diff:Int = curSelected - (Math.floor(curSelected / MAX_PER_ROW) * MAX_PER_ROW);
          curSelected += add * MAX_PER_ROW;
          if (curSelected < 0)
          {
            curSelected += Math.ceil(options.length / MAX_PER_ROW) * MAX_PER_ROW;
            if (curSelected >= options.length) curSelected -= MAX_PER_ROW;
          }
          if (curSelected >= options.length)
          {
            curSelected = diff;
          }
          _changeSelection();
        }
      }

      if (controls.RESET_P && (options[curSelected].unlocked || options[curSelected].curProgress > 0))
      {
        openSubState(new ResetAwardSubState());
      }
    }

    if (controls.BACK_P)
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      goingBack = true;
      FlxG.switchState(() -> new MainMenuState());
    }
  }

  override public function destroy():Void
  {
    if (barTween != null)
    {
      barTween.cancel();
      barTween = null;
    }
    super.destroy();
  }

  function makeAwardOption(name:String, data:Award, unlocked:Bool):AwardOption
  {
    final maxScore:Float = (data.maxScore != null && data.maxScore > 0) ? data.maxScore : 0;
    return {
      name: name,
      displayName: unlocked ? data.name : '???',
      description: data.description,
      curProgress: maxScore > 0 ? Awards.getScore(name) : 0,
      maxProgress: maxScore,
      decProgress: (data.maxDecimals != null) ? data.maxDecimals : 0,
      unlocked: unlocked,
      ID: data.ID ?? 0
    };
  }

  function _changeSelection():Void
  {
    FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);

    final option:AwardOption = options[curSelected];
    final hasProgress:Bool = option.maxProgress > 0;
    nameText.text = option.displayName;
    descText.text = option.description;
    progressTxt.visible = hasProgress;
    barBG.visible = barFill.visible = hasProgress;

    if (barTween != null)
    {
      barTween.cancel();
      barTween = null;
    }

    if (hasProgress)
    {
      progressTxt.text = formatProgress(option.curProgress, option.decProgress) + ' / ' + formatProgress(option.maxProgress, option.decProgress);
      barTween = FlxTween.tween(this, {barDisplayValue: option.curProgress / option.maxProgress}, 0.5,
        {ease: FlxEase.quadOut, onUpdate: _ -> updateBarFill(), onComplete: _ -> updateBarFill()});
    }
    else
    {
      barDisplayValue = 0;
      updateBarFill();
    }

    // Scroll the camera so the selected row stays in view.
    final maxRows:Int = Math.floor(grpOptions.members.length / MAX_PER_ROW);
    if (maxRows > 0)
    {
      final camY:Float = FlxG.height / 2
        + (Math.floor(curSelected / MAX_PER_ROW) / maxRows) * Math.max(0, grpOptions.height - FlxG.height / 2 - 50)
        - 100;
      camFollow.setPosition(0, camY);
    }
    else
    {
      camFollow.setPosition(0, grpOptions.members[curSelected].getGraphicMidpoint().y - 100);
    }

    grpOptions.forEach(function(spr:FlxSprite)
    {
      spr.alpha = 0.6;
      if (spr.ID == curSelected) spr.alpha = 1;
    });
  }

  /**
   * Refresh the progress bar fill from the tweened `barDisplayValue`.
   */
  public function updateBarFill():Void
  {
    if (barFill == null) return;
    barFill.clipRect = new FlxRect(3, 3, Math.max(0, (barFill.width - 6) * barDisplayValue), barFill.height - 6);
    barFill.clipRect = barFill.clipRect; // flixel needs a reassignment to invalidate the clip.
  }

  static function formatProgress(value:Float, decimals:Int):String
  {
    if (decimals <= 0) return Std.string(Std.int(value));
    final mult:Float = Math.pow(10, decimals);
    return Std.string(Math.round(value * mult) / mult);
  }
}

/**
 * Confirmation dialog for resetting an award, ported from Psych Engine's
 * `ResetAchievementSubstate` (Alphabet replaced with FlxText).
 */
class ResetAwardSubState extends MusicBeatSubState
{
  var onYes:Bool = false;
  var yesText:FlxText;
  var noText:FlxText;
  var parent:AwardsMenuState;

  public function new()
  {
    super();
    parent = cast FlxG.state;

    var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    bg.alpha = 0;
    bg.scrollFactor.set();
    add(bg);
    FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});

    var title:FlxText = new FlxText(0, 180, FlxG.width, 'Reset Achievement:', 48);
    title.setFormat(Paths.font(), 48, FlxColor.WHITE, FlxTextAlign.CENTER);
    title.scrollFactor.set();
    add(title);

    var nameLbl:FlxText = new FlxText(50, title.y + 90, FlxG.width - 100, parent.options[parent.curSelected].displayName, 40);
    nameLbl.setFormat(Paths.font(), 40, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    nameLbl.borderSize = 2;
    nameLbl.scrollFactor.set();
    add(nameLbl);

    yesText = new FlxText(0, nameLbl.y + 120, 300, 'Yes', 40);
    yesText.setFormat(Paths.font(), 40, FlxColor.RED, FlxTextAlign.CENTER);
    yesText.screenCenter(X);
    yesText.x -= 200;
    yesText.scrollFactor.set();
    add(yesText);

    noText = new FlxText(0, nameLbl.y + 120, 300, 'No', 40);
    noText.setFormat(Paths.font(), 40, FlxColor.WHITE, FlxTextAlign.CENTER);
    noText.screenCenter(X);
    noText.x += 200;
    noText.scrollFactor.set();
    add(noText);

    updateOptions();
  }

  override public function update(elapsed:Float):Void
  {
    if (controls.BACK_P)
    {
      close();
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      return;
    }

    super.update(elapsed);

    if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
    {
      onYes = !onYes;
      updateOptions();
    }

    if (controls.ACCEPT_P)
    {
      if (onYes)
      {
        final option:AwardOption = parent.options[parent.curSelected];

        Awards.reset(option.name);

        option.unlocked = false;
        option.curProgress = 0;
        option.displayName = '???';
        parent.nameText.text = '???';
        if (option.maxProgress > 0) parent.progressTxt.text = '0 / ' + Std.string(Std.int(option.maxProgress));

        var icon:FlxSprite = parent.grpOptions.members[parent.curSelected];
        icon.loadGraphic(Paths.image('achievements/lockedachievement'));
        icon.antialiasing = true;

        if (parent.progressTxt.visible)
        {
          if (parent.barTween != null)
          {
            parent.barTween.cancel();
            parent.barTween = null;
          }
          parent.barTween = FlxTween.tween(parent, {barDisplayValue: 0}, 0.5,
            {ease: FlxEase.quadOut, onUpdate: _ -> parent.updateBarFill(), onComplete: _ -> parent.updateBarFill()});
        }

        FunkinSound.playOnce(Paths.sound('cancelMenu'));
      }
      close();
      return;
    }
  }

  function updateOptions():Void
  {
    final scales:Array<Float> = [0.75, 1];
    final alphas:Array<Float> = [0.6, 1.25];
    final confirmInt:Int = onYes ? 1 : 0;

    yesText.alpha = alphas[confirmInt];
    yesText.scale.set(scales[confirmInt], scales[confirmInt]);
    noText.alpha = alphas[1 - confirmInt];
    noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
    FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);
  }
}
