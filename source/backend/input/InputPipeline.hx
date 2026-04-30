package backend.input;

import backend.input.InputEvent;
import backend.input.SpamGuard;

/**
 * Collects raw input edges (press/release), timestamps them against song time,
 * and exposes a small buffer so presses can be matched deterministically to notes.
 */
class InputPipeline
{
	public var useBuffer:Bool = false;
	public var earlyMs:Int = 0;
	public var lateMs:Int = 0;
	public var spamGuard:SpamGuard;

	var buffers:Array<Array<InputEvent>> = [[], [], [], []];
	var down:Array<Bool> = [false, false, false, false];
	var maxKeepMs:Int = 1500;

	public function new()
	{
		spamGuard = new SpamGuard();
	}

	public function configure(useBuffer:Bool, earlyMs:Int, lateMs:Int, antiMash:Bool):Void
	{
		this.useBuffer = useBuffer;
		this.earlyMs = clampMs(earlyMs);
		this.lateMs = clampMs(lateMs);
		spamGuard.enabled = antiMash;
	}

	inline function clampMs(v:Int):Int
	{
		if(v < 0) return 0;
		if(v > 500) return 500;
		return v;
	}

	public function update(songPos:Float, _inputOffset:Float, pressed:Array<Bool>, justPressed:Array<Bool>, _released:Array<Bool>):Void
	{
		var now:Float = songPos;
		for(lane in 0...4)
		{
			var newPress:Bool = justPressed[lane] && !down[lane];
			if(newPress)
			{
				if(spamGuard.allowPress(lane, now))
					buffers[lane].push({type: Press, lane: lane, timeMs: now});
				down[lane] = pressed[lane];
			}
			else if(!pressed[lane] && down[lane])
			{
				down[lane] = false;
				spamGuard.onRelease(lane, now);
			}
			else
				down[lane] = pressed[lane];
		}

		prune(now);
	}

	public function hasPendingPress():Bool
	{
		for(buf in buffers)
			if(buf.length > 0) return true;
		return false;
	}

	public function hasPress(lane:Int):Bool
	{
		return lane >= 0 && lane < buffers.length && buffers[lane].length > 0;
	}

	public function peekPress(lane:Int):InputEvent
	{
		if(lane < 0 || lane >= buffers.length) return null;
		var buf = buffers[lane];
		return buf.length > 0 ? buf[0] : null;
	}

	public function consumePress(lane:Int):InputEvent
	{
		if(lane < 0 || lane >= buffers.length) return null;
		var buf = buffers[lane];
		if(buf.length <= 0) return null;
		return buf.shift();
	}

	inline public function deltaToNote(evt:InputEvent, noteTime:Float, inputOffset:Float):Float
		return noteTime + inputOffset - evt.timeMs;

	function prune(songPos:Float):Void
	{
		var cutoff:Float = songPos - (maxKeepMs + earlyMs + lateMs);
		for(buf in buffers)
			while(buf.length > 0 && buf[0].timeMs < cutoff)
				buf.shift();
	}
}
