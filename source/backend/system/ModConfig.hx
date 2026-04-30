package backend.system;

import flixel.util.FlxSave;
import StringTools;
import backend.system.ModTypes.ModInfo;

typedef ModConfigData = {
	var enabled:Array<String>;
	var order:Array<String>;
}

/**
 * Stores persistent mod enablement and ordering.
 * Uses its own save slot to avoid coupling with option saves.
 */
class ModConfig
{
	static var save:FlxSave = new FlxSave();
	static var initialized:Bool = false;

	public static var enabled:Array<String> = [];
	public static var order:Array<String> = [];

	public static function init():Void
	{
		if(initialized) return;
		save.bind("mod-config");
		load();
		initialized = true;
	}

	static function load():Void
	{
		enabled = [];
		order = [];
		var data:Dynamic = save.data.modConfig;
		if(data != null)
		{
			if(Reflect.hasField(data, "enabled"))
				enabled = ModConfig.sanitizeArray(cast Reflect.field(data, "enabled"));
			if(Reflect.hasField(data, "order"))
				order = ModConfig.sanitizeArray(cast Reflect.field(data, "order"));
		}
	}

	public static function persist():Void
	{
		save.data.modConfig = {
			enabled: enabled.copy(),
			order: order.copy()
		};
		save.flush();
	}

	public static function persistFrom(mods:Array<ModInfo>):Void
	{
		order = [];
		enabled = [];
		for(mod in mods)
		{
			order.push(mod.id);
			if(mod.enabled)
				enabled.push(mod.id);
		}
		persist();
	}

	public static function isEnabled(id:String, fallback:Bool):Bool
	{
		if(id == null) return fallback;
		return enabled.length > 0 ? enabled.contains(id.toLowerCase()) : fallback;
	}

	public static function priorityIndex(id:String, fallback:Int):Int
	{
		if(id == null) return fallback;
		var idx = order.indexOf(id.toLowerCase());
		return idx == -1 ? fallback : idx;
	}

	static function sanitizeArray(arr:Array<String>):Array<String>
	{
		var out:Array<String> = [];
		if(arr == null) return out;
		var seen:Map<String, Bool> = new Map();
		for(item in arr)
		{
			if(item == null) continue;
			var clean = StringTools.trim(item.toLowerCase());
			if(clean == "") continue;
			if(!seen.exists(clean))
			{
				seen.set(clean, true);
				out.push(clean);
			}
		}
		return out;
	}
}
