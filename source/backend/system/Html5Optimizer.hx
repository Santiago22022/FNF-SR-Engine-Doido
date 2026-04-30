package backend.system;

#if html5
import Main;
import backend.game.SaveData;
import flixel.FlxG;
import openfl.display.StageQuality;

class Html5Optimizer
{
	static var applied:Bool = false;

	public static function apply():Void
	{
		if (applied) return;
		applied = true;
		var targetFps:Int = 60;
		var changedSettings:Bool = false;
		if (SaveData.data != null && SaveData.data.exists("Framerate Cap"))
		{
			var saved = Std.int(SaveData.data.get("Framerate Cap"));
			if (saved > 0)
				targetFps = saved < targetFps ? saved : targetFps;
			if (saved <= 0 || saved > targetFps)
			{
				SaveData.data.set("Framerate Cap", targetFps);
				changedSettings = true;
			}
		}

		if (SaveData.data != null)
		{
			changedSettings = forceSetting("Shaders", false) || changedSettings;
			changedSettings = forceSetting("Antialiasing", false) || changedSettings;
			changedSettings = forceSetting("Low Quality", true) || changedSettings;
			changedSettings = forceSetting("Unfocus Pause", true) || changedSettings;
		}

		if (changedSettings)
			SaveData.save();
		
		Main.changeFramerate(targetFps);
		if (FlxG.stage != null)
			FlxG.stage.quality = StageQuality.LOW;

		FlxG.autoPause = true;
	}

	static inline function forceSetting(key:String, value:Bool):Bool
	{
		if (!SaveData.data.exists(key) || SaveData.data.get(key) == value)
			return false;

		SaveData.data.set(key, value);
		return true;
	}
}
#end
