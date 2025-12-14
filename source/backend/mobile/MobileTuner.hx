package backend.mobile;

import backend.game.SaveData;

/**
 * Applies mobile-friendly quality tweaks when enabled.
 * Visual-only tweaks; gameplay timings untouched.
 */
class MobileTuner
{
	public static function apply():Void
	{
		if(!SaveData.data.get("useMobileQualityTier"))
			return;

		// Visual reductions that do not affect timing.
		if(SaveData.data.get("Shaders") != false)
			SaveData.data.set("Shaders", false);
		if(SaveData.data.get("Note Splashes") == null || SaveData.data.get("Note Splashes") == "ON")
			SaveData.data.set("Note Splashes", "PLAYER ONLY");
		if(SaveData.data.get("Hold Splashes") != false)
			SaveData.data.set("Hold Splashes", false);
		if(SaveData.data.get("Antialiasing") != false)
			SaveData.data.set("Antialiasing", false);
		if(SaveData.data.get("Low Quality") != true)
			SaveData.data.set("Low Quality", true);
	}
}
