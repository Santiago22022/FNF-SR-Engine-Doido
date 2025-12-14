package backend.mobile;

import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import lime.system.System;

/**
 * Minimal safe area helper for mobile/notch devices.
 * Uses heuristics when platform APIs are unavailable.
 */
class SafeArea
{
	public static var insets:FlxRect = new FlxRect();
	public static var safeRect:FlxRect = new FlxRect();
	public static var enabled:Bool = false;

	public static function init(useSafeArea:Bool):Void
	{
		enabled = useSafeArea;
		recalculate();
	}

	public static function recalculate():Void
	{
		var w = FlxG.width;
		var h = FlxG.height;

		var top = 0.0;
		var bottom = 0.0;
		var left = 0.0;
		var right = 0.0;

		if(enabled)
		{
			#if (ios || android || mobile)
			// Heuristic: reserve 6% of height on top/bottom and 3% on sides for notches/gestures.
			top = Math.max(top, h * 0.06);
			bottom = Math.max(bottom, h * 0.06);
			left = Math.max(left, w * 0.03);
			right = Math.max(right, w * 0.03);
			#end
		}

		insets.set(left, top, right, bottom);
		safeRect.set(left, top, w - left - right, h - top - bottom);
	}

	public static inline function apply(pos:FlxPoint, anchorX:Float, anchorY:Float):FlxPoint
	{
		// anchor in [0..1]; 0=left/top,1=right/bottom
		var out = FlxPoint.get(pos.x, pos.y);
		out.x = safeRect.x + anchorX * safeRect.width;
		out.y = safeRect.y + anchorY * safeRect.height;
		return out;
	}
}
