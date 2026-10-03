package funkin.ui;

import funkin.ui.Alphabet;
import funkin.ui.MenuList;

@:nullSafety
class AlphabetMenuList extends MenuTypedList<AlphabetMenuItem>
{
  public function new(navControls:NavControls = Vertical, ?wrapMode)
  {
    super(navControls, wrapMode);
  }

  public function createItem(x = 0.0, y = 0.0, name:String, ?callback:Void->Void, fireInstantly = false,
      available:Bool = true):AlphabetMenuItem
  {
    var item:AlphabetMenuItem = new AlphabetMenuItem(x, y, name, callback, available);
    item.fireInstantly = fireInstantly;

    return addItem(name, item);
  }
}

@:nullSafety
class AlphabetMenuItem extends MenuTypedItem<Alphabet>
{
  public function new(x = 0.0, y = 0.0, name:String, ?callback:Void->Void, available:Bool = true)
  {
    var alphabet:Alphabet = new Alphabet(x, y, name, false);
    super(x, y, alphabet, name, callback, available);
    setEmptyBackground();
  }

  override function setItem(name:String, ?callback:Void->Void)
  {
    if (label != null)
    {
      label.text = name;
      label.alpha = alpha;
      width = label.width;
      height = label.height;
    }

    super.setItem(name, callback);
  }

  override function set_label(value:Alphabet):Alphabet
  {
    super.set_label(value);
    setItem(name, callback);
    return value;
  }
}
