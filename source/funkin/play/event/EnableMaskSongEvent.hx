package funkin.play.event;

// Data from the chart
import funkin.data.song.SongData.SongEventData;

/**
 * Registered no-op handler for the `EnableMask` song event.
 *
 * The actual behavior is implemented in the stage script
 * `assets/preload/scripts/stages/tankmanBattlefieldErect.hxc`
 * (`onSongEvent` case 'EnableMask').
 *
 * This class exists only so `SongEventRegistry` can resolve the event kind
 * and mark the event as activated; scripts do all the work.
 */
class EnableMaskSongEvent extends SongEvent
{
  public function new()
  {
    super('EnableMask');
  }

  override public function handleEvent(data:SongEventData):Void
  {
    // Intentionally empty: handled by tankmanBattlefieldErect.hxc.
  }

  override public function getTitle():String
  {
    return 'Enable Mask';
  }
}
