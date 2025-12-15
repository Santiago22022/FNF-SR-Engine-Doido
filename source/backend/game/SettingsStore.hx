package backend.game;

import flixel.util.FlxSave;
import haxe.DynamicAccess;
import backend.game.SettingsDefaults;
import backend.game.SettingsModel;

class SettingsStore
{
	static var save:FlxSave = new FlxSave();
	static var bound:Bool = false;
	static inline var SAVE_NAME:String = "settings";

	static function ensure():Void
	{
		if(bound) return;
		save.bind(SAVE_NAME);
		bound = true;
	}

	public static function load():SettingsModel
	{
		ensure();
		var raw:Dynamic = save.data.settingsModel;
		if(raw == null)
			return SettingsDefaults.create();

		var model:SettingsModel = cast raw;
		model = SettingsDefaults.migrate(model);
		if(model.settings == null)
			model.settings = new DynamicAccess<Dynamic>();
		return model;
	}

	public static function saveModel(model:SettingsModel):Void
	{
		ensure();
		if(model == null)
			model = SettingsDefaults.create();
		save.data.settingsModel = model;
		save.flush();
	}

	public static function reset():SettingsModel
	{
		var model = SettingsDefaults.create();
		saveModel(model);
		return model;
	}
}
