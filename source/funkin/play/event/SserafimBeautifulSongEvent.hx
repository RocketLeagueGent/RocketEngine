package funkin.play.event;

// Data from the chart
import funkin.data.song.SongData.SongEventData;

/**
 * Registered no-op handler for the `sserafimBeautiful` song event.
 *
 * The actual behavior is implemented in the character script
 * `assets/preload/scripts/characters/sserafim-gf.hxc`
 * (`onSongEvent` sets `isBeautiful`).
 *
 * This class exists only so `SongEventRegistry` can resolve the event kind
 * and mark the event as activated; scripts do all the work.
 */
class SserafimBeautifulSongEvent extends SongEvent
{
  public function new()
  {
    super('sserafimBeautiful');
  }

  override public function handleEvent(data:SongEventData):Void
  {
    // Intentionally empty: handled by sserafim-gf.hxc.
  }

  override public function getTitle():String
  {
    return 'Sserafim Beautiful';
  }
}
