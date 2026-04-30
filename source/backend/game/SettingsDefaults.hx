package backend.game;

import haxe.DynamicAccess;
import backend.game.SettingsModel;

class SettingsDefaults
{
	public static inline var CURRENT_SCHEMA:Int = 1;

	public static function create():SettingsModel
	{
		return {
			schemaVersion: CURRENT_SCHEMA,
			settings: new DynamicAccess<Dynamic>()
		};
	}

	public static function migrate(model:SettingsModel):SettingsModel
	{
		if(model == null)
			return create();

		// ensure schemaVersion is a valid Int
		if(Reflect.hasField(model, "schemaVersion"))
		{
			var sv:Dynamic = Reflect.field(model, "schemaVersion");
			if(sv == null)
				model.schemaVersion = 0;
			else
				model.schemaVersion = Std.int(sv);
		}
		else
			model.schemaVersion = 0;

		model.schemaVersion = CURRENT_SCHEMA;
		if(model.settings == null)
			model.settings = new DynamicAccess<Dynamic>();
		return model;
	}
}
