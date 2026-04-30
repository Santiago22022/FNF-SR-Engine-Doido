package backend.time;

/**
 * Preset timing windows for different feels.
 */
class HitWindows
{
	public static inline var PRESET_LEGACY:String = "Legacy";
	public static inline var PRESET_ARCADE:String = "Arcade";
	public static inline var PRESET_LENIENT:String = "Lenient";
	public static inline var PRESET_TIGHT:String = "Tight";

	public static function getPreset(name:String):HitWindowConfig
	{
		return switch(name)
		{
			case PRESET_ARCADE: {hit: 120, early: 65, late: 65, spamGuard: true};
			case PRESET_LENIENT: {hit: 150, early: 80, late: 80, spamGuard: false};
			case PRESET_TIGHT: {hit: 90, early: 50, late: 50, spamGuard: true};
			default: {hit: 150, early: 0, late: 0, spamGuard: false};
		}
	}
}

typedef HitWindowConfig = {
	var hit:Int;
	var early:Int;
	var late:Int;
	var spamGuard:Bool;
}
