package funkin.play.event;

// Data from the chart
import funkin.data.song.SongData.SongEventData;

/**
 * Registered no-op handler for the `sserafimLights` song event.
 *
 * The actual behavior is implemented in the stage script
 * `assets/preload/scripts/stages/sserafim.hxc` (`onSongEvent` switch).
 *
 * This class exists only so `SongEventRegistry` can resolve the event kind
 * and mark the event as activated; scripts do all the work.
 */
class SserafimLightsSongEvent extends SongEvent
{
  public function new()
  {
    super('sserafimLights');
  }

  override public function handleEvent(data:SongEventData):Void
  {
    // Intentionally empty: handled by sserafim.hxc.
  }

  override public function getTitle():String
  {
    return 'Sserafim Lights';
  }
}
