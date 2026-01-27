package backend.song;

import backend.song.SongData.SwagSong;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
}
class Conductor
{
	public static var bpm:Float = 100;
	public static var crochet:Float = calcBeat(bpm);
	public static var stepCrochet:Float = calcStep(bpm);

	public static var songPos:Float = 0;

	public static var musicOffset:Float = 0;
	public static var inputOffset:Float = 0;

	public static function setBPM(bpm:Float = 100)
	{
		Conductor.bpm = bpm;
		crochet = calcBeat(bpm);
		stepCrochet = calcStep(bpm);
	}

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];
	public static function mapBPMChanges(?song:SwagSong)
	{
		bpmChangeMap = [];

		if(song == null) return;

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if (song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = song.notes[i].lengthInSteps;
			totalSteps += deltaSteps;
			totalPos += calcStep(curBPM) * deltaSteps;
		}
	}

	public static inline function calcBeat(bpm:Float):Float
		return (60000 / bpm); // 60 * 1000 = 60000, slightly faster than double div/mult

	public static inline function calcStep(bpm:Float):Float
		return calcBeat(bpm) * 0.25; // Mult is faster than div
	
	public static function calcStateStep():Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm
		}
		for(change in bpmChangeMap)
		{
			if (songPos >= change.songTime)
				lastChange = change;
		}

		var localStepCrochet = calcStep(lastChange.bpm);
		if(localStepCrochet == 0) return lastChange.stepTime;

		return lastChange.stepTime + Math.floor((songPos - lastChange.songTime) / localStepCrochet);
	}

	/**
	 * Updates the song position smoothly. 
	 * Fixes visual stutter by interpolating time instead of snapping to the audio thread every frame.
	 */
	public static function update(elapsed:Float):Void
	{
		if (flixel.FlxG.sound.music != null && flixel.FlxG.sound.music.playing)
		{
			// 1. Predict where we should be based on frame time
			songPos += elapsed * 1000;

			// 2. Check reality (Audio Thread)
			var curTime:Float = flixel.FlxG.sound.music.time;

			// 3. Resync logic
			// Use smooth interpolation to correct drift instead of hard snapping
			var drift = Math.abs(songPos - curTime);
			if (drift > 20) {
				// Stronger correction for larger drifts, but still interpolated
				var lerpFactor = (drift > 100) ? 1.0 : 0.1;
				songPos = (songPos * (1 - lerpFactor)) + (curTime * lerpFactor);
			} else {
				// Very subtle correction for micro-drifts
				songPos = (songPos * 0.98) + (curTime * 0.02);
			}
		}
	}
}