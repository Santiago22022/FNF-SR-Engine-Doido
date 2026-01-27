package backend.time;

import flixel.sound.FlxSound;

/**
 * Centralizes song time computation so visuals/input share the same timeline.
 * It can follow audio time (preferred) or fall back to accumulated time when audio is not reliable.
 */
class Timebase
{
	public var songPos:Float = 0;
	public var followAudio:Bool = true;
	public var driftThresholdMs:Float = 18;
	public var driftLerp:Float = 0.35;
	public var running:Bool = false;

	public function new() {}

	public function configure(followAudio:Bool, driftThresholdMs:Float = 18, driftLerp:Float = 0.35):Void
	{
		this.followAudio = followAudio;
		this.driftThresholdMs = driftThresholdMs;
		this.driftLerp = driftLerp;
	}

	public function setInitial(timeMs:Float):Void
	{
		songPos = timeMs;
	}

	public function start():Void
	{
		running = true;
	}

	public function stop():Void
	{
		running = false;
	}

	public function tick(elapsed:Float, audio:FlxSound, songSpeed:Float, advance:Bool):Float
	{
		if(!running || !advance)
			return songPos;
		
		// 1. Advance time based on high-precision frame timer (smoothest movement)
		songPos += elapsed * 1000 * songSpeed;

		// 2. Resync against audio clock if available
		if(followAudio && audio != null && audio.playing)
		{
			var audioTime:Float = audio.time;
			var drift:Float = Math.abs(songPos - audioTime);

			// Continuous smooth correction
			// Small drift? Very subtle nudge (keeps 144hz smoothness)
			// Large drift? Stronger pull (fixes lag spikes)
			var lerpFactor:Float = (drift > 30) ? 0.2 : 0.05;
			
			// If drift is massive (e.g. paused/seeked), snap instantly
			if(drift > 800) lerpFactor = 1.0;

			songPos = backend.utils.CoolUtil.fastLerp(songPos, audioTime, lerpFactor);
		}

		return songPos;
	}

	public function syncWithAudio(audio:FlxSound):Void
	{
		if(audio == null)
			return;

		if(audio.playing)
			songPos = audio.time; // Hard sync on demand
	}

	// Legacy helper removed as logic is now integrated in tick
	function applyDrift(target:Float):Void {}
}
