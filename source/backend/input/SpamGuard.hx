package backend.input;

/**
 * Simple per-lane anti-mash guard.
 * Blocks key-repeat bursts and excessive spam without affecting legacy behavior when disabled.
 */
class SpamGuard
{
	public var enabled:Bool = false;
	public var maxPerSecond:Int = 16;
	public var spamWindowMs:Int = 250;
	public var spamThreshold:Int = 5;
	public var cooldownMs:Int = 120;

	var laneCooldown:Array<Float> = [0, 0, 0, 0];
	var laneHistory:Array<Array<Float>> = [[], [], [], []];

	public function new() {}

	public function allowPress(lane:Int, now:Float):Bool
	{
		if(!enabled)
			return true;

		if(lane < 0 || lane >= laneHistory.length)
			return false;

		if(laneCooldown[lane] > now)
			return false;

		var history = laneHistory[lane];
		trimHistory(history, now - spamWindowMs);

		var minInterval:Float = (maxPerSecond > 0 ? 1000.0 / maxPerSecond : 0);
		var lastTime:Float = (history.length > 0 ? history[history.length - 1] : Math.NEGATIVE_INFINITY);
		if(now - lastTime < minInterval)
			return false;

		history.push(now);
		if(history.length >= spamThreshold)
			laneCooldown[lane] = now + cooldownMs;

		return true;
	}

	public function onRelease(lane:Int, now:Float):Void
	{
		if(!enabled)
			return;

		if(lane < 0 || lane >= laneHistory.length)
			return;

		trimHistory(laneHistory[lane], now - spamWindowMs);
		if(laneCooldown[lane] < now - cooldownMs)
			laneCooldown[lane] = 0;
	}

	inline function trimHistory(history:Array<Float>, cutoff:Float):Void
	{
		while(history.length > 0 && history[0] < cutoff)
			history.shift();
	}
}
