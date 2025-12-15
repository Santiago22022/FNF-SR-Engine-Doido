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

		if(followAudio && audio != null && audio.playing)
		{
			var target:Float = audio.time;
			applyDrift(target);
		}
		else
			songPos += elapsed * 1000 * songSpeed;

		return songPos;
	}

	public function syncWithAudio(audio:FlxSound):Void
	{
		if(audio == null)
			return;

		if(audio.playing)
			applyDrift(audio.time);
	}

	inline function applyDrift(target:Float):Void
	{
		var drift:Float = target - songPos;
		if(Math.abs(drift) <= driftThresholdMs)
		{
			songPos += drift * driftLerp;
			return;
		}
		songPos = target;
	}
}
