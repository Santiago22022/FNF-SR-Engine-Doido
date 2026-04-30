package backend.chart;

import backend.chart.ChartFormat.ChartDataV2;
import backend.song.SongData.SwagSong;
import backend.song.SongData.EventSong;
import haxe.ds.ArraySort;

/**
 * Normalizes engine/Psych charts into a time-based internal format (V2).
 * This is lightweight and keeps legacy data intact for now.
 */
class ChartNormalizer
{
	public static function normalize(song:SwagSong, events:EventSong):ChartDataV2
	{
		var result:ChartDataV2 = {
			meta: {
				version: 2,
				song: song.song,
				difficulty: song.difficulty
			},
			bpm: song.bpm,
			changes: [],
			notes: [],
			events: []
		};

		if(song.bpmChanges != null)
			for(change in song.bpmChanges)
				result.changes.push({time: change.songTime, bpm: change.bpm});

		for(section in song.notes)
		{
			for(note in section.sectionNotes)
			{
				var lane:Int = Std.int(note[1]);
				var time:Float = note[0];
				var len:Float = note[2];
				var kind:String = (note.length > 3 ? Std.string(note[3]) : "default");
				result.notes.push({time: time, lane: lane, length: len, kind: kind});
			}
		}

		if(events != null && events.events != null)
			for(ev in events.events)
				result.events.push({time: ev.songTime, name: ev.eventName, value1: ev.value1, value2: ev.value2});

		ArraySort.sort(result.notes, function(a, b) return (a.time < b.time ? -1 : 1));
		ArraySort.sort(result.events, function(a, b) return (a.time < b.time ? -1 : 1));
		return result;
	}
}
