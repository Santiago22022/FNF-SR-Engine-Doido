package backend.mobile;

import flixel.FlxG;

/**
 * Very small helper to scale UI/text according to screen size.
 */
class UIScaler
{
	public static var baseHeight:Float = 720;
	public static var baseWidth:Float = 1280;
	public static var minScale:Float = 0.75;
	public static var maxScale:Float = 1.25;

	public static function scale():Float
	{
		var hScale = FlxG.height / baseHeight;
		var wScale = FlxG.width / baseWidth;
		var s = Math.min(Math.max(Math.min(hScale, wScale), minScale), maxScale);
		return s;
	}

	public static inline function scaled(value:Float):Float
		return value * scale();
}
