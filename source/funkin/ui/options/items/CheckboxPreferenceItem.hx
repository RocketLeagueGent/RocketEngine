package funkin.ui.options.items;

import flixel.FlxSprite.FlxSprite;

class CheckboxPreferenceItem extends FlxSprite
{
  public var currentValue(default, set):Bool;

  /**
   * Alpha this checkbox falls back to; lowered to 0.5 when unavailable so the
   * per-frame selection sync can multiply against it (Psych-style dimming).
   */
  public var baseAlpha:Float = 1.0;

  public function new(x:Float, y:Float, defaultValue:Bool = false, available:Bool = true)
  {
    super(x, y);

    frames = Paths.getSparrowAtlas('checkboxThingie');
    animation.addByPrefix('static', 'Check Box unselected', 24, false);
    animation.addByPrefix('checked', 'Check Box selecting animation', 24, false);

    setGraphicSize(Std.int(width * 0.7));
    updateHitbox();

    if (!available)
    {
      this.alpha = 0.5;
      baseAlpha = 0.5;
    }

    this.currentValue = defaultValue;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    switch (animation.curAnim.name)
    {
      case 'static':
        offset.set();
      case 'checked':
        offset.set(17, 70);
    }
  }

  function set_currentValue(value:Bool):Bool
  {
    if (value)
    {
      animation.play('checked', true);
    }
    else
    {
      animation.play('static');
    }

    return currentValue = value;
  }
}
